import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/helpers.dart';
import 'evidence_validation_result.dart';

abstract final class HazardVoteType {
  static const hazardExists = 'HAZARD_EXISTS';
  static const hazardResolved = 'HAZARD_RESOLVED';
}

abstract final class ServerVoteValidationStatus {
  static const valid = 'VALID';
  static const invalid = 'INVALID';
  static const notValidated = 'NOT_VALIDATED';
}

class HazardVote {
  const HazardVote({
    required this.id,
    required this.userId,
    required this.voteType,
    this.createdAt,
    required this.distanceFromHazardMeters,
    required this.proximityBand,
    required this.isGpsValidated,
    this.photoUrl,
    required this.hasPhotoEvidence,
    this.evidenceStorage = 'none',
    this.evidenceValidation,
    this.sceneMatchScore,
    this.serverValidationStatus,
    this.serverValidatedAt,
    this.serverValidationReasons = const [],
  });

  final String id;
  final String userId;
  final String voteType;
  final DateTime? createdAt;
  final double distanceFromHazardMeters;
  final String proximityBand;
  final bool isGpsValidated;
  final String? photoUrl;
  final bool hasPhotoEvidence;
  final String evidenceStorage;
  final EvidenceValidationResult? evidenceValidation;

  /// Perceptual-hash similarity score [0,1] comparing this vote's evidence
  /// photo against the original hazard creation photo.
  final double? sceneMatchScore;
  final String? serverValidationStatus;
  final DateTime? serverValidatedAt;
  final List<String> serverValidationReasons;

  bool get hasReliablePhotoEvidence =>
      hasPhotoEvidence && evidenceValidation?.earnsEvidenceBonus == true;

  /// True when the vote photo strongly matches the original hazard scene.
  bool get hasSceneMatchedEvidence =>
      hasReliablePhotoEvidence &&
      (sceneMatchScore ?? evidenceValidation?.sceneMatchScore ?? 0) >= 0.7;

