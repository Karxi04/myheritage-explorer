import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/navigation_stop.dart';
import '../../../models/safe_route.dart';
import '../../../services/location_service.dart';
import 'route_progress_engine.dart';

typedef NavigationAccessCheck = Future<void> Function();
typedef NavigationPositionStream = Stream<Position> Function();
typedef NavigationReverseGeocoder = Future<String?> Function(LatLng point);

enum NavigationLocationIssue {
  permissionDenied,
  permissionDeniedForever,
  servicesDisabled,
  temporarilyUnavailable,
  poorAccuracy,
  streamError,
}

@immutable
class NavigationSessionState {
  NavigationSessionState({
    this.currentPosition,
    this.currentHeading,
    this.displayHeading = 0,
    this.speed = 0,
    this.accuracy,
    this.timestamp,
    this.currentLocationLabel,
    this.isFollowingUser = false,
    this.isNavigating = false,
    this.isStarting = false,
    this.route,
    Iterable<NavigationStop> stops = const [],
    this.locationIssue,
    this.locationMessage,
    this.progress,
    this.isSimulatedLocation = false,
  }) : stops = List<NavigationStop>.unmodifiable(stops);

  final LatLng? currentPosition;

  /// Latest valid real GPS heading, normalized to 0 <= heading < 360.
  final double? currentHeading;

  /// Unwrapped, smoothed heading used by the marker to cross north cleanly.
  final double displayHeading;
  final double speed;
  final double? accuracy;
  final DateTime? timestamp;
  final String? currentLocationLabel;
  final bool isFollowingUser;
  final bool isNavigating;
  final bool isStarting;
  final SafeRoute? route;
  final List<NavigationStop> stops;
  final NavigationLocationIssue? locationIssue;
  final String? locationMessage;
  final NavigationProgress? progress;

  /// Whether [currentPosition] was provided by a debug simulation harness.
  final bool isSimulatedLocation;

  NavigationSessionState copyWith({
    LatLng? currentPosition,
    bool clearCurrentPosition = false,
    double? currentHeading,
    bool clearCurrentHeading = false,
    double? displayHeading,
    double? speed,
    double? accuracy,
    bool clearAccuracy = false,
    DateTime? timestamp,
    bool clearTimestamp = false,
    String? currentLocationLabel,
    bool clearCurrentLocationLabel = false,
    bool? isFollowingUser,
    bool? isNavigating,
    bool? isStarting,
    SafeRoute? route,
    bool clearRoute = false,
    Iterable<NavigationStop>? stops,
    NavigationLocationIssue? locationIssue,
    bool clearLocationIssue = false,
    String? locationMessage,
    bool clearLocationMessage = false,
    NavigationProgress? progress,
    bool clearProgress = false,
    bool? isSimulatedLocation,
    bool clearSimulatedLocation = false,
  }) => NavigationSessionState(
    currentPosition: clearCurrentPosition
        ? null
        : currentPosition ?? this.currentPosition,
    currentHeading: clearCurrentHeading
        ? null
        : currentHeading ?? this.currentHeading,
    displayHeading: displayHeading ?? this.displayHeading,
    speed: speed ?? this.speed,
    accuracy: clearAccuracy ? null : accuracy ?? this.accuracy,
    timestamp: clearTimestamp ? null : timestamp ?? this.timestamp,
    currentLocationLabel: clearCurrentLocationLabel
        ? null
        : currentLocationLabel ?? this.currentLocationLabel,
    isFollowingUser: isFollowingUser ?? this.isFollowingUser,
    isNavigating: isNavigating ?? this.isNavigating,
    isStarting: isStarting ?? this.isStarting,
    route: clearRoute ? null : route ?? this.route,
    stops: stops ?? this.stops,
    locationIssue: clearLocationIssue
        ? null
        : locationIssue ?? this.locationIssue,
    locationMessage: clearLocationMessage
        ? null
        : locationMessage ?? this.locationMessage,
    progress: clearProgress ? null : progress ?? this.progress,
    isSimulatedLocation: clearSimulatedLocation
        ? false
        : isSimulatedLocation ?? this.isSimulatedLocation,
  );
}

