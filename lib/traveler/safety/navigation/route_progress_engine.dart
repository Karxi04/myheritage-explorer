import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/navigation_stop.dart';
import '../../../models/safe_route.dart';

enum NavigationManeuver {
  continueStraight,
  turnLeft,
  turnRight,
  slightLeft,
  slightRight,
  sharpLeft,
  sharpRight,
  keepLeft,
  keepRight,
  roundabout,
  exitRoundabout,
  uTurn,
  depart,
  arrive,
  unknown,
}

enum NavigationArrival { none, intermediateStop, finalDestination }

@immutable
class RouteProjection {
  const RouteProjection({
    required this.point,
    required this.segmentIndex,
    required this.segmentFraction,
    required this.distanceFromRouteMeters,
    required this.distanceAlongGeometryMeters,
  });

  final LatLng point;
  final int segmentIndex;
  final double segmentFraction;
  final double distanceFromRouteMeters;
  final double distanceAlongGeometryMeters;
}

@immutable
class NavigationProgress {
  const NavigationProgress({
    required this.projection,
    required this.geometryProgress,
    required this.activeStepIndex,
    required this.maneuverStepIndex,
    required this.maneuver,
    required this.instruction,
    required this.currentRoadName,
    required this.distanceToManeuverMeters,
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
    required this.currentLegIndex,
    required this.nextStop,
    required this.finalDestination,
    required this.arrival,
    required this.isLikelyOffRoute,
  });

  final RouteProjection projection;
  final double geometryProgress;
  final int? activeStepIndex;
  final int? maneuverStepIndex;
  final NavigationManeuver maneuver;
  final String instruction;
  final String currentRoadName;
  final double distanceToManeuverMeters;
  final double remainingDistanceMeters;
  final double remainingDurationSeconds;
  final int currentLegIndex;
  final NavigationStop? nextStop;
  final NavigationStop? finalDestination;
  final NavigationArrival arrival;
  final bool isLikelyOffRoute;
}

/// Pure, lightweight route projection and turn-by-turn progress calculations.
class RouteProgressEngine {
  const RouteProgressEngine({
    this.arrivalDistanceMeters = 40,
    this.arrivalProgressToleranceMeters = 75,
    this.offRouteDistanceMeters = 75,
  });

  static const double _earthRadiusMeters = 6371000;

  final double arrivalDistanceMeters;
  final double arrivalProgressToleranceMeters;
  final double offRouteDistanceMeters;

  RouteProjection? project(List<LatLng> geometry, LatLng gps) {
    if (geometry.isEmpty) return null;
    if (geometry.length == 1) {
      return RouteProjection(
        point: geometry.first,
        segmentIndex: 0,
        segmentFraction: 0,
        distanceFromRouteMeters: _distance(geometry.first, gps),
        distanceAlongGeometryMeters: 0,
      );
    }
    final cumulative = cumulativeGeometryDistances(geometry);
    RouteProjection? best;
    for (var index = 0; index < geometry.length - 1; index++) {
      final candidate = _projectSegment(
        geometry[index],
        geometry[index + 1],
        gps,
        index,
        cumulative[index],
      );
      if (best == null ||
          candidate.distanceFromRouteMeters < best.distanceFromRouteMeters) {
        best = candidate;
      }
    }
    return best;
  }

  NavigationProgress? calculate({
    required SafeRoute route,
    required List<NavigationStop> stops,
    required LatLng gps,
    int minimumLegIndex = 0,
  }) {
    final projection = project(route.geometry, gps);
    if (projection == null) return null;
    final cumulative = cumulativeGeometryDistances(route.geometry);
    final geometryLength = cumulative.isEmpty ? 0.0 : cumulative.last;
    final along = projection.distanceAlongGeometryMeters.clamp(
      0.0,
      geometryLength,
    );
    final fraction = geometryLength <= 0 ? 0.0 : along / geometryLength;
    final activeStepIndex = _activeStepIndex(route.steps, cumulative, along);
    final maneuverStepIndex = _maneuverStepIndex(route.steps, activeStepIndex);
    final maneuverStep = maneuverStepIndex == null
        ? null
        : route.steps[maneuverStepIndex];
    final activeStep = activeStepIndex == null
        ? null
        : route.steps[activeStepIndex];
    final currentLegIndex = _currentLegIndex(route, minimumLegIndex);
    final nextStop = stops.isEmpty
        ? null
        : stops[currentLegIndex.clamp(0, stops.length - 1)];
    final finalDestination = stops.isEmpty ? null : stops.last;
    final legEnd = _legEndDistance(route, cumulative, currentLegIndex);
    final nearStopByProgress =
        legEnd - along <=
        math.max(arrivalProgressToleranceMeters, arrivalDistanceMeters * 1.5);
    final nearStopByGps =
        nextStop != null &&
        _distance(gps, nextStop.location) <= arrivalDistanceMeters;
    final hasArrived = nearStopByGps && nearStopByProgress;
    final arrival = !hasArrived
        ? NavigationArrival.none
        : currentLegIndex >= math.max(0, stops.length - 1)
        ? NavigationArrival.finalDestination
        : NavigationArrival.intermediateStop;

    return NavigationProgress(
      projection: projection,
      geometryProgress: fraction.clamp(0.0, 1.0),
      activeStepIndex: activeStepIndex,
      maneuverStepIndex: maneuverStepIndex,
      maneuver: maneuverForType(maneuverStep?.maneuverType),
      instruction: _instruction(maneuverStep, nextStop, arrival),
      currentRoadName: _usable(activeStep?.roadName)
          ? activeStep!.roadName.trim()
          : 'Unnamed road',
      distanceToManeuverMeters: _distanceToManeuver(
        route.steps,
        maneuverStepIndex,
        cumulative,
        along,
      ),
      remainingDistanceMeters: geometryLength <= 0
          ? math.max(0, route.distanceMeters * (1 - fraction))
          : math.max(
              0,
              route.distanceMeters * (geometryLength - along) / geometryLength,
            ),
      remainingDurationSeconds: _remainingDuration(
        route,
        cumulative,
        along,
        activeStepIndex,
        fraction,
      ),
      currentLegIndex: currentLegIndex,
      nextStop: nextStop,
      finalDestination: finalDestination,
      arrival: arrival,
      isLikelyOffRoute:
          projection.distanceFromRouteMeters > offRouteDistanceMeters,
    );
  }

