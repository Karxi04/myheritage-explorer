import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_lib;

import '../core/services.dart';
import '../models/hazard_report.dart';

class HazardReportService {
  HazardReportService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? AppServices.db,
      _auth = auth ?? AppServices.auth;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static const collectionName = 'hazard_reports';
  static const evidenceCollectionName = 'evidence';
  static const evidenceDocumentName = 'photo';
  static const maxEvidenceBytes = 400 * 1024;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection(collectionName);

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<HazardReport>> watchVerifiedReports() {
    return _collection
        .where('status', isEqualTo: HazardReportStatus.verified)
        .snapshots()
        .map(_mapAndSort);
  }

  Stream<List<HazardReport>> watchReportsByUser(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(_mapAndSort);
  }

  Stream<List<HazardReport>> watchPendingReports() {
    return _collection
        .where('status', isEqualTo: HazardReportStatus.pendingReview)
        .snapshots()
        .map(_mapAndSort);
  }

  Stream<List<HazardReport>> watchVerifiedUnresolvedReports() {
    return _collection
        .where('status', isEqualTo: HazardReportStatus.verified)
        .snapshots()
        .map(_mapAndSort);
  }

  Stream<List<HazardReport>> watchAllReports() {
    return _collection.snapshots().map(_mapAndSort);
  }

  Stream<HazardReport?> watchReport(String hazardId) {
    return _collection.doc(hazardId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return HazardReport.fromDoc(doc);
    });
  }

  Future<HazardReport?> getReport(String hazardId) async {
    final doc = await _collection.doc(hazardId).get();
    if (!doc.exists) return null;
    return HazardReport.fromDoc(doc);
  }

  Stream<Uint8List?> watchEvidenceBytes(String hazardId) {
    return _collection
        .doc(hazardId)
        .collection(evidenceCollectionName)
        .doc(evidenceDocumentName)
        .snapshots()
        .map((snapshot) {
          final value = snapshot.data()?['imageBytes'];
          return value is Blob ? value.bytes : null;
        });
  }

  Future<String> createReport({
    required String category,
    required String severity,
    required String description,
    required double latitude,
    required double longitude,
    Uint8List? imageBytes,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Please sign in as a tourist first.');
    }

    if (imageBytes == null || imageBytes.isEmpty) {
      throw Exception('Photo evidence is required.');
    }

    final compressedBytes = await compute(compressHazardEvidence, imageBytes);
    final doc = _collection.doc();
    final evidenceRef = doc
        .collection(evidenceCollectionName)
        .doc(evidenceDocumentName);
    final batch = _db.batch();

    batch.set(
      doc,
      HazardReport(
        id: '',
        userId: uid,
        category: category,
        severity: severity,
        description: description,
        latitude: latitude,
        longitude: longitude,
        status: HazardReportStatus.pendingReview,
      ).toCreateMap(
        hazardId: doc.id,
        userId: uid,
        category: category,
        severity: severity,
        description: description,
        latitude: latitude,
        longitude: longitude,
        hasPhotoEvidence: true,
      ),
    );
    batch.set(evidenceRef, {
      'hazardId': doc.id,
      'userId': uid,
      'imageBytes': Blob(compressedBytes),
      'contentType': 'image/jpeg',
      'byteLength': compressedBytes.lengthInBytes,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return doc.id;
  }

  Future<void> updateStatus({
    required HazardReport report,
    required String status,
    required String adminId,
    required String note,
  }) async {
    if (!HazardReportStatus.all.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unsupported status.');
    }

    final reportRef = _collection.doc(report.id);
    final notificationRef = _db.collection('notifications').doc();

    await _db.runTransaction((transaction) async {
      final currentSnapshot = await transaction.get(reportRef);
      if (!currentSnapshot.exists) {
        throw Exception('This hazard report no longer exists.');
      }

      final current = HazardReport.fromDoc(currentSnapshot);
      if (!_isAllowedTransition(current.status, status)) {
        throw Exception(
          'This report can no longer change from ${current.status} to $status.',
        );
      }

      transaction.update(reportRef, {
        'status': status,
        'reviewedBy': adminId,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': status,
            'note': note,
            'changedBy': adminId,
            'changedAt': Timestamp.now(),
          },
        ]),
      });

      transaction.set(notificationRef, {
        'notificationId': notificationRef.id,
        'userId': current.userId,
        'title': _notificationTitle(status),
        'message': 'Your ${current.category} hazard report is now $status.',
        'type': 'hazard_status',
        'hazardId': current.id,
        'referenceId': current.id,
        'isRead': false,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  bool _isAllowedTransition(String from, String to) {
    if (from == HazardReportStatus.pendingReview) {
      return to == HazardReportStatus.verified ||
          to == HazardReportStatus.rejected;
    }
    if (from == HazardReportStatus.verified) {
      return to == HazardReportStatus.resolved;
    }
    return false;
  }

  String _notificationTitle(String status) => switch (status) {
    HazardReportStatus.verified => 'Hazard report verified',
    HazardReportStatus.rejected => 'Hazard report rejected',
    HazardReportStatus.resolved => 'Hazard report resolved',
    _ => 'Hazard report updated',
  };

  List<HazardReport> _mapAndSort(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final reports = snapshot.docs.map(HazardReport.fromDoc).toList()
      ..sort(
        (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
          a.createdAt ?? DateTime(2000),
        ),
      );
    return reports;
  }
}

Uint8List compressHazardEvidence(Uint8List sourceBytes) {
  image_lib.Image? decoded;
  try {
    decoded = image_lib.decodeImage(sourceBytes);
  } catch (_) {
    throw Exception('The selected photo format could not be processed.');
  }
  if (decoded == null) {
    throw Exception('The selected photo format could not be processed.');
  }

  final oriented = image_lib.bakeOrientation(decoded);
  const attempts = <(int, int)>[
    (960, 68),
    (840, 60),
    (720, 52),
    (600, 44),
    (480, 36),
  ];

  Uint8List? smallest;
  for (final attempt in attempts) {
    final maxSide = attempt.$1;
    final quality = attempt.$2;
    final scale = oriented.width > oriented.height
        ? maxSide / oriented.width
        : maxSide / oriented.height;
    final resized = scale < 1
        ? image_lib.copyResize(
            oriented,
            width: (oriented.width * scale).round().clamp(1, maxSide),
            height: (oriented.height * scale).round().clamp(1, maxSide),
            interpolation: image_lib.Interpolation.average,
          )
        : oriented;
    final encoded = Uint8List.fromList(
      image_lib.encodeJpg(resized, quality: quality),
    );
    smallest = encoded;
    if (encoded.lengthInBytes <= HazardReportService.maxEvidenceBytes) {
      return encoded;
    }
  }

  throw Exception(
    'The compressed photo is ${smallest?.lengthInBytes ?? 0} bytes and still '
    'exceeds the Firestore evidence limit. Please retake the photo.',
  );
}