/// Owns the foreground live-GPS lifecycle for one Safe Navigation session.
///
/// It deliberately has no map dependency so later off-route, maneuver, hazard
/// proximity, and rerouting features can consume the same state.
class NavigationSessionController extends ChangeNotifier {
  NavigationSessionController({
    required NavigationAccessCheck ensureLocationAccess,
    required NavigationPositionStream positionStream,
    NavigationReverseGeocoder? reverseGeocoder,
    this.poorAccuracyThresholdMeters = 100,
    this.geocodeDistanceMeters = 100,
    this.geocodeInterval = const Duration(minutes: 1),
    this.headingSmoothing = 0.35,
    this.stationarySpeedThreshold = 0.5,
    this.backwardNoiseToleranceMeters = 30,
    this.reverseTravelHeadingThresholdDegrees = 120,
    RouteProgressEngine progressEngine = const RouteProgressEngine(),
    DateTime Function()? now,
  }) : _ensureLocationAccess = ensureLocationAccess,
       _positionStream = positionStream,
       _reverseGeocoder = reverseGeocoder,
       _progressEngine = progressEngine,
       _now = now ?? DateTime.now;

  factory NavigationSessionController.fromLocationService(
    LocationService locationService, {
    NavigationReverseGeocoder? reverseGeocoder,
  }) => NavigationSessionController(
    ensureLocationAccess: locationService.ensureLocationAccess,
    positionStream: () =>
        locationService.watchPosition(distanceFilterMeters: 5),
    reverseGeocoder: reverseGeocoder,
  );

  final NavigationAccessCheck _ensureLocationAccess;
  final NavigationPositionStream _positionStream;
  final NavigationReverseGeocoder? _reverseGeocoder;
  final RouteProgressEngine _progressEngine;
  final DateTime Function() _now;
  final double poorAccuracyThresholdMeters;
  final double geocodeDistanceMeters;
  final Duration geocodeInterval;
  final double headingSmoothing;
  final double stationarySpeedThreshold;
  final double backwardNoiseToleranceMeters;
  final double reverseTravelHeadingThresholdDegrees;

  NavigationSessionState _state = NavigationSessionState();
  NavigationSessionState get state => _state;

  StreamSubscription<Position>? _positionSubscription;
  LatLng? _lastGeocodedPosition;
  DateTime? _lastGeocodedAt;
  bool _geocodeInFlight = false;
  bool _disposed = false;
  int _sessionGeneration = 0;
  double? _acceptedProgressMeters;
  int _minimumLegIndex = 0;
  bool _isSimulatingLocation = false;
  Position? _latestRealPosition;

  /// Whether the session is currently receiving simulated GPS positions for debugging.
  bool get isSimulatingLocation => _isSimulatingLocation;

  /// The most recent live GPS position received from the real location stream.
  @visibleForTesting
  Position? get latestRealPosition => _latestRealPosition;

  @visibleForTesting
  bool get hasActiveSubscription => _positionSubscription != null;

  Future<bool> start({
    required SafeRoute route,
    required Iterable<NavigationStop> stops,
    LatLng? initialPosition,
  }) async {
    if (_disposed || _state.isNavigating || _state.isStarting) return false;

    final generation = ++_sessionGeneration;
    _acceptedProgressMeters = null;
    _minimumLegIndex = 0;
    _isSimulatingLocation = false;
    _latestRealPosition = null;
    _setState(
      _withProgress(
        _state.copyWith(
          isStarting: true,
          route: route,
          stops: stops,
          currentPosition: initialPosition,
          clearLocationIssue: true,
          clearLocationMessage: true,
          clearSimulatedLocation: true,
        ),
        initialPosition,
      ),
    );

    try {
      await _ensureLocationAccess();
      if (_disposed || generation != _sessionGeneration) return false;

      await _positionSubscription?.cancel();
      final stream = _positionStream();
      _setState(
        _state.copyWith(
          isStarting: false,
          isNavigating: true,
          isFollowingUser: true,
          clearLocationIssue: true,
          clearLocationMessage: true,
        ),
      );
      _positionSubscription = stream.listen(
        _onPositionStreamReceived,
        onError: _handleStreamError,
        cancelOnError: false,
      );
      return true;
    } on LocationAccessException catch (error) {
      if (_disposed || generation != _sessionGeneration) return false;
      final issue = switch (error.code) {
        LocationAccessFailure.denied =>
          NavigationLocationIssue.permissionDenied,
        LocationAccessFailure.deniedForever =>
          NavigationLocationIssue.permissionDeniedForever,
        LocationAccessFailure.servicesDisabled =>
          NavigationLocationIssue.servicesDisabled,
        LocationAccessFailure.unavailable =>
          NavigationLocationIssue.temporarilyUnavailable,
      };
      _setStartFailure(issue, error.message);
      return false;
    } catch (_) {
      if (_disposed || generation != _sessionGeneration) return false;
      _setStartFailure(
        NavigationLocationIssue.temporarilyUnavailable,
        'Current GPS position is temporarily unavailable. Try again shortly.',
      );
      return false;
    }
  }

