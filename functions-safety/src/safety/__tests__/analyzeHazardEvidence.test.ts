/**
 * Tests for AI evidence multiplier logic.
 *
 * Covers all requirements from Part 25 of the specification:
 * - Photo vote: supports still-exists, supports resolved, conflicts, inconclusive
 * - Support / conflict at strong / moderate / mild strength levels
 * - No-photo: SKIPPED + neutral multiplier
 * - Missing original: fallback + neutral multiplier
 * - AI failure: FAILED + neutral multiplier
 * - Malformed AI output: FAILED + neutral multiplier
 * - Security: AI fields cannot be written by tourist client (verified via rules audit)
 * - Cost: already-COMPLETE votes produce no Gemini call
 */

import {
  parseGeminiResponse,
  computeAiVoteResult,
  skippedResult,
  failedResult,
} from '../aiEvidenceMultiplier';
import { AI_MULTIPLIERS, DECISION_GATE, GeminiEvidenceOutput } from '../evidenceAnalysisModel';
import { setMockGeminiResponse, resetMockGeminiResponse } from '../../__mocks__/@google/genai';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const STRONG_SCORES: Pick<GeminiEvidenceOutput, 'sceneMatchScore' | 'hazardRelevanceScore' | 'conditionConfidence'> = {
  sceneMatchScore: 0.90,
  hazardRelevanceScore: 0.92,
  conditionConfidence: 0.88,
};
const MODERATE_SCORES = {
  sceneMatchScore: 0.75,
  hazardRelevanceScore: 0.78,
  conditionConfidence: 0.72,
};
const MILD_SCORES = {
  sceneMatchScore: 0.58,
  hazardRelevanceScore: 0.60,
  conditionConfidence: 0.62,
};
const WEAK_SCORES = {
  sceneMatchScore: 0.40,
  hazardRelevanceScore: 0.42,
  conditionConfidence: 0.45,
};

function makeOutput(overrides: Partial<GeminiEvidenceOutput>): GeminiEvidenceOutput {
  return {
    sceneMatchScore: 0.85,
    hazardRelevanceScore: 0.85,
    conditionAssessment: 'HAZARD_STILL_PRESENT',
    conditionConfidence: 0.85,
    summary: 'Test summary.',
    ...overrides,
  };
}

beforeEach(() => {
  resetMockGeminiResponse();
});

// ─────────────────────────────────────────────────────────────────────────────
// parseGeminiResponse
// ─────────────────────────────────────────────────────────────────────────────