  factory HazardVote.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return HazardVote.fromMap(doc.id, doc.data() ?? {});
  }

  factory HazardVote.fromMap(String id, Map<String, dynamic> data) {
    final base = HazardVote(
      id: id,
      userId: '${data['userId'] ?? ''}',
      voteType: _normalizeVoteType('${data['voteType'] ?? data['type'] ?? ''}'),
      createdAt: asDate(data['createdAt']),
      distanceFromHazardMeters:
          (data['distanceFromHazardMeters'] as num?)?.toDouble() ??
          double.infinity,
      proximityBand: '${data['proximityBand'] ?? 'LEGACY'}',
      isGpsValidated: data['isGpsValidated'] == true,
      photoUrl: data['photoUrl'] as String?,
      hasPhotoEvidence: data['hasPhotoEvidence'] == true,
      evidenceStorage:
          '${data['evidenceStorage'] ?? (data['hasPhotoEvidence'] == true ? 'legacy' : 'none')}',
      evidenceValidation: data['evidenceValidationResult'] is Map
          ? EvidenceValidationResult.fromMap(
              Map<String, dynamic>.from(
                data['evidenceValidationResult'] as Map,
              ),
            )
          : null,
      sceneMatchScore: (data['sceneMatchScore'] as num?)?.toDouble(),
      serverValidationStatus: data['serverValidationStatus'] is String
          ? data['serverValidationStatus'] as String
          : null,
      serverValidatedAt: asDate(data['serverValidatedAt']),
      serverValidationReasons:
          (data['serverValidationReasons'] as List? ?? const [])
              .whereType<String>()
              .toList(),
    );
    return _attachAiFields(base, data);
  }

  Map<String, dynamic> toMap({
    required String userId,
    required String voteType,
    required double distanceFromHazardMeters,
    required String proximityBand,
    String? photoUrl,
    bool hasPhotoEvidence = false,
    String evidenceStorage = 'none',
    EvidenceValidationResult? evidenceValidation,
    double? sceneMatchScore,
  }) {
    return {
      'userId': userId,
      'voteType': voteType,
      'createdAt': FieldValue.serverTimestamp(),
      'distanceFromHazardMeters': distanceFromHazardMeters,
      'proximityBand': proximityBand,
      'isGpsValidated': true,
      'photoUrl': photoUrl ?? '',
      'hasPhotoEvidence': hasPhotoEvidence,
      'evidenceStorage': evidenceStorage,
      if (evidenceValidation != null) ...{
        'evidenceValidationResult': evidenceValidation.toMap(),
        'evidenceSha256': evidenceValidation.sha256Fingerprint,
        'evidencePerceptualHash': evidenceValidation.perceptualHash,
        'evidenceSource': evidenceValidation.evidenceSource,
      },
      'sceneMatchScore': ?sceneMatchScore,
      // AI analysis fields are intentionally NOT written by the client.
      // They are set exclusively by the Cloud Function via Admin SDK.
      // Server validation fields are also intentionally omitted.
    };
  }

  static String _normalizeVoteType(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'upvote' || 'hazard_exists' => HazardVoteType.hazardExists,
      'resolved' || 'hazard_resolved' => HazardVoteType.hazardResolved,
      _ => raw,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI analysis fields — read-only, written exclusively by Cloud Function
// ─────────────────────────────────────────────────────────────────────────────

/// Possible values for [HazardVoteAi.analysisStatus].
abstract final class AiAnalysisStatus {
  static const pending = 'PENDING';
  static const complete = 'COMPLETE';
  static const failed = 'FAILED';
  static const skipped = 'SKIPPED';
  static const notAvailable = 'NOT_AVAILABLE';
}

/// Possible values for [HazardVoteAi.agreement].
abstract final class AiAgreement {
  static const supportsVote = 'SUPPORTS_VOTE';
  static const conflictsWithVote = 'CONFLICTS_WITH_VOTE';
  static const inconclusive = 'INCONCLUSIVE';
}

/// AI evidence analysis result — attached to a [HazardVote] after the
/// Cloud Function writes back the Gemini result.
///
/// All fields are nullable/defaulted so legacy votes without AI data
/// remain fully functional. The multiplier defaults to 1.0 (neutral).
class HazardVoteAi {
  const HazardVoteAi({
    this.analysisStatus,
    this.sceneMatchScore,
    this.hazardRelevanceScore,
    this.conditionAssessment,
    this.conditionConfidence,
    this.agreement,
    this.evidenceWeightMultiplier = 1.0,
    this.analysisSummary,
    this.failureReason,
    this.completedAt,
  });

  /// e.g. PENDING / COMPLETE / FAILED / SKIPPED / NOT_AVAILABLE. Null on legacy votes.
  final String? analysisStatus;

  /// AI semantic scene similarity [0,1]. Null until COMPLETE.
  final double? sceneMatchScore;

  /// AI hazard relevance [0,1]. Null until COMPLETE.
  final double? hazardRelevanceScore;

  /// AI condition: HAZARD_STILL_PRESENT / APPEARS_RESOLVED / UNCERTAIN.
  final String? conditionAssessment;

  /// AI condition confidence [0,1]. Null until COMPLETE.
  final double? conditionConfidence;

  /// SUPPORTS_VOTE / CONFLICTS_WITH_VOTE / INCONCLUSIVE. Null until COMPLETE.
  final String? agreement;

  /// Multiplier applied to the existing evidence weight. Defaults to 1.0
  /// (neutral) while pending, skipped, failed, or legacy. Clamped server-side [0.90–1.10].
  final double evidenceWeightMultiplier;

  /// One-sentence admin summary from Gemini. Null until COMPLETE.
  final String? analysisSummary;

  /// Failure or skip reason code (e.g. NO_PHOTO, ORIGINAL_EVIDENCE_UNAVAILABLE).
  final String? failureReason;

  /// Timestamp when server-side AI analysis finished.
  final DateTime? completedAt;

  bool get isComplete => analysisStatus == AiAnalysisStatus.complete;

  /// True ONLY when explicitly marked PENDING by server or client.
  /// Legacy votes where status is null return false.
  bool get isPending => analysisStatus == AiAnalysisStatus.pending;

  bool get isFailed => analysisStatus == AiAnalysisStatus.failed;
  bool get isSkipped => analysisStatus == AiAnalysisStatus.skipped;

  /// True when the vote was created before AI analysis or without AI tracking.
  bool get isNotAvailable =>
      analysisStatus == null || analysisStatus == AiAnalysisStatus.notAvailable;
}

/// Subclass that carries AI analysis data alongside the base vote.
final class _HazardVoteWithAi extends HazardVote {
  _HazardVoteWithAi(HazardVote base, this._ai)
    : super(
        id: base.id,
        userId: base.userId,
        voteType: base.voteType,
        createdAt: base.createdAt,
        distanceFromHazardMeters: base.distanceFromHazardMeters,
        proximityBand: base.proximityBand,
        isGpsValidated: base.isGpsValidated,
        photoUrl: base.photoUrl,
        hasPhotoEvidence: base.hasPhotoEvidence,
        evidenceStorage: base.evidenceStorage,
        evidenceValidation: base.evidenceValidation,
        sceneMatchScore: base.sceneMatchScore,
        serverValidationStatus: base.serverValidationStatus,
        serverValidatedAt: base.serverValidatedAt,
        serverValidationReasons: base.serverValidationReasons,
      );

  final HazardVoteAi _ai;
}

/// Parse and attach AI fields from a Firestore document data map.
HazardVote _attachAiFields(HazardVote base, Map<String, dynamic> data) {
  final status = data['aiAnalysisStatus'] as String?;
  final rawMultiplier =
      (data['aiEvidenceWeightMultiplier'] as num?)?.toDouble() ?? 1.0;
  // Defensive clamp on the client — authoritative clamping is server-side.
  final multiplier = rawMultiplier.clamp(0.90, 1.10);

  final ai = HazardVoteAi(
    analysisStatus: status,
    sceneMatchScore: (data['aiSceneMatchScore'] as num?)?.toDouble(),
    hazardRelevanceScore: (data['aiHazardRelevanceScore'] as num?)?.toDouble(),
    conditionAssessment: data['aiConditionAssessment'] as String?,
    conditionConfidence: (data['aiConditionConfidence'] as num?)?.toDouble(),
    agreement: data['aiAgreement'] as String?,
    evidenceWeightMultiplier: multiplier,
    analysisSummary: data['aiAnalysisSummary'] as String?,
    failureReason: data['aiAnalysisFailureReason'] as String?,
    completedAt: asDate(data['aiAnalysisCompletedAt']),
  );
  return _HazardVoteWithAi(base, ai);
}

/// Extension to safely access AI analysis from any [HazardVote].
extension HazardVoteAiAccess on HazardVote {
  /// AI analysis result for this vote. Returns a default neutral result if
  /// the vote was created before AI analysis was deployed (legacy).
  HazardVoteAi get aiAnalysis {
    if (this is _HazardVoteWithAi) {
      return (this as _HazardVoteWithAi)._ai;
    }
    return const HazardVoteAi(); // legacy vote — neutral defaults
  }
}
