import {dateFromUnknown} from './voteValidation';

export const CONFIDENCE_FORMULA_VERSION = 'safety-confidence-v1';

export interface ServerConfidenceSummary {
  formulaVersion: string;
  confidencePercent: number;
  confidenceLevel: string;
  weightedStillExists: number;
  weightedResolved: number;
  stillExistsVotes: number;
  resolvedVotes: number;
  totalVotes: number;
  validVoteCount: number;
  recentValidVoteCount: number;
  recentStillExistsVotes: number;
  recentResolvedVotes: number;
  gpsValidatedCount: number;
  photoEvidenceCount: number;
  strongOrGoodEvidenceCount: number;
  lowQualityEvidenceCount: number;
  possibleDuplicateEvidenceCount: number;
  averageEvidenceScore: number;
  sceneMatchedCount: number;
  evidenceStrength: string;
  recommendation: string;
  validUntil?: Date | null;
}

const MINIMUM_VALID_VOTES = 5;
const SUFFICIENT_VALID_VOTES = 10;
const MAX_DISTANCE_METERS = 500;

function finiteNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function recencyWeight(vote: Record<string, unknown>, now: Date): number {
  const createdAt = dateFromUnknown(vote['createdAt']);
  if (createdAt === null) return 0;
  const ageMinutes = (now.getTime() - createdAt.getTime()) / 60000;
  if (ageMinutes < 0 || ageMinutes > 60) return 0;
  if (ageMinutes <= 15) return 1;
  if (ageMinutes <= 30) return 0.8;
  return 0.5;
}

function distanceWeight(vote: Record<string, unknown>): number {
  const distance = finiteNumber(vote['distanceFromHazardMeters']) ?? Infinity;
  if (distance <= 100) return 1;
  if (distance <= 300) return 0.8;
  return 0.5;
}

