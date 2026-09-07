import 'package:latlong2/latlong.dart';

/// A road route returned by the hazard-aware routing provider.
///
/// All collection fields are defensively copied so a route cannot be mutated
/// after construction.
class SafeRoute {
  SafeRoute({
    required Iterable<LatLng> geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required Iterable<RouteStep> steps,
    Iterable<String> avoidedHazardIds = const [],
  }) : geometry = List<LatLng>.unmodifiable(geometry),
       steps = List<RouteStep>.unmodifiable(steps),
       avoidedHazardIds = List<String>.unmodifiable(avoidedHazardIds);

  final List<LatLng> geometry;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;
  final List<String> avoidedHazardIds;
}

/// One navigation instruction and its corresponding geometry range.
class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.roadName,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuverType,
    required this.startGeometryIndex,
    required this.endGeometryIndex,
  });

  final String instruction;
  final String roadName;
  final double distanceMeters;
  final double durationSeconds;

  /// OpenRouteService's integer maneuver type code.
  final int maneuverType;
  final int startGeometryIndex;
  final int endGeometryIndex;
}
