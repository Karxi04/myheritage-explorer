import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/models/hazard_vote.dart';
import 'package:myheritage_explorer/services/confidence_analysis_service.dart';

void main() {
  final fixtureFile =
      jsonDecode(
            File(
              'test/fixtures/safety_confidence_fixtures.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final evaluatedAt = DateTime.parse(fixtureFile['evaluatedAt'] as String);
  final fixtures = fixtureFile['fixtures'] as List<dynamic>;
  const service = ConfidenceAnalysisService();

  for (final rawFixture in fixtures) {
    final fixture = Map<String, dynamic>.from(rawFixture as Map);
    test('shared server confidence fixture: ${fixture['name']}', () {
      final votes = <HazardVote>[];
      for (final rawGroup in fixture['votes'] as List<dynamic>) {
        final group = Map<String, dynamic>.from(rawGroup as Map);
        final count = group['count'] as int;
        for (var index = 0; index < count; index++) {
          final quality = (group['photoQuality'] as num?)?.toDouble();
          final scene = (group['sceneMatchScore'] as num?)?.toDouble();
          final aiStatus = group['aiStatus'];
          final aiMultiplier = group['aiMultiplier'];
          final voteSequence = votes.length;
          votes.add(
            HazardVote.fromMap('${fixture['name']}-$index-$voteSequence', {
              'userId': '${group['voteType']}-$voteSequence',
              'voteType': group['voteType'],
              'createdAt': evaluatedAt
                  .subtract(Duration(minutes: group['minutesAgo'] as int))
                  .toIso8601String(),
              'distanceFromHazardMeters': group['distance'],
              'proximityBand': (group['distance'] as num) <= 100
                  ? 'STRONG'
                  : (group['distance'] as num) <= 300
                  ? 'NORMAL'
                  : 'WEAK',
              'isGpsValidated': true,
              'hasPhotoEvidence': quality != null,
              'evidenceStorage': quality == null ? 'none' : 'firestore',
              if (quality != null)
                'evidenceValidationResult': {
                  'isValid': true,
                  'qualityScore': quality,
                  'sharpnessScore': .8,
                  'brightnessScore': .5,
                  'resolutionScore': 1,
                  'duplicateDetected': false,
                  'evidenceSource': 'CAMERA',
                  'semanticValidationAvailable': false,
                  'validationLevel': 'GOOD',
                  'warnings': <String>[],
                  'overallEvidenceScore': quality,
                  'sha256Fingerprint': 'fixture-sha',
                  'perceptualHash': '0123456789abcdef',
                  'exposureStatus': 'BALANCED',
                  'width': 1000,
                  'height': 1000,
                  'fileFormat': 'JPEG',
                  'sceneMatchScore': ?scene,
                },
              'sceneMatchScore': ?scene,
              'aiAnalysisStatus': ?aiStatus,
              'aiEvidenceWeightMultiplier': ?aiMultiplier,
            }),
          );
        }
      }

      final actual = service.analyze(votes, now: evaluatedAt);
      final expected = Map<String, dynamic>.from(fixture['expected'] as Map);
      expect(
        actual.weightedExists,
        closeTo((expected['weightedStillExists'] as num).toDouble(), 1e-8),
      );
      expect(
        actual.weightedResolved,
        closeTo((expected['weightedResolved'] as num).toDouble(), 1e-8),
      );
      expect(
        actual.confidencePercent,
        closeTo((expected['confidencePercent'] as num).toDouble(), 1e-8),
      );
      expect(actual.level, expected['confidenceLevel']);
      expect(actual.totalVotes, expected['totalVotes']);
      expect(actual.validVoteCount, expected['validVoteCount']);
      expect(actual.totalRecentVotes, expected['recentValidVoteCount']);
      expect(actual.evidenceStrength, expected['evidenceStrength']);
    });
  }
}
