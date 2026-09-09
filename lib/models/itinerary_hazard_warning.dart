import 'hazard_report.dart';

class ItineraryHazardWarning {
  const ItineraryHazardWarning({
    required this.stopIndex,
    required this.hazard,
    required this.distanceMeters,
  });

  final int stopIndex;
  final HazardReport hazard;
  final double distanceMeters;

  int get severityRank => switch (hazard.severity) {
    'High' => 3,
    'Medium' => 2,
    _ => 1,
  };

  String get distanceLabel => distanceMeters < 1000
      ? '${distanceMeters.round()}m away'
      : '${(distanceMeters / 1000).toStringAsFixed(1)}km away';
}
