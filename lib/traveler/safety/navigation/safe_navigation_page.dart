import 'dart:async';
import 'dart:math' as math;

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
import 'navigation_session_controller.dart';

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
    this.hazardReports,
  });

  final SafeNavigationLocationLoader? locationLoader;
  final SafeNavigationRouteCalculator? routeCalculator;
  final SafeNavigationMultiStopCalculator? multiStopRouteCalculator;
  final SafeRoutingService? routingService;
  final PlaceGeocodingService? geocodingService;
  final LocationService? locationService;
  final NavigationSessionController? navigationController;
  final Stream<List<HazardReport>>? hazardReports;

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
  StreamSubscription<List<HazardReport>>? _hazardSubscription;

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
    _listenForHazards();
    _getCurrentLocation();
  }

  @visibleForTesting
  NavigationSessionController get navigationController => _navigationController;

  void _onNavigationChanged() {
    if (!mounted) return;
    setState(() {});
    final navigation = _navigationController.state;
    if (navigation.isFollowingUser &&
        navigation.currentPosition != _lastFollowedPosition) {
      _followCurrentPosition();
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
        setState(() {
          _activeHazards = HazardMapService.activeReports(reports);
          _hazardsLoaded = true;
          _hazardError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
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
        _status == SafeNavigationStatus.calculating) {
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
        _routingError = _routingMessage(error.code);
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
      'Safe routing is busy right now. Wait a moment and try again.',
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
    final searchController = TextEditingController();
    var searching = false;
    var searchResults = <NavigationStop>[];
    String? searchError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> doSearch() async {
            final query = searchController.text.trim();
            if (query.isEmpty) return;
            setSheetState(() {
              searching = true;
              searchError = null;
            });
            try {
              final results = await _geocodingService.searchPlaces(
                query,
                proximity: _start,
              );
              setSheetState(() {
                searching = false;
                searchResults = results;
                if (results.isEmpty) {
                  searchError = 'No places found for "$query".';
                }
              });
            } catch (e) {
              setSheetState(() {
                searching = false;
                searchError = 'Search failed. Check your connection.';
              });
            }
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.search, color: ExplorerColors.navy),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Search and Add Stop',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ExplorerColors.navy,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('safe-navigation-search-input'),
                        controller: searchController,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => doSearch(),
                        decoration: InputDecoration(
                          hintText: 'Search place name or address in Malaysia…',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const ValueKey('safe-navigation-search-submit'),
                      onPressed: searching ? null : doSearch,
                      child: searching
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Search'),
                    ),
                  ],
                ),
                if (searchError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    searchError!,
                    style: const TextStyle(
                      color: ExplorerColors.warning,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final place = searchResults[index];
                      return ListTile(
                        key: ValueKey('safe-navigation-search-result-$index'),
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: ExplorerColors.navy,
                        ),
                        title: Text(
                          place.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: place.address != null
                            ? Text(
                                place.address!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        onTap: () {
                          _addStop(place);
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _hazardSubscription?.cancel();
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
      onTap: (hazard) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${hazard.category}: ${hazard.severity} severity verified hazard',
            ),
          ),
        );
      },
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

    return Scaffold(
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
                      child: Align(
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
                              navigation.isNavigating
                                  ? 'Navigation Active · ${_formatDistance(navigation.route!.distanceMeters)} · ${_formatDuration(navigation.route!.durationSeconds)}'
                                  : _activeHazards.isEmpty
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

  Widget _buildControls(BuildContext context) {
    final route = _route;
    final navigation = _navigationController.state;
    final navigationMessage = navigation.locationMessage;
    if (navigation.isNavigating && route != null) {
      return _buildActiveNavigationControls(context, route, navigation);
    }
    final canCalculate =
        _start != null &&
        _stops.isNotEmpty &&
        _hazardsLoaded &&
        _status != SafeNavigationStatus.calculating;

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
    final point = navigation.currentPosition;
    final locationValue =
        navigation.currentLocationLabel ??
        _startPlaceName ??
        (point == null ? 'Waiting for a GPS fix…' : _formatCoordinates(point));
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
                '${_formatDistance(route.distanceMeters)} · ${_formatDuration(route.durationSeconds)}',
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
            icon: Icons.my_location,
            label: 'Current Location',
            value: locationValue,
          ),
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
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('safe-navigation-end-navigation'),
              onPressed: _endNavigation,
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
