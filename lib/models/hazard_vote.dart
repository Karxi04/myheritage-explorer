import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/helpers.dart';

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
      evidenceStorage: '${data['evidenceStorage'] ?? (data['hasPhotoEvidence'] == true ? 'legacy' : 'none')}',
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
