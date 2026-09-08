part of '../traveler_pages.dart';

class _RouteInstruction {
  const _RouteInstruction({
    required this.text,
    required this.distance,
    required this.type,
  });

  final String text;
  final double distance;
  final String type;
}

class RouteGuidancePage extends StatefulWidget {
  const RouteGuidancePage({
    super.key,
    required this.senderId,
    required this.senderName,
    required this.alertId,
    required this.targetLat,
    required this.targetLng,
  });

  final String senderId;
  final String senderName;
  final String alertId;
  final double targetLat;
  final double targetLng;

  @override
  State<RouteGuidancePage> createState() =>
      _RouteGuidancePageState();
}

class _RouteGuidancePageState
    extends State<RouteGuidancePage> {
  GoogleMapController? _mapController;

  Position? _myPosition;

  Position? _lastRouteOrigin;

  StreamSubscription<Position>?
  _positionStream;

  // ============================================================
  // ROUTE DATA
  // ============================================================

  List<LatLng> _routePoints =
  <LatLng>[];

  List<_RouteInstruction>
  _instructions =
  <_RouteInstruction>[];

  double _distance = 0;

  int _minutes = 0;

  bool _routeLoading = false;

  String? _routeError;

  bool _resolvingSos = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _startTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();

    _mapController?.dispose();

    super.dispose();
  }

  // ============================================================
  // GPS TRACKING
  // ============================================================

  Future<void> _startTracking() async {
    try {
      final initialPosition =
      await determinePosition();

      if (!mounted) return;

      setState(() {
        _myPosition =
            initialPosition;
      });

      await _loadWalkingRoute(
        initialPosition,
      );

      _positionStream =
          Geolocator.getPositionStream(
            locationSettings:
            const LocationSettings(
              accuracy:
              LocationAccuracy.high,

              // Update after leader moves 10m.
              distanceFilter:
              10,
            ),
          ).listen(
                (position) async {
              if (!mounted) return;

              setState(() {
                _myPosition =
                    position;
              });

              // Only request a new route after
              // leader has moved significantly.
              if (_shouldRefreshRoute(
                position,
              )) {
                await _loadWalkingRoute(
                  position,
                );
              }
            },
            onError: (error) {
              debugPrint(
                'Route GPS stream error: $error',
              );
            },
          );
    } catch (error) {
      debugPrint(
        'Unable to get leader location: $error',
      );

      if (mounted) {
        showMessage(
          context,
          error
              .toString()
              .replaceFirst(
            'Exception: ',
            '',
          ),
          error: true,
        );
      }
    }
  }

  // ============================================================
  // SHOULD RECALCULATE ROUTE?
  //
  // Do not call routing API for every tiny GPS movement.
  // Recalculate only after about 25 metres.
  // ============================================================

  bool _shouldRefreshRoute(
      Position position,
      ) {
    final last =
        _lastRouteOrigin;

    if (last == null) {
      return true;
    }

    final moved =
    Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      position.latitude,
      position.longitude,
    );

    return moved >= 25;
  }

  // ============================================================
  // LOAD REAL WALKING ROUTE
  // ============================================================

  Future<void> _loadWalkingRoute(
      Position origin,
      ) async {
    if (_routeLoading) {
      return;
    }

    if (!GeoapifyConfig.isConfigured) {
      _useStraightLineFallback(
        origin,
        'Routing service is not configured.',
      );

      return;
    }

    setState(() {
      _routeLoading = true;

      _routeError = null;
    });

    try {
      // ----------------------------------------------------------
      // GEOAPIFY ROUTING API
      //
      // waypoints:
      // leader latitude,longitude
      // member latitude,longitude
      //
      // mode = walk
      // ----------------------------------------------------------

      final uri =
      Uri.https(
        'api.geoapify.com',
        '/v1/routing',
        {
          'waypoints':
          '${origin.latitude},${origin.longitude}'
              '|${widget.targetLat},${widget.targetLng}',

          'mode':
          'walk',

          'details':
          'instruction_details',

          'lang':
          'en',

          'apiKey':
          GeoapifyConfig.apiKey,
        },
      );

      final response =
      await http
          .get(
        uri,
      )
          .timeout(
        const Duration(
          seconds: 15,
        ),
      );

      if (response.statusCode !=
          200) {
        throw Exception(
          'Routing request failed '
              '(${response.statusCode}).',
        );
      }

      final decoded =
      jsonDecode(
        response.body,
      );

      if (decoded is! Map) {
        throw Exception(
          'Invalid routing response.',
        );
      }

      final data =
      Map<String, dynamic>.from(
        decoded,
      );

      final features =
      data['features'];

      if (features is! List ||
          features.isEmpty) {
        throw Exception(
          'No walking route was found.',
        );
      }

      final firstFeature =
          features.first;

      if (firstFeature is! Map) {
        throw Exception(
          'Invalid route information.',
        );
      }

      final feature =
      Map<String, dynamic>.from(
        firstFeature,
      );

      // ==========================================================
      // PARSE ROUTE GEOMETRY
      //
      // GeoJSON uses:
      // [longitude, latitude]
      //
      // Google Maps uses:
      // LatLng(latitude, longitude)
      // ==========================================================

      final geometry =
      feature['geometry'];

      if (geometry is! Map) {
        throw Exception(
          'Route geometry is unavailable.',
        );
      }

      final geometryMap =
      Map<String, dynamic>.from(
        geometry,
      );

      final coordinates =
      geometryMap['coordinates'];

      final points =
      <LatLng>[];

      if (coordinates is List) {
        // Geoapify returns MultiLineString.
        //
        // [
        //   [
        //     [lng, lat],
        //     [lng, lat],
        //     ...
        //   ]
        // ]

        for (final line
        in coordinates) {
          if (line is! List) {
            continue;
          }

          for (final coordinate
          in line) {
            if (coordinate
            is! List ||
                coordinate.length <
                    2) {
              continue;
            }

            final longitude =
            coordinate[0];

            final latitude =
            coordinate[1];

            if (latitude is num &&
                longitude is num) {
              points.add(
                LatLng(
                  latitude
                      .toDouble(),
                  longitude
                      .toDouble(),
                ),
              );
            }
          }
        }
      }

      if (points.length <
          2) {
        throw Exception(
          'Walking route geometry is empty.',
        );
      }

      // ==========================================================
      // ROUTE INFORMATION
      // ==========================================================

      final properties =
      feature['properties'];

      final propertyMap =
      properties is Map
          ? Map<String, dynamic>
          .from(
        properties,
      )
          : <String, dynamic>{};

      final routeDistance =
      (propertyMap['distance']
      as num?)
          ?.toDouble();

      final routeTime =
      (propertyMap['time']
      as num?)
          ?.toDouble();

      // ==========================================================
      // TURN-BY-TURN DIRECTIONS
      // ==========================================================

      final instructions =
      <_RouteInstruction>[];

      final legs =
      propertyMap['legs'];

      if (legs is List) {
        for (final leg
        in legs) {
          if (leg is! Map) {
            continue;
          }

          final legData =
          Map<String, dynamic>.from(
            leg,
          );

          final steps =
          legData['steps'];

          if (steps is! List) {
            continue;
          }

          for (final step
          in steps) {
            if (step is! Map) {
              continue;
            }

            final stepData =
            Map<String, dynamic>.from(
              step,
            );

            final instruction =
            stepData[
            'instruction'];

            if (instruction
            is! Map) {
              continue;
            }

            final instructionData =
            Map<String,
                dynamic>.from(
              instruction,
            );

            final text =
            '${instructionData['text'] ?? ''}'
                .trim();

            if (text.isEmpty) {
              continue;
            }

            instructions.add(
              _RouteInstruction(
                text: text,

                distance:
                (stepData[
                'distance']
                as num?)
                    ?.toDouble() ??
                    0,

                type:
                '${instructionData['type'] ?? ''}',
              ),
            );
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _routePoints =
            points;

        _instructions =
            instructions;

        _lastRouteOrigin =
            origin;

        // Real walking distance from route.
        _distance =
            routeDistance ??
                _calculatePolylineDistance(
                  points,
                );

        // Real walking ETA from API.
        if (routeTime !=
            null) {
          _minutes =
              (routeTime / 60)
                  .ceil();
        } else {
          _minutes =
              (_distance / 75)
                  .ceil();
        }

        _routeError =
        null;
      });

      await _fitRoute();
    } catch (error) {
      debugPrint(
        'Walking route error: $error',
      );

      _useStraightLineFallback(
        origin,
        error
            .toString()
            .replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _routeLoading =
          false;
        });
      }
    }
  }

  // ============================================================
  // ROUTE DISTANCE FALLBACK
  // ============================================================

  double _calculatePolylineDistance(
      List<LatLng> points,
      ) {
    double total = 0;

    for (var index = 0;
    index <
        points.length - 1;
    index++) {
      total +=
          Geolocator.distanceBetween(
            points[index].latitude,
            points[index].longitude,
            points[index + 1]
                .latitude,
            points[index + 1]
                .longitude,
          );
    }

    return total;
  }

  // ============================================================
  // FALLBACK
  //
  // If routing API is unavailable, retain the old straight-line
  // behavior instead of making the emergency page unusable.
  // ============================================================

  void _useStraightLineFallback(
      Position origin,
      String reason,
      ) {
    final start =
    LatLng(
      origin.latitude,
      origin.longitude,
    );

    final end =
    LatLng(
      widget.targetLat,
      widget.targetLng,
    );

    final distance =
    Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      widget.targetLat,
      widget.targetLng,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _routePoints = [
        start,
        end,
      ];

      _instructions =
      <_RouteInstruction>[];

      _distance =
          distance;

      _minutes =
          (distance / 75)
              .ceil();

      _routeError =
          reason;

      _lastRouteOrigin =
          origin;
    });

    _fitRoute();
  }

  // ============================================================
  // FIT CAMERA TO WHOLE ROUTE
  // ============================================================

  Future<void> _fitRoute() async {
    final controller =
        _mapController;

    if (controller == null) {
      return;
    }

    final points =
        _routePoints;

    if (points.isEmpty) {
      return;
    }

    if (points.length == 1) {
      await controller
          .animateCamera(
        CameraUpdate
            .newLatLngZoom(
          points.first,
          17,
        ),
      );

      return;
    }

    var minLat =
        points.first.latitude;

    var maxLat =
        points.first.latitude;

    var minLng =
        points.first.longitude;

    var maxLng =
        points.first.longitude;

    for (final point
    in points) {
      minLat =
          min(
            minLat,
            point.latitude,
          );

      maxLat =
          max(
            maxLat,
            point.latitude,
          );

      minLng =
          min(
            minLng,
            point.longitude,
          );

      maxLng =
          max(
            maxLng,
            point.longitude,
          );
    }

    if (minLat == maxLat &&
        minLng == maxLng) {
      await controller
          .animateCamera(
        CameraUpdate
            .newLatLngZoom(
          points.first,
          17,
        ),
      );

      return;
    }

    await controller
        .animateCamera(
      CameraUpdate
          .newLatLngBounds(
        LatLngBounds(
          southwest:
          LatLng(
            minLat,
            minLng,
          ),
          northeast:
          LatLng(
            maxLat,
            maxLng,
          ),
        ),
        80,
      ),
    );
  }

  // ============================================================
  // FORMAT DISTANCE
  // ============================================================

  String _formatDistance(
      double distance,
      ) {
    if (distance <
        1000) {
      return '${distance.round()} m';
    }

    return '${(distance / 1000).toStringAsFixed(2)} km';
  }

  // ============================================================
  // DIRECTION ICON
  // ============================================================

  IconData _instructionIcon(
      String type,
      ) {
    final value =
    type.toLowerCase();

    if (value.contains(
      'slightleft',
    ) ||
        value == 'left' ||
        value.contains(
          'sharpleft',
        )) {
      return Icons
          .turn_left_rounded;
    }

    if (value.contains(
      'slightright',
    ) ||
        value == 'right' ||
        value.contains(
          'sharpright',
        )) {
      return Icons
          .turn_right_rounded;
    }

    if (value.contains(
      'roundabout',
    )) {
      return Icons
          .roundabout_left;
    }

    if (value.contains(
      'destination',
    )) {
      return Icons
          .location_on_rounded;
    }

    if (value.contains(
      'start',
    )) {
      return Icons
          .directions_walk_rounded;
    }

    if (value.contains(
      'straight',
    )) {
      return Icons
          .straight_rounded;
    }

    if (value.contains(
      'merge',
    )) {
      return Icons
          .merge_rounded;
    }

    return Icons
        .navigation_outlined;
  }

  // ============================================================
  // SHOW TURN-BY-TURN DIRECTIONS
  // ============================================================

  Future<void>
  _showDirections() async {
    if (_instructions.isEmpty) {
      showMessage(
        context,
        _routeError != null
            ? 'Turn-by-turn directions are unavailable because the routing service could not calculate a route.'
            : 'Directions are still being calculated.',
        error:
        _routeError !=
            null,
      );

      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled:
      true,
      backgroundColor:
      Colors.transparent,

      builder: (
          sheetContext,
          ) {
        return DraggableScrollableSheet(
          initialChildSize:
          .62,

          minChildSize:
          .38,

          maxChildSize:
          .90,

          expand:
          false,

          builder: (
              context,
              scrollController,
              ) {
            return Container(
              decoration:
              const BoxDecoration(
                color:
                ExplorerColors
                    .background,

                borderRadius:
                BorderRadius.vertical(
                  top:
                  Radius.circular(
                    22,
                  ),
                ),
              ),

              child: Column(
                children: [
                  const SizedBox(
                    height:
                    10,
                  ),

                  Container(
                    width:
                    42,
                    height:
                    4,
                    decoration:
                    BoxDecoration(
                      color:
                      ExplorerColors
                          .border,

                      borderRadius:
                      BorderRadius
                          .circular(
                        20,
                      ),
                    ),
                  ),

                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(
                      18,
                      18,
                      18,
                      14,
                    ),
                    child:
                    Row(
                      children: [
                        Container(
                          width:
                          44,
                          height:
                          44,
                          decoration:
                          BoxDecoration(
                            color:
                            ExplorerColors
                                .navySoft,

                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),
                          child:
                          const Icon(
                            Icons
                                .directions_walk_rounded,

                            color:
                            ExplorerColors
                                .navy,
                          ),
                        ),

                        const SizedBox(
                          width:
                          12,
                        ),

                        Expanded(
                          child:
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                            children: [
                              Text(
                                'Directions to ${widget.senderName}',
                                style:
                                const TextStyle(
                                  color:
                                  ExplorerColors
                                      .navy,

                                  fontSize:
                                  17,

                                  fontWeight:
                                  FontWeight
                                      .w900,
                                ),
                              ),

                              const SizedBox(
                                height:
                                3,
                              ),

                              Text(
                                '${_formatDistance(_distance)} • Approx. $_minutes min walk',
                                style:
                                const TextStyle(
                                  color:
                                  ExplorerColors
                                      .muted,

                                  fontSize:
                                  10,
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          onPressed:
                              () =>
                              Navigator.pop(
                                sheetContext,
                              ),
                          icon:
                          const Icon(
                            Icons.close,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(
                    height:
                    1,
                  ),

                  Expanded(
                    child:
                    ListView.separated(
                      controller:
                      scrollController,

                      padding:
                      const EdgeInsets.all(
                        16,
                      ),

                      itemCount:
                      _instructions.length,

                      separatorBuilder:
                          (
                          _,
                          __,
                          ) =>
                      const Divider(
                        height:
                        20,
                      ),

                      itemBuilder:
                          (
                          context,
                          index,
                          ) {
                        final instruction =
                        _instructions[
                        index];

                        return Row(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                          children: [
                            Container(
                              width:
                              42,
                              height:
                              42,
                              decoration:
                              BoxDecoration(
                                color:
                                index ==
                                    _instructions.length -
                                        1
                                    ? ExplorerColors
                                    .dangerSoft
                                    : ExplorerColors
                                    .navySoft,

                                borderRadius:
                                BorderRadius
                                    .circular(
                                  12,
                                ),
                              ),

                              child:
                              Icon(
                                _instructionIcon(
                                  instruction.type,
                                ),

                                color:
                                index ==
                                    _instructions.length -
                                        1
                                    ? ExplorerColors
                                    .danger
                                    : ExplorerColors
                                    .navy,

                                size:
                                22,
                              ),
                            ),

                            const SizedBox(
                              width:
                              12,
                            ),

                            Expanded(
                              child:
                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                                children: [
                                  Text(
                                    instruction.text,

                                    style:
                                    const TextStyle(
                                      color:
                                      ExplorerColors
                                          .text,

                                      fontSize:
                                      13,

                                      fontWeight:
                                      FontWeight
                                          .w700,

                                      height:
                                      1.4,
                                    ),
                                  ),

                                  if (instruction
                                      .distance >
                                      0) ...[
                                    const SizedBox(
                                      height:
                                      4,
                                    ),

                                    Text(
                                      _formatDistance(
                                        instruction.distance,
                                      ),

                                      style:
                                      const TextStyle(
                                        color:
                                        ExplorerColors
                                            .muted,

                                        fontSize:
                                        10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // FOUND COMPANION
  // ============================================================

  Future<void>
  _foundCompanion() async {
    if (_resolvingSos) {
      return;
    }

    setState(() {
      _resolvingSos =
      true;
    });

    try {
      final currentUser =
          AppServices
              .auth.currentUser;

      if (currentUser ==
          null) {
        throw Exception(
          'Please sign in first.',
        );
      }

      final alertRef =
      AppServices.db
          .collection(
        'sos_alerts',
      )
          .doc(
        widget.alertId,
      );

      final alertSnapshot =
      await alertRef
          .get();

      if (!alertSnapshot
          .exists) {
        throw Exception(
          'SOS alert could not be found.',
        );
      }

      final alert =
          alertSnapshot
              .data() ??
              const <
                  String,
                  dynamic>{};

      final groupId =
          '${alert['groupId'] ?? ''}';

      final senderId =
          '${alert['senderId'] ?? widget.senderId}';

      final batch =
      AppServices.db
          .batch();

      // ----------------------------------------------------------
      // Resolve SOS
      // ----------------------------------------------------------

      batch.update(
        alertRef,
        {
          'status':
          'resolved',

          'resolvedAt':
          FieldValue
              .serverTimestamp(),

          'resolvedBy':
          currentUser.uid,
        },
      );

      // ----------------------------------------------------------
      // Remove SOS marker state
      // ----------------------------------------------------------

      if (groupId.isNotEmpty &&
          senderId.isNotEmpty) {
        final locationRef =
        AppServices.db
            .collection(
          'travel_groups',
        )
            .doc(
          groupId,
        )
            .collection(
          'locations',
        )
            .doc(
          senderId,
        );

        batch.set(
          locationRef,
          {
            'sosActive':
            false,

            'updatedAt':
            FieldValue
                .serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );
      }

      await batch.commit();

      // ----------------------------------------------------------
      // Notify member
      // ----------------------------------------------------------

      if (senderId.isNotEmpty) {
        try {
          await AppServices.notify(
            userId: senderId,
            title: 'SOS resolved',
            message:
            'Your group leader found you and marked the SOS alert as resolved.',
            type: 'sos_resolved',
            referenceId: widget.alertId,
            groupId: groupId.isNotEmpty ? groupId : null,
          );
        } catch (error) {
          debugPrint(
            'Unable to send SOS resolved notification: $error',
          );
        }
      }

    if (!mounted) {
    return;
    }

    showMessage(
    context,
    'SOS resolved successfully.',
    );

    Navigator.pop(
    context,
    );
    } catch (error) {
    if (mounted) {
    showMessage(
    context,
    error
        .toString()
        .replaceFirst(
    'Exception: ',
    '',
    ),
    error: true,
    );
    }
    } finally {
    if (mounted) {
    setState(() {
    _resolvingSos =
    false;
    });
    }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final targetPos =
    LatLng(
      widget.targetLat,
      widget.targetLng,
    );

    final myPos =
    _myPosition != null
        ? LatLng(
      _myPosition!
          .latitude,
      _myPosition!
          .longitude,
    )
        : null;

    // ==========================================================
    // MARKERS
    // ==========================================================

    final markers =
    <Marker>{
      Marker(
        markerId:
        const MarkerId(
          'target',
        ),

        position:
        targetPos,

        icon:
        BitmapDescriptor
            .defaultMarkerWithHue(
          BitmapDescriptor
              .hueRed,
        ),

        infoWindow:
        InfoWindow(
          title:
          widget.senderName,

          snippet:
          'Emergency SOS location',
        ),
      ),

      if (myPos != null)
        Marker(
          markerId:
          const MarkerId(
            'me',
          ),

          position:
          myPos,

          icon:
          BitmapDescriptor
              .defaultMarkerWithHue(
            BitmapDescriptor
                .hueAzure,
          ),

          infoWindow:
          const InfoWindow(
            title:
            'Your Location',
          ),
        ),
    };

    // ==========================================================
    // REAL ROUTE POLYLINE
    // ==========================================================

    final polylines =
    <Polyline>{
      if (_routePoints.length >=
          2)
        Polyline(
          polylineId:
          const PolylineId(
            'walking_route',
          ),

          points:
          _routePoints,

          color:
          _routeError ==
              null
              ? ExplorerColors
              .navy
              : ExplorerColors
              .danger,

          width:
          6,

          startCap:
          Cap.roundCap,

          endCap:
          Cap.roundCap,

          jointType:
          JointType.round,

          geodesic:
          false,

          // Straight fallback remains dashed.
          patterns:
          _routeError !=
              null
              ? [
            PatternItem.dash(
              18,
            ),
            PatternItem.gap(
              10,
            ),
          ]
              : <PatternItem>[],
        ),
    };

    return Scaffold(
      appBar:
      AppBar(
        title:
        Text(
          'Finding ${widget.senderName}',
        ),

        actions: [
          IconButton(
            tooltip:
            'Fit route',

            onPressed:
            _fitRoute,

            icon:
            const Icon(
              Icons
                  .center_focus_strong_outlined,
            ),
          ),
        ],
      ),

      body:
      Stack(
        children: [
          // ======================================================
          // MAP
          // ======================================================

          GoogleMap(
            initialCameraPosition:
            CameraPosition(
              target:
              targetPos,

              zoom:
              16,
            ),

            markers:
            markers,

            polylines:
            polylines,

            myLocationEnabled:
            true,

            myLocationButtonEnabled:
            true,

            zoomControlsEnabled:
            false,

            mapToolbarEnabled:
            false,

            onMapCreated:
                (
                controller,
                ) {
              _mapController =
                  controller;

              WidgetsBinding
                  .instance
                  .addPostFrameCallback(
                    (_) {
                  _fitRoute();
                },
              );
            },
          ),

          // ======================================================
          // ROUTE LOADING
          // ======================================================

          if (_routeLoading)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal:
                  14,
                  vertical:
                  10,
                ),

                decoration:
                BoxDecoration(
                  color:
                  Colors.white,

                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),

                  boxShadow:
                  const [
                    BoxShadow(
                      color:
                      Color(
                        0x1A101828,
                      ),
                      blurRadius:
                      12,
                      offset:
                      Offset(
                        0,
                        4,
                      ),
                    ),
                  ],
                ),

                child:
                const Row(
                  children: [
                    SizedBox(
                      width:
                      18,
                      height:
                      18,
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2,
                      ),
                    ),

                    SizedBox(
                      width:
                      10,
                    ),

                    Expanded(
                      child:
                      Text(
                        'Calculating walking route...',
                        style:
                        TextStyle(
                          color:
                          ExplorerColors
                              .navy,

                          fontWeight:
                          FontWeight
                              .w700,

                          fontSize:
                          11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ======================================================
          // ROUTE INFORMATION
          // ======================================================

          if (!_routeLoading)
            Positioned(
              top: 16,
              left: 16,
              right: 16,

              child:
              ExplorerCard(
                backgroundColor:
                ExplorerColors
                    .navy,

                radius:
                16,

                child:
                Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width:
                          44,
                          height:
                          44,

                          decoration:
                          BoxDecoration(
                            color:
                            Colors.white
                                .withValues(
                              alpha:
                              .10,
                            ),

                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),

                          child:
                          const Icon(
                            Icons
                                .directions_walk_rounded,

                            color:
                            ExplorerColors
                                .gold,

                            size:
                            24,
                          ),
                        ),

                        const SizedBox(
                          width:
                          12,
                        ),

                        Expanded(
                          child:
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                            children: [
                              Text(
                                _myPosition ==
                                    null
                                    ? 'Getting your location...'
                                    : _formatDistance(
                                  _distance,
                                ),

                                style:
                                const TextStyle(
                                  color:
                                  Colors.white,

                                  fontSize:
                                  20,

                                  fontWeight:
                                  FontWeight
                                      .w900,
                                ),
                              ),

                              const SizedBox(
                                height:
                                2,
                              ),

                              Text(
                                _routeError ==
                                    null
                                    ? 'Approx. $_minutes min walk • Walking route'
                                    : 'Approx. $_minutes min • Direct-distance fallback',

                                style:
                                TextStyle(
                                  color:
                                  Colors.white
                                      .withValues(
                                    alpha:
                                    .72,
                                  ),

                                  fontSize:
                                  10,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_routeError ==
                            null)
                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal:
                              8,
                              vertical:
                              5,
                            ),
                            decoration:
                            BoxDecoration(
                              color:
                              ExplorerColors
                                  .gold,

                              borderRadius:
                              BorderRadius
                                  .circular(
                                20,
                              ),
                            ),
                            child:
                            const Text(
                              'ROUTE',
                              style:
                              TextStyle(
                                color:
                                ExplorerColors
                                    .navy,

                                fontSize:
                                8,

                                fontWeight:
                                FontWeight
                                    .w900,
                              ),
                            ),
                          ),
                      ],
                    ),

                    if (_routeError !=
                        null) ...[
                      const SizedBox(
                        height:
                        10,
                      ),

                      Container(
                        width:
                        double.infinity,

                        padding:
                        const EdgeInsets.all(
                          9,
                        ),

                        decoration:
                        BoxDecoration(
                          color:
                          Colors.white
                              .withValues(
                            alpha:
                            .08,
                          ),

                          borderRadius:
                          BorderRadius
                              .circular(
                            9,
                          ),
                        ),

                        child:
                        Text(
                          'Route unavailable: $_routeError',

                          style:
                          TextStyle(
                            color:
                            Colors.white
                                .withValues(
                              alpha:
                              .72,
                            ),

                            fontSize:
                            9,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // ======================================================
          // BOTTOM ACTIONS
          // ======================================================

          Positioned(
            bottom: 22,
            left: 18,
            right: 18,

            child:
            ExplorerCard(
              radius:
              16,

              padding:
              const EdgeInsets.all(
                12,
              ),

              child:
              Column(
                mainAxisSize:
                MainAxisSize.min,

                children: [
                  // ------------------------------------------------
                  // DIRECTIONS BUTTON
                  // ------------------------------------------------

                  SizedBox(
                    width:
                    double.infinity,

                    height:
                    46,

                    child:
                    OutlinedButton.icon(
                      onPressed:
                      _routeLoading
                          ? null
                          : _showDirections,

                      icon:
                      const Icon(
                        Icons
                            .route_outlined,
                      ),

                      label:
                      const Text(
                        'View Directions',
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                    8,
                  ),

                  // ------------------------------------------------
                  // FOUND BUTTON
                  // ------------------------------------------------

                  SizedBox(
                    width:
                    double.infinity,

                    height:
                    48,

                    child:
                    FilledButton.icon(
                      onPressed:
                      _resolvingSos
                          ? null
                          : _foundCompanion,

                      style:
                      FilledButton
                          .styleFrom(
                        backgroundColor:
                        ExplorerColors
                            .success,

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            10,
                          ),
                        ),
                      ),

                      icon:
                      _resolvingSos
                          ? const SizedBox(
                        width:
                        18,
                        height:
                        18,
                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,
                          color:
                          Colors.white,
                        ),
                      )
                          : const Icon(
                        Icons
                            .check_circle_outline,
                      ),

                      label:
                      Text(
                        _resolvingSos
                            ? 'Resolving SOS...'
                            : 'I Found ${widget.senderName}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}