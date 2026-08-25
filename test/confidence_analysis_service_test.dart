import 'package:flutter_test/flutter_test.dart';
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

  test('historical votes do not affect recent confidence', () {
    final result = service.analyze([
      vote('recent_exists', HazardVoteType.hazardExists),
      vote('old_resolved', HazardVoteType.hazardResolved, minutesAgo: 16),
    ], now: now);

    expect(result.totalVotes, 2);
    expect(result.totalRecentVotes, 2);
    expect(result.confidencePercent, greaterThan(0));
  });

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
}
