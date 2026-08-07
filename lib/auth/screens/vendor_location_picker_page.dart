part of '../auth_pages.dart';

class VendorLocationPickerPage extends StatefulWidget {
  const VendorLocationPickerPage({
    super.key,
    this.initialLocation,
  });

  final LatLng? initialLocation;

  @override
  State<VendorLocationPickerPage> createState() =>
      _VendorLocationPickerPageState();
}

class _VendorLocationPickerPageState
    extends State<VendorLocationPickerPage> {
  static const LatLng penangCenter = LatLng(5.4141, 100.3288);
  LatLng? selected;
  GoogleMapController? mapController;
  bool locating = false;

  @override
  void initState() {
    super.initState();
    selected = widget.initialLocation;
    if (selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _useCurrent());
    }
  }

  Future<void> _useCurrent() async {
    setState(() => locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is required to use the current position.',
        );
      }
      final position = await Geolocator.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => selected = point);
      await mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(point, 17),
      );
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = selected ?? penangCenter;
    return Scaffold(
      appBar: AppBar(title: const Text('Pin Business Location')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: point,
              zoom: selected == null ? 11 : 17,
            ),
            onMapCreated: (controller) => mapController = controller,
            onTap: (position) => setState(() => selected = position),
            myLocationButtonEnabled: false,
            myLocationEnabled: true,
            markers: selected == null
                ? const <Marker>{}
                : {
                    Marker(
                      markerId: const MarkerId('vendor-location'),
                      position: selected!,
                      infoWindow: const InfoWindow(
                        title: 'Business location',
                      ),
                    ),
                  },
          ),
          Positioned(
            right: 16,
            bottom: 104,
            child: FloatingActionButton.small(
              heroTag: 'vendor-current-location',
              onPressed: locating ? null : _useCurrent,
              child: locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: FilledButton.icon(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(context, selected),
              icon: const Icon(Icons.location_on_outlined),
              label: Text(
                selected == null
                    ? 'Tap the map to choose the business location'
                    : 'Confirm ${selected!.latitude.toStringAsFixed(6)}, '
                        '${selected!.longitude.toStringAsFixed(6)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
