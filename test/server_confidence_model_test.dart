import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/models/hazard_vote.dart';
import 'package:myheritage_explorer/models/server_confidence_summary.dart';

Map<String, dynamic> summaryMap({DateTime? calculatedAt}) => {
  'formulaVersion': ServerConfidenceFormula.current,
  'calculatedAt': Timestamp.fromDate(calculatedAt ?? DateTime.now()),
  'confidencePercent': 75.5,
  'confidenceLevel': 'HIGH',
  'weightedStillExists': 2.5,
  'weightedResolved': 7.5,
  'stillExistsVotes': 3,
  'resolvedVotes': 7,
  'totalVotes': 10,
  'validVoteCount': 10,
  'recentValidVoteCount': 10,
  'recentStillExistsVotes': 3,
  'recentResolvedVotes': 7,
  'gpsValidatedCount': 10,
  'photoEvidenceCount': 2,
  'strongOrGoodEvidenceCount': 2,
  'lowQualityEvidenceCount': 0,
  'possibleDuplicateEvidenceCount': 0,
  'averageEvidenceScore': .8,
  'sceneMatchedCount': 1,
  'evidenceStrength': 'Sufficient',
  'recommendation': 'Administrator review is recommended.',
};

void main() {
  test('HazardVote reads server-owned validation metadata', () {
    final validatedAt = DateTime.now();
    final vote = HazardVote.fromMap('traveler', {
      'userId': 'traveler',
      'voteType': 'HAZARD_EXISTS',
      'distanceFromHazardMeters': 70,
      'proximityBand': 'STRONG',
      'isGpsValidated': true,
      'hasPhotoEvidence': false,
      'serverValidationStatus': ServerVoteValidationStatus.valid,
      'serverValidatedAt': Timestamp.fromDate(validatedAt),
      'serverValidationReasons': <String>[],
    });
    expect(vote.serverValidationStatus, ServerVoteValidationStatus.valid);
    expect(vote.serverValidatedAt, validatedAt);
    expect(vote.serverValidationReasons, isEmpty);
    expect(
      vote.toMap(
        userId: 'traveler',
        voteType: HazardVoteType.hazardExists,
        distanceFromHazardMeters: 70,
        proximityBand: 'STRONG',
      ),
      isNot(contains('serverValidationStatus')),
    );
  });

  test('HazardReport parses a structurally valid fresh server summary', () {
    final report = HazardReport.fromMap('h', {
      'userId': 'owner',
      'category': 'Flooding',
      'severity': 'High',
      'description': 'Water across path',
      'latitude': 5.4,
      'longitude': 100.3,
      'status': 'Verified',
      'serverConfidence': summaryMap(),
    });
    expect(report.serverConfidence, isNotNull);
    expect(report.serverConfidence!.isStructurallyValid, isTrue);
    expect(report.serverConfidence!.isFresh(), isTrue);
    expect(report.serverConfidence!.confidencePercent, 75.5);
  });

  test('legacy hazard without serverConfidence remains compatible', () {
    final report = HazardReport.fromMap('legacy', {
      'userId': 'owner',
      'latitude': 5.4,
      'longitude': 100.3,
      'status': 'Verified',
    });
    expect(report.serverConfidence, isNull);
  });

  test('malformed or stale server summaries are not authoritative', () {
    final malformed = ServerConfidenceSummary.fromMap({
      ...summaryMap(),
      'confidencePercent': 101,
    });
    final stale = ServerConfidenceSummary.fromMap(
      summaryMap(
        calculatedAt: DateTime.now().subtract(const Duration(minutes: 16)),
      ),
    );
    expect(malformed.isStructurallyValid, isFalse);
    expect(malformed.isFresh(), isFalse);
    expect(stale.isStructurallyValid, isTrue);
    expect(stale.isFresh(), isFalse);
  });

  test('Step 15 Fix 5: validUntil governs server confidence freshness', () {
    final baseCalculated = DateTime(2026, 9, 6, 12, 0);
    final validUntil = DateTime(2026, 9, 6, 12, 15);

    final summary = ServerConfidenceSummary.fromMap({
      ...summaryMap(calculatedAt: baseCalculated),
      'validUntil': Timestamp.fromDate(validUntil),
    });

    expect(summary.validUntil, validUntil);
    expect(summary.isStructurallyValid, isTrue);

    // Fresh at exact calculated time
    expect(summary.isFresh(now: baseCalculated), isTrue);

    // Fresh at 14m59s
    expect(
      summary.isFresh(now: validUntil.subtract(const Duration(seconds: 1))),
      isTrue,
    );

    // Fresh right at boundary (12:15:00)
    expect(summary.isFresh(now: validUntil), isTrue);

    // Stale 1 second past validUntil boundary (12:15:01)
    expect(
      summary.isFresh(now: validUntil.add(const Duration(seconds: 1))),
      isFalse,
    );
  });
}
