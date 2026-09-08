import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/safety_config.dart';
import '../../../models/hazard_report.dart';
import '../../../services/hazard_map_service.dart';
import 'navigation_session_controller.dart';

typedef HazardDistanceCalculator =
    double Function(LatLng currentPosition, HazardReport hazard);

enum HazardZoneState { safe, approaching, inside }

@immutable
class HazardProximity {
  const HazardProximity({
    required this.hazard,
    required this.distanceMeters,
    required this.state,
    required this.isOnCurrentRoute,
  });

  final HazardReport hazard;
  final double distanceMeters;
  final HazardZoneState state;
  final bool isOnCurrentRoute;

  bool get isRelevant => state != HazardZoneState.safe;

  HazardNotificationPayload get notificationPayload =>
      HazardNotificationPayload(
        hazardId: hazard.id,
        category: hazard.category,
        severity: hazard.severity,
        description: hazard.description,
        distanceMeters: distanceMeters,
        state: state,
        isOnCurrentRoute: isOnCurrentRoute,
      );
}

/// UI-independent data retained for future local/push notification adapters.
@immutable
class HazardNotificationPayload {
  const HazardNotificationPayload({
    required this.hazardId,
    required this.category,
    required this.severity,
    required this.description,
    required this.distanceMeters,
    required this.state,
    required this.isOnCurrentRoute,
  });

  final String hazardId;
  final String category;
  final String severity;
  final String description;
  final double distanceMeters;
  final HazardZoneState state;
  final bool isOnCurrentRoute;
}

/// Monitors hazards for one active navigation session using the controller's
/// existing live GPS state. It owns no location stream and has no UI dependency.
class HazardProximityController extends ChangeNotifier {
  HazardProximityController({
    required NavigationSessionController navigationController,
    HazardDistanceCalculator? distanceCalculator,
    DateTime Function()? now,
    this.prominentAlertDuration = SafetyConfig.navigationHazardAlertDuration,
    this.alertCooldown = SafetyConfig.navigationHazardAlertCooldown,
  }) : _navigationController = navigationController,
       _distanceCalculator =
           distanceCalculator ??
           ((position, hazard) => const Distance().as(
             LengthUnit.Meter,
             position,
             LatLng(hazard.latitude, hazard.longitude),
           )),
       _now = now ?? DateTime.now {
    _navigationController.addListener(_onNavigationChanged);
    if (_navigationController.state.isNavigating) {
      _beginSession();
    }
  }

  final NavigationSessionController _navigationController;
  final HazardDistanceCalculator _distanceCalculator;
  final DateTime Function() _now;
  final Duration prominentAlertDuration;
  final Duration alertCooldown;

  List<HazardReport> _activeHazards = const [];
  List<HazardProximity> _proximities = const [];
  HazardProximity? _prominentAlert;
  final Map<String, HazardZoneState> _previousStates = {};
  final Map<String, DateTime> _lastAlertAt = {};
  final Map<String, HazardZoneState> _lastAlertState = {};
  final Set<String> _leftWarningZone = {};
  Timer? _prominentTimer;
  bool _sessionActive = false;
  bool _disposed = false;
  int _sessionGeneration = 0;

  List<HazardProximity> get proximities => _proximities;
  List<HazardProximity> get relevantProximities =>
      List.unmodifiable(_proximities.where((item) => item.isRelevant));
  HazardProximity? get primaryProximity {
    for (final proximity in _proximities) {
      if (proximity.isRelevant) return proximity;
    }
    return null;
  }

  HazardProximity? get prominentAlert => _prominentAlert;

  @visibleForTesting
  bool get hasProminentTimer => _prominentTimer?.isActive == true;

  @visibleForTesting
  Map<String, HazardZoneState> get previousStates =>
      Map.unmodifiable(_previousStates);

  @visibleForTesting
  Set<String> get hazardsThatLeftWarningZone =>
      Set.unmodifiable(_leftWarningZone);

  /// Accepts snapshots from the page's existing hazard subscription.
  /// Filtering is repeated here so non-Verified or invalid reports can never
  /// enter the alert pipeline, even when a caller passes an unfiltered list.
  void updateHazards(Iterable<HazardReport> reports) {
    if (_disposed) return;
    _activeHazards = HazardMapService.activeReports(reports.toList());
    _evaluate();
  }

  void clearHazards() => updateHazards(const []);

  void dismissProminentAlert() {
    if (_disposed) return;
    _prominentTimer?.cancel();
    _prominentTimer = null;
    if (_prominentAlert == null) return;
    _prominentAlert = null;
    notifyListeners();
  }

  void _onNavigationChanged() {
    if (_disposed) return;
    final navigating = _navigationController.state.isNavigating;
    if (navigating && !_sessionActive) {
      _beginSession();
      return;
    }
    if (!navigating && _sessionActive) {
      _endSession();
      return;
    }
    if (navigating) _evaluate();
  }

  void _beginSession() {
    _sessionActive = true;
    _sessionGeneration++;
    _clearSessionState(notify: false);
    _evaluate();
  }

  void _endSession() {
    _sessionActive = false;
    _sessionGeneration++;
    _clearSessionState();
  }

  void _clearSessionState({bool notify = true}) {
    _prominentTimer?.cancel();
    _prominentTimer = null;
    _prominentAlert = null;
    _proximities = const [];
    _previousStates.clear();
    _lastAlertAt.clear();
    _lastAlertState.clear();
    _leftWarningZone.clear();
    if (notify && !_disposed) notifyListeners();
  }

