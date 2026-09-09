import '../core/safety_config.dart';
import '../models/evidence_validation_result.dart';
import '../models/hazard_vote.dart';
import '../models/server_confidence_summary.dart';

abstract final class ConfidenceLevel {
  static const insufficient = 'INSUFFICIENT EVIDENCE';
  static const limited = 'LIMITED EVIDENCE';
  static const veryHigh = 'VERY HIGH';
  static const high = 'HIGH';
  static const medium = 'MEDIUM';
  static const low = 'LOW';
}

class ConfidenceAnalysisResult {
  const ConfidenceAnalysisResult({
    required this.existsVotes,
    required this.resolvedVotes,
    required this.totalVotes,
    required this.validVoteCount,
    required this.confidencePercent,
    required this.existsSupportPercent,
    required this.weightedResolved,
    required this.weightedExists,
    required this.level,
    required this.evidenceStrength,
    required this.recommendation,
    required this.recentExistsVotes,
    required this.recentResolvedVotes,
    required this.totalRecentVotes,
    required this.gpsValidatedCount,
    required this.photoEvidenceCount,
    required this.strongOrGoodEvidenceCount,
    required this.lowQualityEvidenceCount,
    required this.possibleDuplicateEvidenceCount,
    required this.averageEvidenceScore,
    required this.sceneMatchedCount,
  });
  final int existsVotes, resolvedVotes, totalVotes, validVoteCount;
  final int recentExistsVotes, recentResolvedVotes, totalRecentVotes;
  final int gpsValidatedCount, photoEvidenceCount;
  final int strongOrGoodEvidenceCount;
  final int lowQualityEvidenceCount;
  final int possibleDuplicateEvidenceCount;

  /// Number of votes whose photo was scene-matched against the original hazard.
  final int sceneMatchedCount;

  final double averageEvidenceScore;
  final double confidencePercent,
      existsSupportPercent,
      weightedResolved,
      weightedExists;
  final String level, evidenceStrength, recommendation;

  factory ConfidenceAnalysisResult.fromServerSummary(
    ServerConfidenceSummary summary,
  ) {
    final totalWeight = summary.weightedResolved + summary.weightedStillExists;
    return ConfidenceAnalysisResult(
      existsVotes: summary.stillExistsVotes,
      resolvedVotes: summary.resolvedVotes,
      totalVotes: summary.totalVotes,
      validVoteCount: summary.validVoteCount,
      confidencePercent: summary.confidencePercent,
      existsSupportPercent: totalWeight == 0
          ? 0
          : summary.weightedStillExists / totalWeight * 100,
      weightedResolved: summary.weightedResolved,
      weightedExists: summary.weightedStillExists,
      level: summary.confidenceLevel,
      evidenceStrength: summary.evidenceStrength,
      recommendation: summary.recommendation,
      recentExistsVotes: summary.recentStillExistsVotes,
      recentResolvedVotes: summary.recentResolvedVotes,
      totalRecentVotes: summary.recentValidVoteCount,
      gpsValidatedCount: summary.gpsValidatedCount,
      photoEvidenceCount: summary.photoEvidenceCount,
      strongOrGoodEvidenceCount: summary.strongOrGoodEvidenceCount,
      lowQualityEvidenceCount: summary.lowQualityEvidenceCount,
      possibleDuplicateEvidenceCount: summary.possibleDuplicateEvidenceCount,
      averageEvidenceScore: summary.averageEvidenceScore,
      sceneMatchedCount: summary.sceneMatchedCount,
    );
  }
  bool get hasSufficientRecentEvidence =>
      totalRecentVotes >= SafetyConfig.sufficientValidVotes;
  String get displayLevel => level;
  double get recentExistsConfirmationScore {
    return totalRecentVotes == 0 ? 0 : recentExistsVotes / totalRecentVotes;
  }
}

class ConfidenceAnalysisService {
  const ConfidenceAnalysisService();
  double recencyWeight(HazardVote vote, DateTime now) {
    if (vote.createdAt == null) return 0;
    final age = now.difference(vote.createdAt!);
    if (age.isNegative || age > SafetyConfig.recencyMediumWeight) return 0;
    if (age <= SafetyConfig.recencyFullWeight) return SafetyConfig.recentWeight;
    if (age <= SafetyConfig.recencyHighWeight) {
      return SafetyConfig.highRecencyWeight;
    }
    if (age <= SafetyConfig.recencyMediumWeight) {
      return SafetyConfig.mediumRecencyWeight;
    }
    return SafetyConfig.oldRecencyWeight;
  }

