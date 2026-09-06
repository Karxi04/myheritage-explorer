import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/helpers.dart';
import 'evidence_validation_result.dart';

abstract final class HazardVoteType {
  static const hazardExists = 'HAZARD_EXISTS';
  static const hazardResolved = 'HAZARD_RESOLVED';
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

  bool get hasReliablePhotoEvidence =>
      hasPhotoEvidence && evidenceValidation?.earnsEvidenceBonus == true;

  /// True when the vote photo strongly matches the original hazard scene.
  bool get hasSceneMatchedEvidence =>
      hasReliablePhotoEvidence &&
      (sceneMatchScore ?? evidenceValidation?.sceneMatchScore ?? 0) >= 0.7;

  factory HazardVote.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return HazardVote(
      id: doc.id,
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
    );
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
