import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/safety_config.dart';
import '../core/services.dart';
import '../models/evidence_validation_result.dart';
import '../models/hazard_report.dart';
import '../models/hazard_vote.dart';
import 'evidence_image_validation_service.dart';
import 'hazard_report_service.dart';

class HazardVoteService {
  HazardVoteService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? AppServices.db,
      _auth = auth ?? AppServices.auth;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  static const _validationService = EvidenceImageValidationService();

  CollectionReference<Map<String, dynamic>> _votesRef(String hazardId) => _db
      .collection(HazardReportService.collectionName)
      .doc(hazardId)
      .collection('votes');

  Stream<List<HazardVote>> watchVotes(String hazardId) => _votesRef(hazardId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(HazardVote.fromDoc).toList());

  Future<List<HazardVote>> getVotes(String hazardId) async =>
      (await _votesRef(hazardId).get()).docs.map(HazardVote.fromDoc).toList();

  Future<bool> hasUserVoted(String hazardId, String userId) async =>
      (await _votesRef(hazardId).doc(userId).get()).exists;

  Stream<Uint8List?> watchEvidenceBytes(String hazardId, String userId) {
    return _votesRef(hazardId)
        .doc(userId)
        .collection(HazardReportService.evidenceCollectionName)
        .doc(HazardReportService.evidenceDocumentName)
        .snapshots()
        .map((snapshot) {
          final value = snapshot.data()?['imageBytes'];
          return value is Blob ? value.bytes : null;
        });
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
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw FirebaseAuthException(code: 'unauthenticated');
    final fingerprints = await HazardReportService(
      firestore: _db,
      auth: _auth,
    ).loadEvidenceFingerprintsForUser(uid);
    return _validationService.validate(
      bytes: imageBytes,
      evidenceSource: evidenceSource,
      existingSha256Fingerprints: fingerprints.sha256,
      existingPerceptualHashes: fingerprints.perceptual,
    );
  }

  Future<void> submitVote({
    required String hazardId,
    required String voteType,
    required double distanceFromHazardMeters,
    required String proximityBand,
    Uint8List? photoBytes,
    String evidenceSource = EvidenceSource.camera,
    EvidenceValidationResult? evidenceValidation,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Please sign in as a tourist first.');
    if (voteType != HazardVoteType.hazardExists &&
        voteType != HazardVoteType.hazardResolved) {
      throw ArgumentError.value(voteType, 'voteType', 'Unsupported vote.');
    }
    if (SafetyConfig.proximityBand(distanceFromHazardMeters) == 'OUTSIDE') {
      throw Exception(
        'You need to be closer to this hazard to provide a '
        'location-validated status confirmation.',
      );
    }

    final checkedEvidence = photoBytes == null
        ? null
        : evidenceValidation ??
              await validateEvidence(
                imageBytes: photoBytes,
                evidenceSource: evidenceSource,
              );
    if (checkedEvidence != null && !checkedEvidence.isValid) {
      throw Exception('Unable to use this image. Please choose another photo.');
    }

    final compressedPhoto = photoBytes == null
        ? null
        : await compute(compressHazardEvidence, photoBytes);
    final voteRef = _votesRef(hazardId).doc(uid);
    final hazardRef = _db
        .collection(HazardReportService.collectionName)
        .doc(hazardId);
    final evidenceRef = voteRef
        .collection(HazardReportService.evidenceCollectionName)
        .doc(HazardReportService.evidenceDocumentName);

    await _db.runTransaction((transaction) async {
      final hazard = await transaction.get(hazardRef);
      if (!hazard.exists ||
          hazard.data()?['status'] != HazardReportStatus.verified) {
        throw Exception('Voting is only available for verified hazards.');
      }
      if ((await transaction.get(voteRef)).exists) {
        throw Exception(
          'You have already provided a status confirmation for this hazard.',
        );
      }

      // Use the same report snapshot as the status check. Do not silently
      // turn a failed Firebase read into a successful "unmatched" result.
      final referenceHash = hazard.data()?['evidencePerceptualHash'];
      final canMatch =
          referenceHash is String &&
          EvidenceImageValidationService.isValidPerceptualHash(referenceHash);
      final rawValidation = checkedEvidence?.withSceneMatchScore(
        canMatch
            ? EvidenceImageValidationService.computeSceneMatchScore(
                checkedEvidence.perceptualHash,
                referenceHash,
              )
            : null,
      );

      final EvidenceValidationResult? validation;
      if (rawValidation != null) {
        final sanitizedLevel = switch (rawValidation.validationLevel) {
          EvidenceValidationLevel.strong => EvidenceValidationLevel.strong,
          EvidenceValidationLevel.good => EvidenceValidationLevel.good,
          EvidenceValidationLevel.lowQuality =>
            EvidenceValidationLevel.lowQuality,
          _ => EvidenceValidationLevel.acceptable,
        };
        validation = EvidenceValidationResult(
          isValid: true,
          qualityScore: rawValidation.qualityScore,
          sharpnessScore: rawValidation.sharpnessScore,
          brightnessScore: rawValidation.brightnessScore,
          resolutionScore: rawValidation.resolutionScore,
          duplicateDetected: false,
          evidenceSource: evidenceSource,
          semanticValidationAvailable: false,
          validationLevel: sanitizedLevel,
          warnings: rawValidation.warnings,
          overallEvidenceScore: rawValidation.overallEvidenceScore > 0
              ? rawValidation.overallEvidenceScore
              : rawValidation.qualityScore.clamp(0.1, 1.0),
          sha256Fingerprint: rawValidation.sha256Fingerprint,
          perceptualHash: rawValidation.perceptualHash,
          exposureStatus: rawValidation.exposureStatus,
          width: rawValidation.width,
          height: rawValidation.height,
          fileFormat: rawValidation.fileFormat,
          semanticRelevanceScore: rawValidation.semanticRelevanceScore,
          sceneMatchScore: rawValidation.sceneMatchScore,
        );
      } else {
        validation = null;
      }

      final hasPhoto = compressedPhoto != null;
      transaction.set(
        voteRef,
        HazardVote(
          id: uid,
          userId: uid,
          voteType: voteType,
          distanceFromHazardMeters: distanceFromHazardMeters,
          proximityBand: SafetyConfig.proximityBand(distanceFromHazardMeters),
          isGpsValidated: true,
          hasPhotoEvidence: hasPhoto,
          evidenceStorage: hasPhoto ? 'firestore' : 'none',
          evidenceValidation: validation,
          sceneMatchScore: validation?.sceneMatchScore,
        ).toMap(
          userId: uid,
          voteType: voteType,
          distanceFromHazardMeters: distanceFromHazardMeters,
          proximityBand: SafetyConfig.proximityBand(distanceFromHazardMeters),
          hasPhotoEvidence: hasPhoto,
          evidenceStorage: hasPhoto ? 'firestore' : 'none',
          evidenceValidation: validation,
          sceneMatchScore: validation?.sceneMatchScore,
        ),
      );

      if (hasPhoto) {
        transaction.set(evidenceRef, {
          'hazardId': hazardId,
          'userId': uid,
          'imageBytes': Blob(compressedPhoto),
          'contentType': 'image/jpeg',
          'byteLength': compressedPhoto.lengthInBytes,
          'sourceSha256': validation!.sha256Fingerprint,
          'perceptualHash': validation.perceptualHash,
          'validationLevel': validation.validationLevel,
          'evidenceSource': validation.evidenceSource,
          if (validation.sceneMatchScore != null)
            'sceneMatchScore': validation.sceneMatchScore,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