  Future<void> end() async {
    if (_disposed) return;
    _sessionGeneration++;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    _lastGeocodedPosition = null;
    _lastGeocodedAt = null;
    _geocodeInFlight = false;
    _acceptedProgressMeters = null;
    _minimumLegIndex = 0;
    _isSimulatingLocation = false;
    _latestRealPosition = null;
    _setState(NavigationSessionState(route: _state.route, stops: _state.stops));
    await subscription?.cancel();
  }

  void disableFollowing() {
    if (_state.isNavigating && _state.isFollowingUser) {
      _setState(_state.copyWith(isFollowingUser: false));
    }
  }

  void recenter() {
    if (_state.isNavigating && !_state.isFollowingUser) {
      _setState(_state.copyWith(isFollowingUser: true));
    }
  }

  /// Acknowledges an intermediate arrival before progress moves to the next leg.
  void continueToNextStop() {
    final progress = _state.progress;
    final route = _state.route;
    if (!_state.isNavigating ||
        route == null ||
        progress?.arrival != NavigationArrival.intermediateStop) {
      return;
    }
    _minimumLegIndex = math.min(
      progress!.currentLegIndex + 1,
      math.max(0, _state.stops.length - 1),
    );
    _setState(_withProgress(_state, _state.currentPosition));
  }

  /// Atomically swaps guidance after a reroute without touching the live GPS
  /// subscription, follow mode, heading, or location error state.
  bool replaceRoute({
    required SafeRoute route,
    required Iterable<NavigationStop> remainingStops,
  }) {
    if (_disposed || !_state.isNavigating || route.geometry.isEmpty) {
      return false;
    }
    final stops = List<NavigationStop>.unmodifiable(remainingStops);
    if (stops.isEmpty) return false;
    _acceptedProgressMeters = null;
    _minimumLegIndex = 0;
    _setState(
      _withProgress(
        _state.copyWith(route: route, stops: stops, clearProgress: true),
        _state.currentPosition,
        heading: _state.currentHeading,
        speed: _state.speed,
      ),
    );
    return true;
  }

  void _onPositionStreamReceived(Position position) {
    _latestRealPosition = position;
    if (_isSimulatingLocation) {
      return;
    }
    _handlePosition(position, isSimulated: false);
  }

  /// Feeds a synthetic GPS position to the navigation session for debug testing.
  ///
  /// Live GPS positions from the background location stream will continue to be
  /// tracked in [_latestRealPosition], but will not update navigation state until
  /// [restoreRealGps] is called.
  void simulatePosition(Position position) {
    if (_disposed || !_state.isNavigating) return;
    _isSimulatingLocation = true;
    _handlePosition(position, isSimulated: true);
  }

  /// Restores live GPS tracking after a debug simulation session.
  ///
  /// If a recent real position was received while simulated positions were active,
  /// it is immediately applied to navigation state.
  void restoreRealGps() {
    if (_disposed || !_state.isNavigating) return;
    _isSimulatingLocation = false;
    final realPos = _latestRealPosition;
    if (realPos != null) {
      _handlePosition(realPos, isSimulated: false);
    } else {
      _setState(_state.copyWith(clearSimulatedLocation: true));
    }
  }

  void _handlePosition(Position position, {bool isSimulated = false}) {
    if (_disposed || !_state.isNavigating) return;
    final point = LatLng(position.latitude, position.longitude);
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        position.latitude < -90 ||
        position.latitude > 90 ||
        position.longitude < -180 ||
        position.longitude > 180) {
      _setIssue(
        NavigationLocationIssue.temporarilyUnavailable,
        'Current GPS position is temporarily unavailable.',
      );
      return;
    }

    final speed = position.speed.isFinite && position.speed >= 0
        ? position.speed
        : 0.0;
    final accuracy = position.accuracy.isFinite && position.accuracy >= 0
        ? position.accuracy
        : null;
    final headingUpdate = _stableHeading(position.heading, speed);
    final hasPoorAccuracy =
        accuracy == null || accuracy > poorAccuracyThresholdMeters;

