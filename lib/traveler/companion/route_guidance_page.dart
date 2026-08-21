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

  Future<void> _startTracking() async {
    try {
      _myPosition = await determinePosition();
      _calculateGuidance();
      
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _myPosition = pos;
            _calculateGuidance();
          });
        }
      });
    } catch (e) {
      if (mounted) showMessage(context, 'Unable to get your location.', error: true);
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
            onMapCreated: (controller) => _mapController = controller,
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
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(backgroundColor: ExplorerColors.success),
                    icon: const Icon(Icons.check),
                    label: const Text('I found them'),
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
