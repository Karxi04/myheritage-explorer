import 'package:geolocator/geolocator.dart';
import '../core/safety_config.dart';
import '../models/hazard_report.dart';
import '../models/itinerary_hazard_warning.dart';

class ItinerarySafetyService {
  const ItinerarySafetyService();
  List<ItineraryHazardWarning> checkStops(
    List<Map<String, dynamic>> stops,
    List<HazardReport> hazards,
  ) {
    final warnings = <ItineraryHazardWarning>[];
    for (var index = 0; index < stops.length; index++) {
      final raw = stops[index]['location'];
      final location = raw is Map
          ? Map<String, dynamic>.from(raw)
          : stops[index];
      final latitude = location['latitude'] ?? location['lat'];
      final longitude = location['longitude'] ?? location['lon'];
      if (latitude is! num ||
          longitude is! num ||
          !SafetyConfig.validCoordinates(
            latitude.toDouble(),
            longitude.toDouble(),
          )) {
        continue;
      }
      for (final hazard in hazards.where(
        (h) => h.isVerified && h.hasValidLocation,
      )) {
        final distance = Geolocator.distanceBetween(
          latitude.toDouble(),
          longitude.toDouble(),
          hazard.latitude,
          hazard.longitude,
        );
        if (distance <= SafetyConfig.itineraryHazardWarningRadiusMeters) {
          warnings.add(
            ItineraryHazardWarning(
              stopIndex: index,
              hazard: hazard,
              distanceMeters: distance,
            ),
          );
        }
      }
    }
    warnings.sort((a, b) {
      final stopOrder = a.stopIndex.compareTo(b.stopIndex);
      if (stopOrder != 0) return stopOrder;
      final severityOrder = b.severityRank.compareTo(a.severityRank);
      return severityOrder != 0
          ? severityOrder
          : a.distanceMeters.compareTo(b.distanceMeters);
    });
    return warnings;
  }
}
