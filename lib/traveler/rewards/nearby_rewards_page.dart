part of '../traveler_pages.dart';

class NearbyRewardsPage extends StatefulWidget {
  const NearbyRewardsPage({super.key});

  @override
  State<NearbyRewardsPage> createState() => _NearbyRewardsPageState();
}

class _NearbyRewardsPageState extends State<NearbyRewardsPage> {
  late final String _uid;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _travelerStream;
  bool loading = true;
  bool showMap = false;
  String? error;
  Position? currentPosition;
  Map<String, int> claimedCounts = <String, int>{};

  List<({QueryDocumentSnapshot<Map<String, dynamic>> doc, double distance})>
  nearby = const [];

  @override
  void initState() {
    super.initState();
    _uid = AppServices.auth.currentUser!.uid;
    _travelerStream = AppServices.travelerRef(_uid).snapshots();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final position = await determinePosition();
      final candidates = await AppServices.nearbyRewardCandidates(position);
      final claimSnapshot = await AppServices.db
          .collection('claimed_vouchers')
          .where('userId', isEqualTo: _uid)
          .limit(AppServices.rewardPageReadLimit)
          .get();

      final results =
          <
            ({QueryDocumentSnapshot<Map<String, dynamic>> doc, double distance})
          >[];

      for (final doc in candidates) {
        final data = doc.data();
        final location = data['location'];
        final startsAt = asDate(data['startsAt']);
        final expiry = asDate(data['expiresAt']);
        final cost = (data['pointCost'] as num?)?.toInt() ?? 0;

        if (data['status'] != 'active' ||
            location is! GeoPoint ||
            cost <= 0 ||
            '${data['vendorId'] ?? ''}'.trim().isEmpty ||
            (startsAt != null && startsAt.isAfter(DateTime.now())) ||
            (expiry != null && expiry.isBefore(DateTime.now()))) {
          continue;
        }

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          location.latitude,
          location.longitude,
        );

        final inventory = (data['inventoryRemaining'] as num?)?.toInt() ?? 0;

        if (distance <= AppServices.nearbyRewardRadiusMeters && inventory > 0) {
          results.add((doc: doc, distance: distance));
        }
      }

      results.sort(
        (first, second) => first.distance.compareTo(second.distance),
      );

      if (!mounted) return;
      final counts = <String, int>{};
      for (final claim in claimSnapshot.docs) {
        final voucherId = '${claim.data()['voucherId'] ?? ''}';
        if (voucherId.isNotEmpty) {
          counts[voucherId] = (counts[voucherId] ?? 0) + 1;
        }
      }
      setState(() {
        nearby = results;
        claimedCounts = counts;
        currentPosition = position;
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  String _claimLabel({
    required int points,
    required int cost,
    required int claimedCount,
    required int? claimLimit,
  }) {
    if (claimLimit != null && claimedCount >= claimLimit) {
      return 'Claim limit reached';
    }
    if (cost <= 0) return 'Voucher unavailable';
    if (points < cost) {
      return 'Need ${cost - points} more points';
    }
    return 'Claim for $cost points';
  }

  Future<void> _openDirections(GeoPoint location) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${location.latitude},${location.longitude}',
      'travelmode': 'walking',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      showMessage(context, 'Unable to open directions.', error: true);
    }
  }

