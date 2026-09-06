/**
 * Evidence analysis data model for the Safety Module AI evidence matching.
 *
 * All numeric fields validated and clamped server-side before storage.
 * These types are shared between the Cloud Function and its tests.
 */

// ─────────────────────────────────────────────────────────────────────────────
// Gemini structured output schema
// ─────────────────────────────────────────────────────────────────────────────

/** Allowed values for AI condition assessment. */
export type ConditionAssessment =
  | 'HAZARD_STILL_PRESENT'
  | 'APPEARS_RESOLVED'
  | 'UNCERTAIN';

/** Raw structured output returned by Gemini (validated before use). */
export interface GeminiEvidenceOutput {
  sceneMatchScore: number;
  hazardRelevanceScore: number;
  conditionAssessment: ConditionAssessment;
  conditionConfidence: number;
  summary: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// AI analysis result stored on the vote document
// ─────────────────────────────────────────────────────────────────────────────

/** Possible values for the aiAnalysisStatus field on a vote document. */
export type AiAnalysisStatus = 'PENDING' | 'COMPLETE' | 'FAILED' | 'SKIPPED';

/** Possible values for the aiAgreement field. */
export type AiAgreement =
  | 'SUPPORTS_VOTE'
  | 'CONFLICTS_WITH_VOTE'
  | 'INCONCLUSIVE';

/** The fields written to the vote document by the Cloud Function. */
export interface AiVoteResult {
  aiAnalysisStatus: AiAnalysisStatus;
  aiEvidenceWeightMultiplier: number;
  aiSceneMatchScore?: number;
  aiHazardRelevanceScore?: number;
  aiConditionAssessment?: ConditionAssessment;
  aiConditionConfidence?: number;
  aiAgreement?: AiAgreement;
  aiAnalysisSummary?: string;
  aiAnalysisCompletedAt?: FirebaseFirestore.FieldValue;
  aiAnalysisFailureReason?: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// AI multiplier thresholds (matches SafetyConfig on the Flutter side)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Constants governing how the AI agreement maps to an evidence weight
 * multiplier. Symmetric with the Dart SafetyConfig class.
 */
export const AI_MULTIPLIERS = Object.freeze({
  /** Agreement thresholds — minimum of (sceneMatch, relevance, confidence) */
  STRONG_THRESHOLD: 0.85,
  MODERATE_THRESHOLD: 0.70,
  MILD_THRESHOLD: 0.55, // decision gate — below this → INCONCLUSIVE

  /** Support multipliers */
  STRONG_SUPPORT: 1.10,
  MODERATE_SUPPORT: 1.05,
  MILD_SUPPORT: 1.02,
  INCONCLUSIVE: 1.00,

  /** Conflict multipliers */
  MILD_CONFLICT: 0.98,
  MODERATE_CONFLICT: 0.95,
  STRONG_CONFLICT: 0.90,

  /** Hard clamp boundary */
  CLAMP_MIN: 0.90,
  CLAMP_MAX: 1.10,
} as const);

/**
 * Minimum scores required before making a SUPPORTS / CONFLICTS decision.
 * All three must exceed this gate; otherwise the result is INCONCLUSIVE.
 */
export const DECISION_GATE = Object.freeze({
  SCENE_MATCH: 0.55,
  HAZARD_RELEVANCE: 0.55,
  CONDITION_CONFIDENCE: 0.60,
} as const);

/** Maximum compressed evidence Blob size (400 KB — matches Flutter constant). */
export const MAX_EVIDENCE_BYTES = 400 * 1024;

/**
 * Centralized Gemini model configuration for server-side evidence analysis.
 * Uses the latest official model supported by @google/genai SDK.
 */
export const GEMINI_MODEL = 'gemini-3.8-flash';