  void _evaluate() {
    if (_disposed) return;
    if (!_sessionActive || !_navigationController.state.isNavigating) {
      if (_proximities.isNotEmpty || _prominentAlert != null) {
        _clearSessionState();
      }
      return;
    }

    final position = _navigationController.state.currentPosition;
    if (position == null ||
        !SafetyConfig.validCoordinates(position.latitude, position.longitude)) {
      return;
    }

    final routeHazardIds =
        _navigationController.state.route?.crossedHazardIds.toSet() ??
        const <String>{};
    final next = <HazardProximity>[];
    for (final hazard in _activeHazards) {
      try {
        final distance = _distanceCalculator(position, hazard);
        if (!distance.isFinite || distance < 0) continue;
        final dangerRadius = SafetyConfig.dangerRadiusForSeverity(
          hazard.severity,
        );
        final warningRadius = SafetyConfig.warningRadiusForSeverity(
          hazard.severity,
        );
        final state = distance <= dangerRadius
            ? HazardZoneState.inside
            : distance <= warningRadius
            ? HazardZoneState.approaching
            : HazardZoneState.safe;
        next.add(
          HazardProximity(
            hazard: hazard,
            distanceMeters: distance,
            state: state,
            isOnCurrentRoute: routeHazardIds.contains(hazard.id),
          ),
        );
      } catch (_) {
        // A malformed distance result must not interrupt navigation.
      }
    }
    next.sort(comparePriority);

    final activeIds = next.map((item) => item.hazard.id).toSet();
    _previousStates.removeWhere((id, _) => !activeIds.contains(id));
    _lastAlertAt.removeWhere((id, _) => !activeIds.contains(id));
    _lastAlertState.removeWhere((id, _) => !activeIds.contains(id));
    _leftWarningZone.removeWhere((id) => !activeIds.contains(id));

    final candidates = <HazardProximity>[];
    final now = _now();
    for (final proximity in next) {
      final id = proximity.hazard.id;
      final previous = _previousStates[id];
      if (proximity.state == HazardZoneState.safe) {
        if (previous != null && previous != HazardZoneState.safe) {
          _leftWarningZone.add(id);
        }
        _previousStates[id] = HazardZoneState.safe;
        continue;
      }

      final lastState = _lastAlertState[id];
      final lastTime = _lastAlertAt[id];
      final entered = previous == null || previous == HazardZoneState.safe;
      final escalated =
          previous == HazardZoneState.approaching &&
          proximity.state == HazardZoneState.inside;
      final neverAlerted = lastState == null;
      final cooldownElapsed =
          lastTime != null && now.difference(lastTime) >= alertCooldown;
      if (entered || escalated || neverAlerted || cooldownElapsed) {
        candidates.add(proximity);
      }
      _previousStates[id] = proximity.state;
      _leftWarningZone.remove(id);
    }

    final currentId = _prominentAlert?.hazard.id;
    final currentStillRelevant =
        currentId != null &&
        next.any((item) => item.hazard.id == currentId && item.isRelevant);
    if (!currentStillRelevant && _prominentAlert != null) {
      _prominentTimer?.cancel();
      _prominentTimer = null;
      _prominentAlert = null;
    }

    _proximities = List.unmodifiable(next);
    if (candidates.isNotEmpty) {
      candidates.sort(comparePriority);
      final selected = candidates.first;
      final primary = next.where((item) => item.isRelevant).first;
      if (selected.hazard.id != primary.hazard.id) {
        notifyListeners();
        return;
      }
      final current = _prominentAlert;
      final shouldReplace =
          current == null ||
          (current.hazard.id == selected.hazard.id &&
              current.state != selected.state) ||
          comparePriority(selected, current) < 0;
      if (shouldReplace) _showProminent(selected, now);
    }
    notifyListeners();
  }

  void _showProminent(HazardProximity proximity, DateTime now) {
    _prominentTimer?.cancel();
    _prominentAlert = proximity;
    _lastAlertAt[proximity.hazard.id] = now;
    _lastAlertState[proximity.hazard.id] = proximity.state;
    final generation = _sessionGeneration;
    _prominentTimer = Timer(prominentAlertDuration, () {
      if (_disposed || generation != _sessionGeneration) return;
      _prominentTimer = null;
      _prominentAlert = null;
      notifyListeners();
    });
  }

  @visibleForTesting
  static int comparePriority(HazardProximity a, HazardProximity b) {
    final state = _stateRank(b.state).compareTo(_stateRank(a.state));
    if (state != 0) return state;
    final severity = _severityRank(
      b.hazard.severity,
    ).compareTo(_severityRank(a.hazard.severity));
    if (severity != 0) return severity;
    return a.distanceMeters.compareTo(b.distanceMeters);
  }

  static int _stateRank(HazardZoneState state) => switch (state) {
    HazardZoneState.inside => 2,
    HazardZoneState.approaching => 1,
    HazardZoneState.safe => 0,
  };

  static int _severityRank(String severity) => switch (severity) {
    'High' => 3,
    'Medium' => 2,
    _ => 1,
  };

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sessionGeneration++;
    _prominentTimer?.cancel();
    _prominentTimer = null;
    _navigationController.removeListener(_onNavigationChanged);
    super.dispose();
  }
}
