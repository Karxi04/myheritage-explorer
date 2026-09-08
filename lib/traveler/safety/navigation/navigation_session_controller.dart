import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/navigation_stop.dart';
import '../../../models/safe_route.dart';
import '../../../services/location_service.dart';

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
    DateTime Function()? now,
  }) : _ensureLocationAccess = ensureLocationAccess,
       _positionStream = positionStream,
       _reverseGeocoder = reverseGeocoder,
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
  final DateTime Function() _now;
  final double poorAccuracyThresholdMeters;
  final double geocodeDistanceMeters;
  final Duration geocodeInterval;
  final double headingSmoothing;
  final double stationarySpeedThreshold;

  NavigationSessionState _state = NavigationSessionState();
  NavigationSessionState get state => _state;

  StreamSubscription<Position>? _positionSubscription;
  LatLng? _lastGeocodedPosition;
  DateTime? _lastGeocodedAt;
  bool _geocodeInFlight = false;
  bool _disposed = false;
  int _sessionGeneration = 0;

  @visibleForTesting
  bool get hasActiveSubscription => _positionSubscription != null;

  Future<bool> start({
    required SafeRoute route,
    required Iterable<NavigationStop> stops,
    LatLng? initialPosition,
  }) async {
    if (_disposed || _state.isNavigating || _state.isStarting) return false;

    final generation = ++_sessionGeneration;
    _setState(
      _state.copyWith(
        isStarting: true,
        route: route,
        stops: stops,
        currentPosition: initialPosition,
        clearLocationIssue: true,
        clearLocationMessage: true,
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
        _handlePosition,
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

  void _handlePosition(Position position) {
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
      _state.copyWith(
        currentPosition: point,
        currentHeading: headingUpdate.$1,
        displayHeading: headingUpdate.$2,
        speed: speed,
        accuracy: accuracy,
        clearAccuracy: accuracy == null,
        timestamp: position.timestamp,
        locationIssue: hasPoorAccuracy
            ? NavigationLocationIssue.poorAccuracy
            : null,
        clearLocationIssue: !hasPoorAccuracy,
        locationMessage: hasPoorAccuracy
            ? 'Location accuracy is currently low.'
            : null,
        clearLocationMessage: !hasPoorAccuracy,
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
            _state.copyWith(
              currentLocationLabel: _usableLabel(label)
                  ? label!.trim()
                  : _formatCoordinates(point),
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
            _state.copyWith(currentLocationLabel: _formatCoordinates(point)),
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
