import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_lib;

import '../core/services.dart';
import '../core/safety_config.dart';
import '../models/evidence_validation_result.dart';
import '../models/hazard_audit_entry.dart';
import '../models/hazard_report.dart';
import 'evidence_image_validation_service.dart';
import 'location_service.dart';

class HazardReportService {
  HazardReportService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    LocationService? locationService,
  }) : _db = firestore ?? AppServices.db,
       _auth = auth ?? AppServices.auth,
       _locationService = locationService ?? const LocationService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final LocationService _locationService;

  static const collectionName = 'hazard_reports';
  static const evidenceCollectionName = 'evidence';
  static const evidenceDocumentName = 'photo';
  static const auditCollectionName = 'audit_logs';
  static const maxEvidenceBytes = 400 * 1024;
  static const _validationService = EvidenceImageValidationService();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection(collectionName);

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<HazardAuditEntry>> watchAuditTrail(String hazardId) {
    return _collection
        .doc(hazardId)
        .collection(auditCollectionName)
        .orderBy('performedAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(HazardAuditEntry.fromDoc).toList(),
        );
  }

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

  Future<List<HazardDuplicateCandidate>> findDuplicateCandidates({
    required String category,
    required double latitude,
    required double longitude,
    double radiusMeters = SafetyConfig.duplicateHazardRadiusMeters,
    Duration lookback = SafetyConfig.duplicateHazardLookback,
  }) async {
    if (!SafetyConfig.validCoordinates(latitude, longitude)) {
      return const [];
    }

    final now = DateTime.now();
    final docsMap = <String, DocumentSnapshot<Map<String, dynamic>>>{};

    // 1. Fetch active Verified reports in this category.
    final verifiedSnapshots = await _collection
        .where('status', isEqualTo: HazardReportStatus.verified)
        .where('category', isEqualTo: category)
        .get();
    for (final doc in verifiedSnapshots.docs) {
      docsMap[doc.id] = doc;
    }

    // 2. Also fetch the current user's own Pending Review reports in this category.
    final uid = _uid;
    if (uid != null) {
      try {
        final pendingSnapshots = await _collection
            .where('userId', isEqualTo: uid)
            .where('status', isEqualTo: HazardReportStatus.pendingReview)
            .where('category', isEqualTo: category)
            .get();
        for (final doc in pendingSnapshots.docs) {
          docsMap[doc.id] = doc;
        }
      } catch (e) {
        // Fallback gracefully if own pending reports query fails
        debugPrint('Pending reports check warning: $e');
      }
    }

    final candidates = <HazardDuplicateCandidate>[];

    for (final doc in docsMap.values) {
      final report = HazardReport.fromDoc(doc);
      if (!report.hasValidLocation) continue;
      if (report.category != category) continue;
      if (report.status != HazardReportStatus.verified &&
          report.status != HazardReportStatus.pendingReview) {
        continue;
      }

      // Check recency lookback
      if (report.createdAt != null) {
        final age = now.difference(report.createdAt!);
        if (age > lookback) continue;
      }

      final distance = _locationService.distanceBetween(
        startLatitude: latitude,
        startLongitude: longitude,
        endLatitude: report.latitude,
        endLongitude: report.longitude,
      );

      if (distance <= radiusMeters) {
        candidates.add(
          HazardDuplicateCandidate(report: report, distanceMeters: distance),
        );
      }
    }

    // Sort by nearest distance first, then newer report first
    candidates.sort((a, b) {
      final distDiff = a.distanceMeters.compareTo(b.distanceMeters);
      if (distDiff != 0) return distDiff;
      final timeA = a.report.createdAt ?? DateTime(2000);
      final timeB = b.report.createdAt ?? DateTime(2000);
      return timeB.compareTo(timeA);
    });

    return candidates;
  }

  Future<EvidenceValidationResult> validateEvidence({
    required Uint8List imageBytes,
    required String evidenceSource,
    bool checkDuplicates = false,
  }) async {
    if (!checkDuplicates) {
      return _validationService.validate(
        bytes: imageBytes,
        evidenceSource: evidenceSource,
      );
    }
    final uid = _uid;
    if (uid == null) throw FirebaseAuthException(code: 'unauthenticated');
    final fingerprints = await loadEvidenceFingerprintsForUser(uid);
    return _validationService.validate(
      bytes: imageBytes,
      evidenceSource: evidenceSource,
      existingSha256Fingerprints: fingerprints.sha256,
      existingPerceptualHashes: fingerprints.perceptual,
    );
  }

  Future<EvidenceFingerprints> loadEvidenceFingerprintsForUser(
    String userId,
  ) async {
    // A cache-only result could miss earlier evidence and approve a duplicate.
    final reports = await _collection
        .where('userId', isEqualTo: userId)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    final priorVotes = await _db
        .collectionGroup('votes')
        .where('userId', isEqualTo: userId)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    final sha = <String>{};
    final perceptual = <String>{};
    for (final report in [...reports.docs, ...priorVotes.docs]) {
      final data = report.data();
      final exact = '${data['evidenceSha256'] ?? ''}'.trim();
      final similar = '${data['evidencePerceptualHash'] ?? ''}'.trim();
      if (exact.isNotEmpty) sha.add(exact);
      if (similar.isNotEmpty) perceptual.add(similar);
    }
    return EvidenceFingerprints(sha256: sha, perceptual: perceptual);
  }

  Future<String> createReport({
    required String category,
    required String severity,
    required String description,
    required double latitude,
    required double longitude,
    Uint8List? imageBytes,
    String evidenceSource = EvidenceSource.camera,
    EvidenceValidationResult? evidenceValidation,
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('Please sign in as a tourist first.');
    }

    if (description.trim().isEmpty ||
        description.trim().length > 500 ||
        category.trim().isEmpty ||
        !['Low', 'Medium', 'High'].contains(severity)) {
      throw ArgumentError(
        'Enter a category, severity and description of up to 500 characters.',
      );
    }
    if (!SafetyConfig.validCoordinates(latitude, longitude)) {
      throw ArgumentError('A valid report location is required.');
    }
    if (imageBytes == null || imageBytes.isEmpty) {
      throw Exception('Photo evidence is required.');
    }

    final validation =
        evidenceValidation ??
        await validateEvidence(
          imageBytes: imageBytes,
          evidenceSource: evidenceSource,
        );
    if (!validation.isValid) {
      throw Exception('Unable to use this image. Please choose another photo.');
    }

    final sanitizedLevel = switch (validation.validationLevel) {
      EvidenceValidationLevel.strong => EvidenceValidationLevel.strong,
      EvidenceValidationLevel.good => EvidenceValidationLevel.good,
      EvidenceValidationLevel.lowQuality => EvidenceValidationLevel.lowQuality,
      _ => EvidenceValidationLevel.acceptable,
    };
    final sanitizedValidation = EvidenceValidationResult(
      isValid: true,
      qualityScore: validation.qualityScore,
      sharpnessScore: validation.sharpnessScore,
      brightnessScore: validation.brightnessScore,
      resolutionScore: validation.resolutionScore,
      duplicateDetected: false,
      evidenceSource: evidenceSource,
      semanticValidationAvailable: false,
      validationLevel: sanitizedLevel,
      warnings: validation.warnings,
      overallEvidenceScore: validation.overallEvidenceScore > 0
          ? validation.overallEvidenceScore
          : validation.qualityScore.clamp(0.1, 1.0),
      sha256Fingerprint: validation.sha256Fingerprint,
      perceptualHash: validation.perceptualHash,
      exposureStatus: validation.exposureStatus,
      width: validation.width,
      height: validation.height,
      fileFormat: validation.fileFormat,
      semanticRelevanceScore: validation.semanticRelevanceScore,
      sceneMatchScore: validation.sceneMatchScore,
    );

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
        evidenceValidation: sanitizedValidation,
      ),
    );
    batch.set(evidenceRef, {
      'hazardId': doc.id,
      'userId': uid,
      'imageBytes': Blob(compressedBytes),
      'contentType': 'image/jpeg',
      'byteLength': compressedBytes.lengthInBytes,
      'sourceSha256': sanitizedValidation.sha256Fingerprint,
      'perceptualHash': sanitizedValidation.perceptualHash,
      'validationLevel': sanitizedValidation.validationLevel,
      'evidenceSource': sanitizedValidation.evidenceSource,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return doc.id;
  }

  Future<void> updateStatus({
    required HazardReport report,
    required String status,
    required String adminId,
    String? adminName,
    required String note,
  }) async {
    if (_uid == null || _uid != adminId) {
      throw FirebaseAuthException(code: 'unauthenticated');
    }
    if (!HazardReportStatus.all.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unsupported status.');
    }

    final reportRef = _collection.doc(report.id);
    final notificationRef = _db.collection('notifications').doc();
    final auditRef = reportRef.collection(auditCollectionName).doc();

    final auditAction = switch (status) {
      HazardReportStatus.verified => HazardAuditAction.verified,
      HazardReportStatus.rejected => HazardAuditAction.rejected,
      HazardReportStatus.resolved => HazardAuditAction.markedResolved,
      _ => status,
    };

    await _db.runTransaction((transaction) async {
      final currentSnapshot = await transaction.get(reportRef);
      if (!currentSnapshot.exists) {
        throw Exception('This hazard report no longer exists.');
      }

      final current = HazardReport.fromDoc(currentSnapshot);
      if (current.status != report.status ||
          !_isAllowedTransition(current.status, status)) {
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

      transaction.set(auditRef, {
        'action': auditAction,
        'previousStatus': current.status,
        'newStatus': status,
        'performedBy': adminId,
        if (adminName != null && adminName.isNotEmpty)
          'performedByName': adminName,
        'performedAt': FieldValue.serverTimestamp(),
        'note': note,
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

  Future<void> keepVerified({
    required HazardReport report,
    required String adminId,
    String? adminName,
    required String note,
  }) async {
    if (_uid == null || _uid != adminId) {
      throw FirebaseAuthException(code: 'unauthenticated');
    }
    if (report.status != HazardReportStatus.verified) {
      throw ArgumentError('Only verified hazards can be kept verified.');
    }

    final reportRef = _collection.doc(report.id);
    final auditRef = reportRef.collection(auditCollectionName).doc();

    await _db.runTransaction((transaction) async {
      final currentSnapshot = await transaction.get(reportRef);
      if (!currentSnapshot.exists) {
        throw Exception('This hazard report no longer exists.');
      }

      final current = HazardReport.fromDoc(currentSnapshot);
      if (current.status != HazardReportStatus.verified) {
        throw Exception('This hazard report is no longer verified.');
      }

      transaction.update(reportRef, {
        'reviewedBy': adminId,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(auditRef, {
        'action': HazardAuditAction.reviewedKeepVerified,
        'previousStatus': HazardReportStatus.verified,
        'newStatus': HazardReportStatus.verified,
        'performedBy': adminId,
        if (adminName != null && adminName.isNotEmpty)
          'performedByName': adminName,
        'performedAt': FieldValue.serverTimestamp(),
        'note': note,
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

class EvidenceFingerprints {
  const EvidenceFingerprints({required this.sha256, required this.perceptual});

  final Set<String> sha256;
  final Set<String> perceptual;
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
