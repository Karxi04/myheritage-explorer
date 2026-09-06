/**
 * AI evidence multiplier computation logic.
 *
 * Determines:
 *  - aiAgreement (SUPPORTS_VOTE | CONFLICTS_WITH_VOTE | INCONCLUSIVE)
 *  - aiEvidenceWeightMultiplier [0.90 – 1.10]
 *
 * Agreement rules (Part 5 & 6 of requirements):
 * - Relevance alone does NOT determine agreement — vote direction matters.
 * - Only strong/moderate/mild confidence passes the decision gate.
 * - UNCERTAIN AI condition always → INCONCLUSIVE.
 * - Weak scene/relevance/confidence → INCONCLUSIVE.
 */

import {
  AiAgreement,
  AiVoteResult,
  AI_MULTIPLIERS,
  DECISION_GATE,
  ConditionAssessment,
  SyntheticImageRisk,
  GeminiEvidenceOutput,
} from './evidenceAnalysisModel';
import { FieldValue } from 'firebase-admin/firestore';

// Known vote type constants (mirrors HazardVoteType in Dart)
const HAZARD_EXISTS = 'HAZARD_EXISTS';

/**
 * Clamp a value to the allowed AI multiplier range.
 */
function clampMultiplier(value: number): number {
  return Math.min(AI_MULTIPLIERS.CLAMP_MAX, Math.max(AI_MULTIPLIERS.CLAMP_MIN, value));
}

/**
 * Determine strength category from the minimum of the three scores.
 * Returns 'strong', 'moderate', 'mild', or null (below gate → INCONCLUSIVE).
 */
function agreementStrength(
  scene: number,
  relevance: number,
  conditionConf: number,
): 'strong' | 'moderate' | 'mild' | null {
  const minScore = Math.min(scene, relevance, conditionConf);
  if (minScore >= AI_MULTIPLIERS.STRONG_THRESHOLD) return 'strong';
  if (minScore >= AI_MULTIPLIERS.MODERATE_THRESHOLD) return 'moderate';
  if (minScore >= AI_MULTIPLIERS.MILD_THRESHOLD) return 'mild';
  return null; // below gate
}

/**
 * Determine the AI agreement value by comparing the AI condition against
 * the tourist vote direction.
 *
 * Agreement matrix:
 *  Tourist HAZARD_EXISTS + AI HAZARD_STILL_PRESENT → SUPPORTS_VOTE
 *  Tourist HAZARD_EXISTS + AI APPEARS_RESOLVED    → CONFLICTS_WITH_VOTE
 *  Tourist HAZARD_RESOLVED + AI APPEARS_RESOLVED  → SUPPORTS_VOTE
 *  Tourist HAZARD_RESOLVED + AI HAZARD_STILL_PRESENT → CONFLICTS_WITH_VOTE
 *  Any UNCERTAIN condition                         → INCONCLUSIVE
 */
function computeAgreement(
  voteType: string,
  aiCondition: ConditionAssessment,
  scene: number,
  relevance: number,
  conditionConf: number,
): AiAgreement {
  // Gate check — weak confidence always inconclusive
  if (
    scene < DECISION_GATE.SCENE_MATCH ||
    relevance < DECISION_GATE.HAZARD_RELEVANCE ||
    conditionConf < DECISION_GATE.CONDITION_CONFIDENCE
  ) {
    return 'INCONCLUSIVE';
  }

  // Uncertain AI condition → inconclusive
  if (aiCondition === 'UNCERTAIN') {
    return 'INCONCLUSIVE';
  }

  const touristSaysExists = voteType === HAZARD_EXISTS;
  const aiSaysPresent = aiCondition === 'HAZARD_STILL_PRESENT';

  if (touristSaysExists === aiSaysPresent) {
    return 'SUPPORTS_VOTE';
  }
  return 'CONFLICTS_WITH_VOTE';
}

/**
 * Map agreement + strength to a multiplier value.
 */
function multiplierForAgreement(
  agreement: AiAgreement,
  strength: 'strong' | 'moderate' | 'mild' | null,
): number {
  if (agreement === 'INCONCLUSIVE' || strength === null) {
    return AI_MULTIPLIERS.INCONCLUSIVE;
  }
  if (agreement === 'SUPPORTS_VOTE') {
    switch (strength) {
      case 'strong':   return AI_MULTIPLIERS.STRONG_SUPPORT;
      case 'moderate': return AI_MULTIPLIERS.MODERATE_SUPPORT;
      case 'mild':     return AI_MULTIPLIERS.MILD_SUPPORT;
    }
  }
  // CONFLICTS_WITH_VOTE
  switch (strength) {
    case 'strong':   return AI_MULTIPLIERS.STRONG_CONFLICT;
    case 'moderate': return AI_MULTIPLIERS.MODERATE_CONFLICT;
    case 'mild':     return AI_MULTIPLIERS.MILD_CONFLICT;
  }
}

/**
 * Validate and clamp a Gemini score field to [0, 1].
 * Returns null if the value is not a finite number.
 */
function safeScore(raw: unknown): number | null {
  const n = Number(raw);
  if (!isFinite(n)) return null;
  return Math.min(1, Math.max(0, n));
}

/**
 * Validate and parse the raw Gemini response text into a GeminiEvidenceOutput.
 * Returns null if the response is malformed or contains invalid values.
 */
