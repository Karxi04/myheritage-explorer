import '../core/safety_config.dart';
import '../models/hazard_report.dart';

class SafetyAlertPriorityResult {
  const SafetyAlertPriorityResult({
    required this.priorityScore,
    required this.priorityLevel,
    required this.severityScore,
    required this.distanceScore,
    required this.communityScore,
  });
  final double priorityScore, severityScore, distanceScore, communityScore;
  final String priorityLevel;
}

class SafetyAlertPriorityService {
  const SafetyAlertPriorityService();
  SafetyAlertCandidate? selectAlert(
    List<SafetyAlertCandidate> candidates, {
    required Map<String, DateTime> lastAlertedAt,
    required Map<String, double> lastPriority,
    DateTime? now,
  }) {
    final evaluatedAt = now ?? DateTime.now();
    final eligible =
        candidates.where((candidate) {
          if (!candidate.report.isVerified ||
              !candidate.report.hasValidLocation ||
              !candidate.distanceMeters.isFinite ||
              candidate.distanceMeters < 0 ||
              candidate.distanceMeters >
                  SafetyConfig.dangerRadiusForSeverity(
                    candidate.report.severity,
                  )) {
            return false;
          }
          final last = lastAlertedAt[candidate.report.id];
          final prior = lastPriority[candidate.report.id];
          return last == null ||
              evaluatedAt.difference(last) >= SafetyConfig.alertCooldown ||
              (prior != null &&
                  candidate.priority.priorityScore - prior >=
                      SafetyConfig.alertEscalationDelta);
        }).toList()..sort((a, b) {
          final score = b.priority.priorityScore.compareTo(
            a.priority.priorityScore,
          );
          return score == 0
              ? a.distanceMeters.compareTo(b.distanceMeters)
              : score;
        });
    return eligible.isEmpty ? null : eligible.first;
  }

  SafetyAlertPriorityResult calculate({
    required String severity,
    required double distanceMeters,
    double? existsConfirmationScore,
    double detectionRadius = SafetyConfig.detectionRadiusMeters,
  }) {
    final severityScore = switch (severity.toLowerCase()) {
      'high' => 1.0,
      'medium' => .67,
      _ => .33,
    };
    if (!distanceMeters.isFinite ||
        distanceMeters < 0 ||
        !detectionRadius.isFinite ||
        detectionRadius <= 0) {
      throw ArgumentError(
        'A finite distance and positive radius are required.',
      );
    }
    final distanceScore = (1 - distanceMeters / detectionRadius).clamp(
      0.0,
      1.0,
    );
    final communityScore =
        (existsConfirmationScore?.isFinite == true
                ? existsConfirmationScore!
                : SafetyConfig.neutralCommunityScore)
            .clamp(0.0, 1.0);
    final score =
        severityScore * SafetyConfig.alertSeverityWeight +
        distanceScore * SafetyConfig.alertDistanceWeight +
        communityScore * SafetyConfig.alertCommunityWeight;
    final level = score >= .8
        ? 'CRITICAL'
        : score >= .6
        ? 'HIGH'
        : score >= .4
        ? 'MODERATE'
        : 'LOW';
    return SafetyAlertPriorityResult(
      priorityScore: score,
      priorityLevel: level,
      severityScore: severityScore,
      distanceScore: distanceScore,
      communityScore: communityScore,
    );
  }
}

class SafetyAlertCandidate {
  const SafetyAlertCandidate({
    required this.report,
    required this.distanceMeters,
    required this.priority,
  });
  final HazardReport report;
  final double distanceMeters;
  final SafetyAlertPriorityResult priority;
}
