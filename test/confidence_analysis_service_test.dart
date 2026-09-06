import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/models/evidence_validation_result.dart';
import 'package:myheritage_explorer/models/hazard_vote.dart';
import 'package:myheritage_explorer/services/confidence_analysis_service.dart';

void main() {
  const service = ConfidenceAnalysisService();
  final now = DateTime(2026, 8, 24, 12);

  HazardVote vote(
    String id,
    String type, {
    int minutesAgo = 1,
    double distance = 70,
    bool photo = false,
  }) {
    final evidence = photo
        ? const EvidenceValidationResult(
            isValid: true,
            qualityScore: .8,
            sharpnessScore: .8,
            brightnessScore: .5,
            resolutionScore: 1,
            duplicateDetected: false,
            evidenceSource: EvidenceSource.camera,
            semanticValidationAvailable: false,
            validationLevel: EvidenceValidationLevel.good,
            warnings: [],
            overallEvidenceScore: .8,
            sha256Fingerprint: 'sha',
            perceptualHash: 'hash',
            exposureStatus: 'BALANCED',
            width: 900,
            height: 900,
            fileFormat: 'JPEG',
          )
        : null;
    return HazardVote(
      id: id,
      userId: id,
      voteType: type,
      createdAt: now.subtract(Duration(minutes: minutesAgo)),
      distanceFromHazardMeters: distance,
      proximityBand: distance <= 100
          ? 'STRONG'
          : distance <= 300
          ? 'NORMAL'
          : 'WEAK',
      isGpsValidated: true,
      photoUrl: photo ? 'https://example.test/evidence.jpg' : null,
      hasPhotoEvidence: photo,
      evidenceValidation: evidence,
    );
  }

  test(
    '25 resolved and 1 exists recent votes produces very high confidence',
    () {
      final votes = <HazardVote>[
        for (var i = 0; i < 25; i++)
          vote('resolved_$i', HazardVoteType.hazardResolved),
        vote('exists', HazardVoteType.hazardExists),
      ];

      final result = service.analyze(votes, now: now);

      expect(result.totalRecentVotes, 26);
      expect(result.confidencePercent, closeTo(96.1538, .001));
      expect(result.level, ConfidenceLevel.veryHigh);
      expect(result.hasSufficientRecentEvidence, isTrue);
    },
  );

  test('one resolved vote is explicitly insufficient', () {
    final result = service.analyze([
      vote('resolved', HazardVoteType.hazardResolved),
    ], now: now);

    expect(result.confidencePercent, 100);
    expect(result.level, ConfidenceLevel.insufficient);
    expect(result.hasSufficientRecentEvidence, isFalse);
    expect(result.displayLevel, 'INSUFFICIENT EVIDENCE');
  });

  test(
    '16-minute vote is weighted but excluded from the 15-minute recent count',
    () {
      final result = service.analyze([
        vote('recent_exists', HazardVoteType.hazardExists),
        vote('old_resolved', HazardVoteType.hazardResolved, minutesAgo: 16),
      ], now: now);

      expect(result.totalVotes, 2);
      expect(result.totalRecentVotes, 1);
      expect(result.confidencePercent, greaterThan(0));
    },
  );

  test(
    'weak proximity has a lower vote weight and photo has a small boost',
    () {
      final strong = vote('strong', HazardVoteType.hazardResolved);
      final weak = vote('weak', HazardVoteType.hazardResolved, distance: 420);
      final photo = vote('photo', HazardVoteType.hazardResolved, photo: true);
      expect(
        service.voteWeight(weak, now),
        lessThan(service.voteWeight(strong, now)),
      );
      expect(
        service.voteWeight(photo, now),
        closeTo(service.voteWeight(strong, now) * 1.1, .001),
      );
    },
  );

  test('old resolved history cannot outweigh current exists evidence', () {
    final result = service.analyze([
      for (var i = 0; i < 100; i++)
        vote('old_$i', HazardVoteType.hazardResolved, minutesAgo: 120),
      vote('current', HazardVoteType.hazardExists),
    ], now: now);
    expect(result.confidencePercent, 0);
    expect(result.level, ConfidenceLevel.insufficient);
    expect(result.totalRecentVotes, 1);
    expect(result.recentExistsConfirmationScore, 1);
  });

  test('old-only evidence never receives a high current confidence label', () {
    final result = service.analyze([
      for (var i = 0; i < 25; i++)
        vote('old_$i', HazardVoteType.hazardResolved, minutesAgo: 20),
    ], now: now);
    expect(result.confidencePercent, 100);
    expect(result.level, ConfidenceLevel.insufficient);
    expect(result.hasSufficientRecentEvidence, isFalse);
  });

  test('future timestamps and invalid distances do not improve confidence', () {
    final result = service.analyze([
      vote('future', HazardVoteType.hazardResolved, minutesAgo: -10),
      vote('negative', HazardVoteType.hazardResolved, distance: -1),
      vote('nan', HazardVoteType.hazardResolved, distance: double.nan),
      vote(
        'infinite',
        HazardVoteType.hazardResolved,
        distance: double.infinity,
      ),
    ], now: now);
    expect(result.confidencePercent, 0);
    expect(result.totalRecentVotes, 0);
    expect(result.level, ConfidenceLevel.insufficient);
  });

  test('empty evidence has finite zero support', () {
    final result = service.analyze([], now: now);
    expect(result.confidencePercent, 0);
    expect(result.averageEvidenceScore, 0);
    expect(result.level, ConfidenceLevel.insufficient);
  });

  test('invalid or duplicate photo does not add evidence weight', () {
    final base = vote('base', HazardVoteType.hazardResolved);
    final duplicate = HazardVote(
      id: 'duplicate',
      userId: 'duplicate',
      voteType: HazardVoteType.hazardResolved,
      createdAt: now.subtract(const Duration(minutes: 1)),
      distanceFromHazardMeters: 70,
      proximityBand: 'STRONG',
      isGpsValidated: true,
      hasPhotoEvidence: true,
      evidenceValidation: const EvidenceValidationResult(
        isValid: true,
        qualityScore: .9,
        sharpnessScore: .9,
        brightnessScore: .5,
        resolutionScore: 1,
        duplicateDetected: true,
        evidenceSource: EvidenceSource.gallery,
        semanticValidationAvailable: false,
        validationLevel: EvidenceValidationLevel.possibleDuplicate,
        warnings: ['Duplicate'],
        overallEvidenceScore: 0,
        sha256Fingerprint: 'duplicate',
        perceptualHash: 'duplicate',
        exposureStatus: 'BALANCED',
        width: 900,
        height: 900,
        fileFormat: 'JPEG',
      ),
    );

    expect(service.voteWeight(duplicate, now), service.voteWeight(base, now));
  });

  test(
    'Step 15 Fix 4: fallback confidence excludes server-invalid votes and includes valid/legacy votes',
    () {
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
        voteType: HazardVoteType.hazardResolved,
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
      expect(result.validVoteCount, 2);
      expect(result.totalVotes, 3);
    },
  );
}