  static List<double> cumulativeGeometryDistances(List<LatLng> geometry) {
    if (geometry.isEmpty) return const [];
    final result = List<double>.filled(geometry.length, 0);
    for (var index = 1; index < geometry.length; index++) {
      result[index] =
          result[index - 1] + _distance(geometry[index - 1], geometry[index]);
    }
    return result;
  }

  static NavigationManeuver maneuverForType(int? type) => switch (type) {
    0 => NavigationManeuver.turnLeft,
    1 => NavigationManeuver.turnRight,
    2 => NavigationManeuver.sharpLeft,
    3 => NavigationManeuver.sharpRight,
    4 => NavigationManeuver.slightLeft,
    5 => NavigationManeuver.slightRight,
    6 => NavigationManeuver.continueStraight,
    7 => NavigationManeuver.roundabout,
    8 => NavigationManeuver.exitRoundabout,
    9 => NavigationManeuver.uTurn,
    10 => NavigationManeuver.arrive,
    11 => NavigationManeuver.depart,
    12 => NavigationManeuver.keepLeft,
    13 => NavigationManeuver.keepRight,
    _ => NavigationManeuver.unknown,
  };

  static String fallbackInstruction(
    NavigationManeuver maneuver, {
    String? roadName,
  }) {
    final action = switch (maneuver) {
      NavigationManeuver.continueStraight => 'Continue straight',
      NavigationManeuver.turnLeft => 'Turn left',
      NavigationManeuver.turnRight => 'Turn right',
      NavigationManeuver.slightLeft => 'Slight left',
      NavigationManeuver.slightRight => 'Slight right',
      NavigationManeuver.sharpLeft => 'Sharp left',
      NavigationManeuver.sharpRight => 'Sharp right',
      NavigationManeuver.keepLeft => 'Keep left',
      NavigationManeuver.keepRight => 'Keep right',
      NavigationManeuver.roundabout => 'Enter the roundabout',
      NavigationManeuver.exitRoundabout => 'Exit the roundabout',
      NavigationManeuver.uTurn => 'Make a U-turn',
      NavigationManeuver.depart => 'Start route',
      NavigationManeuver.arrive => 'Arrive at destination',
      NavigationManeuver.unknown => 'Continue on route',
    };
    return _usable(roadName) && maneuver != NavigationManeuver.arrive
        ? '$action onto ${roadName!.trim()}'
        : action;
  }

  RouteProjection _projectSegment(
    LatLng first,
    LatLng second,
    LatLng gps,
    int segmentIndex,
    double distanceBeforeSegment,
  ) {
    final centerLatitude = _radians(gps.latitude);
    ({double x, double y}) local(LatLng point) => (
      x:
          _earthRadiusMeters *
          _radians(point.longitude - gps.longitude) *
          math.cos(centerLatitude),
      y: _earthRadiusMeters * _radians(point.latitude - gps.latitude),
    );
    final a = local(first);
    final b = local(second);
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0
        ? 0.0
        : (-(a.x * dx + a.y * dy) / lengthSquared).clamp(0.0, 1.0);
    final closestX = a.x + dx * t;
    final closestY = a.y + dy * t;
    final cosLatitude = math.cos(centerLatitude);
    final latitude =
        gps.latitude + closestY / _earthRadiusMeters * 180 / math.pi;
    final longitude = cosLatitude.abs() < 1e-12
        ? gps.longitude
        : gps.longitude +
              closestX / (_earthRadiusMeters * cosLatitude) * 180 / math.pi;
    final segmentLength = _distance(first, second);
    return RouteProjection(
      point: LatLng(latitude, longitude),
      segmentIndex: segmentIndex,
      segmentFraction: t,
      distanceFromRouteMeters: math.sqrt(
        closestX * closestX + closestY * closestY,
      ),
      distanceAlongGeometryMeters: distanceBeforeSegment + segmentLength * t,
    );
  }

