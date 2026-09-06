/**
 * Firestore onCreate trigger: analyzeHazardEvidence
 *
 * Fires when a new vote document is created at:
 *   hazard_reports/{hazardId}/votes/{voteId}
 *
 * The transaction in HazardVoteService.submitVote() atomically writes:
 *   1. The vote document
 *   2. The evidence document (evidence/photo)
 * Both are committed before this trigger fires, so evidence is guaranteed
 * to be present when this function reads it.
 *
 * Cost control: the function checks for an already-COMPLETE result before
 * calling Gemini, preventing redundant analysis on re-triggered events.
 */

import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { defineSecret } from 'firebase-functions/params';
import * as logger from 'firebase-functions/logger';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { GoogleGenAI } from '@google/genai';

import {
  AiVoteResult,
  MAX_EVIDENCE_BYTES,
  GEMINI_MODEL,
} from './evidenceAnalysisModel';
import { buildAnalysisPrompt } from './evidenceAnalysisPrompt';
import {
  parseGeminiResponse,
  computeAiVoteResult,
  skippedResult,
  failedResult,
} from './aiEvidenceMultiplier';
import { validateVote } from './voteValidation';

// ─────────────────────────────────────────────────────────────────────────────
// Secret — never hardcoded; set via Firebase secret management
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Gemini API key stored as a Firebase Functions secret.
 *
 * To set this secret before deploying:
 *   firebase functions:secrets:set GEMINI_API_KEY
 * Then enter the key value when prompted.
 */
const geminiApiKey = defineSecret('GEMINI_API_KEY');

// ─────────────────────────────────────────────────────────────────────────────
// Collection / document constants (must match Dart HazardReportService)
// ─────────────────────────────────────────────────────────────────────────────
const HAZARD_COLLECTION = 'hazard_reports';
const EVIDENCE_COLLECTION = 'evidence';
const EVIDENCE_DOC = 'photo';
const EVIDENCE_FIELD = 'imageBytes';

// ─────────────────────────────────────────────────────────────────────────────
// Trigger
// ─────────────────────────────────────────────────────────────────────────────

