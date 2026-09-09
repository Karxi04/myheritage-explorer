import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/safety_config.dart';
import '../../../models/hazard_report.dart';
import '../../../models/safe_route.dart';
import '../../../services/hazard_map_service.dart';
import '../../../services/safe_routing_service.dart';
import 'navigation_session_controller.dart';
import 'route_progress_engine.dart';

@immutable
class SimulationResult {
  const SimulationResult({
    required this.success,
    required this.message,
    this.simulatedPosition,
  });

  final bool success;
  final String message;
  final LatLng? simulatedPosition;
}

/// Compile-time flag to activate the Safe Navigation GPS simulator in debug builds.
const bool enableNavigationDebug = bool.fromEnvironment(
  'ENABLE_NAV_DEBUG',
  defaultValue: false,
);

/// Development-only GPS simulator for manual verification of Safe Navigation
/// without physical movement.
///
/// Gated behind [kDebugMode] AND [enableNavigationDebug] by default (can be overridden in testing via [enabledOverride]).
class DebugNavigationSimulator {
  const DebugNavigationSimulator({
    this.enabledOverride,
    this.routeProgressEngine = const RouteProgressEngine(),
  });

  final bool? enabledOverride;
  final RouteProgressEngine routeProgressEngine;

  bool get isEnabled =>
      enabledOverride ?? (kDebugMode && enableNavigationDebug);

  /// Builds a [Position] instance from a [LatLng] with sensible defaults.
  static Position createPosition({
    required LatLng point,
    DateTime? timestamp,
    double heading = 0.0,
    double speed = 0.0,
    double accuracy = 4.0,
  }) => Position(
    latitude: point.latitude,
    longitude: point.longitude,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: accuracy,
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: heading,
    headingAccuracy: 0.0,
    speed: speed,
    speedAccuracy: 0.0,
  );

  /// Finds the nearest verified active hazard from [hazards] relative to [referencePoint].
  static HazardReport? findNearestVerifiedHazard({
    required Iterable<HazardReport> hazards,
    required LatLng referencePoint,
  }) {
    final active = HazardMapService.activeReports(hazards.toList());
    if (active.isEmpty) return null;
    const distanceCalc = Distance();
    HazardReport? nearest;
    double? minDistance;
    for (final h in active) {
      final d = distanceCalc.as(
        LengthUnit.Meter,
        referencePoint,
        LatLng(h.latitude, h.longitude),
      );
      if (minDistance == null || d < minDistance) {
        minDistance = d;
        nearest = h;
      }
    }
    return nearest;
  }

  /// Simulates an on-route advance of [stepMeters] (default 25m) along the active route.
  SimulationResult simulateOnRoute({
    required NavigationSessionController controller,
    double stepMeters = 25.0,
  }) {
    if (!isEnabled) {
      return const SimulationResult(
        success: false,
        message: 'GPS simulator is disabled in release builds.',
      );
    }
    final state = controller.state;
    final route = state.route;
    if (!state.isNavigating || route == null || route.geometry.isEmpty) {
      return const SimulationResult(
        success: false,
        message: 'Cannot simulate on-route: No active route guidance.',
      );
    }

    final currentPos = state.currentPosition ?? route.geometry.first;
    final projection = routeProgressEngine.project(route.geometry, currentPos);
    final targetDistance =
        (projection?.distanceAlongGeometryMeters ?? 0.0) + stepMeters;
    final cumulative = RouteProgressEngine.cumulativeGeometryDistances(
      route.geometry,
    );
    final totalDistance = cumulative.isEmpty ? 0.0 : cumulative.last;

    LatLng nextPoint;
    double heading = 0.0;
    if (totalDistance <= 0.0 || targetDistance >= totalDistance) {
      nextPoint = route.geometry.last;
      if (route.geometry.length >= 2) {
        heading = SafeRoutingService.initialBearingDegrees(
          route.geometry[route.geometry.length - 2],
          route.geometry.last,
        );
      }
    } else {
      var segIdx = 0;
      for (var i = 0; i < cumulative.length - 1; i++) {
        if (targetDistance <= cumulative[i + 1]) {
          segIdx = i;
          break;
        }
      }
      final p1 = route.geometry[segIdx];
      final p2 = route.geometry[segIdx + 1];
      heading = SafeRoutingService.initialBearingDegrees(p1, p2);
      final distInSeg = targetDistance - cumulative[segIdx];
      nextPoint = SafeRoutingService.computeDestinationPoint(
        p1,
        distInSeg,
        heading,
      );
    }

    final pos = createPosition(
      point: nextPoint,
      heading: heading,
      speed: 8.33,
      accuracy: 4.0,
    );
    controller.simulatePosition(pos);
    return SimulationResult(
      success: true,
      message:
          'Simulated on-route advance (${stepMeters.toStringAsFixed(0)}m).',
      simulatedPosition: nextPoint,
    );
  }