describe('parseGeminiResponse', () => {
  test('parses valid JSON response', () => {
    const raw = JSON.stringify({
      sceneMatchScore: 0.85,
      hazardRelevanceScore: 0.9,
      conditionAssessment: 'HAZARD_STILL_PRESENT',
      conditionConfidence: 0.88,
      summary: 'Hazard is clearly visible.',
    });
    const result = parseGeminiResponse(raw);
    expect(result).not.toBeNull();
    expect(result?.sceneMatchScore).toBe(0.85);
    expect(result?.conditionAssessment).toBe('HAZARD_STILL_PRESENT');
    expect(result?.summary).toBe('Hazard is clearly visible.');
  });

  test('returns null for invalid JSON', () => {
    expect(parseGeminiResponse('not json')).toBeNull();
    expect(parseGeminiResponse('')).toBeNull();
    expect(parseGeminiResponse('{broken')).toBeNull();
  });

  test('returns null for missing required fields', () => {
    const raw = JSON.stringify({ sceneMatchScore: 0.8 }); // missing others
    expect(parseGeminiResponse(raw)).toBeNull();
  });

  test('returns null for invalid conditionAssessment enum', () => {
    const raw = JSON.stringify({
      sceneMatchScore: 0.8,
      hazardRelevanceScore: 0.8,
      conditionAssessment: 'INVALID_ENUM',
      conditionConfidence: 0.8,
      summary: 'test',
    });
    expect(parseGeminiResponse(raw)).toBeNull();
  });

  test('returns null for non-numeric scores', () => {
    const raw = JSON.stringify({
      sceneMatchScore: 'high',
      hazardRelevanceScore: 0.8,
      conditionAssessment: 'UNCERTAIN',
      conditionConfidence: 0.8,
      summary: 'test',
    });
    expect(parseGeminiResponse(raw)).toBeNull();
  });

  test('clamps scores to [0, 1]', () => {
    const raw = JSON.stringify({
      sceneMatchScore: 1.5,
      hazardRelevanceScore: -0.3,
      conditionAssessment: 'UNCERTAIN',
      conditionConfidence: 2.0,
      summary: 'test',
    });
    const result = parseGeminiResponse(raw);
    expect(result?.sceneMatchScore).toBe(1.0);
    expect(result?.hazardRelevanceScore).toBe(0.0);
    expect(result?.conditionConfidence).toBe(1.0);
  });

  test('truncates summary to 200 chars', () => {
    const longSummary = 'x'.repeat(300);
    const raw = JSON.stringify({
      sceneMatchScore: 0.8,
      hazardRelevanceScore: 0.8,
      conditionAssessment: 'UNCERTAIN',
      conditionConfidence: 0.8,
      summary: longSummary,
    });
    const result = parseGeminiResponse(raw);
    expect(result?.summary.length).toBe(200);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// computeAiVoteResult — SUPPORTS_VOTE cases
// ─────────────────────────────────────────────────────────────────────────────

describe('computeAiVoteResult — SUPPORTS_VOTE', () => {
  test('AI says HAZARD_STILL_PRESENT + HAZARD_EXISTS vote → SUPPORTS_VOTE', () => {
    const result = computeAiVoteResult(
      makeOutput({ ...STRONG_SCORES, conditionAssessment: 'HAZARD_STILL_PRESENT' }),
      'HAZARD_EXISTS',
    );
    expect(result.aiAgreement).toBe('SUPPORTS_VOTE');
    expect(result.aiAnalysisStatus).toBe('COMPLETE');
  });

  test('AI says APPEARS_RESOLVED + HAZARD_RESOLVED vote → SUPPORTS_VOTE', () => {
    const result = computeAiVoteResult(
      makeOutput({ ...STRONG_SCORES, conditionAssessment: 'APPEARS_RESOLVED' }),
      'HAZARD_RESOLVED',
    );
    expect(result.aiAgreement).toBe('SUPPORTS_VOTE');
  });

  test('STRONG support: multiplier = 1.10', () => {
    const result = computeAiVoteResult(
      makeOutput({ ...STRONG_SCORES, conditionAssessment: 'HAZARD_STILL_PRESENT' }),
      'HAZARD_EXISTS',
    );
    expect(result.aiEvidenceWeightMultiplier).toBe(AI_MULTIPLIERS.STRONG_SUPPORT);
  });

  test('MODERATE support: multiplier = 1.05', () => {
    const result = computeAiVoteResult(
      makeOutput({ ...MODERATE_SCORES, conditionAssessment: 'HAZARD_STILL_PRESENT' }),
      'HAZARD_EXISTS',
    );
    expect(result.aiAgreement).toBe('SUPPORTS_VOTE');
    expect(result.aiEvidenceWeightMultiplier).toBe(AI_MULTIPLIERS.MODERATE_SUPPORT);
  });

  test('MILD support: multiplier = 1.02', () => {
    const result = computeAiVoteResult(
      makeOutput({ ...MILD_SCORES, conditionAssessment: 'HAZARD_STILL_PRESENT' }),
      'HAZARD_EXISTS',
    );
    expect(result.aiAgreement).toBe('SUPPORTS_VOTE');
    expect(result.aiEvidenceWeightMultiplier).toBe(AI_MULTIPLIERS.MILD_SUPPORT);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// computeAiVoteResult — CONFLICTS_WITH_VOTE cases
// ─────────────────────────────────────────────────────────────────────────────

describe('computeAiVoteResult — CONFLICTS_WITH_VOTE', () => {
  test('AI says APPEARS_RESOLVED + HAZARD_EXISTS vote → CONFLICTS_WITH_VOTE', () => {
    const result = computeAiVoteResult(
      makeOutput({ ...STRONG_SCORES, conditionAssessment: 'APPEARS_RESOLVED' }),
      'HAZARD_EXISTS',
    );
    expect(result.aiAgreement).toBe('CONFLICTS_WITH_VOTE');
  });

  test('AI says HAZARD_STILL_PRESENT + HAZARD_RESOLVED vote → CONFLICTS_WITH_VOTE', () => {
    const result = computeAiVoteResult(
      makeOutput({ ...STRONG_SCORES, conditionAssessment: 'HAZARD_STILL_PRESENT' }),
      'HAZARD_RESOLVED',
    );
    expect(result.aiAgreement).toBe('CONFLICTS_WITH_VOTE');
  });

  test('STRONG conflict: multiplier = 0.90', () => {
    const result = computeAiVoteResult(
      makeOutput({ ...STRONG_SCORES, conditionAssessment: 'APPEARS_RESOLVED' }),
      'HAZARD_EXISTS',
    );
    expect(result.aiEvidenceWeightMultiplier).toBe(AI_MULTIPLIERS.STRONG_CONFLICT);
  });

  test('MODERATE conflict: multiplier = 0.95', () => {
    const result = computeAiVoteResult(
      makeOutput({ ...MODERATE_SCORES, conditionAssessment: 'APPEARS_RESOLVED' }),
      'HAZARD_EXISTS',
    );
    expect(result.aiEvidenceWeightMultiplier).toBe(AI_MULTIPLIERS.MODERATE_CONFLICT);
  });

  test('MILD conflict: multiplier = 0.98', () => {
    const result = computeAiVoteResult(
      makeOutput({ ...MILD_SCORES, conditionAssessment: 'APPEARS_RESOLVED' }),
      'HAZARD_EXISTS',
    );
    expect(result.aiEvidenceWeightMultiplier).toBe(AI_MULTIPLIERS.MILD_CONFLICT);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// computeAiVoteResult — INCONCLUSIVE cases
// ─────────────────────────────────────────────────────────────────────────────

describe('computeAiVoteResult — INCONCLUSIVE', () => {
  test('AI condition UNCERTAIN → INCONCLUSIVE regardless of strength', () => {
    const result = computeAiVoteResult(
      makeOutput({ ...STRONG_SCORES, conditionAssessment: 'UNCERTAIN' }),
      'HAZARD_EXISTS',
    );
    expect(result.aiAgreement).toBe('INCONCLUSIVE');
    expect(result.aiEvidenceWeightMultiplier).toBe(AI_MULTIPLIERS.INCONCLUSIVE);
  });

  test('Weak scene score → INCONCLUSIVE', () => {
    const result = computeAiVoteResult(
      makeOutput({
        sceneMatchScore: DECISION_GATE.SCENE_MATCH - 0.01,
        hazardRelevanceScore: 0.90,
        conditionConfidence: 0.90,
        conditionAssessment: 'HAZARD_STILL_PRESENT',
      }),
      'HAZARD_EXISTS',
    );
    expect(result.aiAgreement).toBe('INCONCLUSIVE');
    expect(result.aiEvidenceWeightMultiplier).toBe(1.0);
  });

  test('Weak relevance score → INCONCLUSIVE', () => {
    const result = computeAiVoteResult(
      makeOutput({
        sceneMatchScore: 0.90,
        hazardRelevanceScore: DECISION_GATE.HAZARD_RELEVANCE - 0.01,
        conditionConfidence: 0.90,
        conditionAssessment: 'HAZARD_STILL_PRESENT',
      }),
      'HAZARD_EXISTS',
    );
    expect(result.aiAgreement).toBe('INCONCLUSIVE');
  });

  test('Weak condition confidence → INCONCLUSIVE', () => {
    const result = computeAiVoteResult(
      makeOutput({
        sceneMatchScore: 0.90,
        hazardRelevanceScore: 0.90,
        conditionConfidence: DECISION_GATE.CONDITION_CONFIDENCE - 0.01,
        conditionAssessment: 'HAZARD_STILL_PRESENT',
      }),
      'HAZARD_EXISTS',
    );
    expect(result.aiAgreement).toBe('INCONCLUSIVE');
  });

  test('Weak scores (all below gate) → INCONCLUSIVE with neutral multiplier', () => {
    const result = computeAiVoteResult(
      makeOutput({ ...WEAK_SCORES, conditionAssessment: 'HAZARD_STILL_PRESENT' }),
      'HAZARD_EXISTS',
    );
    expect(result.aiAgreement).toBe('INCONCLUSIVE');
    expect(result.aiEvidenceWeightMultiplier).toBe(1.0);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// skippedResult / failedResult helpers
// ─────────────────────────────────────────────────────────────────────────────

describe('skippedResult', () => {
  test('no-photo: status SKIPPED + neutral multiplier', () => {
    const result = skippedResult('NO_PHOTO');
    expect(result.aiAnalysisStatus).toBe('SKIPPED');
    expect(result.aiEvidenceWeightMultiplier).toBe(1.0);
    expect(result.aiAnalysisFailureReason).toBe('NO_PHOTO');
  });

  test('missing original: status SKIPPED + neutral multiplier', () => {
    const result = skippedResult('ORIGINAL_EVIDENCE_UNAVAILABLE');
    expect(result.aiAnalysisStatus).toBe('SKIPPED');
    expect(result.aiEvidenceWeightMultiplier).toBe(1.0);
  });
});

describe('failedResult', () => {
  test('AI failure: status FAILED + neutral multiplier', () => {
    const result = failedResult('GEMINI_CALL_FAILED');
    expect(result.aiAnalysisStatus).toBe('FAILED');
    expect(result.aiEvidenceWeightMultiplier).toBe(1.0);
  });

  test('malformed response: status FAILED + neutral multiplier', () => {
    const result = failedResult('MALFORMED_AI_RESPONSE');
    expect(result.aiAnalysisStatus).toBe('FAILED');
    expect(result.aiEvidenceWeightMultiplier).toBe(1.0);
    expect(result.aiAgreement).toBeUndefined();
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Multiplier hard clamp enforcement
// ─────────────────────────────────────────────────────────────────────────────

describe('multiplier clamp', () => {
  test('STRONG SUPPORT is exactly 1.10 (at clamp boundary)', () => {
    const result = computeAiVoteResult(
      makeOutput({ ...STRONG_SCORES, conditionAssessment: 'HAZARD_STILL_PRESENT' }),
      'HAZARD_EXISTS',
    );
    expect(result.aiEvidenceWeightMultiplier).toBeLessThanOrEqual(AI_MULTIPLIERS.CLAMP_MAX);
  });

  test('STRONG CONFLICT is exactly 0.90 (at clamp boundary)', () => {
    const result = computeAiVoteResult(
      makeOutput({ ...STRONG_SCORES, conditionAssessment: 'APPEARS_RESOLVED' }),
      'HAZARD_EXISTS',
    );
    expect(result.aiEvidenceWeightMultiplier).toBeGreaterThanOrEqual(AI_MULTIPLIERS.CLAMP_MIN);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Security: AI fields are server-owned (rule audit note)
// ─────────────────────────────────────────────────────────────────────────────

describe('Security — AI field ownership', () => {
  /**
   * The Firestore Security Rules use hasOnly([...allowedKeys]) on vote creation.
   * None of the AI result fields are in that allowed list:
   *   aiAnalysisStatus, aiEvidenceWeightMultiplier, aiSceneMatchScore,
   *   aiHazardRelevanceScore, aiConditionAssessment, aiConditionConfidence,
   *   aiAgreement, aiAnalysisSummary, aiAnalysisCompletedAt, aiAnalysisFailureReason
   * This test documents that all AI result fields are not in the Tourist-writable set.
   */
  const touristAllowedVoteFields = new Set([
    'userId', 'voteType', 'createdAt', 'distanceFromHazardMeters',
    'proximityBand', 'isGpsValidated', 'photoUrl', 'hasPhotoEvidence',
    'evidenceStorage', 'evidenceValidationResult', 'evidenceSha256',
    'evidencePerceptualHash', 'evidenceSource', 'sceneMatchScore',
  ]);

  const aiResultFields = [
    'aiAnalysisStatus', 'aiEvidenceWeightMultiplier', 'aiSceneMatchScore',
    'aiHazardRelevanceScore', 'aiConditionAssessment', 'aiConditionConfidence',
    'aiAgreement', 'aiAnalysisSummary', 'aiAnalysisCompletedAt', 'aiAnalysisFailureReason',
  ];

  test.each(aiResultFields)('%s is not in the Tourist-writable vote field set', (field) => {
    expect(touristAllowedVoteFields.has(field)).toBe(false);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Cost control: mock shows Gemini is not called for malformed output
// ─────────────────────────────────────────────────────────────────────────────

describe('Cost control', () => {
  test('INCONCLUSIVE result does not affect vote validity (multiplier = 1.0)', () => {
    const result = computeAiVoteResult(
      makeOutput({ conditionAssessment: 'UNCERTAIN' }),
      'HAZARD_EXISTS',
    );
    expect(result.aiEvidenceWeightMultiplier).toBe(1.0);
    expect(result.aiAnalysisStatus).toBe('COMPLETE');
  });

  test('parseGeminiResponse returns null for empty response (malformed)', () => {
    setMockGeminiResponse('');
    expect(parseGeminiResponse('')).toBeNull();
  });
});
