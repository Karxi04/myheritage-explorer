import '../core/safety_config.dart';
import '../models/hazard_vote.dart';

abstract final class ConfidenceLevel {
  static const insufficient = 'INSUFFICIENT EVIDENCE';
  static const limited = 'MEDIUM / LIMITED';
  static const veryHigh = 'VERY HIGH';
  static const high = 'HIGH';
  static const medium = 'MEDIUM';
  static const low = 'LOW';
}

class ConfidenceAnalysisResult {
  const ConfidenceAnalysisResult({required this.existsVotes, required this.resolvedVotes, required this.totalVotes, required this.validVoteCount, required this.confidencePercent, required this.existsSupportPercent, required this.weightedResolved, required this.weightedExists, required this.level, required this.evidenceStrength, required this.recommendation, required this.recentExistsVotes, required this.recentResolvedVotes, required this.totalRecentVotes, required this.gpsValidatedCount, required this.photoEvidenceCount});
  final int existsVotes, resolvedVotes, totalVotes, validVoteCount;
  final int recentExistsVotes, recentResolvedVotes, totalRecentVotes;
  final int gpsValidatedCount, photoEvidenceCount;
  final double confidencePercent, existsSupportPercent, weightedResolved, weightedExists;
  final String level, evidenceStrength, recommendation;
  bool get hasSufficientRecentEvidence => validVoteCount >= SafetyConfig.sufficientValidVotes;
  String get displayLevel => level;
  double get recentExistsConfirmationScore {
    final total = weightedResolved + weightedExists;
    return total <= 0 ? 0 : (weightedExists / total).clamp(0, 1);
  }
}

class ConfidenceAnalysisService {
  const ConfidenceAnalysisService();
  double recencyWeight(HazardVote vote, DateTime now) {
    if (vote.createdAt == null) return SafetyConfig.oldRecencyWeight;
    final age = now.difference(vote.createdAt!);
    if (age <= SafetyConfig.recencyFullWeight) return SafetyConfig.recentWeight;
    if (age <= SafetyConfig.recencyHighWeight) return SafetyConfig.highRecencyWeight;
    if (age <= SafetyConfig.recencyMediumWeight) return SafetyConfig.mediumRecencyWeight;
    return SafetyConfig.oldRecencyWeight;
  }
  double distanceWeight(HazardVote vote) {
    final distance = vote.distanceFromHazardMeters;
    if (distance <= SafetyConfig.strongProximityMeters) return SafetyConfig.strongDistanceWeight;
    if (distance <= SafetyConfig.normalProximityMeters) return SafetyConfig.normalDistanceWeight;
    return SafetyConfig.weakDistanceWeight;
  }
  double voteWeight(HazardVote vote, DateTime now) => recencyWeight(vote, now) * distanceWeight(vote) * (vote.hasPhotoEvidence ? SafetyConfig.photoEvidenceWeight : 1);

  ConfidenceAnalysisResult analyze(List<HazardVote> votes, {DateTime? now}) {
    final evaluatedAt = now ?? DateTime.now();
    final recognized = votes.where((v) => v.voteType == HazardVoteType.hazardExists || v.voteType == HazardVoteType.hazardResolved).toList();
    final valid = recognized.where((v) => v.isGpsValidated && v.distanceFromHazardMeters <= SafetyConfig.maxHazardConfirmationDistanceMeters).toList();
    final exists = recognized.where((v) => v.voteType == HazardVoteType.hazardExists).length;
    var weightedExists = 0.0, weightedResolved = 0.0;
    for (final vote in valid) {
      final weight = voteWeight(vote, evaluatedAt);
      if (vote.voteType == HazardVoteType.hazardResolved) { weightedResolved += weight; } else { weightedExists += weight; }
    }
    final totalWeight = weightedResolved + weightedExists;
    final percent = totalWeight == 0 ? 0.0 : weightedResolved / totalWeight * 100;
    final recent = valid.where((v) => v.createdAt != null && evaluatedAt.difference(v.createdAt!) <= SafetyConfig.recencyMediumWeight).toList();
    final level = _level(percent, valid.length);
    return ConfidenceAnalysisResult(
      existsVotes: exists, resolvedVotes: recognized.length - exists, totalVotes: recognized.length, validVoteCount: valid.length,
      confidencePercent: percent, existsSupportPercent: totalWeight == 0 ? 0 : weightedExists / totalWeight * 100,
      weightedResolved: weightedResolved, weightedExists: weightedExists, level: level,
      evidenceStrength: valid.length < SafetyConfig.minimumValidVotes ? 'Insufficient' : valid.length < SafetyConfig.sufficientValidVotes ? 'Limited' : 'Sufficient',
      recommendation: _recommendation(level),
      recentExistsVotes: recent.where((v) => v.voteType == HazardVoteType.hazardExists).length,
      recentResolvedVotes: recent.where((v) => v.voteType == HazardVoteType.hazardResolved).length,
      totalRecentVotes: recent.length, gpsValidatedCount: valid.length,
      photoEvidenceCount: valid.where((v) => v.hasPhotoEvidence).length,
    );
  }
  String _level(double percent, int count) {
    if (count < SafetyConfig.minimumValidVotes) return ConfidenceLevel.insufficient;
    if (count < SafetyConfig.sufficientValidVotes) return ConfidenceLevel.limited;
    if (percent >= SafetyConfig.veryHighConfidencePercent) return ConfidenceLevel.veryHigh;
    if (percent >= SafetyConfig.highConfidencePercent) return ConfidenceLevel.high;
    if (percent >= SafetyConfig.mediumConfidencePercent) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }
  String _recommendation(String level) => switch (level) {
    ConfidenceLevel.insufficient => 'Too few location-validated community confirmations are available. Administrator review is required.',
    ConfidenceLevel.limited => 'Evidence is limited. Review the community evidence before changing the official status.',
    ConfidenceLevel.veryHigh => 'Recent location-validated community evidence strongly indicates that this hazard may have been resolved. Administrator review is recommended before changing the official status.',
    ConfidenceLevel.high => 'Community evidence indicates that this hazard may have been resolved. Administrator review is recommended.',
    ConfidenceLevel.medium => 'Community evidence is mixed. Further administrator review is recommended.',
    _ => 'Community evidence indicates the hazard may still exist. Keep it verified unless other evidence supports resolution.',
  };
}
