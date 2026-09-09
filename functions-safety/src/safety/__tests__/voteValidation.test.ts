import {validateVote} from '../voteValidation';

const NOW = new Date('2026-09-06T12:00:00.000Z');
const SHA = 'a'.repeat(64);

function vote(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    userId: 'traveler-1',
    voteType: 'HAZARD_EXISTS',
    createdAt: NOW,
    distanceFromHazardMeters: 70,
    proximityBand: 'STRONG',
    isGpsValidated: true,
    hasPhotoEvidence: false,
    evidenceStorage: 'none',
    ...overrides,
  };
}

function validate(data: Record<string, unknown>, hazardStatus = 'Verified') {
  return validateVote(data, {
    voteId: 'traveler-1',
    hazardExists: true,
    hazardStatus,
    now: NOW,
  });
}

describe('server vote validation', () => {
  test.each(['HAZARD_EXISTS', 'HAZARD_RESOLVED'])(
    'accepts valid %s vote',
    (voteType) => expect(validate(vote({voteType})).status).toBe('VALID'),
  );

  test.each([0, 500])('accepts boundary distance %s m', (distance) => {
    const proximityBand = distance <= 100 ? 'STRONG' : 'WEAK';
    expect(validate(vote({distanceFromHazardMeters: distance, proximityBand})).status)
      .toBe('VALID');
  });

  test('accepts structurally valid optional photo metadata', () => {
    const result = validate(vote({
      hasPhotoEvidence: true,
      evidenceStorage: 'firestore',
      sceneMatchScore: 0.7,
      evidenceValidationResult: {
        isValid: true,
        duplicateDetected: false,
        evidenceSource: 'CAMERA',
        overallEvidenceScore: 0.85,
        sha256Fingerprint: SHA,
        perceptualHash: '0123456789abcdef',
      },
    }));
    expect(result.status).toBe('VALID');
  });

  test.each([
    ['unsupported vote type', {voteType: 'UP'}, 'INVALID_VOTE_TYPE'],
    ['negative distance', {distanceFromHazardMeters: -1}, 'INVALID_DISTANCE'],
    ['outside distance', {distanceFromHazardMeters: 500.01}, 'INVALID_DISTANCE'],
    ['non-finite distance', {distanceFromHazardMeters: Infinity}, 'INVALID_DISTANCE'],
    ['invalid band', {proximityBand: 'CLOSE'}, 'INVALID_PROXIMITY_BAND'],
    ['distance/band mismatch', {distanceFromHazardMeters: 250, proximityBand: 'WEAK'}, 'DISTANCE_BAND_MISMATCH'],
    ['GPS flag false', {isGpsValidated: false}, 'GPS_VALIDATION_REQUIRED'],
    ['UID mismatch', {userId: 'someone-else'}, 'INVALID_USER_ID'],
  ])('rejects %s', (_name, changes, reason) => {
    const result = validate(vote(changes as Record<string, unknown>));
    expect(result.status).toBe('INVALID');
    expect(result.reasons).toContain(reason);
  });

  test.each(['Pending Review', 'Rejected', 'Resolved'])(
    'rejects vote when hazard is %s',
    (status) => {
      const result = validate(vote(), status);
      expect(result.status).toBe('INVALID');
      expect(result.reasons).toContain('HAZARD_NOT_VERIFIED');
    },
  );

  test('rejects missing hazard and unreasonable future timestamp', () => {
    const result = validateVote(vote({createdAt: new Date(NOW.getTime() + 301000)}), {
      voteId: 'traveler-1', hazardExists: false, hazardStatus: undefined, now: NOW,
    });
    expect(result.reasons).toEqual(expect.arrayContaining([
      'HAZARD_NOT_FOUND', 'HAZARD_NOT_VERIFIED', 'INVALID_CREATED_AT',
    ]));
  });
});
