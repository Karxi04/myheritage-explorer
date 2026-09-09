import '../core/helpers.dart';
import '../core/safety_config.dart';

abstract final class ServerConfidenceFormula {
  static const current = 'safety-confidence-v1';
}

/// Trusted confidence summary written to a hazard by Firebase Admin SDK.
///
/// A summary is used only when both structurally valid and fresh. Legacy,
/// malformed, missing or stale values safely fall back to the Dart calculation.
class ServerConfidenceSummary {
  const ServerConfidenceSummary({
    required this.formulaVersion,
    required this.calculatedAt,
    required this.confidencePercent,
    required this.confidenceLevel,
    required this.weightedStillExists,
    required this.weightedResolved,
    required this.stillExistsVotes,
    required this.resolvedVotes,
    required this.totalVotes,
    required this.validVoteCount,
    required this.recentValidVoteCount,
    required this.recentStillExistsVotes,
    required this.recentResolvedVotes,
    required this.gpsValidatedCount,
    required this.photoEvidenceCount,
    required this.strongOrGoodEvidenceCount,
    required this.lowQualityEvidenceCount,
    required this.possibleDuplicateEvidenceCount,
    required this.averageEvidenceScore,
    required this.sceneMatchedCount,
    required this.evidenceStrength,
    required this.recommendation,
    required this.isStructurallyValid,
    this.validUntil,
  });

  final String formulaVersion;
  final DateTime? calculatedAt;
  final DateTime? validUntil;
  final double confidencePercent;
  final String confidenceLevel;
  final double weightedStillExists;
  final double weightedResolved;
  final int stillExistsVotes;
  final int resolvedVotes;
  final int totalVotes;
  final int validVoteCount;
  final int recentValidVoteCount;
  final int recentStillExistsVotes;
  final int recentResolvedVotes;
  final int gpsValidatedCount;
  final int photoEvidenceCount;
  final int strongOrGoodEvidenceCount;
  final int lowQualityEvidenceCount;
  final int possibleDuplicateEvidenceCount;
  final double averageEvidenceScore;
  final int sceneMatchedCount;
  final String evidenceStrength;
  final String recommendation;
  final bool isStructurallyValid;

  bool isFresh({DateTime? now}) {
    if (!isStructurallyValid || calculatedAt == null) return false;
    final current = now ?? DateTime.now();
    final skew = calculatedAt!.difference(current);
    if (skew > SafetyConfig.serverConfidenceFutureTolerance) return false;
    if (validUntil != null) {
      return !current.isAfter(validUntil!);
    }
    final age = current.difference(calculatedAt!);
    return age <= SafetyConfig.serverConfidenceFreshness;
  }

