import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/safety_config.dart';
import '../../../models/hazard_report.dart';
import '../../../models/navigation_stop.dart';
import '../../../models/safe_route.dart';
import '../../../services/hazard_map_service.dart';
import 'navigation_session_controller.dart';
import 'off_route_detector.dart';
import 'route_progress_engine.dart';

typedef HazardAwareRerouteCalculator =
    Future<SafeRoute> Function({
      required LatLng start,
      required List<NavigationStop> stops,
      required List<HazardReport> hazards,
    });

enum RerouteReason { offRoute, newHazard }

enum RerouteStatus { idle, rerouting, succeeded, failed }

@immutable
class RerouteState {
  const RerouteState({
    this.status = RerouteStatus.idle,
    this.reason,
    this.hazardId,
    this.message,
  });

  final RerouteStatus status;
  final RerouteReason? reason;
  final String? hazardId;
  final String? message;

  bool get isRerouting => status == RerouteStatus.rerouting;
}

/// Coordinates automatic rerouting while reusing the session's GPS stream.
///
/// It accepts verified-hazard snapshots from the page's existing subscription,
/// detects conflicts only on the untravelled route, preserves ordered remaining
/// stops, and atomically replaces navigation geometry when routing succeeds.
class RerouteCoordinator extends ChangeNotifier {
  RerouteCoordinator({
    required NavigationSessionController navigationController,
    required HazardAwareRerouteCalculator calculateRoute,
    OffRouteDetector? offRouteDetector,
    RouteProgressEngine projectionEngine = const RouteProgressEngine(),
    this.cooldown = SafetyConfig.navigationRerouteCooldown,
    DateTime Function()? now,
  }) : _navigationController = navigationController,
       _calculateRoute = calculateRoute,
       _offRouteDetector = offRouteDetector ?? OffRouteDetector(),
       _projectionEngine = projectionEngine,
       _now = now ?? DateTime.now {
    _navigationController.addListener(_onNavigationChanged);
    _wasNavigating = _navigationController.state.isNavigating;
  }

  final NavigationSessionController _navigationController;
  final HazardAwareRerouteCalculator _calculateRoute;
  final OffRouteDetector _offRouteDetector;
  final RouteProgressEngine _projectionEngine;
  final DateTime Function() _now;
  final Duration cooldown;

  RerouteState _state = const RerouteState();
  RerouteState get state => _state;
  OffRouteState get offRouteState => _offRouteDetector.state;

  List<HazardReport> _hazards = const [];
  Set<String> _acknowledgedRouteConflicts = <String>{};
  SafeRoute? _observedRoute;
  DateTime? _lastAttemptAt;
  bool _rerouteInFlight = false;
  bool _wasNavigating = false;
  bool _disposed = false;
  int _generation = 0;
  String? _pendingHazardId;
  Timer? _successTimer;

  @visibleForTesting
  bool get rerouteInFlight => _rerouteInFlight;

  /// Called with snapshots from the existing Verified hazard stream.
  void updateHazards(Iterable<HazardReport> reports) {
    if (_disposed) return;
    _hazards = HazardMapService.activeReports(reports.toList());
    final navigation = _navigationController.state;
    if (!navigation.isNavigating || navigation.route == null) return;

    final conflicts = conflictingHazardsOnRemainingRoute(
      route: navigation.route!,
      currentPosition: navigation.currentPosition,
      hazards: _hazards,
      projectionEngine: _projectionEngine,
    );
    final newConflicts = conflicts
        .where(
          (hazard) =>
              !_acknowledgedRouteConflicts.contains(hazard.id) &&
              !navigation.route!.crossedHazardIds.contains(hazard.id),
        )
        .toList(growable: false);
    _acknowledgedRouteConflicts = conflicts.map((hazard) => hazard.id).toSet();
    if (newConflicts.isNotEmpty) {
      if (_rerouteInFlight) {
        _pendingHazardId = newConflicts.first.id;
        return;
      }
      unawaited(
        requestReroute(
          RerouteReason.newHazard,
          hazardId: newConflicts.first.id,
        ),
      );
    }
  }

  void _onNavigationChanged() {
    if (_disposed) return;
    final navigation = _navigationController.state;
    if (!navigation.isNavigating) {
      if (_wasNavigating) _resetSession();
      _wasNavigating = false;
      return;
    }

    if (!_wasNavigating) {
      _wasNavigating = true;
      _generation++;
      _offRouteDetector.reset();
      _observedRoute = navigation.route;
      _acknowledgedRouteConflicts = _conflictIds(navigation);
    } else if (!identical(_observedRoute, navigation.route)) {
      _observedRoute = navigation.route;
      _offRouteDetector.reset();
      _acknowledgedRouteConflicts = _conflictIds(navigation);
    }

    if (_rerouteInFlight ||
        navigation.currentPosition == null ||
        navigation.route == null ||
        navigation.route!.geometry.isEmpty ||
        navigation.progress?.arrival != NavigationArrival.none) {
      return;
    }
    final projection = _projectionEngine.project(
      navigation.route!.geometry,
      navigation.currentPosition!,
    );
    if (projection == null) return;
    final result = _offRouteDetector.evaluate(
      distanceFromRouteMeters: projection.distanceFromRouteMeters,
      position: navigation.currentPosition!,
      timestamp: navigation.timestamp ?? _now(),
      accuracyMeters: navigation.accuracy,
    );
    if (result == OffRouteState.confirmed) {
      unawaited(requestReroute(RerouteReason.offRoute));
    }
  }