function evidenceData(vote: Record<string, unknown>): Record<string, unknown> | null {
  const value = vote['evidenceValidationResult'];
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function earnsEvidenceBonus(vote: Record<string, unknown>): boolean {
  if (vote['hasPhotoEvidence'] !== true) return false;
  const evidence = evidenceData(vote);
  return evidence !== null && evidence['isValid'] === true &&
    evidence['duplicateDetected'] !== true &&
    evidence['validationLevel'] !== 'LOW_QUALITY';
}

export function trustedAiMultiplier(vote: Record<string, unknown>): number {
  if (vote['aiAnalysisStatus'] !== 'COMPLETE') return 1;
  const multiplier = finiteNumber(vote['aiEvidenceWeightMultiplier']);
  return multiplier === null ? 1 : Math.min(1.10, Math.max(0.90, multiplier));
}

function evidenceWeight(vote: Record<string, unknown>): number {
  if (vote['hasPhotoEvidence'] !== true) return 1;
  const evidence = evidenceData(vote);
  if (!earnsEvidenceBonus(vote) || evidence === null) return 1;

  const scene = finiteNumber(vote['sceneMatchScore']) ??
    finiteNumber(evidence['sceneMatchScore']) ?? 0;
  const sceneBoost = scene >= 1 ? 1.3 : scene >= 0.7 ? 1.15 : scene >= 0.4 ? 1.05 : 1;
  const overall = finiteNumber(evidence['overallEvidenceScore']) ?? 0;
  const base = overall >= 0.85 ? 1.15 : overall >= 0.65 ? 1.1 : 1.05;
  return base * sceneBoost * trustedAiMultiplier(vote);
}

function confidenceLevel(percent: number, recentCount: number): string {
  if (recentCount < MINIMUM_VALID_VOTES) return 'INSUFFICIENT EVIDENCE';
  if (recentCount < SUFFICIENT_VALID_VOTES) return 'LIMITED EVIDENCE';
  if (percent >= 90) return 'VERY HIGH';
  if (percent >= 75) return 'HIGH';
  if (percent >= 50) return 'MEDIUM';
  return 'LOW';
}

function recommendation(level: string): string {
  switch (level) {
    case 'INSUFFICIENT EVIDENCE':
      return 'Too few location-validated community confirmations are available. Administrator review is required.';
    case 'LIMITED EVIDENCE':
      return 'Evidence is limited. Review the community evidence before changing the official status.';
    case 'VERY HIGH':
      return 'Recent location-validated community evidence strongly indicates that this hazard may have been resolved. Administrator review is recommended before changing the official status.';
    case 'HIGH':
      return 'Community evidence indicates that this hazard may have been resolved. Administrator review is recommended.';
    case 'MEDIUM':
      return 'Community evidence is mixed. Further administrator review is recommended.';
    default:
      return 'Community evidence indicates the hazard may still exist. Keep it verified unless other evidence supports resolution.';
  }
}

/** Port of Flutter ConfidenceAnalysisService for already server-validated votes. */
export function calculateConfidence(
  votes: Record<string, unknown>[],
  now: Date = new Date(),
): ServerConfidenceSummary {
  const recognized = votes.filter((vote) =>
    vote['voteType'] === 'HAZARD_EXISTS' || vote['voteType'] === 'HAZARD_RESOLVED');
  const valid = recognized.filter((vote) => {
    const distance = finiteNumber(vote['distanceFromHazardMeters']);
    return vote['isGpsValidated'] === true && distance !== null &&
      distance >= 0 && distance <= MAX_DISTANCE_METERS;
  });

  let weightedStillExists = 0;
  let weightedResolved = 0;
  for (const vote of valid) {
    const weight = recencyWeight(vote, now) * distanceWeight(vote) * evidenceWeight(vote);
    if (vote['voteType'] === 'HAZARD_RESOLVED') weightedResolved += weight;
    else weightedStillExists += weight;
  }

  const totalWeight = weightedStillExists + weightedResolved;
  const percent = totalWeight === 0 ? 0 : weightedResolved / totalWeight * 100;
  const recent = valid.filter((vote) => {
    const createdAt = dateFromUnknown(vote['createdAt']);
    if (createdAt === null) return false;
    const age = now.getTime() - createdAt.getTime();
    return age >= 0 && age <= 15 * 60 * 1000;
  });
  const level = confidenceLevel(percent, recent.length);
  const reliablePhotos = valid.filter(earnsEvidenceBonus);
  const evidenceScores = reliablePhotos
    .map((vote) => finiteNumber(evidenceData(vote)?.['overallEvidenceScore']))
    .filter((score): score is number => score !== null);
  const averageEvidenceScore = evidenceScores.length === 0 ? 0 :
    evidenceScores.reduce((total, score) => total + score, 0) / evidenceScores.length;

  const stillExistsVotes = recognized.filter((vote) => vote['voteType'] === 'HAZARD_EXISTS').length;
  const recentStillExistsVotes = recent.filter((vote) => vote['voteType'] === 'HAZARD_EXISTS').length;

  const nowMs = now.getTime();
  const upcomingBoundaries: number[] = [];
  for (const vote of valid) {
    const createdAt = dateFromUnknown(vote['createdAt']);
    if (createdAt === null) continue;
    const t = createdAt.getTime();
    for (const offsetMin of [15, 30, 60]) {
      const boundary = t + offsetMin * 60 * 1000;
      if (boundary > nowMs) {
        upcomingBoundaries.push(boundary);
      }
    }
  }
  const validUntil = upcomingBoundaries.length > 0
    ? new Date(Math.min(...upcomingBoundaries))
    : new Date(nowMs + 15 * 60 * 1000);

  return {
    formulaVersion: CONFIDENCE_FORMULA_VERSION,
    confidencePercent: percent,
    confidenceLevel: level,
    weightedStillExists,
    weightedResolved,
    stillExistsVotes,
    resolvedVotes: recognized.length - stillExistsVotes,
    totalVotes: recognized.length,
    validVoteCount: valid.length,
    recentValidVoteCount: recent.length,
    recentStillExistsVotes,
    recentResolvedVotes: recent.length - recentStillExistsVotes,
    gpsValidatedCount: valid.length,
    photoEvidenceCount: valid.filter((vote) => vote['hasPhotoEvidence'] === true).length,
    strongOrGoodEvidenceCount: reliablePhotos.filter((vote) => {
      const level = evidenceData(vote)?.['validationLevel'];
      return level === 'STRONG' || level === 'GOOD';
    }).length,
    lowQualityEvidenceCount: valid.filter((vote) =>
      evidenceData(vote)?.['validationLevel'] === 'LOW_QUALITY').length,
    possibleDuplicateEvidenceCount: valid.filter((vote) =>
      evidenceData(vote)?.['duplicateDetected'] === true).length,
    averageEvidenceScore,
    sceneMatchedCount: reliablePhotos.filter((vote) => {
      const evidence = evidenceData(vote);
      const score = finiteNumber(vote['sceneMatchScore']) ??
        finiteNumber(evidence?.['sceneMatchScore']) ?? 0;
      return score >= 0.7;
    }).length,
    evidenceStrength: recent.length < MINIMUM_VALID_VOTES ? 'Insufficient' :
      recent.length < SUFFICIENT_VALID_VOTES ? 'Limited' : 'Sufficient',
    recommendation: recommendation(level),
    validUntil,
  };
}
