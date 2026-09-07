part of '../traveler_pages.dart';

class GroupMapPage extends StatefulWidget {
  const GroupMapPage({
    super.key,
    required this.groupId,
    required this.group,
  });

  final String groupId;
  final Map<String, dynamic> group;

  @override
  State<GroupMapPage> createState() => _GroupMapPageState();
}

class _GroupMapPageState extends State<GroupMapPage> {
  GoogleMapController? _mapController;
  final Map<String, Marker> _markers = {};

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.group['name'] ?? 'Group'} Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppServices.db
            .collection('travel_groups')
            .doc(widget.groupId)
            .collection('locations')
            .where('approvedViewerIds', arrayContains: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          _markers.clear();

          for (final doc in docs) {
            final data = doc.data();
            final geo = data['location'];
            if (geo is GeoPoint) {
              final isMe = doc.id == uid;
              final marker = Marker(
                markerId: MarkerId(doc.id),
                position: LatLng(geo.latitude, geo.longitude),
                icon: isMe
                  ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
                  : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                infoWindow: InfoWindow(
                  title: isMe ? 'You' : 'Companion',
                  snippet: 'Last updated: ${DateFormat.jm().format(asDate(data['updatedAt']) ?? DateTime.now())}',
                  onTap: () {
                    if (!isMe) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CompanionLocationPage(
                            companionId: doc.id,
                            groupId: widget.groupId,
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
              _markers[doc.id] = marker;
            }
          }

          final initialPos = _markers.containsKey(uid)
              ? _markers[uid]!.position
              : _markers.isNotEmpty
                  ? _markers.values.first.position
                  : const LatLng(5.4141, 100.3288); // Default to Penang

          return GoogleMap(
            initialCameraPosition: CameraPosition(target: initialPos, zoom: 15),
            markers: _markers.values.toSet(),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onMapCreated: (controller) => _mapController = controller,
          );
        },
      ),
    );
  }
}