  /// Starts a single hazard-aware replacement request if the session is valid.
  Future<bool> requestReroute(RerouteReason reason, {String? hazardId}) async {
    if (_disposed || _rerouteInFlight) return false;
    final navigation = _navigationController.state;
    final position = navigation.currentPosition;
    final route = navigation.route;
    if (!navigation.isNavigating || position == null || route == null) {
      return false;
    }
    if (navigation.progress?.arrival == NavigationArrival.finalDestination) {
      return false;
    }
    final now = _now();
    final lastAttemptAt = _lastAttemptAt;
    if (reason == RerouteReason.offRoute &&
        lastAttemptAt != null &&
        now.difference(lastAttemptAt) < cooldown) {
      return false;
    }
    final remainingStops = remainingStopsFor(navigation);
    if (remainingStops.isEmpty) return false;

    _rerouteInFlight = true;
    _lastAttemptAt = now;
    _successTimer?.cancel();
    _setState(
      RerouteState(
        status: RerouteStatus.rerouting,
        reason: reason,
        hazardId: hazardId,
        message: reason == RerouteReason.newHazard
            ? 'New hazard ahead · Rerouting…'
            : 'Off route · Rerouting…',
      ),
    );
    final generation = _generation;
    try {
      final replacement = await _calculateRoute(
        start: position,
        stops: remainingStops,
        hazards: List<HazardReport>.unmodifiable(_hazards),
      );
      if (_disposed ||
          generation != _generation ||
          !_navigationController.state.isNavigating) {
        return false;
      }
      final replaced = _navigationController.replaceRoute(
        route: replacement,
        remainingStops: remainingStops,
      );
      if (!replaced) {
        throw StateError('Routing provider returned unusable route geometry.');
      }
      _observedRoute = replacement;
      _offRouteDetector.reset();
      _acknowledgedRouteConflicts = _conflictIds(_navigationController.state);
      _setState(
        RerouteState(
          status: RerouteStatus.succeeded,
          reason: reason,
          hazardId: hazardId,
          message: 'Safer route ready',
        ),
      );
      _successTimer = Timer(const Duration(seconds: 3), () {
        if (!_disposed && generation == _generation) {
          _setState(const RerouteState());
        }
      });
      return true;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        _setState(
          RerouteState(
            status: RerouteStatus.failed,
            reason: reason,
            hazardId: hazardId,
            message: 'Could not reroute. Continuing on the current route.',
          ),
        );
      }
      return false;
    } finally {
      _rerouteInFlight = false;
      final pendingHazardId = _pendingHazardId;
      _pendingHazardId = null;
      if (!_disposed &&
          pendingHazardId != null &&
          _hazardStillConflicts(pendingHazardId)) {
        unawaited(
          requestReroute(RerouteReason.newHazard, hazardId: pendingHazardId),
        );
      }
    }
  }

  bool _hazardStillConflicts(String hazardId) {
    final navigation = _navigationController.state;
    final route = navigation.route;
    if (!navigation.isNavigating || route == null) return false;
    return conflictingHazardsOnRemainingRoute(
      route: route,
      currentPosition: navigation.currentPosition,
      hazards: _hazards.where((hazard) => hazard.id == hazardId),
      projectionEngine: _projectionEngine,
    ).isNotEmpty;
  }

  Set<String> _conflictIds(NavigationSessionState navigation) {
    final route = navigation.route;
    if (route == null) return <String>{};
    return conflictingHazardsOnRemainingRoute(
      route: route,
      currentPosition: navigation.currentPosition,
      hazards: _hazards,
      projectionEngine: _projectionEngine,
    ).map((hazard) => hazard.id).toSet();
  }

  @visibleForTesting
  static List<NavigationStop> remainingStopsFor(
    NavigationSessionState navigation,
  ) {
    if (navigation.stops.isEmpty) return const [];
    final index = (navigation.progress?.currentLegIndex ?? 0).clamp(
      0,
      navigation.stops.length - 1,
    );
    return List<NavigationStop>.unmodifiable(navigation.stops.skip(index));
  }

  @visibleForTesting
  static List<HazardReport> conflictingHazardsOnRemainingRoute({
    required SafeRoute route,
    required LatLng? currentPosition,
    required Iterable<HazardReport> hazards,
    RouteProgressEngine projectionEngine = const RouteProgressEngine(),
  }) {
    if (route.geometry.isEmpty) return const [];
    var remaining = route.geometry;
    if (currentPosition != null && route.geometry.length > 1) {
      final projection = projectionEngine.project(
        route.geometry,
        currentPosition,
      );
      if (projection != null) {
        remaining = <LatLng>[
          projection.point,
          ...route.geometry.skip(projection.segmentIndex + 1),
        ];
      }
    }
    final result = <HazardReport>[];
    for (final hazard in hazards) {
      if (!hazard.isVerified || !hazard.hasValidLocation) continue;
      final radius = SafetyConfig.dangerRadiusForSeverity(hazard.severity);
      final hazardPoint = LatLng(hazard.latitude, hazard.longitude);
      final projection = projectionEngine.project(remaining, hazardPoint);
      if (projection != null && projection.distanceFromRouteMeters <= radius) {
        result.add(hazard);
      }
    }
    return List<HazardReport>.unmodifiable(result);
  }

  void _resetSession() {
    _generation++;
    _rerouteInFlight = false;
    _lastAttemptAt = null;
    _observedRoute = null;
    _pendingHazardId = null;
    _offRouteDetector.reset();
    _acknowledgedRouteConflicts.clear();
    _successTimer?.cancel();
    _successTimer = null;
    _setState(const RerouteState());
  }

  void _setState(RerouteState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _successTimer?.cancel();
    _navigationController.removeListener(_onNavigationChanged);
    super.dispose();
  }
}
