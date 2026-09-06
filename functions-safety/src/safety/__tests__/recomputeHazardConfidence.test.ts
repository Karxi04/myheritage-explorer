import {
  selectVotesForConfidence,
  shouldRecomputeConfidence,
} from '../recomputeHazardConfidence';

describe('confidence trigger recursion/cost guard', () => {
  test('create and delete always recalculate', () => {
    expect(shouldRecomputeConfidence(undefined, {voteType: 'HAZARD_EXISTS'})).toBe(true);
    expect(shouldRecomputeConfidence({voteType: 'HAZARD_EXISTS'}, undefined)).toBe(true);
  });
  test('AI completion and server validation changes recalculate', () => {
    const before = {voteType: 'HAZARD_EXISTS', aiAnalysisStatus: 'PENDING'};
    expect(shouldRecomputeConfidence(before, {...before, aiAnalysisStatus: 'COMPLETE'})).toBe(true);
    expect(shouldRecomputeConfidence(before, {...before, serverValidationStatus: 'VALID'})).toBe(true);
  });
  test('irrelevant metadata update does not recalculate', () => {
    const before = {voteType: 'HAZARD_EXISTS', harmlessMetadata: 'a'};
    expect(shouldRecomputeConfidence(before, {...before, harmlessMetadata: 'b'})).toBe(false);
  });
});

describe('legacy compatibility during recalculation', () => {
  const legacyVote = {
    userId: 'legacy-user',
    voteType: 'HAZARD_RESOLVED',
    createdAt: new Date(),
    distanceFromHazardMeters: 100,
    proximityBand: 'STRONG',
    isGpsValidated: true,
    hasPhotoEvidence: false,
    evidenceStorage: 'none',
  };

  test('valid legacy vote is included without migration', () => {
    expect(selectVotesForConfidence([
      {id: 'legacy-user', data: legacyVote},
    ], 'Verified')).toHaveLength(1);
  });

  test('legacy vote is validated in memory and invalid vote is excluded', () => {
    expect(selectVotesForConfidence([
      {id: 'legacy-user', data: {...legacyVote, distanceFromHazardMeters: 501}},
    ], 'Verified')).toHaveLength(0);
  });

  test('stored validation result controls official inclusion', () => {
    expect(selectVotesForConfidence([
      {id: 'legacy-user', data: {...legacyVote, serverValidationStatus: 'VALID'}},
      {id: 'invalid-user', data: {...legacyVote, userId: 'invalid-user', serverValidationStatus: 'INVALID'}},
    ], 'Verified')).toHaveLength(1);
  });
});