  double distanceWeight(HazardVote vote) {
    final distance = vote.distanceFromHazardMeters;
    if (distance <= SafetyConfig.strongProximityMeters) {
      return SafetyConfig.strongDistanceWeight;
    }
    if (distance <= SafetyConfig.normalProximityMeters) {
      return SafetyConfig.normalDistanceWeight;
    }
    return SafetyConfig.weakDistanceWeight;
  }

  double evidenceWeight(HazardVote vote) {
    if (!vote.hasPhotoEvidence) return 1;
    final evidence = vote.evidenceValidation;
    if (evidence == null ||
        !evidence.isValid ||
        evidence.duplicateDetected ||
        !evidence.earnsEvidenceBonus) {
      return SafetyConfig.lowQualityPhotoEvidenceWeight;
    }

    // Scene-match boost: applies when the vote photo visually matches the
    // original hazard creation photo using perceptual hash comparison.
    final sceneScore = vote.sceneMatchScore ?? evidence.sceneMatchScore ?? 0.0;
    double sceneBoost = 1.0;
    if (sceneScore >= 1.0) {
      sceneBoost = SafetyConfig.strongSceneMatchWeight;
    } else if (sceneScore >= 0.7) {
      sceneBoost = SafetyConfig.partialSceneMatchWeight;
    } else if (sceneScore >= 0.4) {
      sceneBoost = SafetyConfig.weakSceneMatchWeight;
    }

    double baseWeight;
    if (evidence.overallEvidenceScore >= .85) {
      baseWeight = SafetyConfig.strongPhotoEvidenceWeight * sceneBoost;
    } else if (evidence.overallEvidenceScore >= .65) {
      baseWeight = SafetyConfig.photoEvidenceWeight * sceneBoost;
    } else {
      baseWeight = 1.05 * sceneBoost;
    }

    // Step 6 extension — multiply by AI evidence weight multiplier.
    // The multiplier is stored on the vote document by the Cloud Function.
    // It defaults to 1.0 (neutral) for legacy votes or while AI is pending.
    // The multiplier is clamped to [0.90–1.10] to bound its influence.
    final ai = vote.aiAnalysis;
    final rawAiMultiplier = ai.isComplete ? ai.evidenceWeightMultiplier : 1.0;
    final aiMultiplier = rawAiMultiplier.clamp(
      SafetyConfig.aiMultiplierMin,
      SafetyConfig.aiMultiplierMax,
    );
    return baseWeight * aiMultiplier;
  }

  double voteWeight(HazardVote vote, DateTime now) =>
      recencyWeight(vote, now) * distanceWeight(vote) * evidenceWeight(vote);

