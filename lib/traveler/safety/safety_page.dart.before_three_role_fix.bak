
part of '../traveler_pages.dart';

class SafetyPage extends StatefulWidget {
  const SafetyPage({super.key});

  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  static const center = LatLng(5.4141, 100.3288);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Text('Safety & Hazard Reporting'),
        actions: [
          IconButton(
            tooltip: 'My reports',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MyHazardReportsPage(),
              ),
            ),
            icon: const Icon(Icons.assignment_outlined),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsPage(),
              ),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppServices.db
            .collection('hazards')
            .where('status', isEqualTo: 'verified')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.toList()
            ..sort(
              (a, b) => (asDate(b.data()['createdAt']) ?? DateTime(2000))
                  .compareTo(
                asDate(a.data()['createdAt']) ?? DateTime(2000),
              ),
            );

          final markers = docs.map((doc) {
            final data = doc.data();
            final geo = data['location'];
            if (geo is! GeoPoint) return null;
            return Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(geo.latitude, geo.longitude),
              infoWindow: InfoWindow(
                title: data['category'] ?? 'Hazard',
                snippet:
                    '${data['severity'] ?? ''}: ${data['description'] ?? ''}',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                _hazardHue(data['severity']),
              ),
            );
          }).whereType<Marker>().toSet();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            children: [
              ExplorerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ExplorerSectionTitle(
                      'Report a Hazard',
                      subtitle:
                          'Contribute to the safety of our heritage sites.',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: ExplorerColors.dangerSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.report_problem_outlined,
                            color: ExplorerColors.danger,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Use your current GPS location, select the hazard category and severity, then add a clear description and photo.',
                            style: TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 11,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateHazardPage(),
                        ),
                      ),
                      icon: const Icon(Icons.add_alert_outlined),
                      label: const Text('Create Hazard Report'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ExplorerSectionTitle(
                'Verified Danger Zones',
                subtitle:
                    'Avoid high-severity areas reported by verified stewards.',
                trailing: IconButton(
                  tooltip: 'Check nearby hazards',
                  onPressed: () => checkNearby(docs),
                  icon: const Icon(Icons.radar),
                ),
              ),
              const SizedBox(height: 10),
              ExplorerCard(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: 225,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: center,
                        zoom: 12.5,
                      ),
                      markers: markers,
                      myLocationButtonEnabled: true,
                      myLocationEnabled: true,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const ExplorerSectionTitle('Live Safety Feed'),
              const SizedBox(height: 10),
              if (docs.isEmpty)
                const ExplorerEmptyState(
                  title: 'No verified hazards',
                  subtitle:
                      'Verified safety updates will appear here.',
                  icon: Icons.health_and_safety_outlined,
                )
              else
                ...docs.take(8).map(
                      (doc) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _hazardCard(context, doc),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _hazardCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final severity = '${data['severity'] ?? 'Low'}';
    final high = severity == 'High';
    final medium = severity == 'Medium';
    final color = high
        ? ExplorerColors.danger
        : medium
            ? ExplorerColors.warning
            : ExplorerColors.success;
    final soft = high
        ? ExplorerColors.dangerSoft
        : medium
            ? ExplorerColors.warningSoft
            : ExplorerColors.successSoft;

    return ExplorerCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: soft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              high ? Icons.crisis_alert : Icons.warning_amber_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${data['category'] ?? 'Hazard'}',
                        style: const TextStyle(
                          color: ExplorerColors.navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ExplorerStatusBadge(
                      label: severity.toUpperCase(),
                      tone: high
                          ? ExplorerStatusTone.danger
                          : medium
                              ? ExplorerStatusTone.warning
                              : ExplorerStatusTone.success,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${data['description'] ?? ''}',
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 13,
                      color: ExplorerColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      asDate(data['createdAt']) == null
                          ? 'Recently reported'
                          : DateFormat.yMMMd()
                              .add_jm()
                              .format(asDate(data['createdAt'])!),
                      style: const TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 9,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      tooltip: 'Hazard actions',
                      padding: EdgeInsets.zero,
                      onSelected: (value) => _vote(doc, value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'upvote',
                          child: Text('Confirm hazard'),
                        ),
                        PopupMenuItem(
                          value: 'resolved',
                          child: Text('Vote as resolved'),
                        ),
                      ],
                      icon: const Icon(
                        Icons.more_horiz,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _vote(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String value,
  ) async {
    final uid = AppServices.auth.currentUser!.uid;
    final voteId = '${uid}_${doc.id}_$value';
    final voteRef = AppServices.db.collection('hazard_votes').doc(voteId);

    if ((await voteRef.get()).exists) {
      if (mounted) {
        showMessage(
          context,
          'You already voted on this hazard.',
          error: true,
        );
      }
      return;
    }

    await AppServices.db.runTransaction((transaction) async {
      transaction.set(voteRef, {
        'userId': uid,
        'hazardId': doc.id,
        'type': value,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(doc.reference, {
        value == 'upvote' ? 'upvoteCount' : 'resolveCount':
            FieldValue.increment(1),
      });
    });
  }

  Future<void> checkNearby(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> hazards,
  ) async {
    try {
      final position = await determinePosition();
      QueryDocumentSnapshot<Map<String, dynamic>>? nearest;
      double nearestMeters = double.infinity;

      for (final hazard in hazards) {
        final location = hazard.data()['location'];
        if (location is! GeoPoint) continue;

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          location.latitude,
          location.longitude,
        );

        if (distance < nearestMeters) {
          nearestMeters = distance;
          nearest = hazard;
        }
      }

      if (!mounted) return;

      if (nearest == null || nearestMeters > 2000) {
        showMessage(
          context,
          'No verified hazard was found within 2 km.',
        );
        return;
      }

      final hazard = nearest.data();
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Nearby Safety Alert'),
          content: Text(
            '${hazard['category'] ?? 'Hazard'} is approximately '
            '${nearestMeters < 1000 ? '${nearestMeters.round()} m' : '${(nearestMeters / 1000).toStringAsFixed(1)} km'} away.\n\n'
            '${hazard['description'] ?? ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString(), error: true);
      }
    }
  }

  double _hazardHue(dynamic severity) {
    if (severity == 'High') return BitmapDescriptor.hueRed;
    if (severity == 'Medium') return BitmapDescriptor.hueOrange;
    return BitmapDescriptor.hueGreen;
  }
}