  /// Computes a perpendicular offset point from the active route.
  LatLng? computeOffRoutePoint({
    required SafeRoute route,
    required LatLng referencePoint,
    required double distanceMeters,
    bool offsetRight = true,
  }) {
    if (route.geometry.isEmpty) return null;
    final projection = routeProgressEngine.project(
      route.geometry,
      referencePoint,
    );
    final anchor = projection?.point ?? route.geometry.first;
    final segIdx = projection?.segmentIndex ?? 0;
    final p1 = route.geometry[segIdx];
    final p2 = (segIdx + 1 < route.geometry.length)
        ? route.geometry[segIdx + 1]
        : p1;
    final trackBearing = (p1 == p2 && route.geometry.length >= 2)
        ? SafeRoutingService.initialBearingDegrees(
            route.geometry[0],
            route.geometry[1],
          )
        : SafeRoutingService.initialBearingDegrees(p1, p2);
    final perpBearing =
        (trackBearing + (offsetRight ? 90.0 : -90.0) + 360.0) % 360.0;
    return SafeRoutingService.computeDestinationPoint(
      anchor,
      distanceMeters,
      perpBearing,
    );
  }

  /// Simulates a single off-route sample at [distanceMeters] (default 80m).
  ///
  /// This produces an unconfirmed (suspect) off-route state and does not trigger rerouting.
  SimulationResult simulateOffRouteSingle({
    required NavigationSessionController controller,
    double distanceMeters = 80.0,
    double accuracy = 4.0,
  }) {
    if (!isEnabled) {
      return const SimulationResult(
        success: false,
        message: 'GPS simulator is disabled in release builds.',
      );
    }
    final state = controller.state;
    final route = state.route;
    if (!state.isNavigating || route == null || route.geometry.isEmpty) {
      return const SimulationResult(
        success: false,
        message: 'Cannot simulate off-route: No active route guidance.',
      );
    }

    final reference = state.currentPosition ?? route.geometry.first;
    final offRoutePoint = computeOffRoutePoint(
      route: route,
      referencePoint: reference,
      distanceMeters: distanceMeters,
    );
    if (offRoutePoint == null) {
      return const SimulationResult(
        success: false,
        message: 'Failed to compute off-route point.',
      );
    }

    final pos = createPosition(
      point: offRoutePoint,
      accuracy: accuracy,
      speed: 4.0,
    );
    controller.simulatePosition(pos);
    return SimulationResult(
      success: true,
      message:
          'Simulated single off-route fix (${distanceMeters.toStringAsFixed(0)}m - Suspect).',
      simulatedPosition: offRoutePoint,
    );
  }

  /// Simulates 3 consecutive off-route fixes at [distanceMeters] (e.g. 80m or 150m)
  /// spaced by 8m and 3s, satisfying OffRouteDetector confirmation criteria (>=3 fixes,
  /// >=5s elapsed, >=15m moved) and triggering an automatic reroute.
  Future<SimulationResult> simulateOffRouteConfirmed({
    required NavigationSessionController controller,
    double distanceMeters = 80.0,
    double accuracy = 4.0,
    Duration delayBetweenFixes = Duration.zero,
  }) async {
    if (!isEnabled) {
      return const SimulationResult(
        success: false,
        message: 'GPS simulator is disabled in release builds.',
      );
    }
    final state = controller.state;
    final route = state.route;
    if (!state.isNavigating || route == null || route.geometry.isEmpty) {
      return const SimulationResult(
        success: false,
        message: 'Cannot simulate off-route: No active route guidance.',
      );
    }

    final reference = state.currentPosition ?? route.geometry.first;
    final projection = routeProgressEngine.project(route.geometry, reference);
    final anchor = projection?.point ?? route.geometry.first;
    final segIdx = projection?.segmentIndex ?? 0;
    final p1 = route.geometry[segIdx];
    final p2 = (segIdx + 1 < route.geometry.length)
        ? route.geometry[segIdx + 1]
        : p1;
    final trackBearing = (p1 == p2 && route.geometry.length >= 2)
        ? SafeRoutingService.initialBearingDegrees(
            route.geometry[0],
            route.geometry[1],
          )
        : SafeRoutingService.initialBearingDegrees(p1, p2);
    final perpBearing = (trackBearing + 90.0) % 360.0;
    final point1 = SafeRoutingService.computeDestinationPoint(
      anchor,
      distanceMeters,
      perpBearing,
    );
    final point2 = SafeRoutingService.computeDestinationPoint(
      point1,
      8.0,
      trackBearing,
    );
    final point3 = SafeRoutingService.computeDestinationPoint(
      point1,
      16.0,
      trackBearing,
    );

    final t0 = DateTime.now();
    final pos1 = createPosition(
      point: point1,
      timestamp: t0,
      accuracy: accuracy,
      speed: 4.0,
      heading: trackBearing,
    );
    final pos2 = createPosition(
      point: point2,
      timestamp: t0.add(const Duration(seconds: 3)),
      accuracy: accuracy,
      speed: 4.0,
      heading: trackBearing,
    );
    final pos3 = createPosition(
      point: point3,
      timestamp: t0.add(const Duration(seconds: 6)),
      accuracy: accuracy,
      speed: 4.0,
      heading: trackBearing,
    );

    controller.simulatePosition(pos1);
    if (delayBetweenFixes > Duration.zero) {
      await Future.delayed(delayBetweenFixes);
    }
    controller.simulatePosition(pos2);
    if (delayBetweenFixes > Duration.zero) {
      await Future.delayed(delayBetweenFixes);
    }
    controller.simulatePosition(pos3);

    return SimulationResult(
      success: true,
      message:
          'Simulated 3 off-route fixes (${distanceMeters.toStringAsFixed(0)}m - Confirmed Reroute).',
      simulatedPosition: point3,
    );
  }

