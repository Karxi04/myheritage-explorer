import 'package:latlong2/latlong.dart';

import 'navigation_stop.dart';

/// Risk level classification for a calculated safe route.
enum RouteRiskLevel {
  /// All active verified hazards (High, Medium, Low) are avoided.
  hazardFree,

  /// High and Medium hazards avoided; one or more Low hazards may be crossed.
  lowRisk,

  /// High hazards avoided; one or more Medium hazards may be crossed.
  moderateRisk,

  /// Unavoidable hazard exposure along the direct route.
  unavoidableExposure,
}

/// A single leg between two consecutive stops in a multi-stop route.
class RouteLeg {
  RouteLeg({
    required this.startStopName,
    required this.endStopName,
    required this.startLocation,
    required this.endLocation,
    required this.distanceMeters,
    required this.durationSeconds,
    required Iterable<RouteStep> steps,
  }) : steps = List<RouteStep>.unmodifiable(steps);

  final String startStopName;
  final String endStopName;
  final LatLng startLocation;
  final LatLng endLocation;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;
}

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
    this.startedInsideHazard = false,
    Iterable<String> escapeHazardIds = const [],
    Iterable<RouteLeg> legs = const [],
    this.riskLevel = RouteRiskLevel.hazardFree,
    Iterable<String> crossedHazardIds = const [],
    Iterable<NavigationStop> stops = const [],
  }) : geometry = List<LatLng>.unmodifiable(geometry),
       steps = List<RouteStep>.unmodifiable(steps),
       avoidedHazardIds = List<String>.unmodifiable(avoidedHazardIds),
       escapeHazardIds = List<String>.unmodifiable(escapeHazardIds),
       legs = List<RouteLeg>.unmodifiable(legs),
       crossedHazardIds = List<String>.unmodifiable(crossedHazardIds),
       stops = List<NavigationStop>.unmodifiable(stops);

  final List<LatLng> geometry;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;
  final List<String> avoidedHazardIds;
  final bool startedInsideHazard;
  final List<String> escapeHazardIds;
  final List<RouteLeg> legs;
  final RouteRiskLevel riskLevel;
  final List<String> crossedHazardIds;
  final List<NavigationStop> stops;
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
