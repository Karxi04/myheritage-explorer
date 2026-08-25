import 'package:geolocator/geolocator.dart';
import '../core/safety_config.dart';
import '../models/hazard_report.dart';
import '../models/itinerary_hazard_warning.dart';

class ItinerarySafetyService {
  const ItinerarySafetyService();
  List<ItineraryHazardWarning> checkStops(List<Map<String, dynamic>> stops, List<HazardReport> hazards) {
    final warnings = <ItineraryHazardWarning>[];
    for (var index = 0; index < stops.length; index++) {
      final raw = stops[index]['location'];
      final location = raw is Map ? Map<String, dynamic>.from(raw) : stops[index];
      final latitude = (location['latitude'] ?? location['lat']) as num?;
      final longitude = (location['longitude'] ?? location['lon']) as num?;
      if (latitude == null || longitude == null) continue;
      for (final hazard in hazards.where((h) => h.isVerified)) {
        final distance = Geolocator.distanceBetween(latitude.toDouble(), longitude.toDouble(), hazard.latitude, hazard.longitude);
        if (distance <= SafetyConfig.itineraryHazardWarningRadiusMeters) {
          warnings.add(ItineraryHazardWarning(stopIndex: index, hazard: hazard, distanceMeters: distance));
        }
      }
    }
    return warnings;
  }
}
