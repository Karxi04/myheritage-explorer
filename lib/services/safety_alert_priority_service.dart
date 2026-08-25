import '../core/safety_config.dart';

class SafetyAlertPriorityResult {
  const SafetyAlertPriorityResult({required this.priorityScore, required this.priorityLevel, required this.severityScore, required this.distanceScore, required this.communityScore});
  final double priorityScore, severityScore, distanceScore, communityScore;
  final String priorityLevel;
}

class SafetyAlertPriorityService {
  const SafetyAlertPriorityService();
  SafetyAlertPriorityResult calculate({required String severity, required double distanceMeters, required double existsConfirmationScore, double detectionRadius = SafetyConfig.detectionRadiusMeters}) {
    final severityScore = switch (severity.toLowerCase()) { 'high' => 1.0, 'medium' => .67, _ => .33 };
    final distanceScore = (1 - distanceMeters / detectionRadius).clamp(0.0, 1.0);
    final communityScore = existsConfirmationScore.clamp(0.0, 1.0);
    final score = severityScore * SafetyConfig.alertSeverityWeight + distanceScore * SafetyConfig.alertDistanceWeight + communityScore * SafetyConfig.alertCommunityWeight;
    final level = score >= .8 ? 'CRITICAL' : score >= .6 ? 'HIGH' : score >= .4 ? 'MODERATE' : 'LOW';
    return SafetyAlertPriorityResult(priorityScore: score, priorityLevel: level, severityScore: severityScore, distanceScore: distanceScore, communityScore: communityScore);
  }
}
