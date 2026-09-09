import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {onDocumentWritten} from 'firebase-functions/v2/firestore';
import * as logger from 'firebase-functions/logger';

import {calculateConfidence} from './confidenceCalculation';
import {validateVote} from './voteValidation';

const HAZARD_COLLECTION = 'hazard_reports';
const RELEVANT_VOTE_FIELDS = [
  'voteType', 'createdAt', 'distanceFromHazardMeters', 'proximityBand',
  'isGpsValidated', 'hasPhotoEvidence', 'evidenceStorage',
  'evidenceValidationResult', 'sceneMatchScore', 'serverValidationStatus',
  'aiAnalysisStatus', 'aiEvidenceWeightMultiplier', 'aiSceneMatchScore',
  'aiHazardRelevanceScore', 'aiConditionAssessment', 'aiConditionConfidence',
  'aiAgreement', 'aiAnalysisCompletedAt',
];

function comparable(value: unknown): string {
  if (typeof value === 'object' && value !== null) {
    const timestamp = value as {toMillis?: () => number};
    if (typeof timestamp.toMillis === 'function') return String(timestamp.toMillis());
  }
  return JSON.stringify(value);
}

export function shouldRecomputeConfidence(
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
): boolean {
  if (before === undefined || after === undefined) return true;
  return RELEVANT_VOTE_FIELDS.some((field) =>
    comparable(before[field]) !== comparable(after[field]));
}

export interface StoredVote {
  id: string;
  data: Record<string, unknown>;
}

export function selectVotesForConfidence(
  votes: StoredVote[],
  hazardStatus: unknown,
): Record<string, unknown>[] {
  const accepted: Record<string, unknown>[] = [];
  for (const voteDoc of votes) {
    const vote = voteDoc.data;
    const status = vote['serverValidationStatus'];
    if (status === 'VALID') {
      accepted.push(vote);
      continue;
    }
    if (status === 'INVALID') continue;

    // Missing/NOT_VALIDATED metadata is treated as legacy: validate the vote
    // in memory instead of requiring a migration or blindly trusting it.
    const validation = validateVote(vote, {
      voteId: voteDoc.id,
      hazardExists: true,
      hazardStatus,
    });
    if (validation.status === 'VALID') accepted.push(vote);
  }
  return accepted;
}

export async function recomputeHazardConfidence(hazardId: string): Promise<void> {
  const db = getFirestore();
  const hazardRef = db.collection(HAZARD_COLLECTION).doc(hazardId);

  // Reading and writing the parent in one transaction serializes competing
  // recalculations. On retry, the query is re-read so a late result cannot
  // overwrite a newer vote set with an older manual counter value.
  await db.runTransaction(async (transaction) => {
    const hazardSnap = await transaction.get(hazardRef);
    if (!hazardSnap.exists) return;
    const hazard = hazardSnap.data() ?? {};
    const votesSnap = await transaction.get(hazardRef.collection('votes'));
    const accepted = selectVotesForConfidence(
      votesSnap.docs.map((voteDoc) => ({
        id: voteDoc.id,
        data: voteDoc.data() as Record<string, unknown>,
      })),
      hazard['status'],
    );

    const summary = calculateConfidence(accepted);
    transaction.update(hazardRef, {
      serverConfidence: {
        ...summary,
        calculatedAt: FieldValue.serverTimestamp(),
      },
    });
  });
}

export const recomputeSafetyConfidence = onDocumentWritten(
  {
    document: `${HAZARD_COLLECTION}/{hazardId}/votes/{voteId}`,
    timeoutSeconds: 60,
    memory: '256MiB',
    region: 'asia-southeast1',
  },
  async (event) => {
    const before = event.data?.before.data() as Record<string, unknown> | undefined;
    const after = event.data?.after.data() as Record<string, unknown> | undefined;
    if (!shouldRecomputeConfidence(before, after)) return;
    try {
      await recomputeHazardConfidence(event.params.hazardId);
    } catch (error) {
      logger.error('recomputeSafetyConfidence: recalculation failed', {
        hazardId: event.params.hazardId,
        voteId: event.params.voteId,
        error: String(error).slice(0, 300),
      });
      throw error;
    }
  },
);