  ConfidenceAnalysisResult analyze(List<HazardVote> votes, {DateTime? now}) {
    final evaluatedAt = now ?? DateTime.now();
    final recognized = votes
        .where(
          (v) =>
              v.voteType == HazardVoteType.hazardExists ||
              v.voteType == HazardVoteType.hazardResolved,
        )
        .toList();
    final valid = recognized
        .where(
          (v) =>
              v.isGpsValidated &&
              v.distanceFromHazardMeters.isFinite &&
              v.distanceFromHazardMeters >= 0 &&
              v.distanceFromHazardMeters <=
                  SafetyConfig.maxHazardConfirmationDistanceMeters &&
              v.serverValidationStatus != ServerVoteValidationStatus.invalid &&
              v.serverValidationStatus != 'INVALID',
        )
        .toList();
    final exists = recognized
        .where((v) => v.voteType == HazardVoteType.hazardExists)
        .length;
    var weightedExists = 0.0, weightedResolved = 0.0;
    for (final vote in valid) {
      final weight = voteWeight(vote, evaluatedAt);
      if (vote.voteType == HazardVoteType.hazardResolved) {
        weightedResolved += weight;
      } else {
        weightedExists += weight;
      }
    }
    final totalWeight = weightedResolved + weightedExists;
    final percent = totalWeight == 0
        ? 0.0
        : weightedResolved / totalWeight * 100;
    final recent = valid
        .where(
          (v) =>
              v.createdAt != null &&
              !evaluatedAt.difference(v.createdAt!).isNegative &&
              evaluatedAt.difference(v.createdAt!) <=
                  SafetyConfig.recentVoteWindow,
        )
        .toList();
    final level = _level(percent, recent.length);
    final photoVotes = valid.where((v) => v.hasReliablePhotoEvidence).toList();
    final analyzedPhotos = photoVotes
        .map((vote) => vote.evidenceValidation)
        .whereType<EvidenceValidationResult>()
        .toList();
    final evidenceScore = analyzedPhotos.isEmpty
        ? 0.0
        : analyzedPhotos.fold<double>(
                0,
                (total, evidence) => total + evidence.overallEvidenceScore,
              ) /
              analyzedPhotos.length;

    final sceneMatchedCount = valid
        .where((v) => v.hasSceneMatchedEvidence)
        .length;

    return ConfidenceAnalysisResult(
      existsVotes: exists,
      resolvedVotes: recognized.length - exists,
      totalVotes: recognized.length,
      validVoteCount: valid.length,
      confidencePercent: percent,
      existsSupportPercent: totalWeight == 0
          ? 0
          : weightedExists / totalWeight * 100,
      weightedResolved: weightedResolved,
      weightedExists: weightedExists,
      level: level,
      evidenceStrength: recent.length < SafetyConfig.minimumValidVotes
          ? 'Insufficient'
          : recent.length < SafetyConfig.sufficientValidVotes
          ? 'Limited'
          : 'Sufficient',
      recommendation: _recommendation(level),
      recentExistsVotes: recent
          .where((v) => v.voteType == HazardVoteType.hazardExists)
          .length,
      recentResolvedVotes: recent
          .where((v) => v.voteType == HazardVoteType.hazardResolved)
          .length,
      totalRecentVotes: recent.length,
      gpsValidatedCount: valid.length,
      photoEvidenceCount: valid.where((v) => v.hasPhotoEvidence).length,
      strongOrGoodEvidenceCount: valid.where((vote) {
        final level = vote.evidenceValidation?.validationLevel;
        return vote.hasReliablePhotoEvidence &&
            (level == 'STRONG' || level == 'GOOD');
      }).length,
      lowQualityEvidenceCount: valid
          .where(
            (vote) => vote.evidenceValidation?.validationLevel == 'LOW_QUALITY',
          )
          .length,
      possibleDuplicateEvidenceCount: valid
          .where((vote) => vote.evidenceValidation?.duplicateDetected == true)
          .length,
      averageEvidenceScore: evidenceScore,
      sceneMatchedCount: sceneMatchedCount,
    );
  }

  String _level(double percent, int count) {
    if (count < SafetyConfig.minimumValidVotes) {
      return ConfidenceLevel.insufficient;
    }
    if (count < SafetyConfig.sufficientValidVotes) {
      return ConfidenceLevel.limited;
    }
    if (percent >= SafetyConfig.veryHighConfidencePercent) {
      return ConfidenceLevel.veryHigh;
    }
    if (percent >= SafetyConfig.highConfidencePercent) {
      return ConfidenceLevel.high;
    }
    if (percent >= SafetyConfig.mediumConfidencePercent) {
      return ConfidenceLevel.medium;
    }
    return ConfidenceLevel.low;
  }

  String _recommendation(String level) => switch (level) {
    ConfidenceLevel.insufficient =>
      'Too few location-validated community confirmations are available. Administrator review is required.',
    ConfidenceLevel.limited =>
      'Evidence is limited. Review the community evidence before changing the official status.',
    ConfidenceLevel.veryHigh =>
      'Recent location-validated community evidence strongly indicates that this hazard may have been resolved. Administrator review is recommended before changing the official status.',
    ConfidenceLevel.high =>
      'Community evidence indicates that this hazard may have been resolved. Administrator review is recommended.',
    ConfidenceLevel.medium =>
      'Community evidence is mixed. Further administrator review is recommended.',
    _ =>
      'Community evidence indicates the hazard may still exist. Keep it verified unless other evidence supports resolution.',
  };
}