  static int? _activeStepIndex(
    List<RouteStep> steps,
    List<double> cumulative,
    double along,
  ) {
    if (steps.isEmpty || cumulative.isEmpty) return null;
    for (var index = 0; index < steps.length; index++) {
      final end = _indexDistance(cumulative, steps[index].endGeometryIndex);
      if (along < end || index == steps.length - 1) return index;
    }
    return steps.length - 1;
  }

  static int? _maneuverStepIndex(List<RouteStep> steps, int? activeIndex) {
    if (steps.isEmpty || activeIndex == null) return null;
    return activeIndex + 1 < steps.length ? activeIndex + 1 : activeIndex;
  }

  static double _distanceToManeuver(
    List<RouteStep> steps,
    int? maneuverIndex,
    List<double> cumulative,
    double along,
  ) {
    if (maneuverIndex == null || cumulative.isEmpty) return 0;
    final step = steps[maneuverIndex];
    final isFinalArrival =
        maneuverIndex == steps.length - 1 &&
        maneuverForType(step.maneuverType) == NavigationManeuver.arrive;
    final targetIndex = isFinalArrival
        ? step.endGeometryIndex
        : step.startGeometryIndex;
    return math.max(0, _indexDistance(cumulative, targetIndex) - along);
  }

  static double _remainingDuration(
    SafeRoute route,
    List<double> cumulative,
    double along,
    int? activeStepIndex,
    double routeFraction,
  ) {
    if (activeStepIndex == null || route.steps.isEmpty || cumulative.isEmpty) {
      return math.max(0, route.durationSeconds * (1 - routeFraction));
    }
    var remaining = 0.0;
    for (var index = activeStepIndex; index < route.steps.length; index++) {
      final step = route.steps[index];
      if (index != activeStepIndex) {
        remaining += step.durationSeconds;
        continue;
      }
      final start = _indexDistance(cumulative, step.startGeometryIndex);
      final end = _indexDistance(cumulative, step.endGeometryIndex);
      final length = math.max(0, end - start);
      final fractionRemaining = length <= 0
          ? (along <= end ? 1.0 : 0.0)
          : ((end - along) / length).clamp(0.0, 1.0);
      remaining += step.durationSeconds * fractionRemaining;
    }
    return math.max(0, remaining);
  }

  static int _currentLegIndex(SafeRoute route, int minimumLegIndex) {
    if (route.legs.isEmpty) return 0;
    // The controller advances this index only after explicit acknowledgement.
    // Keeping it locked prevents a parallel road or noisy projection from
    // silently skipping an ordered stop.
    return minimumLegIndex.clamp(0, route.legs.length - 1);
  }

  static double _legEndDistance(
    SafeRoute route,
    List<double> cumulative,
    int legIndex,
  ) {
    if (cumulative.isEmpty) return 0;
    if (route.legs.isEmpty || legIndex >= route.legs.length) {
      return cumulative.last;
    }
    final steps = route.legs[legIndex].steps;
    return steps.isEmpty
        ? cumulative.last
        : _indexDistance(cumulative, steps.last.endGeometryIndex);
  }

  static String _instruction(
    RouteStep? step,
    NavigationStop? nextStop,
    NavigationArrival arrival,
  ) {
    if (arrival != NavigationArrival.none) {
      return arrival == NavigationArrival.finalDestination
          ? 'You have arrived at ${nextStop?.displayName ?? 'your destination'}.'
          : 'Arriving at ${nextStop?.displayName ?? 'your next stop'}';
    }
    if (_usable(step?.instruction)) return step!.instruction.trim();
    return fallbackInstruction(
      maneuverForType(step?.maneuverType),
      roadName: step?.roadName,
    );
  }

  static double _indexDistance(List<double> cumulative, int index) =>
      cumulative[index.clamp(0, cumulative.length - 1)];

  static bool _usable(String? value) =>
      value != null && value.trim().isNotEmpty;

  static double _distance(LatLng a, LatLng b) {
    final lat1 = _radians(a.latitude);
    final lat2 = _radians(b.latitude);
    final dLat = lat2 - lat1;
    final dLon = _radians(b.longitude - a.longitude);
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final h =
        sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLon * sinLon;
    return _earthRadiusMeters * 2 * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  static double _radians(double value) => value * math.pi / 180;
}
