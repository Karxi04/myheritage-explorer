abstract final class SafetyConfig {
  static const double maxHazardConfirmationDistanceMeters = 500;
  static const double itineraryHazardWarningRadiusMeters = 500;
  static const double strongProximityMeters = 100;
  static const double normalProximityMeters = 300;

  static const Duration recencyFullWeight = Duration(minutes: 15);
  static const Duration recencyHighWeight = Duration(minutes: 30);
  static const Duration recencyMediumWeight = Duration(minutes: 60);
  static const double recentWeight = 1;
  static const double highRecencyWeight = .8;
  static const double mediumRecencyWeight = .5;
  static const double oldRecencyWeight = .25;
  static const double strongDistanceWeight = 1;
  static const double normalDistanceWeight = .8;
  static const double weakDistanceWeight = .5;
  static const double photoEvidenceWeight = 1.1;

  static const int minimumValidVotes = 5;
  static const int sufficientValidVotes = 10;
  static const double veryHighConfidencePercent = 90;
  static const double highConfidencePercent = 75;
  static const double mediumConfidencePercent = 50;

  static const double alertSeverityWeight = .45;
  static const double alertDistanceWeight = .35;
  static const double alertCommunityWeight = .20;
  static const double alertEscalationDelta = .25;
  static const double lowSeverityRadiusMeters = 150;
  static const double mediumSeverityRadiusMeters = 300;
  static const double highSeverityRadiusMeters = 500;

  /// Largest radius used when explaining nearby-hazard checks to travelers.
  static const double detectionRadiusMeters = highSeverityRadiusMeters;

  static double dangerRadiusForSeverity(String severity) => switch (severity) {
    'High' => highSeverityRadiusMeters,
    'Medium' => mediumSeverityRadiusMeters,
    _ => lowSeverityRadiusMeters,
  };

  /// A hazard can alert again after this interval while the app is active.
  static const Duration alertCooldown = Duration(minutes: 30);

  /// Minimum movement before the proximity monitor evaluates again.
  static const double locationDistanceFilterMeters = 40;

  /// Community confidence is calculated from votes in this rolling window.
  static const Duration recentVoteWindow = Duration(minutes: 15);

  /// High-confidence labels require a meaningful recent sample.
  static const int minimumReliableRecentVotes = 10;
}
