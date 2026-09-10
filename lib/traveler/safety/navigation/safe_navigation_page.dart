import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/explorer_ui.dart';
import '../../../core/safety_config.dart';
import '../../../core/safety_error_message.dart';
import '../../../models/hazard_report.dart';
import '../../../models/navigation_stop.dart';
import '../../../models/safe_route.dart';
import '../../../services/hazard_map_service.dart';
import '../../../services/hazard_report_service.dart';
import '../../../services/location_service.dart';
import '../../../services/place_geocoding_service.dart';
import '../../../services/safe_routing_service.dart';
import 'debug_navigation_simulator.dart';
import 'destination_search_page.dart';
import 'hazard_proximity_controller.dart';
import 'navigation_session_controller.dart';
import 'reroute_coordinator.dart';
import 'route_progress_engine.dart';

typedef SafeNavigationLocationLoader = Future<Position> Function();
typedef SafeNavigationRouteCalculator =
    Future<SafeRoute> Function({
      required LatLng start,
      required LatLng destination,
      required List<HazardReport> hazards,
    });
typedef SafeNavigationMultiStopCalculator =
    Future<SafeRoute> Function({
      required LatLng start,
      required List<NavigationStop> stops,
      required List<HazardReport> hazards,
    });
typedef SafeNavigationHazardViewer =
    void Function(BuildContext context, HazardReport hazard);

enum SafeNavigationStatus {
  gettingLocation,
  waitingForDestination,
  ready,
  calculating,
  success,
  error,
}

/// Tourist-facing route preview supporting ordered multi-stop itineraries.
class SafeNavigationPage extends StatefulWidget {
  const SafeNavigationPage({
    super.key,
    this.locationLoader,
    this.routeCalculator,
    this.multiStopRouteCalculator,
    this.routingService,
    this.geocodingService,
    this.locationService,
    this.navigationController,
    this.hazardProximityController,
    this.rerouteCoordinator,
    this.hazardReports,
    this.onViewHazard,
    this.enableDebugSimulator = kDebugMode && enableNavigationDebug,
  });

  final SafeNavigationLocationLoader? locationLoader;
  final SafeNavigationRouteCalculator? routeCalculator;
  final SafeNavigationMultiStopCalculator? multiStopRouteCalculator;
  final SafeRoutingService? routingService;
  final PlaceGeocodingService? geocodingService;
  final LocationService? locationService;
  final NavigationSessionController? navigationController;
  final HazardProximityController? hazardProximityController;
  final RerouteCoordinator? rerouteCoordinator;
  final Stream<List<HazardReport>>? hazardReports;
  final SafeNavigationHazardViewer? onViewHazard;
  final bool enableDebugSimulator;

  @override
  State<SafeNavigationPage> createState() => _SafeNavigationPageState();
}

class _SafeNavigationPageState extends State<SafeNavigationPage> {
  final _mapController = fm.MapController();
  final _hazardMapService = const HazardMapService();

  late final SafeNavigationLocationLoader _loadPosition;
  late final Stream<List<HazardReport>> _hazardReports;
  SafeRoutingService? _ownedRoutingService;
  PlaceGeocodingService? _ownedGeocodingService;
  late final PlaceGeocodingService _geocodingService;
  late final NavigationSessionController _navigationController;
  late final bool _ownsNavigationController;
  late final HazardProximityController _hazardProximityController;
  late final bool _ownsHazardProximityController;
  late final RerouteCoordinator _rerouteCoordinator;
  late final bool _ownsRerouteCoordinator;
  late final DebugNavigationSimulator _debugSimulator;
  StreamSubscription<List<HazardReport>>? _hazardSubscription;
  Timer? _rateLimitTimer;

  SafeNavigationStatus _status = SafeNavigationStatus.gettingLocation;
  LatLng? _start;
  String? _startPlaceName;
  final List<NavigationStop> _stops = [];
  SafeRoute? _route;
  List<HazardReport> _activeHazards = const [];
  String? _locationError;
  String? _routingError;
  String? _hazardError;
  bool _hazardsLoaded = false;
  bool _mapReady = false;
  LatLng? _lastFollowedPosition;
  bool _showingEndConfirmation = false;
  bool _detectingNearbyHazards = false;

  @override
  void initState() {
    super.initState();
    _loadPosition =
        widget.locationLoader ?? const LocationService().getCurrentPosition;

    if (widget.geocodingService case final injectedGeocoding?) {
      _geocodingService = injectedGeocoding;
    } else {
      _ownedGeocodingService = PlaceGeocodingService();
      _geocodingService = _ownedGeocodingService!;
    }

    if (widget.routingService == null &&
        widget.routeCalculator == null &&
        widget.multiStopRouteCalculator == null) {
      _ownedRoutingService = SafeRoutingService();
    }

    _ownsNavigationController = widget.navigationController == null;
    _navigationController =
        widget.navigationController ??
        NavigationSessionController.fromLocationService(
          widget.locationService ?? const LocationService(),
          reverseGeocoder: (point) async {
            final resolved = await _geocodingService.reverseGeocode(point);
            return resolved.address?.trim().isNotEmpty == true
                ? resolved.address
                : resolved.displayName;
          },
        );
    _navigationController.addListener(_onNavigationChanged);

    _hazardReports =
        widget.hazardReports ?? HazardReportService().watchVerifiedReports();
    _ownsHazardProximityController = widget.hazardProximityController == null;
    _hazardProximityController =
        widget.hazardProximityController ??
        HazardProximityController(navigationController: _navigationController);
    _hazardProximityController.addListener(_onHazardProximityChanged);
    _ownsRerouteCoordinator = widget.rerouteCoordinator == null;
    _rerouteCoordinator =
        widget.rerouteCoordinator ??
        RerouteCoordinator(
          navigationController: _navigationController,
          calculateRoute: _calculateReroute,
        );
    _rerouteCoordinator.addListener(_onRerouteChanged);
    _debugSimulator = DebugNavigationSimulator(
      enabledOverride: widget.enableDebugSimulator,
    );
    _listenForHazards();
    _getCurrentLocation();

    if (SafeRoutingService.isRateLimited) {
      _routingError = _rateLimitedMessage(
        SafeRoutingService.rateLimitRemainingSeconds,
      );
      _startRateLimitTimer();
    }
  }

  @visibleForTesting
  NavigationSessionController get navigationController => _navigationController;

  @visibleForTesting
  RerouteCoordinator get rerouteCoordinator => _rerouteCoordinator;

  @visibleForTesting
  DebugNavigationSimulator get debugSimulator => _debugSimulator;

  void _onNavigationChanged() {
    if (!mounted) return;
    final navigation = _navigationController.state;
    setState(() {
      if (navigation.isNavigating && navigation.route != null) {
        _route = navigation.route;
      }
    });
    if (navigation.isFollowingUser &&
        navigation.currentPosition != _lastFollowedPosition) {
      _followCurrentPosition();
    }
  }

  void _onHazardProximityChanged() {
    if (mounted) setState(() {});
  }

  void _onRerouteChanged() {
    if (!mounted) return;
    setState(() {});
    if (_rerouteCoordinator.state.status == RerouteStatus.succeeded) {
      _followCurrentPosition(force: true);
    }
  }