    _setState(
      _withProgress(
        _state.copyWith(
          currentPosition: point,
          currentHeading: headingUpdate.$1,
          displayHeading: headingUpdate.$2,
          speed: speed,
          accuracy: accuracy,
          clearAccuracy: accuracy == null,
          timestamp: position.timestamp,
          isSimulatedLocation: isSimulated || _isSimulatingLocation,
          locationIssue: hasPoorAccuracy
              ? NavigationLocationIssue.poorAccuracy
              : null,
          clearLocationIssue: !hasPoorAccuracy,
          locationMessage: hasPoorAccuracy
              ? 'Location accuracy is currently low.'
              : null,
          clearLocationMessage: !hasPoorAccuracy,
        ),
        point,
        heading: headingUpdate.$1,
        speed: speed,
      ),
    );
    _maybeReverseGeocode(point);
  }

  (double?, double) _stableHeading(double rawHeading, double speed) {
    final previous = _state.currentHeading;
    if (!rawHeading.isFinite || rawHeading < 0 || rawHeading > 360) {
      return (previous, _state.displayHeading);
    }

    final target = rawHeading == 360 ? 0.0 : rawHeading;
    if (previous == null) return (target, target);
    if (speed < stationarySpeedThreshold) {
      return (previous, _state.displayHeading);
    }

    final currentDisplay = _state.displayHeading;
    final normalizedDisplay = _normalizeHeading(currentDisplay);
    final delta = shortestHeadingDelta(normalizedDisplay, target);
    final smoothing = headingSmoothing.clamp(0.0, 1.0);
    return (target, currentDisplay + delta * smoothing);
  }

  @visibleForTesting
  static double shortestHeadingDelta(double from, double to) =>
      ((to - from + 540) % 360) - 180;

  static double _normalizeHeading(double heading) =>
      (heading % 360 + 360) % 360;

  NavigationSessionState _withProgress(
    NavigationSessionState base,
    LatLng? point, {
    double? heading,
    double speed = 0,
  }) {
    final route = base.route;
    if (point == null || route == null || route.geometry.isEmpty) {
      return base.copyWith(clearProgress: true);
    }
    final pendingArrival = base.progress;
    if (pendingArrival?.arrival == NavigationArrival.intermediateStop &&
        pendingArrival!.currentLegIndex == _minimumLegIndex) {
      return base.copyWith(progress: pendingArrival);
    }
    var calculated = _progressEngine.calculate(
      route: route,
      stops: base.stops,
      gps: point,
      minimumLegIndex: _minimumLegIndex,
    );
    if (calculated == null) return base.copyWith(clearProgress: true);

    final previous = _acceptedProgressMeters;
    final proposed = calculated.projection.distanceAlongGeometryMeters;
    if (previous != null && proposed < previous) {
      final backward = previous - proposed;
      final reversed =
          backward > backwardNoiseToleranceMeters &&
          speed >= stationarySpeedThreshold &&
          _headingOpposesSegment(route, calculated, heading);
      if (!reversed) {
        final guardedPoint = _pointAtDistance(route.geometry, previous);
        final guarded = _progressEngine.calculate(
          route: route,
          stops: base.stops,
          gps: guardedPoint,
          minimumLegIndex: _minimumLegIndex,
        );
        if (guarded != null) calculated = guarded;
      }
    }
    _acceptedProgressMeters = calculated.projection.distanceAlongGeometryMeters;

    final geocodedRoad =
        calculated.currentRoadName == 'Unnamed road' &&
            _usableLabel(base.currentLocationLabel) &&
            !_looksLikeCoordinates(base.currentLocationLabel!)
        ? base.currentLocationLabel!.trim()
        : null;
    if (geocodedRoad != null) {
      calculated = NavigationProgress(
        projection: calculated.projection,
        geometryProgress: calculated.geometryProgress,
        activeStepIndex: calculated.activeStepIndex,
        maneuverStepIndex: calculated.maneuverStepIndex,
        maneuver: calculated.maneuver,
        instruction: calculated.instruction,
        currentRoadName: geocodedRoad,
        distanceToManeuverMeters: calculated.distanceToManeuverMeters,
        remainingDistanceMeters: calculated.remainingDistanceMeters,
        remainingDurationSeconds: calculated.remainingDurationSeconds,
        currentLegIndex: calculated.currentLegIndex,
        nextStop: calculated.nextStop,
        finalDestination: calculated.finalDestination,
        arrival: calculated.arrival,
        isLikelyOffRoute: calculated.isLikelyOffRoute,
      );
    }
    return base.copyWith(progress: calculated);
  }

  bool _headingOpposesSegment(
    SafeRoute route,
    NavigationProgress progress,
    double? heading,
  ) {
    if (heading == null || route.geometry.length < 2) return false;
    final index = progress.projection.segmentIndex.clamp(
      0,
      route.geometry.length - 2,
    );
    final bearing = _bearing(route.geometry[index], route.geometry[index + 1]);
    return shortestHeadingDelta(bearing, heading).abs() >=
        reverseTravelHeadingThresholdDegrees;
  }

  static double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return _normalizeHeading(math.atan2(y, x) * 180 / math.pi);
  }

  static LatLng _pointAtDistance(List<LatLng> geometry, double distance) {
    final cumulative = RouteProgressEngine.cumulativeGeometryDistances(
      geometry,
    );
    if (geometry.isEmpty) return const LatLng(0, 0);
    if (distance <= 0 || geometry.length == 1) return geometry.first;
    if (distance >= cumulative.last) return geometry.last;
    for (var index = 1; index < geometry.length; index++) {
      if (cumulative[index] < distance) continue;
      final segment = cumulative[index] - cumulative[index - 1];
      final fraction = segment <= 0
          ? 0.0
          : (distance - cumulative[index - 1]) / segment;
      return LatLng(
        geometry[index - 1].latitude +
            (geometry[index].latitude - geometry[index - 1].latitude) *
                fraction,
        geometry[index - 1].longitude +
            (geometry[index].longitude - geometry[index - 1].longitude) *
                fraction,
      );
    }
    return geometry.last;
  }

  static bool _looksLikeCoordinates(String value) =>
      RegExp(r'^-?\d+\.\d+,\s*-?\d+\.\d+$').hasMatch(value.trim());

  void _maybeReverseGeocode(LatLng point) {
    final geocoder = _reverseGeocoder;
    if (geocoder == null || _geocodeInFlight) return;

    final now = _now();
    final lastPoint = _lastGeocodedPosition;
    final lastTime = _lastGeocodedAt;
    final movedEnough =
        lastPoint == null ||
        const Distance().as(LengthUnit.Meter, lastPoint, point) >=
            geocodeDistanceMeters;
    final enoughTimePassed =
        lastTime == null || now.difference(lastTime) >= geocodeInterval;
    if (!movedEnough && !enoughTimePassed) return;

    _geocodeInFlight = true;
    _lastGeocodedPosition = point;
    _lastGeocodedAt = now;
    final generation = _sessionGeneration;
    geocoder(point)
        .then((label) {
          if (_disposed ||
              generation != _sessionGeneration ||
              !_state.isNavigating) {
            return;
          }
          _setState(
            _withProgress(
              _state.copyWith(
                currentLocationLabel: _usableLabel(label)
                    ? label!.trim()
                    : _formatCoordinates(point),
              ),
              _state.currentPosition,
            ),
          );
        })
        .catchError((Object _) {
          if (_disposed ||
              generation != _sessionGeneration ||
              !_state.isNavigating) {
            return;
          }
          _setState(
            _withProgress(
              _state.copyWith(currentLocationLabel: _formatCoordinates(point)),
              _state.currentPosition,
            ),
          );
        })
        .whenComplete(() {
          if (!_disposed && generation == _sessionGeneration) {
            _geocodeInFlight = false;
          }
        });
  }

  static bool _usableLabel(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String _formatCoordinates(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

  void _handleStreamError(Object _) {
    if (_disposed || !_state.isNavigating) return;
    _setIssue(
      NavigationLocationIssue.streamError,
      'Live location was interrupted. Check GPS access and try again.',
    );
  }

  void _setStartFailure(NavigationLocationIssue issue, String message) {
    _positionSubscription = null;
    _setState(
      _state.copyWith(
        isStarting: false,
        isNavigating: false,
        isFollowingUser: false,
        locationIssue: issue,
        locationMessage: message,
      ),
    );
  }

  void _setIssue(NavigationLocationIssue issue, String message) {
    _setState(_state.copyWith(locationIssue: issue, locationMessage: message));
  }

  void _setState(NavigationSessionState value) {
    if (_disposed) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sessionGeneration++;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    unawaited(subscription?.cancel());
    super.dispose();
  }
}
