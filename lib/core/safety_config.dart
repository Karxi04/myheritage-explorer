abstract final class SafetyConfig {
  static bool validCoordinates(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  static String proximityBand(double distance) {
    if (!distance.isFinite ||
        distance < 0 ||
        distance > maxHazardConfirmationDistanceMeters) {
      return 'OUTSIDE';
    }
    if (distance <= strongProximityMeters) return 'STRONG';
    if (distance <= normalProximityMeters) return 'NORMAL';
    return 'WEAK';
  }

  static const double maxHazardConfirmationDistanceMeters = 500;
  static const double itineraryHazardWarningRadiusMeters = 500;
  static const double strongProximityMeters = 100;
  static const double normalProximityMeters = 300;

  /// Search radius for detecting possible duplicate hazards of the same category.
  static const double duplicateHazardRadiusMeters = 100;

  /// Lookback window for considering an existing report a duplicate candidate.
  static const Duration duplicateHazardLookback = Duration(days: 14);

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
  static const double strongPhotoEvidenceWeight = 1.15;
  static const double lowQualityPhotoEvidenceWeight = 1.0;

  // Scene-match weights — applied when the vote photo visually matches the
  // original hazard creation photo using perceptual hash comparison.
  static const double strongSceneMatchWeight = 1.3;
  static const double partialSceneMatchWeight = 1.15;
  static const double weakSceneMatchWeight = 1.05;
  // Hamming-distance thresholds for perceptual hash comparison (64-bit hash).
  static const int strongSceneMatchMaxDistance = 4;
  static const int partialSceneMatchMaxDistance = 8;
  static const int weakSceneMatchMaxDistance = 14;

  static const int maxSourceEvidenceBytes = 12 * 1024 * 1024;
  static const int minimumEvidenceDimensionPixels = 160;
  static const int recommendedEvidenceDimensionPixels = 720;
  static const double minimumUsableSharpnessScore = .035;
  static const double goodSharpnessScore = .085;
  static const double extremelyDarkBrightness = .075;
  static const double lowBrightness = .16;
  static const double highBrightness = .90;
  static const double extremelyBrightBrightness = .97;
  static const Duration duplicateEvidenceLookback = Duration(days: 30);

  static const int minimumValidVotes = 5;
  static const int sufficientValidVotes = 10;
  static const double veryHighConfidencePercent = 90;
  static const double highConfidencePercent = 75;
  static const double mediumConfidencePercent = 50;

  static const double alertSeverityWeight = .45;
  static const double alertDistanceWeight = .35;
  static const double alertCommunityWeight = .20;
  static const double neutralCommunityScore = .5;
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