  factory ServerConfidenceSummary.fromMap(Map<String, dynamic> map) {
    double number(String key) {
      final value = map[key];
      return value is num && value.toDouble().isFinite
          ? value.toDouble()
          : double.nan;
    }

    int count(String key) {
      final value = map[key];
      if (value is! num || !value.toDouble().isFinite) return -1;
      final rounded = value.round();
      return value.toDouble() == rounded.toDouble() ? rounded : -1;
    }

    final formulaVersion = map['formulaVersion'] is String
        ? map['formulaVersion'] as String
        : '';
    final calculatedAt = asDate(map['calculatedAt']);
    final validUntil = asDate(map['validUntil']);
    final confidencePercent = number('confidencePercent');
    final confidenceLevel = map['confidenceLevel'] is String
        ? map['confidenceLevel'] as String
        : '';
    final weightedStillExists = number('weightedStillExists');
    final weightedResolved = number('weightedResolved');
    final stillExistsVotes = count('stillExistsVotes');
    final resolvedVotes = count('resolvedVotes');
    final totalVotes = count('totalVotes');
    final validVoteCount = count('validVoteCount');
    final recentValidVoteCount = count('recentValidVoteCount');
    final recentStillExistsVotes = count('recentStillExistsVotes');
    final recentResolvedVotes = count('recentResolvedVotes');
    final gpsValidatedCount = count('gpsValidatedCount');
    final photoEvidenceCount = count('photoEvidenceCount');
    final strongOrGoodEvidenceCount = count('strongOrGoodEvidenceCount');
    final lowQualityEvidenceCount = count('lowQualityEvidenceCount');
    final possibleDuplicateEvidenceCount = count(
      'possibleDuplicateEvidenceCount',
    );
    final averageEvidenceScore = number('averageEvidenceScore');
    final sceneMatchedCount = count('sceneMatchedCount');
    final evidenceStrength = map['evidenceStrength'] is String
        ? map['evidenceStrength'] as String
        : '';
    final recommendation = map['recommendation'] is String
        ? map['recommendation'] as String
        : '';
    const levels = {
      'INSUFFICIENT EVIDENCE',
      'LIMITED EVIDENCE',
      'VERY HIGH',
      'HIGH',
      'MEDIUM',
      'LOW',
    };
    const strengths = {'Insufficient', 'Limited', 'Sufficient'};
    final counts = [
      stillExistsVotes,
      resolvedVotes,
      totalVotes,
      validVoteCount,
      recentValidVoteCount,
      recentStillExistsVotes,
      recentResolvedVotes,
      gpsValidatedCount,
      photoEvidenceCount,
      strongOrGoodEvidenceCount,
      lowQualityEvidenceCount,
      possibleDuplicateEvidenceCount,
      sceneMatchedCount,
    ];
    final valid =
        formulaVersion == ServerConfidenceFormula.current &&
        calculatedAt != null &&
        confidencePercent.isFinite &&
        confidencePercent >= 0 &&
        confidencePercent <= 100 &&
        weightedStillExists.isFinite &&
        weightedStillExists >= 0 &&
        weightedResolved.isFinite &&
        weightedResolved >= 0 &&
        averageEvidenceScore.isFinite &&
        averageEvidenceScore >= 0 &&
        averageEvidenceScore <= 1 &&
        counts.every((value) => value >= 0) &&
        stillExistsVotes + resolvedVotes == totalVotes &&
        validVoteCount <= totalVotes &&
        recentValidVoteCount <= validVoteCount &&
        recentStillExistsVotes + recentResolvedVotes == recentValidVoteCount &&
        gpsValidatedCount <= validVoteCount &&
        photoEvidenceCount <= validVoteCount &&
        levels.contains(confidenceLevel) &&
        strengths.contains(evidenceStrength) &&
        recommendation.trim().isNotEmpty;

    return ServerConfidenceSummary(
      formulaVersion: formulaVersion,
      calculatedAt: calculatedAt,
      confidencePercent: confidencePercent,
      confidenceLevel: confidenceLevel,
      weightedStillExists: weightedStillExists,
      weightedResolved: weightedResolved,
      stillExistsVotes: stillExistsVotes,
      resolvedVotes: resolvedVotes,
      totalVotes: totalVotes,
      validVoteCount: validVoteCount,
      recentValidVoteCount: recentValidVoteCount,
      recentStillExistsVotes: recentStillExistsVotes,
      recentResolvedVotes: recentResolvedVotes,
      gpsValidatedCount: gpsValidatedCount,
      photoEvidenceCount: photoEvidenceCount,
      strongOrGoodEvidenceCount: strongOrGoodEvidenceCount,
      lowQualityEvidenceCount: lowQualityEvidenceCount,
      possibleDuplicateEvidenceCount: possibleDuplicateEvidenceCount,
      averageEvidenceScore: averageEvidenceScore,
      sceneMatchedCount: sceneMatchedCount,
      evidenceStrength: evidenceStrength,
      recommendation: recommendation,
      isStructurallyValid: valid,
      validUntil: validUntil,
    );
  }
}
