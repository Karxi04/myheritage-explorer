import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/helpers.dart';

abstract final class HazardAuditAction {
  static const reportSubmitted = 'REPORT_SUBMITTED';
  static const verified = 'VERIFIED';
  static const rejected = 'REJECTED';
  static const reviewedKeepVerified = 'REVIEWED_KEEP_VERIFIED';
  static const markedResolved = 'MARKED_RESOLVED';

  static const all = [
    reportSubmitted,
    verified,
    rejected,
    reviewedKeepVerified,
    markedResolved,
  ];
}

class HazardAuditEntry {
  const HazardAuditEntry({
    required this.id,
    required this.action,
    this.previousStatus,
    this.newStatus,
    this.performedBy,
    this.performedByName,
    this.performedAt,
    this.note,
  });

  final String id;
  final String action;
  final String? previousStatus;
  final String? newStatus;
  final String? performedBy;
  final String? performedByName;
  final DateTime? performedAt;
  final String? note;

  factory HazardAuditEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return HazardAuditEntry.fromMap(doc.id, data);
  }

  factory HazardAuditEntry.fromMap(String id, Map<String, dynamic> data) {
    return HazardAuditEntry(
      id: id,
      action: '${data['action'] ?? ''}',
      previousStatus: data['previousStatus'] is String
          ? data['previousStatus'] as String
          : null,
      newStatus: data['newStatus'] is String
          ? data['newStatus'] as String
          : null,
      performedBy: data['performedBy'] is String
          ? data['performedBy'] as String
          : null,
      performedByName: data['performedByName'] is String
          ? data['performedByName'] as String
          : null,
      performedAt: asDate(data['performedAt']),
      note: data['note'] is String ? data['note'] as String : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      if (previousStatus != null) 'previousStatus': previousStatus,
      if (newStatus != null) 'newStatus': newStatus,
      if (performedBy != null) 'performedBy': performedBy,
      if (performedByName != null) 'performedByName': performedByName,
      'performedAt': performedAt != null
          ? Timestamp.fromDate(performedAt!)
          : FieldValue.serverTimestamp(),
      if (note != null) 'note': note,
    };
  }

  String get humanAction => switch (action) {
    HazardAuditAction.reportSubmitted => 'Hazard Submitted',
    HazardAuditAction.verified => 'Verified',
    HazardAuditAction.rejected => 'Rejected',
    HazardAuditAction.reviewedKeepVerified => 'Reviewed — Kept Verified',
    HazardAuditAction.markedResolved => 'Marked Resolved',
    _ => action,
  };
}