  Widget _buildMap() {
    final position = currentPosition!;
    final markers = <Marker>{
      for (final item in nearby)
        if (item.doc.data()['location'] is GeoPoint)
          Marker(
            markerId: MarkerId(item.doc.id),
            position: LatLng(
              (item.doc.data()['location'] as GeoPoint).latitude,
              (item.doc.data()['location'] as GeoPoint).longitude,
            ),
            infoWindow: InfoWindow(
              title: '${item.doc.data()['title'] ?? 'Nearby reward'}',
              snippet:
                  '${item.doc.data()['vendorName'] ?? 'Vendor'} • Tap for walking directions',
              onTap: () =>
                  _openDirections(item.doc.data()['location'] as GeoPoint),
            ),
          ),
    };

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 14.5,
          ),
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          compassEnabled: true,
          mapToolbarEnabled: false,
        ),
        Positioned(
          left: 14,
          right: 14,
          top: 14,
          child: ExplorerCard(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.map_outlined, color: ExplorerColors.navy),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '${nearby.length} nearby vendors • Tap a marker for walking directions',
                    style: const TextStyle(
                      color: ExplorerColors.navy,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Rewards'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VoucherWalletPage()),
            ),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Voucher wallet',
          ),
          IconButton(
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh nearby rewards',
          ),
          if (!loading && error == null && currentPosition != null)
            IconButton(
              onPressed: () => setState(() => showMap = !showMap),
              icon: Icon(
                showMap ? Icons.view_list_outlined : Icons.map_outlined,
              ),
              tooltip: showMap ? 'Show reward list' : 'Show vendor map',
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _travelerStream,
        builder: (context, travelerSnapshot) {
          if (!travelerSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final points =
              (travelerSnapshot.data?.data()?['points'] as num?)?.toInt() ?? 0;

          if (loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (error != null) {
            return ExplorerEmptyState(
              title: 'Unable to find nearby rewards',
              subtitle: error,
              icon: Icons.location_off_outlined,
              action: FilledButton.icon(
                onPressed: load,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            );
          }

          if (showMap && currentPosition != null) return _buildMap();

          if (nearby.isEmpty) {
            return ExplorerEmptyState(
              title: 'No nearby rewards right now',
              subtitle:
                  'Your location was checked successfully. Move closer to a participating vendor or browse the full catalogue.',
              icon: Icons.near_me_outlined,
              action: OutlinedButton.icon(
                onPressed: load,
                icon: const Icon(Icons.refresh),
                label: const Text('Check Again'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: nearby.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExplorerCard(
                      backgroundColor: ExplorerColors.navy,
                      borderColor: ExplorerColors.navy,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_searching,
                            color: ExplorerColors.gold,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${nearby.length} nearby ${nearby.length == 1 ? 'reward' : 'rewards'} found',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Sorted from nearest to farthest',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$points pts',
                            style: const TextStyle(
                              color: ExplorerColors.gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => showMap = true),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('View Nearby Vendors on Map'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const ExplorerSectionTitle(
                      'Rewards within range',
                      subtitle:
                          'Every vendor uses the same fair 750-metre discovery range.',
                    ),
                  ],
                );
              }

              final item = nearby[index - 1];
              final voucher = item.doc.data();
              final cost = (voucher['pointCost'] as num?)?.toInt() ?? 0;
              final claimedCount = claimedCounts[item.doc.id] ?? 0;
              final rawClaimLimit =
                  (voucher['perTouristClaimLimit'] as num?)?.toInt() ?? 0;
              final int? claimLimit = rawClaimLimit > 0 ? rawClaimLimit : null;
              final canClaim =
                  (claimLimit == null || claimedCount < claimLimit) &&
                  points >= cost &&
                  cost > 0;
              final location = voucher['location'];

              return ExplorerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${voucher['title'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ExplorerStatusBadge(
                          label: item.distance < 1000
                              ? '${item.distance.round()} M AWAY'
                              : '${(item.distance / 1000).toStringAsFixed(1)} KM AWAY',
                          tone: ExplorerStatusTone.navy,
                          icon: Icons.near_me_outlined,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          size: 16,
                          color: ExplorerColors.muted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${voucher['vendorName'] ?? 'Registered vendor'}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${voucher['description'] ?? ''}'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        ExplorerStatusBadge(
                          label: '$cost POINTS',
                          tone: ExplorerStatusTone.warning,
                          icon: Icons.stars_rounded,
                        ),
                        ExplorerStatusBadge(
                          label: '${voucher['inventoryRemaining'] ?? 0} LEFT',
                          tone: ExplorerStatusTone.success,
                          icon: Icons.inventory_2_outlined,
                        ),
                      ],
                    ),
                    if (location is GeoPoint) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _openDirections(location),
                          icon: const Icon(Icons.directions_walk, size: 18),
                          label: const Text('Walking Directions'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    VoucherDetailPage(voucherId: item.doc.id),
                              ),
                            ),
                            child: const Text('View Details'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: canClaim
                                ? () async {
                                    try {
                                      final receipt =
                                          await AppServices.claimVoucher(
                                            voucherId: item.doc.id,
                                            voucher: voucher,
                                          );

                                      if (context.mounted) {
                                        setState(() {
                                          claimedCounts[item.doc.id] =
                                              claimedCount + 1;
                                        });
                                        await showVoucherClaimReceipt(
                                          context,
                                          receipt,
                                        );
                                      }
                                    } catch (exception) {
                                      if (context.mounted) {
                                        showMessage(
                                          context,
                                          exception.toString().replaceFirst(
                                            'Exception: ',
                                            '',
                                          ),
                                          error: true,
                                        );
                                      }
                                    }
                                  }
                                : null,
                            child: Text(
                              _claimLabel(
                                points: points,
                                cost: cost,
                                claimedCount: claimedCount,
                                claimLimit: claimLimit,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
