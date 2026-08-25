import 'hazard_report.dart';

class ItineraryHazardWarning {
  const ItineraryHazardWarning({required this.stopIndex, required this.hazard, required this.distanceMeters});
  final int stopIndex;
  final HazardReport hazard;
  final double distanceMeters;
}
