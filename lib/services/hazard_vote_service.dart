import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/safety_config.dart';
import '../core/services.dart';
import '../models/hazard_report.dart';
import '../models/hazard_vote.dart';
import 'hazard_report_service.dart';

class HazardVoteService {
  HazardVoteService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? AppServices.db,
      _auth = auth ?? AppServices.auth;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> _votesRef(String hazardId) => _db
      .collection(HazardReportService.collectionName)
      .doc(hazardId)
      .collection('votes');

  Stream<List<HazardVote>> watchVotes(String hazardId) =>
      _votesRef(hazardId).snapshots().map(
        (snapshot) => snapshot.docs.map(HazardVote.fromDoc).toList(),
      );

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

  Future<void> submitVote({
    required String hazardId,
    required String voteType,
    required double distanceFromHazardMeters,
    required String proximityBand,
    Uint8List? photoBytes,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Please sign in as a tourist first.');
    if (voteType != HazardVoteType.hazardExists &&
        voteType != HazardVoteType.hazardResolved) {
      throw ArgumentError.value(voteType, 'voteType', 'Unsupported vote.');
    }
    if (distanceFromHazardMeters >
        SafetyConfig.maxHazardConfirmationDistanceMeters) {
      throw Exception(
        'You need to be closer to this hazard to provide a '
        'location-validated status confirmation.',
      );
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

      final hasPhoto = compressedPhoto != null;
      transaction.set(
        voteRef,
        HazardVote(
          id: uid,
          userId: uid,
          voteType: voteType,
          distanceFromHazardMeters: distanceFromHazardMeters,
          proximityBand: proximityBand,
          isGpsValidated: true,
          hasPhotoEvidence: hasPhoto,
          evidenceStorage: hasPhoto ? 'firestore' : 'none',
        ).toMap(
          userId: uid,
          voteType: voteType,
          distanceFromHazardMeters: distanceFromHazardMeters,
          proximityBand: proximityBand,
          hasPhotoEvidence: hasPhoto,
          evidenceStorage: hasPhoto ? 'firestore' : 'none',
        ),
      );

      if (hasPhoto) {
        transaction.set(evidenceRef, {
          'hazardId': hazardId,
          'userId': uid,
          'imageBytes': Blob(compressedPhoto),
          'contentType': 'image/jpeg',
          'byteLength': compressedPhoto.lengthInBytes,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
