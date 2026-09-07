part of '../traveler_pages.dart';

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
  State<RouteGuidancePage> createState() => _RouteGuidancePageState();
}

class _RouteGuidancePageState extends State<RouteGuidancePage> {
  GoogleMapController? _mapController;
  Position? _myPosition;
  StreamSubscription<Position>? _positionStream;

  double _distance = 0;
  int _minutes = 0;
  bool _resolvingSos = false;

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

  Future<void> _foundCompanion() async {
    if (_resolvingSos) return;

    setState(() {
      _resolvingSos = true;
    });

    try {
      final currentUser =
          AppServices.auth.currentUser;

      if (currentUser == null) {
        throw Exception(
          'Please sign in first.',
        );
      }

      final alertRef = AppServices.db
          .collection('sos_alerts')
          .doc(widget.alertId);

      final alertSnapshot =
      await alertRef.get();

      if (!alertSnapshot.exists) {
        throw Exception(
          'SOS alert could not be found.',
        );
      }

      final alert =
          alertSnapshot.data() ??
              const <String, dynamic>{};

      final groupId =
          '${alert['groupId'] ?? ''}';

      final senderId =
          '${alert['senderId'] ?? widget.senderId}';

      final batch =
      AppServices.db.batch();

      // ===============================
      // RESOLVE SOS ALERT
      // ===============================

      batch.update(
        alertRef,
        {
          'status': 'resolved',
          'resolvedAt':
          FieldValue.serverTimestamp(),
          'resolvedBy':
          currentUser.uid,
        },
      );

      // ===============================
      // REMOVE SOS STATE FROM MAP
      // ===============================

      if (groupId.isNotEmpty &&
          senderId.isNotEmpty) {
        final locationRef =
        AppServices.db
            .collection('travel_groups')
            .doc(groupId)
            .collection('locations')
            .doc(senderId);

        batch.set(
          locationRef,
          {
            'sosActive': false,
            'updatedAt':
            FieldValue.serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );
      }

      await batch.commit();

      // Optional notification to member
      if (senderId.isNotEmpty) {
        await AppServices.notify(
          userId: senderId,
          title: 'SOS resolved',
          message:
          'Your group leader found you and marked the SOS alert as resolved.',
          type: 'sos_resolved',
          referenceId:
          widget.alertId,
        );
      }

      if (!mounted) return;

      showMessage(
        context,
        'SOS resolved successfully.',
      );

      Navigator.pop(context);
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
          _resolvingSos = false;
        });
      }
    }
  }

  Future<void> _fitRoute() async {
    final controller =
        _mapController;

    final currentPosition =
        _myPosition;

    if (controller == null ||
        currentPosition == null) {
      return;
    }

    final leader = LatLng(
      currentPosition.latitude,
      currentPosition.longitude,
    );

    final member = LatLng(
      widget.targetLat,
      widget.targetLng,
    );

    final minLat = min(
      leader.latitude,
      member.latitude,
    );

    final maxLat = max(
      leader.latitude,
      member.latitude,
    );

    final minLng = min(
      leader.longitude,
      member.longitude,
    );

    final maxLng = max(
      leader.longitude,
      member.longitude,
    );

    if (minLat == maxLat &&
        minLng == maxLng) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          leader,
          17,
        ),
      );

      return;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            minLat,
            minLng,
          ),
          northeast: LatLng(
            maxLat,
            maxLng,
          ),
        ),
        80,
      ),
    );
  }

  Future<void> _startTracking() async {
    try {
      final initialPosition =
      await determinePosition();

      if (!mounted) return;

      setState(() {
        _myPosition =
            initialPosition;

        _calculateGuidance();
      });

      _fitRoute();

      _positionStream =
          Geolocator.getPositionStream(
            locationSettings:
            const LocationSettings(
              accuracy:
              LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen(
                (position) {
              if (!mounted) return;

              setState(() {
                _myPosition =
                    position;

                _calculateGuidance();
              });

              _fitRoute();
            },
          );
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          'Unable to get your location.',
          error: true,
        );
      }
    }
  }

  void _calculateGuidance() {
    if (_myPosition == null) return;

    // Straight line distance
    _distance = Geolocator.distanceBetween(
      _myPosition!.latitude,
      _myPosition!.longitude,
      widget.targetLat,
      widget.targetLng,
    );

    // Walking speed ~4.5 km/h -> 75 meters/minute
    _minutes = (_distance / 75).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final targetPos = LatLng(widget.targetLat, widget.targetLng);
    final myPos = _myPosition != null ? LatLng(_myPosition!.latitude, _myPosition!.longitude) : null;

    final markers = {
      Marker(
        markerId: const MarkerId('target'),
        position: targetPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: widget.senderName, snippet: 'SOS Location'),
      ),
      if (myPos != null)
        Marker(
          markerId: const MarkerId('me'),
          position: myPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'You'),
        ),
    };

    final polylines = {
      if (myPos != null)
        Polyline(
          polylineId: const PolylineId('route'),
          points: [myPos, targetPos],
          color: ExplorerColors.danger,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
    };

    return Scaffold(
      appBar: AppBar(title: Text('Finding ${widget.senderName}')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: targetPos, zoom: 17),
            markers: markers,
            polylines: polylines,
            myLocationEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;

              WidgetsBinding.instance
                  .addPostFrameCallback(
                    (_) {
                  _fitRoute();
                },
              );
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: ExplorerCard(
              backgroundColor: ExplorerColors.navy,
              child: Row(
                children: [
                  const Icon(Icons.directions_walk, color: Colors.white, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _myPosition == null ? 'Calculating...' : '${(_distance / 1000).toStringAsFixed(2)} km away',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          _myPosition == null ? 'Waiting for GPS' : 'Approx. $_minutes mins walk',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _resolvingSos
                        ? null
                        : _foundCompanion,

                    style: FilledButton.styleFrom(
                      backgroundColor:
                      ExplorerColors.success,
                      padding:
                      const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                    ),

                    icon: _resolvingSos
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(
                      Icons.check_circle_outline,
                    ),

                    label: Text(
                      _resolvingSos
                          ? 'Resolving SOS...'
                          : 'I Found Them',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