  void _followCurrentPosition({bool force = false}) {
    final point = _navigationController.state.currentPosition;
    if (!_mapReady || point == null) return;
    _lastFollowedPosition = point;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      final distanceFromCenter = SafeRoutingService.distanceMeters(
        _mapController.camera.center,
        point,
      );
      if (force || distanceFromCenter >= 15) {
        _mapController.move(point, _mapController.camera.zoom);
      }
    });
  }

  Future<void> _startNavigation() async {
    final route = _route;
    if (route == null) return;
    final started = await _navigationController.start(
      route: route,
      stops: List<NavigationStop>.unmodifiable(_stops),
      initialPosition: _start,
    );
    if (started) _followCurrentPosition(force: true);
  }

  Future<void> _endNavigation() async {
    await _navigationController.end();
    _lastFollowedPosition = null;
  }

  Future<bool> _confirmEndNavigation(BuildContext context) async {
    if (!mounted || _showingEndConfirmation) return false;
    if (!_navigationController.state.isNavigating) return true;
    _showingEndConfirmation = true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('safe-navigation-end-confirmation-dialog'),
          title: const Text('End Navigation?'),
          content: const Text(
            'Are you sure you want to end active navigation? Your current route guidance and live tracking will stop.',
          ),
          actions: [
            TextButton(
              key: const ValueKey('safe-navigation-keep-navigating-button'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Navigating'),
            ),
            FilledButton(
              key: const ValueKey('safe-navigation-confirm-end-button'),
              style: FilledButton.styleFrom(
                backgroundColor: ExplorerColors.danger,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('End Navigation'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await _endNavigation();
        return true;
      }
      return false;
    } finally {
      _showingEndConfirmation = false;
    }
  }

  void _recenterNavigation() {
    _navigationController.recenter();
    _followCurrentPosition(force: true);
  }

  @visibleForTesting
  SafeRoutingService? get routingService =>
      widget.routingService ?? _ownedRoutingService;

  @visibleForTesting
  List<NavigationStop> get stops => List.unmodifiable(_stops);

  void _listenForHazards() {
    _hazardSubscription = _hazardReports.listen(
      (reports) {
        if (!mounted) return;
        _hazardProximityController.updateHazards(reports);
        _rerouteCoordinator.updateHazards(reports);
        setState(() {
          _activeHazards = HazardMapService.activeReports(reports);
          _hazardsLoaded = true;
          _hazardError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        _hazardProximityController.clearHazards();
        _rerouteCoordinator.updateHazards(const []);
        setState(() {
          _activeHazards = const [];
          _hazardsLoaded = false;
          _hazardError = friendlySafetyError(
            error,
            subject: 'verified hazards',
          );
        });
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _status = SafeNavigationStatus.gettingLocation;
      _locationError = null;
      _routingError = null;
      _route = null;
    });
    try {
      final position = await _loadPosition();
      if (!LocationService.isUsablePosition(position)) {
        throw const LocationAccessException(
          'Your location is not accurate enough yet. Move to an open area and retry.',
        );
      }
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _start = point;
        _status = _stops.isEmpty
            ? SafeNavigationStatus.waitingForDestination
            : SafeNavigationStatus.ready;
      });
      if (_mapReady) _mapController.move(point, 14);

      _geocodingService
          .reverseGeocode(point)
          .then((resolved) {
            if (!mounted || _start != point) return;
            setState(() {
              _startPlaceName = resolved.displayName;
            });
          })
          .catchError((_) {});
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _start = null;
        _status = SafeNavigationStatus.error;
        _locationError = friendlySafetyActionError(
          error,
          fallback:
              'Current location is unavailable. Check location access and try again.',
        );
      });
    }
  }

  void _selectDestination(LatLng point) {
    _addStopFromCoordinates(point);
  }

  void _addStopFromCoordinates(LatLng point) {
    if (!SafetyConfig.validCoordinates(point.latitude, point.longitude)) {
      return;
    }
    final stopIndex = _stops.length + 1;
    final fallbackStop = NavigationStop(
      id: 'stop_${DateTime.now().microsecondsSinceEpoch}',
      location: point,
      displayName: 'Stop $stopIndex · ${_formatCoordinates(point)}',
      isDestination: true,
    );

    setState(() {
      for (var i = 0; i < _stops.length; i++) {
        _stops[i] = _stops[i].copyWith(isDestination: false);
      }
      _stops.add(fallbackStop);
      _route = null;
      _routingError = null;
      _status = _start == null
          ? SafeNavigationStatus.gettingLocation
          : SafeNavigationStatus.ready;
    });

    final targetIndex = _stops.length - 1;
    _geocodingService
        .reverseGeocode(point)
        .then((resolved) {
          if (!mounted || targetIndex >= _stops.length) return;
          if (_stops[targetIndex].location == point) {
            setState(() {
              _stops[targetIndex] = _stops[targetIndex].copyWith(
                displayName: resolved.displayName,
                address: resolved.address,
              );
            });
          }
        })
        .catchError((_) {});
  }

  void _addStop(NavigationStop stop) {
    setState(() {
      for (var i = 0; i < _stops.length; i++) {
        _stops[i] = _stops[i].copyWith(isDestination: false);
      }
      _stops.add(stop.copyWith(isDestination: true));
      _route = null;
      _routingError = null;
      _status = _start == null
          ? SafeNavigationStatus.gettingLocation
          : SafeNavigationStatus.ready;
    });
    if (_mapReady) {
      _mapController.move(stop.location, 14);
    }
  }

  void _removeStop(int index) {
    if (index < 0 || index >= _stops.length) return;
    setState(() {
      _stops.removeAt(index);
      for (var i = 0; i < _stops.length; i++) {
        _stops[i] = _stops[i].copyWith(isDestination: i == _stops.length - 1);
      }
      _route = null;
      _routingError = null;
      if (_stops.isEmpty) {
        _status = _start == null
            ? SafeNavigationStatus.gettingLocation
            : SafeNavigationStatus.waitingForDestination;
      }
    });
  }

  void _moveStopUp(int index) {
    if (index <= 0 || index >= _stops.length) return;
    setState(() {
      final item = _stops.removeAt(index);
      _stops.insert(index - 1, item);
      for (var i = 0; i < _stops.length; i++) {
        _stops[i] = _stops[i].copyWith(isDestination: i == _stops.length - 1);
      }
      _route = null;
    });
  }

  void _moveStopDown(int index) {
    if (index < 0 || index >= _stops.length - 1) return;
    setState(() {
      final item = _stops.removeAt(index);
      _stops.insert(index + 1, item);
      for (var i = 0; i < _stops.length; i++) {
        _stops[i] = _stops[i].copyWith(isDestination: i == _stops.length - 1);
      }
      _route = null;
    });
  }

  Future<void> _findSafeRoute() async {
    final start = _start;
    if (start == null ||
        _stops.isEmpty ||
        !_hazardsLoaded ||
        _status == SafeNavigationStatus.calculating ||
        SafeRoutingService.isRateLimited) {
      return;
    }

    setState(() {
      _status = SafeNavigationStatus.calculating;
      _routingError = null;
      _route = null;
    });

    try {
      SafeRoute route;
      if (widget.multiStopRouteCalculator case final multiCalculator?) {
        route = await multiCalculator(
          start: start,
          stops: List<NavigationStop>.unmodifiable(_stops),
          hazards: List<HazardReport>.unmodifiable(_activeHazards),
        );
      } else if (widget.routeCalculator case final legacyCalculator?) {
        route = await legacyCalculator(
          start: start,
          destination: _stops.last.location,
          hazards: List<HazardReport>.unmodifiable(_activeHazards),
        );
      } else {
        final service =
            widget.routingService ??
            _ownedRoutingService ??
            SafeRoutingService();
        route = await service.calculateSafeRoute(
          start: start,
          stops: List<NavigationStop>.unmodifiable(_stops),
          hazards: List<HazardReport>.unmodifiable(_activeHazards),
        );
      }

      if (!mounted) return;
      setState(() {
        _route = route;
        _status = SafeNavigationStatus.success;
      });
      _fitRouteWhenReady(route);
    } on SafeRoutingException catch (error) {
      if (!mounted) return;
      debugPrint(
        '[SafeNavigation] routing failure: ${error.code.name} (status: ${error.statusCode})',
      );
      setState(() {
        _status = SafeNavigationStatus.error;
        if (error.code == SafeRoutingFailureCode.rateLimited) {
          final remaining = error.retryAfter?.inSeconds ??
              SafeRoutingService.rateLimitRemainingSeconds;
          _routingError = _rateLimitedMessage(remaining);
          _startRateLimitTimer();
        } else {
          _routingError = _routingMessage(error.code);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = SafeNavigationStatus.error;
        _routingError =
            'The routing service could not be reached. Check your connection and try again.';
      });
    }
  }

  void _startRateLimitTimer() {
    _rateLimitTimer?.cancel();
    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!SafeRoutingService.isRateLimited) {
        timer.cancel();
        setState(() {
          if (_routingError != null && _routingError!.contains('rate limit')) {
            _routingError = null;
            _status = SafeNavigationStatus.waitingForDestination;
          }
        });
      } else {
        setState(() {
          final remaining = SafeRoutingService.rateLimitRemainingSeconds;
          _routingError = _rateLimitedMessage(remaining);
        });
      }
    });
  }

  String _rateLimitedMessage(int seconds) {
    final s = seconds > 0 ? seconds : 1;
    return 'Route provider rate limit reached. Please wait $s second${s == 1 ? '' : 's'} before trying again.';
  }

  Future<SafeRoute> _calculateReroute({
    required LatLng start,
    required List<NavigationStop> stops,
    required List<HazardReport> hazards,
  }) async {
    if (widget.multiStopRouteCalculator case final multiCalculator?) {
      return multiCalculator(start: start, stops: stops, hazards: hazards);
    }
    final legacyCalculator = widget.routeCalculator;
    if (stops.length == 1 && legacyCalculator != null) {
      return legacyCalculator(
        start: start,
        destination: stops.single.location,
        hazards: hazards,
      );
    }
    final service =
        widget.routingService ??
        (_ownedRoutingService ??= SafeRoutingService());
    return service.calculateSafeRoute(
      start: start,
      stops: stops,
      hazards: hazards,
    );
  }

  void _fitRouteWhenReady(SafeRoute route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady || route.geometry.isEmpty) return;
      final points = <LatLng>[
        ?_start,
        ...route.geometry,
        ..._stops.map((s) => s.location),
      ];
      _mapController.fitCamera(
        fm.CameraFit.bounds(
          bounds: fm.LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(44),
        ),
      );
    });
  }

  void _chooseAnotherDestination() {
    setState(() {
      _stops.clear();
      _route = null;
      _routingError = null;
      _status = _start == null
          ? SafeNavigationStatus.gettingLocation
          : SafeNavigationStatus.waitingForDestination;
    });
  }

  // -------------------------------------------------------------------------
  // Manual "Detect Nearby Hazards" — lightweight GPS + verified hazard check.
  // Does NOT call OpenRouteService. Does NOT modify the route.
  // -------------------------------------------------------------------------
  static const double _nearbyHazardRadiusMeters = 500.0;

  Future<void> _detectNearbyHazards() async {
    // Prevent duplicate / spam clicks.
    if (_detectingNearbyHazards) return;

    setState(() => _detectingNearbyHazards = true);

    try {
      // 1. Obtain a fresh GPS position.
      Position position;
      try {
        position = await _loadPosition();
      } catch (error) {
        if (!mounted) return;
        _showDetectionError(
          friendlySafetyActionError(
            error,
            fallback:
                'Current location is unavailable. Check location permissions and try again.',
          ),
        );
        return;
      }

      // 2. Validate the position is usable.
      if (!LocationService.isUsablePosition(position)) {
        if (!mounted) return;
        _showDetectionError(
          'Your GPS position is not accurate enough to detect nearby hazards. '
          'Move to an open area and try again.',
        );
        return;
      }

      final userLocation = LatLng(position.latitude, position.longitude);

      // 3. Filter already-loaded ACTIVE VERIFIED hazards within the radius.
      //    _activeHazards is already filtered to verified + hasValidLocation
      //    by HazardMapService.activeReports in _listenForHazards().
      final List<({HazardReport hazard, double distance})> nearby = [];
      for (final hazard in _activeHazards) {
        final hazardPoint = LatLng(hazard.latitude, hazard.longitude);
        final dist = SafeRoutingService.distanceMeters(userLocation, hazardPoint);
        if (dist <= _nearbyHazardRadiusMeters) {
          nearby.add((hazard: hazard, distance: dist));
        }
      }

      // Sort nearest first.
      nearby.sort((a, b) => a.distance.compareTo(b.distance));

      if (!mounted) return;
      _showNearbyHazardsSheet(nearby);
    } finally {
      if (mounted) setState(() => _detectingNearbyHazards = false);
    }
  }

  void _showDetectionError(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.location_off_outlined,
          color: ExplorerColors.warning,
          size: 36,
        ),
        title: const Text('Location Unavailable'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNearbyHazardsSheet(
    List<({HazardReport hazard, double distance})> nearby,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _NearbyHazardsSheet(
        nearby: nearby,
        onViewHazard: (hazard) {
          Navigator.pop(sheetContext);
          _viewHazard(hazard);
        },
      ),
    );
  }

  String _routingMessage(SafeRoutingFailureCode code) => switch (code) {
    SafeRoutingFailureCode.startInsideHazard =>
      'Your current location is inside a verified hazard area. The route will first guide you out of the hazard zone.',
    SafeRoutingFailureCode.destinationInsideHazard =>
      'The selected destination is inside a verified hazard area. Choose a different destination.',
    SafeRoutingFailureCode.noRoute =>
      'No hazard-avoiding route could be found for this destination.',
    SafeRoutingFailureCode.missingApiKey =>
      'Safe routing is not configured. Launch the app with ORS_API_KEY.',
    SafeRoutingFailureCode.rateLimited =>
      'Route provider rate limit reached. Please wait a moment before trying again.',
    SafeRoutingFailureCode.timeout ||
    SafeRoutingFailureCode.networkFailure ||
    SafeRoutingFailureCode.providerUnavailable =>
      'The routing service could not be reached. Check your connection and try again.',
    SafeRoutingFailureCode.unauthorized =>
      'Safe routing authorization is unavailable. Check the ORS configuration.',
    SafeRoutingFailureCode.invalidStart =>
      'Your current location is invalid. Refresh your location and try again.',
    SafeRoutingFailureCode.invalidDestination =>
      'The selected destination is invalid. Choose another point.',
    SafeRoutingFailureCode.requestTooLarge =>
      'There are too many hazard zones to request a safe route right now.',
    SafeRoutingFailureCode.invalidRequest ||
    SafeRoutingFailureCode.malformedResponse ||
    SafeRoutingFailureCode.providerFailure =>
      'A safe route could not be calculated. Choose another destination or try again later.',
  };

  Future<void> _openSearchSheet(BuildContext context) async {
    final proximity = _navigationController.state.currentPosition ?? _start;
    final selectedStop = await Navigator.of(context).push<NavigationStop>(
      MaterialPageRoute(
        builder: (searchContext) => DestinationSearchPage(
          geocodingService: _geocodingService,
          proximity: proximity,
        ),
      ),
    );
    if (selectedStop != null && mounted) {
      _addStop(selectedStop);
    }
  }

  @override
  void dispose() {
    _rateLimitTimer?.cancel();
    _hazardSubscription?.cancel();
    _rerouteCoordinator.removeListener(_onRerouteChanged);
    if (_ownsRerouteCoordinator) _rerouteCoordinator.dispose();
    _hazardProximityController.removeListener(_onHazardProximityChanged);
    if (_ownsHazardProximityController) {
      _hazardProximityController.dispose();
    }
    _navigationController.removeListener(_onNavigationChanged);
    if (_ownsNavigationController) _navigationController.dispose();
    _ownedGeocodingService?.dispose();
    _ownedRoutingService?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigation = _navigationController.state;
    final hazardMarkers = _hazardMapService.buildHazardMarkers(
      reports: _activeHazards,
      onTap: _viewHazard,
    );
    final startMarker = navigation.isNavigating
        ? null
        : _hazardMapService.buildUserMarker(_start);
    final markers = <fm.Marker>[
      ...hazardMarkers,
      ?startMarker,
      for (var i = 0; i < _stops.length; i++)
        if (i == _stops.length - 1)
          fm.Marker(
            point: _stops[i].location,
            width: 44,
            height: 44,
            child: const Icon(
              key: ValueKey('safe-navigation-destination-marker'),
              Icons.flag_circle_rounded,
              color: ExplorerColors.danger,
              size: 38,
            ),
          )
        else
          fm.Marker(
            point: _stops[i].location,
            width: 32,
            height: 32,
            child: Container(
              key: ValueKey('safe-navigation-stop-marker-$i'),
              decoration: BoxDecoration(
                color: ExplorerColors.navy,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
      if (navigation.isNavigating && navigation.currentPosition != null)
        fm.Marker(
          point: navigation.currentPosition!,
          width: 52,
          height: 52,
          child: Transform.rotate(
            key: const ValueKey('safe-navigation-live-marker'),
            angle: navigation.displayHeading * math.pi / 180,
            child: Container(
              decoration: BoxDecoration(
                color: ExplorerColors.navy,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 7,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
    ];

    return PopScope(
      canPop: !navigation.isNavigating,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirmed = await _confirmEndNavigation(context);
        if (confirmed && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: ExplorerColors.background,
        appBar: AppBar(title: const Text('Safe Navigation')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: fm.FlutterMap(
                          key: const ValueKey('safe-navigation-map'),
                          mapController: _mapController,
                          options: fm.MapOptions(
                            initialCenter:
                                _start ?? HazardMapService.defaultCenter,
                            initialZoom: HazardMapService.defaultZoom,
                            onMapReady: () {
                              _mapReady = true;
                              final route = _route;
                              if (route != null) {
                                _fitRouteWhenReady(route);
                              } else if (_start case final start?) {
                                _mapController.move(start, 14);
                              }
                            },
                            onTap: (_, point) {
                              if (!navigation.isNavigating) {
                                _selectDestination(point);
                              }
                            },
                            onPositionChanged: (_, hasGesture) {
                              if (hasGesture && navigation.isNavigating) {
                                _navigationController.disableFollowing();
                              }
                            },
                            interactionOptions: const fm.InteractionOptions(
                              flags:
                                  fm.InteractiveFlag.all &
                                  ~fm.InteractiveFlag.rotate,
                            ),
                          ),
                          children: [
                            fm.TileLayer(
                              urlTemplate: HazardMapService.osmTileUrl,
                              userAgentPackageName: 'com.myheritage.explorer',
                            ),
                            fm.CircleLayer(
                              circles: _hazardMapService.buildDangerZoneCircles(
                                reports: _activeHazards,
                              ),
                            ),
                            if (_route case final route?)
                              fm.PolylineLayer(
                                key: const ValueKey(
                                  'safe-navigation-route-layer',
                                ),
                                polylines: [
                                  fm.Polyline(
                                    points: route.geometry,
                                    color: ExplorerColors.navy,
                                    strokeWidth: 6,
                                    borderColor: Colors.white,
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                            fm.MarkerLayer(markers: markers),
                            const fm.RichAttributionWidget(
                              alignment: fm.AttributionAlignment.bottomLeft,
                              showFlutterMapAttribution: false,
                              attributions: [
                                fm.TextSourceAttribution(
                                  'OpenStreetMap contributors',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: navigation.isNavigating
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (navigation.isSimulatedLocation) ...[
                                    _buildSimulatedGpsBadge(),
                                    const SizedBox(height: 8),
                                  ],
                                  _buildManeuverHud(navigation),
                                  if (_rerouteCoordinator.state.status !=
                                      RerouteStatus.idle) ...[
                                    const SizedBox(height: 8),
                                    _buildRerouteBanner(
                                      _rerouteCoordinator.state,
                                    ),
                                  ],
                                  if (_hazardProximityController.prominentAlert
                                      case final alert?) ...[
                                    const SizedBox(height: 8),
                                    _buildProminentHazardAlert(alert),
                                  ],
                                ],
                              )
                            : Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  color: Colors.white.withValues(alpha: .94),
                                  elevation: 2,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    child: Text(
                                      _activeHazards.isEmpty
                                          ? 'Tap the map to choose a destination'
                                          : '${_activeHazards.length} verified hazard zone${_activeHazards.length == 1 ? '' : 's'} shown',
                                      style: const TextStyle(
                                        color: ExplorerColors.navy,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      if (widget.enableDebugSimulator &&
                          navigation.isNavigating)
                        Positioned(
                          left: 14,
                          bottom: 14,
                          child: FloatingActionButton.small(
                            key: const ValueKey(
                              'safe-navigation-debug-simulator-toggle',
                            ),
                            heroTag: 'safe-navigation-debug-simulator',
                            onPressed: () => _openDebugSimulatorSheet(context),
                            backgroundColor: Colors.amber.shade800,
                            foregroundColor: Colors.white,
                            tooltip: 'GPS Simulator',
                            child: const Icon(Icons.developer_mode),
                          ),
                        ),
                      if (navigation.isNavigating)
                        Positioned(
                          right: 14,
                          bottom: 14,
                          child: FloatingActionButton.small(
                            key: const ValueKey(
                              'safe-navigation-recenter-button',
                            ),
                            heroTag: 'safe-navigation-recenter',
                            onPressed: _recenterNavigation,
                            backgroundColor: navigation.isFollowingUser
                                ? ExplorerColors.navy
                                : Colors.white,
                            foregroundColor: navigation.isFollowingUser
                                ? Colors.white
                                : ExplorerColors.navy,
                            tooltip: navigation.isFollowingUser
                                ? 'Following current location'
                                : 'Recenter and follow',
                            child: Icon(
                              navigation.isFollowingUser
                                  ? Icons.gps_fixed
                                  : Icons.gps_not_fixed,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 330),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                      child: _buildControls(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _viewHazard(HazardReport hazard) {
    _hazardProximityController.dismissProminentAlert();
    final viewer = widget.onViewHazard;
    if (viewer != null) {
      viewer(context, hazard);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hazard details are unavailable here.')),
    );
  }

  Widget _buildRerouteBanner(RerouteState reroute) {
    final failed = reroute.status == RerouteStatus.failed;
    final succeeded = reroute.status == RerouteStatus.succeeded;
    final color = failed
        ? ExplorerColors.warning
        : succeeded
        ? ExplorerColors.success
        : ExplorerColors.navy;
    return Material(
      key: const ValueKey('safe-navigation-reroute-banner'),
      color: Colors.white.withValues(alpha: .97),
      elevation: 5,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            if (reroute.isRerouting)
              SizedBox(
                key: const ValueKey('safe-navigation-rerouting-progress'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: color,
                ),
              )
            else
              Icon(
                succeeded ? Icons.check_circle_outline : Icons.warning_amber,
                color: color,
                size: 20,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reroute.message ?? 'Rerouting…',
                key: const ValueKey('safe-navigation-reroute-message'),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProminentHazardAlert(HazardProximity proximity) {
    final hazard = proximity.hazard;
    final inside = proximity.state == HazardZoneState.inside;
    final title = inside
        ? 'YOU ARE INSIDE A ${hazard.severity.toUpperCase()} SEVERITY HAZARD AREA'
        : '${hazard.severity.toUpperCase()} SEVERITY ${hazard.category.toUpperCase()} HAZARD AHEAD';
    final action = inside
        ? 'Leave the area if it is safe to do so.'
        : proximity.isOnCurrentRoute
        ? 'Hazard exposure on your current route.'
        : 'Rerouting recommended.';
    return Material(
      key: const ValueKey('safe-navigation-prominent-hazard-alert'),
      color: inside ? ExplorerColors.danger : const Color(0xFFFFF4D6),
      elevation: 7,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: inside ? Colors.white : ExplorerColors.danger,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    key: const ValueKey(
                      'safe-navigation-prominent-hazard-title',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: inside ? Colors.white : ExplorerColors.danger,
                      fontSize: 13,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hazard.category,
              style: TextStyle(
                color: inside ? Colors.white : ExplorerColors.navy,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            if (hazard.description.trim().isNotEmpty)
              Text(
                hazard.description.trim(),
                key: const ValueKey(
                  'safe-navigation-prominent-hazard-description',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: inside ? Colors.white : ExplorerColors.text,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              '${proximity.distanceMeters.round()} m away · $action',
              key: const ValueKey('safe-navigation-prominent-hazard-action'),
              style: TextStyle(
                color: inside ? Colors.white : ExplorerColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('safe-navigation-view-hazard-button'),
                  style: TextButton.styleFrom(
                    foregroundColor: inside
                        ? Colors.white
                        : ExplorerColors.navy,
                  ),
                  onPressed: () => _viewHazard(hazard),
                  child: const Text('View Hazard'),
                ),
                TextButton(
                  key: const ValueKey('safe-navigation-dismiss-hazard-button'),
                  style: TextButton.styleFrom(
                    foregroundColor: inside
                        ? Colors.white
                        : ExplorerColors.navy,
                  ),
                  onPressed: _hazardProximityController.dismissProminentAlert,
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _isStartInsideHazard {
    final start = _start;
    if (start == null || !_hazardsLoaded) return false;
    return _activeHazards.any((hazard) {
      final radius = SafetyConfig.dangerRadiusForSeverity(hazard.severity);
      final hazardPoint = LatLng(hazard.latitude, hazard.longitude);
      return SafeRoutingService.distanceMeters(start, hazardPoint) <= radius;
    });
  }

  Widget _buildManeuverHud(NavigationSessionState navigation) {
    final progress = navigation.progress;
    final isArrival = progress?.arrival != NavigationArrival.none;
    final hazard = _hazardProximityController.primaryProximity;
    return Material(
      key: const ValueKey('safe-navigation-maneuver-hud'),
      color: isArrival ? ExplorerColors.success : ExplorerColors.navy,
      elevation: 5,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _maneuverIcon(progress?.maneuver),
                  key: const ValueKey('safe-navigation-maneuver-icon'),
                  color: Colors.white,
                  size: 44,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        progress?.instruction ?? 'Continue on route',
                        key: const ValueKey('safe-navigation-next-instruction'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!isArrival) ...[
                        const SizedBox(height: 4),
                        Text(
                          progress == null
                              ? 'Waiting for a GPS fix…'
                              : _formatDistance(
                                  progress.distanceToManeuverMeters,
                                ),
                          key: const ValueKey(
                            'safe-navigation-distance-to-maneuver',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (hazard != null) ...[
              const SizedBox(height: 8),
              Container(
                key: const ValueKey(
                  'safe-navigation-persistent-hazard-indicator',
                ),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hazard.state == HazardZoneState.inside
                      ? '⚠ Inside ${hazard.hazard.severity} Hazard Area'
                      : '⚠ ${hazard.hazard.severity} Hazard Ahead',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final route = _route;
    final navigation = _navigationController.state;
    final navigationMessage = navigation.locationMessage;
    if (navigation.isNavigating && route != null) {
      return _buildActiveNavigationControls(context, route, navigation);
    }
    final isRateLimited = SafeRoutingService.isRateLimited;
    final canCalculate =
        _start != null &&
        _stops.isNotEmpty &&
        _hazardsLoaded &&
        _status != SafeNavigationStatus.calculating &&
        !isRateLimited;

    return ExplorerCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route == null
                ? 'Plan a Safe Route'
                : route.startedInsideHazard
                ? 'Escape-First Safe Route'
                : 'Safe Route',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: ExplorerColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _LocationRow(
            icon: Icons.my_location,
            label: 'Current Location',
            value: _start == null
                ? _status == SafeNavigationStatus.gettingLocation
                      ? 'Finding current location…'
                      : 'Location unavailable'
                : _startPlaceName != null
                ? '$_startPlaceName · ${_formatCoordinates(_start!)}'
                : _formatCoordinates(_start!),
          ),
          const SizedBox(height: 8),
          _LocationRow(
            icon: Icons.flag_outlined,
            label: 'Destination',
            value: _stops.isEmpty
                ? 'Tap the map to choose one destination'
                : _stops.length == 1
                ? 'Destination selected · ${_stops.first.displayName}'
                : 'Destination selected · ${_stops.length} stops (Final: ${_stops.last.displayName})',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('safe-navigation-add-stop-button'),
                  onPressed: () => _openSearchSheet(context),
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: const Text('Add Stop / Search Place'),
                ),
              ),
            ],
          ),
          if (_stops.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Stops & Waypoints (${_stops.length})',
              style: const TextStyle(
                color: ExplorerColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < _stops.length; i++) ...[
              _buildStopTile(i, _stops[i]),
              if (i < _stops.length - 1) const SizedBox(height: 4),
            ],
          ],
          if (_isStartInsideHazard && route == null) ...[
            const SizedBox(height: 10),
            const _InlineMessage(
              key: ValueKey('safe-navigation-start-inside-warning'),
              icon: Icons.warning_amber_rounded,
              message:
                  'Your current location is inside a verified hazard area. The route will first guide you out of the hazard zone.',
              color: ExplorerColors.warning,
            ),
          ],
          if (_hazardError case final error?) ...[
            const SizedBox(height: 10),
            _InlineMessage(
              key: const ValueKey('safe-navigation-hazard-error'),
              icon: Icons.cloud_off_outlined,
              message: error,
              color: ExplorerColors.warning,
            ),
          ],
          if (_locationError case final error?) ...[
            const SizedBox(height: 10),
            _InlineMessage(
              key: const ValueKey('safe-navigation-location-error'),
              icon: Icons.location_off_outlined,
              message: error,
              color: ExplorerColors.warning,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const ValueKey('safe-navigation-retry-location'),
              onPressed: _getCurrentLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Current Location'),
            ),
          ],
          if (_routingError case final error?) ...[
            const SizedBox(height: 10),
            _InlineMessage(
              key: const ValueKey('safe-navigation-routing-error'),
              icon: Icons.warning_amber_rounded,
              message: error,
              color: ExplorerColors.danger,
            ),
          ],
          if (!navigation.isNavigating && navigationMessage != null) ...[
            const SizedBox(height: 10),
            _InlineMessage(
              key: const ValueKey('safe-navigation-live-location-error'),
              icon: _navigationIssueIcon(navigation.locationIssue),
              message: navigationMessage,
              color: ExplorerColors.warning,
            ),
          ],
          if (route != null) ...[
            const SizedBox(height: 10),
            _buildRiskLevelBadge(route.riskLevel),
            if (route.startedInsideHazard) ...[
              const SizedBox(height: 10),
              const _InlineMessage(
                key: ValueKey('safe-navigation-escape-notice'),
                icon: Icons.shield_outlined,
                message:
                    'Starting inside hazard — route first exits the affected area.',
                color: ExplorerColors.warning,
              ),
            ],
            if (route.crossedHazardIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              _InlineMessage(
                key: const ValueKey('safe-navigation-crossed-warning'),
                icon: Icons.warning_amber_rounded,
                message:
                    'Route intersects ${route.crossedHazardIds.length} active hazard zone(s). Proceed with caution.',
                color: ExplorerColors.warning,
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _SummaryValue(
                  label: 'Distance',
                  value: _formatDistance(route.distanceMeters),
                ),
                _SummaryValue(
                  label: 'Estimated Time',
                  value: _formatDuration(route.durationSeconds),
                ),
                _SummaryValue(
                  label: 'Hazards Avoided',
                  value: route.startedInsideHazard
                      ? '${route.avoidedHazardIds.length} verified hazards · Escape segment included'
                      : '${route.avoidedHazardIds.length} verified hazard${route.avoidedHazardIds.length == 1 ? '' : 's'} avoided',
                ),
                if (_stops.length > 1)
                  _SummaryValue(
                    label: 'Stops',
                    value: '${_stops.length} destinations',
                  ),
              ],
            ),
            if (route.legs.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Route Legs (${route.legs.length})',
                style: const TextStyle(
                  color: ExplorerColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < route.legs.length; i++) ...[
                _buildLegTile(i, route.legs[i]),
                if (i < route.legs.length - 1) const SizedBox(height: 6),
              ],
            ],
          ],
          const SizedBox(height: 14),
          // Manual Detect Nearby Hazards button — separate from Safe Route.
          // Only checks verified hazards near GPS. Does NOT call ORS.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('safe-navigation-detect-nearby-hazards'),
              onPressed: _detectingNearbyHazards ? null : _detectNearbyHazards,
              icon: _detectingNearbyHazards
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ExplorerColors.warning,
                      ),
                    )
                  : const Icon(Icons.warning_amber_rounded),
              style: OutlinedButton.styleFrom(
                foregroundColor: ExplorerColors.warning,
                side: const BorderSide(
                  color: ExplorerColors.warning,
                ),
              ),
              label: Text(
                _detectingNearbyHazards
                    ? 'Detecting Nearby Hazards…'
                    : '⚠ Detect Nearby Hazards',
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: route == null
                ? FilledButton.icon(
                    key: const ValueKey('safe-navigation-find-route'),
                    onPressed: canCalculate ? _findSafeRoute : null,
                    icon: _status == SafeNavigationStatus.calculating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.route_outlined),
                    label: Text(
                      _status == SafeNavigationStatus.calculating
                          ? 'Calculating Safe Route…'
                          : isRateLimited
                              ? 'Rate Limited (wait ${SafeRoutingService.rateLimitRemainingSeconds}s)'
                              : 'Find Safe Route',
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('safe-navigation-start-navigation'),
                        onPressed: navigation.isStarting
                            ? null
                            : _startNavigation,
                        icon: navigation.isStarting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.navigation_rounded),
                        label: Text(
                          navigation.isStarting
                              ? 'Starting Navigation…'
                              : 'Start Navigation',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const ValueKey(
                          'safe-navigation-choose-another-destination',
                        ),
                        onPressed: navigation.isStarting
                            ? null
                            : _chooseAnotherDestination,
                        icon: const Icon(Icons.edit_location_alt_outlined),
                        label: const Text('Choose Another Destination'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveNavigationControls(
    BuildContext context,
    SafeRoute route,
    NavigationSessionState navigation,
  ) {
    final progress = navigation.progress;
    final point = navigation.currentPosition;
    final currentRoad =
        progress?.currentRoadName ??
        navigation.currentLocationLabel ??
        _startPlaceName ??
        (point == null ? 'Waiting for a GPS fix…' : 'Unnamed road');
    final remainingDistance =
        progress?.remainingDistanceMeters ?? route.distanceMeters;
    final remainingDuration =
        progress?.remainingDurationSeconds ?? route.durationSeconds;
    final nextStop =
        progress?.nextStop ??
        (navigation.stops.isEmpty ? null : navigation.stops.first);
    final finalDestination =
        progress?.finalDestination ??
        (navigation.stops.isEmpty ? null : navigation.stops.last);
    return ExplorerCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.navigation_rounded, color: ExplorerColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Navigation Active',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ExplorerColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${_formatDistance(remainingDistance)} · ${_formatDuration(remainingDuration)} ETA',
                key: const ValueKey('safe-navigation-remaining-summary'),
                style: const TextStyle(
                  color: ExplorerColors.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LocationRow(
            icon: Icons.signpost_outlined,
            label: 'Current road',
            value: currentRoad,
          ),
          const SizedBox(height: 10),
          _LocationRow(
            icon: Icons.flag_outlined,
            label: navigation.stops.length > 1 ? 'Next stop' : 'Destination',
            value: nextStop?.displayName ?? 'Destination',
          ),
          if (navigation.stops.length > 1 &&
              finalDestination != null &&
              finalDestination != nextStop) ...[
            const SizedBox(height: 8),
            _LocationRow(
              icon: Icons.sports_score_outlined,
              label: 'Final destination',
              value: finalDestination.displayName,
            ),
          ],
          const SizedBox(height: 12),
          LinearProgressIndicator(
            key: const ValueKey('safe-navigation-route-progress'),
            value: progress?.geometryProgress ?? 0,
            minHeight: 7,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: ExplorerColors.border,
            color: ExplorerColors.success,
          ),
          if (route.crossedHazardIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            const _InlineMessage(
              key: ValueKey('safe-navigation-active-hazard-warning'),
              icon: Icons.warning_amber_rounded,
              message: 'Hazard exposure on current route',
              color: ExplorerColors.warning,
            ),
          ],
          if (progress?.isLikelyOffRoute == true) ...[
            const SizedBox(height: 10),
            const _InlineMessage(
              key: ValueKey('safe-navigation-off-route-notice'),
              icon: Icons.route_outlined,
              message: 'You may be away from the planned route.',
              color: ExplorerColors.warning,
            ),
          ],
          if (navigation.accuracy case final accuracy?) ...[
            const SizedBox(height: 6),
            Text(
              'GPS accuracy: ±${accuracy.round()} m',
              key: const ValueKey('safe-navigation-gps-accuracy'),
              style: const TextStyle(color: ExplorerColors.muted, fontSize: 11),
            ),
          ],
          if (navigation.locationMessage case final message?) ...[
            const SizedBox(height: 10),
            _InlineMessage(
              key: const ValueKey('safe-navigation-live-location-error'),
              icon: _navigationIssueIcon(navigation.locationIssue),
              message: message,
              color: ExplorerColors.warning,
            ),
          ],
          if (progress?.arrival == NavigationArrival.intermediateStop) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('safe-navigation-continue-next-stop'),
                onPressed: _navigationController.continueToNextStop,
                icon: const Icon(Icons.next_plan_outlined),
                label: const Text('Continue to Next Stop'),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('safe-navigation-end-navigation'),
              onPressed: () => _confirmEndNavigation(context),
              style: FilledButton.styleFrom(
                backgroundColor: ExplorerColors.danger,
              ),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('End Navigation'),
            ),
          ),
        ],
      ),
    );
  }

  void _openDebugSimulatorSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _buildDebugSimulatorSheet(sheetContext),
    );
  }

  Widget _buildSimulatedGpsBadge() => Container(
    key: const ValueKey('safe-navigation-simulated-gps-badge'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.amber.shade900,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
      ],
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.developer_mode, size: 16, color: Colors.white),
        SizedBox(width: 6),
        Text(
          'SIMULATED GPS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),
      ],
    ),
  );

  Widget _buildDebugSimulatorSheet(BuildContext sheetContext) {
    final isSimulating = _navigationController.state.isSimulatedLocation;
    return Material(
      key: const ValueKey('safe-navigation-debug-simulator-panel'),
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.developer_mode,
                    color: Colors.amber.shade900,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPS Simulator (Debug Mode)',
                      style: TextStyle(
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (isSimulating) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SIMULATING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey(
                      'safe-navigation-simulate-on-route-button',
                    ),
                    onPressed: _simulateOnRoute,
                    icon: const Icon(Icons.navigation_outlined, size: 16),
                    label: const Text('Simulate On-Route (+25m)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.brown.shade900,
                      side: BorderSide(color: Colors.amber.shade700),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey(
                      'safe-navigation-simulate-off-route-80m-button',
                    ),
                    onPressed: _simulateOffRoute80mSingle,
                    icon: const Icon(Icons.warning_amber_rounded, size: 16),
                    label: const Text('Off-Route 80m (Suspect)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.brown.shade900,
                      side: BorderSide(color: Colors.amber.shade700),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey(
                      'safe-navigation-simulate-off-route-80m-confirmed-button',
                    ),
                    onPressed: _simulateOffRoute80mConfirmed,
                    icon: const Icon(Icons.alt_route_rounded, size: 16),
                    label: const Text('Off-Route 80m (Confirmed Reroute)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.brown.shade900,
                      side: BorderSide(color: Colors.amber.shade700),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey(
                      'safe-navigation-simulate-off-route-150m-button',
                    ),
                    onPressed: _simulateOffRoute150mConfirmed,
                    icon: const Icon(Icons.trending_up_rounded, size: 16),
                    label: const Text('Off-Route 150m (Confirmed Reroute)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.brown.shade900,
                      side: BorderSide(color: Colors.amber.shade700),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey(
                      'safe-navigation-simulate-approaching-hazard-button',
                    ),
                    onPressed: _simulateApproachingHazard,
                    icon: const Icon(Icons.crisis_alert_rounded, size: 16),
                    label: const Text('Simulate Approaching Hazard'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.brown.shade900,
                      side: BorderSide(color: Colors.amber.shade700),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey(
                      'safe-navigation-simulate-inside-hazard-button',
                    ),
                    onPressed: _simulateInsideHazard,
                    icon: const Icon(Icons.dangerous_outlined, size: 16),
                    label: const Text('Simulate Inside Hazard'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.brown.shade900,
                      side: BorderSide(color: Colors.amber.shade700),
                    ),
                  ),
                  FilledButton.icon(
                    key: const ValueKey(
                      'safe-navigation-restore-real-gps-button',
                    ),
                    onPressed: _restoreRealGps,
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Restore Real GPS'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _simulateOnRoute() {
    final result = _debugSimulator.simulateOnRoute(
      controller: _navigationController,
    );
    _showSimulatorFeedback(result.message);
  }

  void _simulateOffRoute80mSingle() {
    final result = _debugSimulator.simulateOffRouteSingle(
      controller: _navigationController,
      distanceMeters: 80.0,
    );
    _showSimulatorFeedback(result.message);
  }

  Future<void> _simulateOffRoute80mConfirmed() async {
    final result = await _debugSimulator.simulateOffRouteConfirmed(
      controller: _navigationController,
      distanceMeters: 80.0,
    );
    _showSimulatorFeedback(result.message);
  }

  Future<void> _simulateOffRoute150mConfirmed() async {
    final result = await _debugSimulator.simulateOffRouteConfirmed(
      controller: _navigationController,
      distanceMeters: 150.0,
    );
    _showSimulatorFeedback(result.message);
  }

  void _simulateApproachingHazard() {
    final result = _debugSimulator.simulateApproachingHazard(
      controller: _navigationController,
      hazards: _activeHazards,
    );
    _showSimulatorFeedback(result.message);
  }

  void _simulateInsideHazard() {
    final result = _debugSimulator.simulateInsideHazard(
      controller: _navigationController,
      hazards: _activeHazards,
    );
    _showSimulatorFeedback(result.message);
  }

  void _restoreRealGps() {
    final result = _debugSimulator.restoreRealGps(
      controller: _navigationController,
    );
    _showSimulatorFeedback(result.message);
  }

  void _showSimulatorFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  static IconData _navigationIssueIcon(NavigationLocationIssue? issue) =>
      switch (issue) {
        NavigationLocationIssue.permissionDenied ||
        NavigationLocationIssue.permissionDeniedForever =>
          Icons.location_disabled_outlined,
        NavigationLocationIssue.servicesDisabled => Icons.gps_off,
        NavigationLocationIssue.poorAccuracy => Icons.gps_not_fixed,
        NavigationLocationIssue.temporarilyUnavailable ||
        NavigationLocationIssue.streamError ||
        null => Icons.location_searching,
      };

  static IconData _maneuverIcon(NavigationManeuver? maneuver) =>
      switch (maneuver) {
        NavigationManeuver.turnLeft => Icons.turn_left_rounded,
        NavigationManeuver.turnRight => Icons.turn_right_rounded,
        NavigationManeuver.slightLeft => Icons.turn_slight_left_rounded,
        NavigationManeuver.slightRight => Icons.turn_slight_right_rounded,
        NavigationManeuver.sharpLeft => Icons.turn_sharp_left_rounded,
        NavigationManeuver.sharpRight => Icons.turn_sharp_right_rounded,
        NavigationManeuver.keepLeft => Icons.fork_left_rounded,
        NavigationManeuver.keepRight => Icons.fork_right_rounded,
        NavigationManeuver.roundabout ||
        NavigationManeuver.exitRoundabout => Icons.roundabout_right_rounded,
        NavigationManeuver.uTurn => Icons.u_turn_left_rounded,
        NavigationManeuver.arrive => Icons.flag_rounded,
        NavigationManeuver.continueStraight ||
        NavigationManeuver.depart => Icons.straight_rounded,
        NavigationManeuver.unknown || null => Icons.navigation_rounded,
      };

  Widget _buildStopTile(int index, NavigationStop stop) {
    final isLast = index == _stops.length - 1;
    return Container(
      key: ValueKey('safe-navigation-stop-item-$index'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isLast
            ? ExplorerColors.danger.withValues(alpha: 0.08)
            : ExplorerColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLast
              ? ExplorerColors.danger.withValues(alpha: 0.3)
              : ExplorerColors.navy.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: isLast
                ? ExplorerColors.danger
                : ExplorerColors.navy,
            child: Text(
              isLast ? 'D' : '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLast
                      ? 'Final Destination: ${stop.displayName}'
                      : stop.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: ExplorerColors.navy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (stop.address != null && stop.address!.isNotEmpty)
                  Text(
                    stop.address!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: ExplorerColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('safe-navigation-stop-up-$index'),
            icon: const Icon(Icons.arrow_upward, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: index > 0 ? () => _moveStopUp(index) : null,
          ),
          IconButton(
            key: ValueKey('safe-navigation-stop-down-$index'),
            icon: const Icon(Icons.arrow_downward, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: index < _stops.length - 1
                ? () => _moveStopDown(index)
                : null,
          ),
          IconButton(
            key: ValueKey('safe-navigation-stop-remove-$index'),
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: ExplorerColors.danger,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => _removeStop(index),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskLevelBadge(RouteRiskLevel level) {
    final (color, icon, text) = switch (level) {
      RouteRiskLevel.hazardFree => (
        Colors.green.shade700,
        Icons.check_circle_outline,
        'Level 1: Hazard-Free (All hazards avoided)',
      ),
      RouteRiskLevel.lowRisk => (
        Colors.amber.shade800,
        Icons.info_outline,
        'Level 2: Low-Risk Fallback (Low-severity hazard crossed)',
      ),
      RouteRiskLevel.moderateRisk => (
        Colors.orange.shade800,
        Icons.warning_amber_rounded,
        'Level 3: Moderate-Risk Fallback (Moderate-severity hazard crossed)',
      ),
      RouteRiskLevel.unavoidableExposure => (
        ExplorerColors.danger,
        Icons.dangerous_outlined,
        'Level 4: Direct Route (Hazard exposure unavoidable)',
      ),
    };

    return Container(
      key: const ValueKey('safe-navigation-risk-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegTile(int index, RouteLeg leg) {
    return Container(
      key: ValueKey('safe-navigation-leg-$index'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ExplorerColors.navy.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: ExplorerColors.navy,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Leg ${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${leg.startStopName} → ${leg.endStopName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: ExplorerColors.navy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDistance(leg.distanceMeters)} · ${_formatDuration(leg.durationSeconds)} · ${leg.steps.length} step${leg.steps.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ExplorerColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCoordinates(LatLng point) =>
      '${point.latitude.toStringAsFixed(5)}, '
      '${point.longitude.toStringAsFixed(5)}';

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String _formatDuration(double seconds) {
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '$hours hr' : '$hours hr $remainder min';
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: ExplorerColors.navy),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: ExplorerColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(color: ExplorerColors.text, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    super.key,
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: .38)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: ExplorerColors.text,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 110),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ExplorerColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: ExplorerColors.navy,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Nearby Hazards Result Sheet — shown after manual Detect Nearby Hazards.
// ---------------------------------------------------------------------------

class _NearbyHazardsSheet extends StatelessWidget {
  const _NearbyHazardsSheet({
    required this.nearby,
    required this.onViewHazard,
  });

  final List<({HazardReport hazard, double distance})> nearby;
  final void Function(HazardReport) onViewHazard;

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  Color _severityColor(String severity) => switch (severity.toLowerCase()) {
    'high' => ExplorerColors.danger,
    'medium' => ExplorerColors.warning,
    _ => ExplorerColors.navy,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('nearby-hazards-sheet'),
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ExplorerColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.radar_outlined,
                    color: ExplorerColors.navy,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nearby Hazards Detected',
                          style: TextStyle(
                            color: ExplorerColors.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          nearby.isEmpty
                              ? 'No nearby verified hazards detected.'
                              : '${nearby.length} active hazard${nearby.length == 1 ? '' : 's'} found nearby',
                          style: const TextStyle(
                            color: ExplorerColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            // Result list (scrollable if many hazards)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: nearby.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 44,
                            color: ExplorerColors.muted,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No known verified hazard was detected within 500 m of your current position.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ExplorerColors.text,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'This only reflects currently verified hazard reports in the system.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: nearby.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = nearby[index];
                        final hazard = entry.hazard;
                        final dist = entry.distance;
                        final color = _severityColor(hazard.severity);
                        return Container(
                          key: ValueKey(
                            'nearby-hazard-item-${hazard.id}',
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${hazard.severity} — ${hazard.category}',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDistance(dist),
                                      style: const TextStyle(
                                        color: ExplorerColors.text,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (hazard.description.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        hazard.description.trim(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: ExplorerColors.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              TextButton(
                                key: ValueKey(
                                  'nearby-hazard-view-${hazard.id}',
                                ),
                                onPressed: () => onViewHazard(hazard),
                                style: TextButton.styleFrom(
                                  foregroundColor: ExplorerColors.navy,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                child: const Text(
                                  'View Details',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
