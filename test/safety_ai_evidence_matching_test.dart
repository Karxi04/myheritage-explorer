import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/core/safety_config.dart';
import 'package:myheritage_explorer/models/evidence_validation_result.dart';
import 'package:myheritage_explorer/models/hazard_vote.dart';
import 'package:myheritage_explorer/services/confidence_analysis_service.dart';

void main() {
  group('HazardVote AI field deserialization & access', () {
    test(
      'legacy vote without AI fields has neutral defaults and isNotAvailable',
      () {
        const vote = HazardVote(
          id: 'vote_1',
          userId: 'user_1',
          voteType: HazardVoteType.hazardExists,
          distanceFromHazardMeters: 50,
          proximityBand: 'STRONG',
          isGpsValidated: true,
          hasPhotoEvidence: true,
        );

        final ai = vote.aiAnalysis;
        expect(ai.analysisStatus, isNull);
        expect(ai.isNotAvailable, isTrue);
        expect(ai.isPending, isFalse);
        expect(ai.isComplete, isFalse);
        expect(ai.isFailed, isFalse);
        expect(ai.isSkipped, isFalse);
        expect(ai.evidenceWeightMultiplier, 1.0);
        expect(ai.sceneMatchScore, isNull);
        expect(ai.hazardRelevanceScore, isNull);
        expect(ai.conditionAssessment, isNull);
        expect(ai.agreement, isNull);
        expect(ai.analysisSummary, isNull);
        expect(ai.failureReason, isNull);
        expect(ai.completedAt, isNull);
      },
    );

    test(
      'vote with AI fields deserializes all 10 fields and clamps correctly via fromMap',
      () {
        final now = DateTime(2026, 9, 6, 12, 0, 0);
        final simulatedDocData = {
          'userId': 'user_2',
          'voteType': 'HAZARD_EXISTS',
          'distanceFromHazardMeters': 30,
          'proximityBand': 'STRONG',
          'isGpsValidated': true,
          'hasPhotoEvidence': true,
          'aiAnalysisStatus': AiAnalysisStatus.complete,
          'aiSceneMatchScore': 0.88,
          'aiHazardRelevanceScore': 0.92,
          'aiConditionAssessment': 'HAZARD_STILL_PRESENT',
          'aiConditionConfidence': 0.85,
          'aiAgreement': AiAgreement.supportsVote,
          'aiEvidenceWeightMultiplier': 1.10,
          'aiAnalysisSummary': 'Scene matches and hazard is clearly visible.',
          'aiAnalysisFailureReason': null,
          'aiAnalysisCompletedAt': now.toIso8601String(),
        };

        final vote = HazardVote.fromMap('vote_2', simulatedDocData);
        final ai = vote.aiAnalysis;

        expect(ai.analysisStatus, AiAnalysisStatus.complete);
        expect(ai.isComplete, isTrue);
        expect(ai.isPending, isFalse);
        expect(ai.isNotAvailable, isFalse);
        expect(ai.sceneMatchScore, 0.88);
        expect(ai.hazardRelevanceScore, 0.92);
        expect(ai.conditionAssessment, 'HAZARD_STILL_PRESENT');
        expect(ai.conditionConfidence, 0.85);
        expect(ai.agreement, AiAgreement.supportsVote);
        expect(ai.evidenceWeightMultiplier, 1.10);
        expect(
          ai.analysisSummary,
          'Scene matches and hazard is clearly visible.',
        );
        expect(ai.completedAt, now);
      },
    );

    test('client defensively clamps multiplier outside [0.90, 1.10]', () {
      final highVote = HazardVote.fromMap('u', {
        'userId': 'u',
        'voteType': 'HAZARD_EXISTS',
        'hasPhotoEvidence': true,
        'aiEvidenceWeightMultiplier': 1.50,
      });
      final lowVote = HazardVote.fromMap('u', {
        'userId': 'u',
        'voteType': 'HAZARD_EXISTS',
        'hasPhotoEvidence': true,
        'aiEvidenceWeightMultiplier': 0.50,
      });

      expect(highVote.aiAnalysis.evidenceWeightMultiplier, 1.10);
      expect(lowVote.aiAnalysis.evidenceWeightMultiplier, 0.90);
    });

    test('SafetyConfig AI multiplier bounds match Step 6 requirements', () {
      expect(SafetyConfig.aiMultiplierMin, 0.90);
      expect(SafetyConfig.aiMultiplierMax, 1.10);
    });
  });

  group('ConfidenceAnalysisService.evidenceWeight with AI multiplier', () {
    const service = ConfidenceAnalysisService();

    EvidenceValidationResult validEvidence({
      double overall = 0.85,
      double? sceneMatch,
      String source = EvidenceSource.camera,
    }) {
      return EvidenceValidationResult(
        isValid: true,
        qualityScore: overall,
        sharpnessScore: 0.8,
        brightnessScore: 0.5,
        resolutionScore: 1.0,
        duplicateDetected: false,
        evidenceSource: source,
        semanticValidationAvailable: false,
        validationLevel: EvidenceValidationLevel.good,
        warnings: const [],
        overallEvidenceScore: overall,
        sha256Fingerprint: 'sha',
        perceptualHash: 'hash',
        exposureStatus: 'BALANCED',
        width: 1000,
        height: 1000,
        fileFormat: 'JPEG',
        sceneMatchScore: sceneMatch,
      );
    }

    test(
      'vote without photo always returns 1.0 regardless of AI multiplier',
      () {
        const noPhotoVote = HazardVote(
          id: 'v1',
          userId: 'u1',
          voteType: HazardVoteType.hazardExists,
          distanceFromHazardMeters: 20,
          proximityBand: 'STRONG',
          isGpsValidated: true,
          hasPhotoEvidence: false,
        );

        expect(service.evidenceWeight(noPhotoVote), 1.0);
      },
    );

    test('valid photo without AI data uses neutral 1.0 multiplier', () {
      final baseVote = HazardVote(
        id: 'v2',
        userId: 'u2',
        voteType: HazardVoteType.hazardExists,
        distanceFromHazardMeters: 20,
        proximityBand: 'STRONG',
        isGpsValidated: true,
        hasPhotoEvidence: true,
        evidenceValidation: validEvidence(overall: 0.85),
      );

      // strongPhotoEvidenceWeight = 1.15, no scene boost = 1.0, ai multiplier = 1.0 -> 1.15
      expect(service.evidenceWeight(baseVote), closeTo(1.15, 0.001));
    });

    test(
      'invalid or duplicate evidence gets lowQualityPhotoEvidenceWeight (1.0)',
      () {
        final duplicateVote = HazardVote(
          id: 'v3',
          userId: 'u3',
          voteType: HazardVoteType.hazardExists,
          distanceFromHazardMeters: 20,
          proximityBand: 'STRONG',
          isGpsValidated: true,
          hasPhotoEvidence: true,
          evidenceValidation: const EvidenceValidationResult(
            isValid: false,
            qualityScore: 0.8,
            sharpnessScore: 0.8,
            brightnessScore: 0.5,
            resolutionScore: 1.0,
            duplicateDetected: true,
            evidenceSource: EvidenceSource.camera,
            semanticValidationAvailable: false,
            validationLevel: EvidenceValidationLevel.lowQuality,
            warnings: ['Duplicate photo'],
            overallEvidenceScore: 0.0,
            sha256Fingerprint: 'sha',
            perceptualHash: 'hash',
            exposureStatus: 'BALANCED',
            width: 800,
            height: 800,
            fileFormat: 'JPEG',
          ),
        );

        expect(
          service.evidenceWeight(duplicateVote),
          SafetyConfig.lowQualityPhotoEvidenceWeight,
        );
      },
    );

    test('strong AI support (1.10) scales strong base photo weight', () {
      final vote = HazardVote.fromMap('v_support', {
        'userId': 'u_sup',
        'voteType': 'HAZARD_EXISTS',
        'hasPhotoEvidence': true,
        'evidenceStorage': 'firestore',
        'evidenceValidationResult': validEvidence(overall: 0.85).toMap(),
        'aiAnalysisStatus': AiAnalysisStatus.complete,
        'aiAgreement': AiAgreement.supportsVote,
        'aiEvidenceWeightMultiplier': 1.10,
      });

      // 1.15 * 1.10 = 1.265
      expect(service.evidenceWeight(vote), closeTo(1.265, 0.001));
    });

    test('moderate AI support (1.05) scales base photo weight', () {
      final vote = HazardVote.fromMap('v_mod_sup', {
        'userId': 'u_mod_sup',
        'voteType': 'HAZARD_EXISTS',
        'hasPhotoEvidence': true,
        'evidenceStorage': 'firestore',
        'evidenceValidationResult': validEvidence(overall: 0.85).toMap(),
        'aiAnalysisStatus': AiAnalysisStatus.complete,
        'aiAgreement': AiAgreement.supportsVote,
        'aiEvidenceWeightMultiplier': 1.05,
      });

      // 1.15 * 1.05 = 1.2075
      expect(service.evidenceWeight(vote), closeTo(1.2075, 0.001));
    });

    test('strong AI conflict (0.90) scales strong base photo weight', () {
      final vote = HazardVote.fromMap('v_conflict', {
        'userId': 'u_con',
        'voteType': 'HAZARD_EXISTS',
        'hasPhotoEvidence': true,
        'evidenceStorage': 'firestore',
        'evidenceValidationResult': validEvidence(overall: 0.85).toMap(),
        'aiAnalysisStatus': AiAnalysisStatus.complete,
        'aiAgreement': AiAgreement.conflictsWithVote,
        'aiEvidenceWeightMultiplier': 0.90,
      });

      // 1.15 * 0.90 = 1.035
      expect(service.evidenceWeight(vote), closeTo(1.035, 0.001));
    });

    test('moderate AI conflict (0.95) scales strong base photo weight', () {
      final vote = HazardVote.fromMap('v_mod_con', {
        'userId': 'u_mod_con',
        'voteType': 'HAZARD_EXISTS',
        'hasPhotoEvidence': true,
        'evidenceStorage': 'firestore',
        'evidenceValidationResult': validEvidence(overall: 0.85).toMap(),
        'aiAnalysisStatus': AiAnalysisStatus.complete,
        'aiAgreement': AiAgreement.conflictsWithVote,
        'aiEvidenceWeightMultiplier': 0.95,
      });

      // 1.15 * 0.95 = 1.0925
      expect(service.evidenceWeight(vote), closeTo(1.0925, 0.001));
    });

    test('pHash scene boost and AI multiplier compose multiplicatively', () {
      final vote = HazardVote.fromMap('v_boosted', {
        'userId': 'u_boosted',
        'voteType': 'HAZARD_EXISTS',
        'hasPhotoEvidence': true,
        'evidenceStorage': 'firestore',
        'sceneMatchScore': 0.75, // partial scene match boost = 1.15
        'evidenceValidationResult': validEvidence(overall: 0.85).toMap(),
        'aiAnalysisStatus': AiAnalysisStatus.complete,
        'aiAgreement': AiAgreement.supportsVote,
        'aiEvidenceWeightMultiplier': 1.10, // AI strong support = 1.10
      });

      // 1.15 base * 1.15 pHash * 1.10 AI = 1.45475
      expect(service.evidenceWeight(vote), closeTo(1.45475, 0.001));
    });

    test('medium quality photo (0.70) with AI support is scaled correctly', () {
      final vote = HazardVote.fromMap('v_med', {
        'userId': 'u_med',
        'voteType': 'HAZARD_EXISTS',
        'hasPhotoEvidence': true,
        'evidenceStorage': 'firestore',
        'evidenceValidationResult': validEvidence(overall: 0.70).toMap(),
        'aiAnalysisStatus': AiAnalysisStatus.complete,
        'aiEvidenceWeightMultiplier': 1.05,
      });

      // 1.10 (photoEvidenceWeight) * 1.05 = 1.155
      expect(service.evidenceWeight(vote), closeTo(1.155, 0.001));
    });
  });

  group('HazardVoteAi status flags and values', () {
    test('AI status values match specifications', () {
      expect(AiAnalysisStatus.pending, 'PENDING');
      expect(AiAnalysisStatus.complete, 'COMPLETE');
      expect(AiAnalysisStatus.failed, 'FAILED');
      expect(AiAnalysisStatus.skipped, 'SKIPPED');
      expect(AiAnalysisStatus.notAvailable, 'NOT_AVAILABLE');

      expect(AiAgreement.supportsVote, 'SUPPORTS_VOTE');
      expect(AiAgreement.conflictsWithVote, 'CONFLICTS_WITH_VOTE');
      expect(AiAgreement.inconclusive, 'INCONCLUSIVE');
    });

    test('AI status flags correctly reflect current state', () {
      final legacyVote = HazardVote.fromMap('v_legacy', {});
      expect(legacyVote.aiAnalysis.isNotAvailable, isTrue);
      expect(legacyVote.aiAnalysis.isPending, isFalse);
      expect(legacyVote.aiAnalysis.isComplete, isFalse);

      final notAvailableVote = HazardVote.fromMap('v_na', {
        'aiAnalysisStatus': AiAnalysisStatus.notAvailable,
      });
      expect(notAvailableVote.aiAnalysis.isNotAvailable, isTrue);
      expect(notAvailableVote.aiAnalysis.isPending, isFalse);

      final pendingVote = HazardVote.fromMap('v_p', {
        'aiAnalysisStatus': AiAnalysisStatus.pending,
      });
      expect(pendingVote.aiAnalysis.isPending, isTrue);
      expect(pendingVote.aiAnalysis.isNotAvailable, isFalse);
      expect(pendingVote.aiAnalysis.isComplete, isFalse);

      final failedVote = HazardVote.fromMap('v_f', {
        'aiAnalysisStatus': AiAnalysisStatus.failed,
      });
      expect(failedVote.aiAnalysis.isFailed, isTrue);
      expect(failedVote.aiAnalysis.isComplete, isFalse);

      final skippedVote = HazardVote.fromMap('v_s', {
        'aiAnalysisStatus': AiAnalysisStatus.skipped,
      });
      expect(skippedVote.aiAnalysis.isSkipped, isTrue);
      expect(skippedVote.aiAnalysis.isComplete, isFalse);
    });
  });
}
