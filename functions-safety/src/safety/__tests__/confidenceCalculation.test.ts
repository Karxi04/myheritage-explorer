import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';

import {
  calculateConfidence,
  CONFIDENCE_FORMULA_VERSION,
  trustedAiMultiplier,
} from '../confidenceCalculation';

interface FixtureVote {
  count: number;
  voteType: string;
  minutesAgo: number;
  distance: number;
  photoQuality?: number;
  sceneMatchScore?: number;
  aiStatus?: string;
  aiMultiplier?: number;
}

interface Fixture {
  name: string;
  votes: FixtureVote[];
  expected: Record<string, number | string>;
}

const fixtureFile = JSON.parse(readFileSync(resolve(
  process.cwd(), '../test/fixtures/safety_confidence_fixtures.json',
), 'utf8')) as {evaluatedAt: string; fixtures: Fixture[]};
const evaluatedAt = new Date(fixtureFile.evaluatedAt);

function expandVotes(groups: FixtureVote[]): Record<string, unknown>[] {
  const votes: Record<string, unknown>[] = [];
  for (const group of groups) {
    for (let index = 0; index < group.count; index++) {
      const photo = group.photoQuality !== undefined;
      votes.push({
        userId: group.voteType + '-' + votes.length,
        voteType: group.voteType,
        createdAt: new Date(evaluatedAt.getTime() - group.minutesAgo * 60000),
        distanceFromHazardMeters: group.distance,
        proximityBand: group.distance <= 100 ? 'STRONG' : group.distance <= 300 ? 'NORMAL' : 'WEAK',
        isGpsValidated: true,
        hasPhotoEvidence: photo,
        evidenceStorage: photo ? 'firestore' : 'none',
        ...(photo ? {evidenceValidationResult: {
          isValid: true,
          duplicateDetected: false,
          validationLevel: 'GOOD',
          overallEvidenceScore: group.photoQuality,
          sceneMatchScore: group.sceneMatchScore,
        }} : {}),
        ...(group.sceneMatchScore === undefined ? {} : {sceneMatchScore: group.sceneMatchScore}),
        ...(group.aiStatus === undefined ? {} : {aiAnalysisStatus: group.aiStatus}),
        ...(group.aiMultiplier === undefined ? {} : {aiEvidenceWeightMultiplier: group.aiMultiplier}),
      });
    }
  }
  return votes;
}

describe('Dart/TypeScript shared confidence golden fixtures', () => {
  test.each(fixtureFile.fixtures)('$name', (fixture) => {
    const actual = calculateConfidence(expandVotes(fixture.votes), evaluatedAt);
    expect(actual.formulaVersion).toBe(CONFIDENCE_FORMULA_VERSION);
    for (const [key, expected] of Object.entries(fixture.expected)) {
      const value = actual[key as keyof typeof actual];
      if (typeof expected === 'number') expect(value as number).toBeCloseTo(expected, 8);
      else expect(value).toBe(expected);
    }
  });
});

describe('trusted AI multiplier', () => {
  test.each([undefined, 'PENDING', 'FAILED', 'SKIPPED', 'NOT_AVAILABLE'])(
    '%s uses neutral multiplier',
    (status) => expect(trustedAiMultiplier({
      aiAnalysisStatus: status,
      aiEvidenceWeightMultiplier: 1.1,
    })).toBe(1),
  );
  test('COMPLETE support and conflict values are used', () => {
    expect(trustedAiMultiplier({aiAnalysisStatus: 'COMPLETE', aiEvidenceWeightMultiplier: 1.1})).toBe(1.1);
    expect(trustedAiMultiplier({aiAnalysisStatus: 'COMPLETE', aiEvidenceWeightMultiplier: 0.9})).toBe(0.9);
  });
  test('out-of-range and non-finite COMPLETE values are clamped or neutral', () => {
    expect(trustedAiMultiplier({aiAnalysisStatus: 'COMPLETE', aiEvidenceWeightMultiplier: 4})).toBe(1.1);
    expect(trustedAiMultiplier({aiAnalysisStatus: 'COMPLETE', aiEvidenceWeightMultiplier: -4})).toBe(0.9);
    expect(trustedAiMultiplier({aiAnalysisStatus: 'COMPLETE', aiEvidenceWeightMultiplier: NaN})).toBe(1);
  });
});