  /// Simulates approaching the nearest active Verified hazard (warning zone).
  SimulationResult simulateApproachingHazard({
    required NavigationSessionController controller,
    required Iterable<HazardReport> hazards,
  }) {
    if (!isEnabled) {
      return const SimulationResult(
        success: false,
        message: 'GPS simulator is disabled in release builds.',
      );
    }
    final state = controller.state;
    if (!state.isNavigating) {
      return const SimulationResult(
        success: false,
        message: 'Cannot simulate hazard: Navigation is not active.',
      );
    }
    final refPoint =
        state.currentPosition ??
        state.route?.geometry.firstOrNull ??
        const LatLng(0, 0);
    final nearest = findNearestVerifiedHazard(
      hazards: hazards,
      referencePoint: refPoint,
    );
    if (nearest == null) {
      return const SimulationResult(
        success: false,
        message: 'No active Verified hazard available for simulation.',
      );
    }

    final dangerRadius = SafetyConfig.dangerRadiusForSeverity(nearest.severity);
    final warningRadius = SafetyConfig.warningRadiusForSeverity(
      nearest.severity,
    );
    final approachingDistance =
        dangerRadius + (warningRadius - dangerRadius) / 2;
    final hazardPoint = LatLng(nearest.latitude, nearest.longitude);
    final bearing =
        (refPoint != hazardPoint &&
            SafetyConfig.validCoordinates(
              refPoint.latitude,
              refPoint.longitude,
            ))
        ? SafeRoutingService.initialBearingDegrees(hazardPoint, refPoint)
        : 0.0;
    final simPoint = SafeRoutingService.computeDestinationPoint(
      hazardPoint,
      approachingDistance,
      bearing,
    );

    final pos = createPosition(point: simPoint, accuracy: 4.0, speed: 5.0);
    controller.simulatePosition(pos);
    return SimulationResult(
      success: true,
      message:
          'Simulated approaching ${nearest.category} (${nearest.severity}) at ${approachingDistance.toStringAsFixed(0)}m.',
      simulatedPosition: simPoint,
    );
  }

  /// Simulates entering inside the danger zone of the nearest active Verified hazard.
  SimulationResult simulateInsideHazard({
    required NavigationSessionController controller,
    required Iterable<HazardReport> hazards,
  }) {
    if (!isEnabled) {
      return const SimulationResult(
        success: false,
        message: 'GPS simulator is disabled in release builds.',
      );
    }
    final state = controller.state;
    if (!state.isNavigating) {
      return const SimulationResult(
        success: false,
        message: 'Cannot simulate hazard: Navigation is not active.',
      );
    }
    final refPoint =
        state.currentPosition ??
        state.route?.geometry.firstOrNull ??
        const LatLng(0, 0);
    final nearest = findNearestVerifiedHazard(
      hazards: hazards,
      referencePoint: refPoint,
    );
    if (nearest == null) {
      return const SimulationResult(
        success: false,
        message: 'No active Verified hazard available for simulation.',
      );
    }

    final dangerRadius = SafetyConfig.dangerRadiusForSeverity(nearest.severity);
    final insideDistance = dangerRadius / 2;
    final hazardPoint = LatLng(nearest.latitude, nearest.longitude);
    final bearing =
        (refPoint != hazardPoint &&
            SafetyConfig.validCoordinates(
              refPoint.latitude,
              refPoint.longitude,
            ))
        ? SafeRoutingService.initialBearingDegrees(hazardPoint, refPoint)
        : 0.0;
    final simPoint = SafeRoutingService.computeDestinationPoint(
      hazardPoint,
      insideDistance,
      bearing,
    );

    final pos = createPosition(point: simPoint, accuracy: 4.0, speed: 5.0);
    controller.simulatePosition(pos);
    return SimulationResult(
      success: true,
      message:
          'Simulated inside ${nearest.category} (${nearest.severity}) at ${insideDistance.toStringAsFixed(0)}m.',
      simulatedPosition: simPoint,
    );
  }

  /// Restores live GPS tracking by delegating to [NavigationSessionController.restoreRealGps].
  SimulationResult restoreRealGps({
    required NavigationSessionController controller,
  }) {
    if (!isEnabled) {
      return const SimulationResult(
        success: false,
        message: 'GPS simulator is disabled in release builds.',
      );
    }
    controller.restoreRealGps();
    return const SimulationResult(
      success: true,
      message: 'Real GPS tracking restored.',
    );
  }
}
