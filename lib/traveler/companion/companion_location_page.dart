part of '../traveler_pages.dart';

class CompanionLocationPage extends StatefulWidget {
  const CompanionLocationPage({
    super.key,
    required this.companionId,
    required this.groupId,
  });

  final String companionId;
  final String groupId;

  @override
  State<CompanionLocationPage> createState() => _CompanionLocationPageState();
}

class _CompanionLocationPageState extends State<CompanionLocationPage> {
  GoogleMapController? _mapController;
  
  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: AppServices.travelerRef(widget.companionId).get(),
          builder: (context, snapshot) {
            final name = snapshot.data?.data()?['displayName'] ?? 'Companion';
            return Text('$name\'s Location');
          },
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: AppServices.db
            .collection('travel_groups')
            .doc(widget.groupId)
            .collection('locations')
            .doc(widget.companionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const ExplorerEmptyState(
              title: 'Location Unavailable',
              subtitle: 'This companion has not shared their location or permission was revoked.',
              icon: Icons.location_off_outlined,
            );
          }

          final data = snapshot.data!.data()!;
          final viewerIds = List<String>.from(data['approvedViewerIds'] ?? []);
          
          if (!viewerIds.contains(uid)) {
            return const ExplorerEmptyState(
              title: 'Access Denied',
              subtitle: 'You do not have permission to view this companion\'s location.',
              icon: Icons.lock_outline,
            );
          }

          final geo = data['location'];
          if (geo is! GeoPoint) {
            return const Center(child: Text('Invalid location data.'));
          }

          final pos = LatLng(geo.latitude, geo.longitude);
          final marker = Marker(
            markerId: MarkerId(widget.companionId),
            position: pos,
            infoWindow: InfoWindow(
              title: 'Companion',
              snippet: 'Last updated: ${DateFormat.jm().format(asDate(data['updatedAt']) ?? DateTime.now())}',
            ),
          );

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: pos, zoom: 16),
                markers: {marker},
                myLocationEnabled: true,
                onMapCreated: (controller) => _mapController = controller,
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: ExplorerCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Location Details',
                        style: TextStyle(fontWeight: FontWeight.bold, color: ExplorerColors.navy),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Updated at ${DateFormat.yMMMd().add_jm().format(asDate(data['updatedAt']) ?? DateTime.now())}',
                        style: const TextStyle(fontSize: 12, color: ExplorerColors.muted),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
                        },
                        icon: const Icon(Icons.center_focus_strong),
                        label: const Text('Recenter'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