export function parseGeminiResponse(raw: string): GeminiEvidenceOutput | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  if (typeof parsed !== 'object' || parsed === null) return null;

  const obj = parsed as Record<string, unknown>;

  const sceneMatchScore = safeScore(obj['sceneMatchScore']);
  const hazardRelevanceScore = safeScore(obj['hazardRelevanceScore']);
  const conditionConfidence = safeScore(obj['conditionConfidence']);

  if (
    sceneMatchScore === null ||
    hazardRelevanceScore === null ||
    conditionConfidence === null
  ) {
    return null;
  }

  const VALID_CONDITIONS: ConditionAssessment[] = [
    'HAZARD_STILL_PRESENT',
    'APPEARS_RESOLVED',
    'UNCERTAIN',
  ];
  const rawCondition = obj['conditionAssessment'];
  if (!VALID_CONDITIONS.includes(rawCondition as ConditionAssessment)) return null;

  const summary = typeof obj['summary'] === 'string'
    ? obj['summary'].slice(0, 200).trim()
    : '';

  // Parse Step 11 synthetic image risk fields defensively.
  // Malformed synthetic fields must degrade to undefined (unavailable) without
  // invalidating or breaking the valid Step 6 semantic result.
  const VALID_SYNTHETIC_RISKS: SyntheticImageRisk[] = [
    'LOW',
    'UNCERTAIN',
    'ELEVATED',
  ];
  let syntheticImageRisk: SyntheticImageRisk | undefined;
  let syntheticImageConfidence: number | undefined;
  let syntheticImageSummary: string | undefined;

  const rawRisk = obj['syntheticImageRisk'];
  if (typeof rawRisk === 'string') {
    const trimmedRisk = rawRisk.trim().toUpperCase();
    if (VALID_SYNTHETIC_RISKS.includes(trimmedRisk as SyntheticImageRisk)) {
      syntheticImageRisk = trimmedRisk as SyntheticImageRisk;
    }
  }

  const rawRiskConf = obj['syntheticImageConfidence'];
  if (rawRiskConf !== undefined && rawRiskConf !== null) {
    const conf = safeScore(rawRiskConf);
    if (conf !== null) {
      syntheticImageConfidence = conf;
    }
  }

  const rawRiskSummary = obj['syntheticImageSummary'];
  if (typeof rawRiskSummary === 'string') {
    const clean = rawRiskSummary.replace(/[\u0000-\u001f\u007f]/g, ' ').slice(0, 200).trim();
    if (clean.length > 0) {
      syntheticImageSummary = clean;
    }
  }

  return {
    sceneMatchScore,
    hazardRelevanceScore,
    conditionAssessment: rawCondition as ConditionAssessment,
    conditionConfidence,
    summary,
    ...(syntheticImageRisk !== undefined ? { syntheticImageRisk } : {}),
    ...(syntheticImageConfidence !== undefined ? { syntheticImageConfidence } : {}),
    ...(syntheticImageSummary !== undefined ? { syntheticImageSummary } : {}),
  };
}

/**
 * Compute the final AiVoteResult from a successfully parsed Gemini output.
 * This is the single authoritative function for agreement + multiplier logic.
 */
export function computeAiVoteResult(
  gemini: GeminiEvidenceOutput,
  voteType: string,
): AiVoteResult {
  const {
    sceneMatchScore,
    hazardRelevanceScore,
    conditionAssessment,
    conditionConfidence,
    summary,
    syntheticImageRisk,
    syntheticImageConfidence,
    syntheticImageSummary,
  } = gemini;

  const agreement = computeAgreement(
    voteType,
    conditionAssessment,
    sceneMatchScore,
    hazardRelevanceScore,
    conditionConfidence,
  );

  const strength = agreementStrength(sceneMatchScore, hazardRelevanceScore, conditionConfidence);
  const rawMultiplier = multiplierForAgreement(agreement, strength);
  const multiplier = clampMultiplier(rawMultiplier);

  const result: AiVoteResult = {
    aiAnalysisStatus: 'COMPLETE',
    aiEvidenceWeightMultiplier: multiplier,
    aiSceneMatchScore: sceneMatchScore,
    aiHazardRelevanceScore: hazardRelevanceScore,
    aiConditionAssessment: conditionAssessment,
    aiConditionConfidence: conditionConfidence,
    aiAgreement: agreement,
    aiAnalysisSummary: summary,
    aiAnalysisCompletedAt: FieldValue.serverTimestamp(),
  };

  if (syntheticImageRisk !== undefined) {
    result.aiSyntheticImageRisk = syntheticImageRisk;
  }
  if (syntheticImageConfidence !== undefined) {
    result.aiSyntheticImageConfidence = syntheticImageConfidence;
  }
  if (syntheticImageSummary !== undefined) {
    result.aiSyntheticImageSummary = syntheticImageSummary;
  }

  return result;
}

/**
 * Build a neutral SKIPPED result with a reason string.
 */
export function skippedResult(reason: string): AiVoteResult {
  return {
    aiAnalysisStatus: 'SKIPPED',
    aiEvidenceWeightMultiplier: 1.0,
    aiAnalysisFailureReason: reason,
  };
}

/**
 * Build a FAILED result. Vote remains fully valid; multiplier is neutral.
 */
export function failedResult(reason: string): AiVoteResult {
  return {
    aiAnalysisStatus: 'FAILED',
    aiEvidenceWeightMultiplier: 1.0,
    aiAnalysisFailureReason: reason,
  };
}