export const analyzeHazardEvidence = onDocumentCreated(
  {
    document: `${HAZARD_COLLECTION}/{hazardId}/votes/{voteId}`,
    secrets: [geminiApiKey],
    timeoutSeconds: 120,
    memory: '512MiB',
    region: 'asia-southeast1',
  },
  async (event) => {
    const { hazardId, voteId } = event.params;
    const voteData = event.data?.data();

    if (!voteData) {
      logger.warn('analyzeHazardEvidence: empty vote snapshot', { hazardId, voteId });
      return;
    }

    const db = getFirestore();
    const voteRef = db
      .collection(HAZARD_COLLECTION)
      .doc(hazardId)
      .collection('votes')
      .doc(voteId);

    // Read the committed vote so server timestamps and any server-owned fields
    // are observed rather than trusting only the trigger payload.
    const currentSnap = await voteRef.get();
    const currentData = currentSnap.data() ?? voteData;

    // ── Basic server validation before any paid AI work ───────────────────
    // This establishes structural consistency only. It cannot prove that the
    // client-reported physical GPS position was truthful.
    let hazardSnap: FirebaseFirestore.DocumentSnapshot;
    try {
      hazardSnap = await db.collection(HAZARD_COLLECTION).doc(hazardId).get();
    } catch (error) {
      logger.error('analyzeHazardEvidence: validation dependency unavailable', {
        hazardId,
        voteId,
        error: String(error).slice(0, 300),
      });
      await voteRef.update({
        serverValidationStatus: 'NOT_VALIDATED',
        serverValidatedAt: FieldValue.serverTimestamp(),
        serverValidationReasons: ['VALIDATION_DEPENDENCY_UNAVAILABLE'],
      });
      return;
    }
    const hazardData = hazardSnap.data() ?? {};
    const validation = validateVote(currentData, {
      voteId,
      hazardExists: hazardSnap.exists,
      hazardStatus: hazardData['status'],
      now: event.time ? new Date(event.time) : new Date(),
    });
    const validationFields = {
      serverValidationStatus: validation.status,
      serverValidatedAt: FieldValue.serverTimestamp(),
      serverValidationReasons: validation.reasons,
    };
    if (validation.status === 'INVALID') {
      await voteRef.update({
        ...validationFields,
        ...skippedResult('INVALID_VOTE'),
      });
      logger.warn('analyzeHazardEvidence: invalid vote — AI skipped', {
        hazardId,
        voteId,
        reasons: validation.reasons,
      });
      return;
    }
    await voteRef.update(validationFields);

    // ── Cost guard: skip if already analysed ──────────────────────────────
    const currentStatus = currentData['aiAnalysisStatus'];
    if (currentStatus === 'COMPLETE') {
      logger.info('analyzeHazardEvidence: already COMPLETE — skipping', { hazardId, voteId });
      return;
    }

    // ── Skip votes with no photo evidence ─────────────────────────────────
    if (currentData['hasPhotoEvidence'] !== true) {
      await writeResult(voteRef, skippedResult('NO_PHOTO'));
      return;
    }

    const voteType: string = currentData['voteType'] ?? '';

    // ── Load vote evidence bytes ───────────────────────────────────────────
    const voteEvidenceBytes = await loadEvidenceBlob(
      db, HAZARD_COLLECTION, hazardId, 'votes', voteId,
    );
    if (voteEvidenceBytes === null) {
      logger.warn('analyzeHazardEvidence: vote evidence blob missing', { hazardId, voteId });
      await writeResult(voteRef, skippedResult('VOTE_EVIDENCE_UNAVAILABLE'));
      return;
    }

    // ── Load original hazard evidence bytes ───────────────────────────────
    // If the original hazard evidence cannot be loaded, scene comparison is
    // unavailable. Per FIX 4, this must be SKIPPED with a neutral 1.00 multiplier.
    const originalEvidenceBytes = await loadOriginalEvidenceBlob(db, hazardId);
    if (originalEvidenceBytes === null) {
      logger.info('analyzeHazardEvidence: original evidence unavailable — skipping comparison', {
        hazardId,
        voteId,
      });
      await writeResult(voteRef, skippedResult('ORIGINAL_EVIDENCE_UNAVAILABLE'));
      return;
    }

    // ── Load hazard metadata ──────────────────────────────────────────────
    const hazardCategory: string = hazardData['category'] ?? 'Hazard';
    const hazardDescription: string = hazardData['description'] ?? '';

    // ── Call Gemini ───────────────────────────────────────────────────────
    let result: AiVoteResult;
    try {
      result = await callGeminiAnalysis({
        apiKey: geminiApiKey.value(),
        voteEvidenceBytes,
        originalEvidenceBytes,
        hazardCategory,
        hazardDescription,
        voteType,
      });
    } catch (error) {
      logger.error('analyzeHazardEvidence: Gemini call failed', {
        hazardId,
        voteId,
        error: String(error).slice(0, 300), // never log image bytes
      });
      result = failedResult('GEMINI_CALL_FAILED');
    }

    await writeResult(voteRef, result);
    logger.info('analyzeHazardEvidence: complete', {
      hazardId,
      voteId,
      status: result.aiAnalysisStatus,
      agreement: result.aiAgreement ?? 'N/A',
      multiplier: result.aiEvidenceWeightMultiplier,
    });
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Load the Blob evidence bytes from a vote's evidence/photo subcollection.
 * Returns null if the document is missing, the field is absent, or the bytes
 * exceed the maximum allowed size.
 */
async function loadEvidenceBlob(
  db: FirebaseFirestore.Firestore,
  collection: string,
  docId: string,
  subCollection: string,
  subDocId: string,
): Promise<Uint8Array | null> {
  try {
    const snap = await db
      .collection(collection)
      .doc(docId)
      .collection(subCollection)
      .doc(subDocId)
      .collection(EVIDENCE_COLLECTION)
      .doc(EVIDENCE_DOC)
      .get();

    if (!snap.exists) return null;
    const raw = snap.data()?.[EVIDENCE_FIELD];
    if (!raw || typeof raw.toUint8Array !== 'function') return null;

    const bytes: Uint8Array = raw.toUint8Array();
    if (bytes.length === 0 || bytes.length > MAX_EVIDENCE_BYTES) return null;
    return bytes;
  } catch {
    return null;
  }
}

/**
 * Load the original hazard creation evidence blob.
 * Collection path: hazard_reports/{hazardId}/evidence/photo
 */
async function loadOriginalEvidenceBlob(
  db: FirebaseFirestore.Firestore,
  hazardId: string,
): Promise<Uint8Array | null> {
  try {
    const snap = await db
      .collection(HAZARD_COLLECTION)
      .doc(hazardId)
      .collection(EVIDENCE_COLLECTION)
      .doc(EVIDENCE_DOC)
      .get();

    if (!snap.exists) return null;
    const raw = snap.data()?.[EVIDENCE_FIELD];
    if (!raw || typeof raw.toUint8Array !== 'function') return null;

    const bytes: Uint8Array = raw.toUint8Array();
    if (bytes.length === 0 || bytes.length > MAX_EVIDENCE_BYTES) return null;
    return bytes;
  } catch {
    return null;
  }
}

/**
 * Call Gemini multimodal API and return a computed AiVoteResult.
 * Throws on network/quota errors — caller handles and writes FAILED status.
 */
async function callGeminiAnalysis(params: {
  apiKey: string;
  voteEvidenceBytes: Uint8Array;
  originalEvidenceBytes: Uint8Array;
  hazardCategory: string;
  hazardDescription: string;
  voteType: string;
}): Promise<AiVoteResult> {
  const {
    apiKey,
    voteEvidenceBytes,
    originalEvidenceBytes,
    hazardCategory,
    hazardDescription,
    voteType,
  } = params;

  const ai = new GoogleGenAI({ apiKey });
  const { systemInstruction, userParts, config } = buildAnalysisPrompt({
    hazardCategory,
    hazardDescription,
    hasOriginalImage: true,
  });

  // Both the original hazard photo and the community vote photo are provided
  const contentParts = [
    {
      inlineData: {
        mimeType: 'image/jpeg',
        data: Buffer.from(originalEvidenceBytes).toString('base64'),
      },
    },
    ...userParts,
    {
      inlineData: {
        mimeType: 'image/jpeg',
        data: Buffer.from(voteEvidenceBytes).toString('base64'),
      },
    },
  ];

  const response = await ai.models.generateContent({
    model: GEMINI_MODEL,
    contents: [{ role: 'user', parts: contentParts }],
    config: {
      ...config,
      systemInstruction,
    },
  });

  const rawText = response.text ?? '';
  const parsed = parseGeminiResponse(rawText);

  if (parsed === null) {
    logger.warn('analyzeHazardEvidence: malformed Gemini response', {
      preview: rawText.slice(0, 200),
    });
    return failedResult('MALFORMED_AI_RESPONSE');
  }

  return computeAiVoteResult(parsed, voteType);
}

/**
 * Write the AI result to the vote document using Admin SDK (bypasses rules).
 */
async function writeResult(
  voteRef: FirebaseFirestore.DocumentReference,
  result: AiVoteResult,
): Promise<void> {
  // completedAt is only set for COMPLETE results (already in result for COMPLETE)
  await voteRef.update({
    ...result,
    // Ensure aiEvidenceWeightMultiplier is always written even on SKIPPED/FAILED
    aiEvidenceWeightMultiplier: result.aiEvidenceWeightMultiplier,
  });
}
