import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/helpers.dart';
import '../core/safety_config.dart';
import 'evidence_validation_result.dart';
import 'server_confidence_summary.dart';

/// Firestore status values — must match use-case specification exactly.
abstract final class HazardReportStatus {
  static const pendingReview = 'Pending Review';
  static const verified = 'Verified';
  static const rejected = 'Rejected';
  static const resolved = 'Resolved';

  static const all = [pendingReview, verified, rejected, resolved];
}

class HazardStatusHistoryEntry {
  const HazardStatusHistoryEntry({
    required this.status,
    this.note,
    this.changedBy,
    this.changedAt,
  });

  final String status;
  final String? note;
  final String? changedBy;
  final DateTime? changedAt;

  factory HazardStatusHistoryEntry.fromMap(Map<String, dynamic> map) {
    return HazardStatusHistoryEntry(
      status: '${map['status'] ?? ''}',
      note: map['note'] is String ? map['note'] as String : null,
      changedBy: map['changedBy'] is String ? map['changedBy'] as String : null,
      changedAt: asDate(map['changedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'status': status,
    if (note != null) 'note': note,
    if (changedBy != null) 'changedBy': changedBy,
    'changedAt': Timestamp.fromDate(changedAt ?? DateTime.now()),
  };
}

class HazardReport {
  const HazardReport({
    required this.id,
    required this.userId,
    required this.category,
    required this.severity,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.status,
    this.imageUrl,
    this.hasPhotoEvidence = false,
    this.evidenceValidation,
    this.createdAt,
    this.updatedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.statusHistory = const [],
    this.serverConfidence,
  });

  final String id;
  final String userId;
  final String category;
  final String severity;
  final String description;
  final String? imageUrl;
  final bool hasPhotoEvidence;
  final EvidenceValidationResult? evidenceValidation;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final List<HazardStatusHistoryEntry> statusHistory;
  final ServerConfidenceSummary? serverConfidence;

  bool get hasValidLocation =>
      SafetyConfig.validCoordinates(latitude, longitude);

  bool get isVerified => status == HazardReportStatus.verified;
  bool get isPendingReview => status == HazardReportStatus.pendingReview;
  bool get hasPhoto =>
      hasPhotoEvidence || (imageUrl != null && imageUrl!.trim().isNotEmpty);

  factory HazardReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return HazardReport.fromMap(doc.id, data);
  }

  factory HazardReport.fromMap(String id, Map<String, dynamic> data) {
    double readCoordinate(Object? primary, Object? fallback) {
      if (primary is num) return primary.toDouble();
      if (fallback is num) return fallback.toDouble();
      return double.nan;
    }

    final location = data['location'];
    final latitude = readCoordinate(
      data['latitude'],
      location is GeoPoint ? location.latitude : null,
    );
    final longitude = readCoordinate(
      data['longitude'],
      location is GeoPoint ? location.longitude : null,
    );

    final historyRaw = data['statusHistory'];
    final history = historyRaw is List
        ? historyRaw
              .whereType<Map>()
              .map(
                (entry) => HazardStatusHistoryEntry.fromMap(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .toList()
        : <HazardStatusHistoryEntry>[];

    return HazardReport(
      id: id,
      userId: '${data['userId'] ?? data['reporterId'] ?? ''}',
      category: '${data['category'] ?? 'Hazard'}',
      severity: '${data['severity'] ?? 'Medium'}',
      description: '${data['description'] ?? ''}',
      imageUrl:
          data['imageUrl'] is String && '${data['imageUrl']}'.trim().isNotEmpty
          ? '${data['imageUrl']}'
          : null,
      hasPhotoEvidence:
          data['hasPhotoEvidence'] == true ||
          data['evidenceStorage'] == 'firestore',
      evidenceValidation: data['evidenceValidationResult'] is Map
          ? EvidenceValidationResult.fromMap(
              Map<String, dynamic>.from(
                data['evidenceValidationResult'] as Map,
              ),
            )
          : null,
      latitude: latitude,
      longitude: longitude,
      status: '${data['status'] ?? HazardReportStatus.pendingReview}',
      createdAt: asDate(data['createdAt']),
      updatedAt: asDate(data['updatedAt']),
      reviewedBy: data['reviewedBy'] is String
          ? data['reviewedBy'] as String
          : null,
      reviewedAt: asDate(data['reviewedAt']),
      statusHistory: history,
      serverConfidence: data['serverConfidence'] is Map
          ? ServerConfidenceSummary.fromMap(
              Map<String, dynamic>.from(data['serverConfidence'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toCreateMap({
    required String hazardId,
    required String userId,
    required String category,
    required String severity,
    required String description,
    required double latitude,
    required double longitude,
    String? imageUrl,
    bool hasPhotoEvidence = false,
    EvidenceValidationResult? evidenceValidation,
  }) {
    return {
      'hazardId': hazardId,
      'userId': userId,
      'category': category,
      'severity': severity,
      'description': description,
      'imageUrl': imageUrl ?? '',
      'hasPhotoEvidence': hasPhotoEvidence,
      if (hasPhotoEvidence) 'evidenceStorage': 'firestore',
      if (evidenceValidation != null) ...{
        'evidenceValidationResult': evidenceValidation.toMap(),
        'evidenceSha256': evidenceValidation.sha256Fingerprint,
        'evidencePerceptualHash': evidenceValidation.perceptualHash,
        'evidenceSource': evidenceValidation.evidenceSource,
      },
      'latitude': latitude,
      'longitude': longitude,
      'status': HazardReportStatus.pendingReview,
      'statusHistory': [
        {
          'status': HazardReportStatus.pendingReview,
          'note': 'Report submitted for administrator review',
          'changedBy': userId,
          // Firestore transform sentinels are not supported inside arrays.
          'changedAt': Timestamp.now(),
        },
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class HazardDuplicateCandidate {
  const HazardDuplicateCandidate({
    required this.report,
    required this.distanceMeters,
  });

  final HazardReport report;
  final double distanceMeters;
}
