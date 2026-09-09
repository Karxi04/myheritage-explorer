/**
 * Basic server-side validation for a community confirmation.
 *
 * This verifies document structure and consistency with the Safety rules. It
 * does NOT prove that the client-reported GPS position was physically genuine.
 */

export type ServerValidationStatus = 'VALID' | 'INVALID' | 'NOT_VALIDATED';

export interface VoteValidationResult {
  status: ServerValidationStatus;
  reasons: string[];
}

export interface VoteValidationContext {
  voteId: string;
  hazardExists: boolean;
  hazardStatus?: unknown;
  now?: Date;
}

const VOTE_TYPES = new Set(['HAZARD_EXISTS', 'HAZARD_RESOLVED']);
const PROXIMITY_BANDS = new Set(['STRONG', 'NORMAL', 'WEAK']);
const EVIDENCE_SOURCES = new Set(['CAMERA', 'GALLERY']);
const HASH_64 = /^[0-9a-fA-F]{16}$/;
const SHA_256 = /^[0-9a-f]{64}$/;
const MAX_DISTANCE_METERS = 500;
const FUTURE_TOLERANCE_MS = 5 * 60 * 1000;

export function proximityBandForDistance(distance: number): string {
  if (distance <= 100) return 'STRONG';
  if (distance <= 300) return 'NORMAL';
  return 'WEAK';
}

export function dateFromUnknown(value: unknown): Date | null {
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
  if (typeof value === 'string' || typeof value === 'number') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (typeof value === 'object' && value !== null) {
    const timestamp = value as {toDate?: () => Date};
    if (typeof timestamp.toDate === 'function') {
      const parsed = timestamp.toDate();
      return parsed instanceof Date && !Number.isNaN(parsed.getTime())
        ? parsed
        : null;
    }
  }
  return null;
}

function isFiniteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

function validatePhotoMetadata(vote: Record<string, unknown>): string[] {
  const reasons: string[] = [];
  const hasPhoto = vote['hasPhotoEvidence'];
  if (typeof hasPhoto !== 'boolean') return ['INVALID_PHOTO_FLAG'];

  if (!hasPhoto) {
    if (vote['evidenceStorage'] !== 'none') reasons.push('INVALID_EVIDENCE_STORAGE');
    return reasons;
  }

  if (vote['evidenceStorage'] !== 'firestore') reasons.push('INVALID_EVIDENCE_STORAGE');
  const evidence = vote['evidenceValidationResult'];
  if (typeof evidence !== 'object' || evidence === null || Array.isArray(evidence)) {
    reasons.push('INVALID_EVIDENCE_METADATA');
    return reasons;
  }

  const data = evidence as Record<string, unknown>;
  if (data['isValid'] !== true || data['duplicateDetected'] !== false) {
    reasons.push('INVALID_EVIDENCE_METADATA');
  }
  if (!EVIDENCE_SOURCES.has(String(data['evidenceSource'] ?? ''))) {
    reasons.push('INVALID_EVIDENCE_SOURCE');
  }
  if (!isFiniteNumber(data['overallEvidenceScore']) ||
      data['overallEvidenceScore'] < 0 || data['overallEvidenceScore'] > 1) {
    reasons.push('INVALID_EVIDENCE_SCORE');
  }
  if (!SHA_256.test(String(data['sha256Fingerprint'] ?? '')) ||
      !HASH_64.test(String(data['perceptualHash'] ?? ''))) {
    reasons.push('INVALID_EVIDENCE_FINGERPRINT');
  }
  const scene = vote['sceneMatchScore'];
  if (scene !== undefined &&
      (!isFiniteNumber(scene) || scene < 0 || scene > 1)) {
    reasons.push('INVALID_SCENE_MATCH_SCORE');
  }
  return reasons;
}

/** Return every reason so backend logs/tests remain explainable. */
export function validateVote(
  vote: Record<string, unknown>,
  context: VoteValidationContext,
): VoteValidationResult {
  const reasons: string[] = [];
  const now = context.now ?? new Date();

  if (!context.hazardExists) reasons.push('HAZARD_NOT_FOUND');
  if (context.hazardStatus !== 'Verified') reasons.push('HAZARD_NOT_VERIFIED');

  const userId = vote['userId'];
  if (typeof userId !== 'string' || userId.length === 0 || userId.length > 128 ||
      userId.includes('/') || userId !== context.voteId) {
    reasons.push('INVALID_USER_ID');
  }
  if (!VOTE_TYPES.has(String(vote['voteType'] ?? ''))) {
    reasons.push('INVALID_VOTE_TYPE');
  }

  const createdAt = dateFromUnknown(vote['createdAt']);
  if (createdAt === null ||
      createdAt.getTime() > now.getTime() + FUTURE_TOLERANCE_MS) {
    reasons.push('INVALID_CREATED_AT');
  }

  const distance = vote['distanceFromHazardMeters'];
  if (!isFiniteNumber(distance) || distance < 0 || distance > MAX_DISTANCE_METERS) {
    reasons.push('INVALID_DISTANCE');
  }

  const band = vote['proximityBand'];
  if (!PROXIMITY_BANDS.has(String(band ?? ''))) {
    reasons.push('INVALID_PROXIMITY_BAND');
  } else if (isFiniteNumber(distance) && distance >= 0 &&
      distance <= MAX_DISTANCE_METERS &&
      band !== proximityBandForDistance(distance)) {
    reasons.push('DISTANCE_BAND_MISMATCH');
  }

  if (vote['isGpsValidated'] !== true) reasons.push('GPS_VALIDATION_REQUIRED');
  reasons.push(...validatePhotoMetadata(vote));

  return {
    status: reasons.length === 0 ? 'VALID' : 'INVALID',
    reasons: [...new Set(reasons)],
  };
}
