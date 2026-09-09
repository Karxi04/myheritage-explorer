import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/models/hazard_vote.dart';
import 'package:myheritage_explorer/models/server_confidence_summary.dart';
import 'package:myheritage_explorer/services/confidence_analysis_service.dart';
import 'package:myheritage_explorer/services/mobile_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 15 Fix 9: MobileNotificationService payload clearing', () {
    test('clearPendingPayload resets pendingHazardPayload to null', () {
      final service = MobileNotificationService.instance;
      service.pendingHazardPayload = 'hazard:test-hazard-123';
      expect(service.pendingHazardPayload, 'hazard:test-hazard-123');

      service.clearPendingPayload();
      expect(service.pendingHazardPayload, isNull);
    });
  });

  group('Step 15 Fix 4: Confidence fallback excludes INVALID votes', () {
    test(
      'INVALID votes do not contribute to fallback confidence calculation',
      () {
        const service = ConfidenceAnalysisService();
        final now = DateTime(2026, 9, 6, 12, 0);

        final validVote = HazardVote(
          id: 'v1',
          userId: 'u1',
          voteType: HazardVoteType.hazardResolved,
          createdAt: now.subtract(const Duration(minutes: 5)),
          distanceFromHazardMeters: 50,
          proximityBand: 'STRONG',
          isGpsValidated: true,
          hasPhotoEvidence: false,
          serverValidationStatus: ServerVoteValidationStatus.valid,
        );

        final invalidVote = HazardVote(
          id: 'v2',
          userId: 'u2',
          voteType: HazardVoteType.hazardResolved,
          createdAt: now.subtract(const Duration(minutes: 5)),
          distanceFromHazardMeters: 50,
          proximityBand: 'STRONG',
          isGpsValidated: true,
          hasPhotoEvidence: false,
          serverValidationStatus: ServerVoteValidationStatus.invalid,
        );

        final legacyVote = HazardVote(
          id: 'v3',
          userId: 'u3',
          voteType: HazardVoteType.hazardExists,
          createdAt: now.subtract(const Duration(minutes: 5)),
          distanceFromHazardMeters: 50,
          proximityBand: 'STRONG',
          isGpsValidated: true,
          hasPhotoEvidence: false,
          serverValidationStatus: null,
        );

        final result = service.analyze([
          validVote,
          invalidVote,
          legacyVote,
        ], now: now);

        // Total votes recognized = 3, but validVoteCount must exclude the INVALID vote
        expect(result.totalVotes, 3);
        expect(result.validVoteCount, 2);
        expect(result.resolvedVotes, 2); // all recognized resolved votes
        expect(result.existsVotes, 1);
      },
    );
  });

  group('Step 15 Fix 5: validUntil freshness evaluation', () {
    test(
      'ServerConfidenceSummary evaluates freshness using validUntil boundary',
      () {
        final calculatedAt = DateTime(2026, 9, 6, 12, 0);
        final validUntil = DateTime(2026, 9, 6, 12, 15);

        final summary = ServerConfidenceSummary(
          formulaVersion: ServerConfidenceFormula.current,
          calculatedAt: calculatedAt,
          validUntil: validUntil,
          confidencePercent: 80.0,
          confidenceLevel: 'HIGH',
          weightedStillExists: 1.0,
          weightedResolved: 4.0,
          stillExistsVotes: 1,
          resolvedVotes: 4,
          totalVotes: 5,
          validVoteCount: 5,
          recentValidVoteCount: 5,
          recentStillExistsVotes: 1,
          recentResolvedVotes: 4,
          gpsValidatedCount: 5,
          photoEvidenceCount: 0,
          strongOrGoodEvidenceCount: 0,
          lowQualityEvidenceCount: 0,
          possibleDuplicateEvidenceCount: 0,
          averageEvidenceScore: 0.0,
          sceneMatchedCount: 0,
          evidenceStrength: 'Limited',
          recommendation: 'Review community evidence.',
          isStructurallyValid: true,
        );

        // Fresh before boundary
        expect(summary.isFresh(now: DateTime(2026, 9, 6, 12, 14, 59)), isTrue);
        // Fresh at exact boundary
        expect(summary.isFresh(now: validUntil), isTrue);
        // Stale after boundary
        expect(summary.isFresh(now: DateTime(2026, 9, 6, 12, 15, 1)), isFalse);
      },
    );

    test(
      'ServerConfidenceSummary falls back to 15m window when validUntil is null',
      () {
        final calculatedAt = DateTime(2026, 9, 6, 12, 0);

        final summary = ServerConfidenceSummary(
          formulaVersion: ServerConfidenceFormula.current,
          calculatedAt: calculatedAt,
          validUntil: null,
          confidencePercent: 80.0,
          confidenceLevel: 'HIGH',
          weightedStillExists: 1.0,
          weightedResolved: 4.0,
          stillExistsVotes: 1,
          resolvedVotes: 4,
          totalVotes: 5,
          validVoteCount: 5,
          recentValidVoteCount: 5,
          recentStillExistsVotes: 1,
          recentResolvedVotes: 4,
          gpsValidatedCount: 5,
          photoEvidenceCount: 0,
          strongOrGoodEvidenceCount: 0,
          lowQualityEvidenceCount: 0,
          possibleDuplicateEvidenceCount: 0,
          averageEvidenceScore: 0.0,
          sceneMatchedCount: 0,
          evidenceStrength: 'Limited',
          recommendation: 'Review community evidence.',
          isStructurallyValid: true,
        );

        // Fresh within 15 minutes
        expect(summary.isFresh(now: DateTime(2026, 9, 6, 12, 14)), isTrue);
        // Stale after 15 minutes
        expect(summary.isFresh(now: DateTime(2026, 9, 6, 12, 16)), isFalse);
      },
    );
  });
}
