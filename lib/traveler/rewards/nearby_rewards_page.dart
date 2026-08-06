part of '../traveler_pages.dart';

class NearbyRewardsPage extends StatefulWidget {
  const NearbyRewardsPage({super.key});

  @override
  State<NearbyRewardsPage> createState() => _NearbyRewardsPageState();
}

class _NearbyRewardsPageState extends State<NearbyRewardsPage> {
  bool loading = true;
  String? error;
  List<({QueryDocumentSnapshot<Map<String, dynamic>> doc, double distance})>
      nearby = const [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final position = await determinePosition();
      final snapshot = await AppServices.db
          .collection('vouchers')
          .where('status', isEqualTo: 'active')
          .get();
      final results = <({
        QueryDocumentSnapshot<Map<String, dynamic>> doc,
        double distance,
      })>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final location = data['location'];
        final expiry = asDate(data['expiresAt']);
        if (location is! GeoPoint ||
            (expiry != null && expiry.isBefore(DateTime.now()))) {
          continue;
        }
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          location.latitude,
          location.longitude,
        );
        final radius =
            ((data['notificationRadiusMeters'] ?? 750.0) as num).toDouble();
        if (distance <= radius &&
            ((data['inventoryRemaining'] ?? 0) as num) > 0) {
          results.add((doc: doc, distance: distance));
        }
      }
      results.sort((a, b) => a.distance.compareTo(b.distance));
      if (!mounted) return;
      setState(() {
        nearby = results;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ExplorerPageHeader(
              title: 'Nearby Rewards',
              subtitle: 'Location-based offers from participating local vendors.',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh nearby rewards',
                  onPressed: loading ? null : load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: ExplorerCard(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircleAvatar(
                                    radius: 28,
                                    backgroundColor: ExplorerColors.dangerSoft,
                                    foregroundColor: ExplorerColors.danger,
                                    child: Icon(Icons.location_off_outlined),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: ExplorerColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  FilledButton.icon(
                                    onPressed: load,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Try Again'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : nearby.isEmpty
                          ? const ExplorerEmptyState(
                              title: 'No rewards nearby',
                              subtitle:
                                  'Move closer to a participating vendor or browse the full reward catalogue.',
                              icon: Icons.near_me_outlined,
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                              itemCount: nearby.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = nearby[index];
                                final voucher = item.doc.data();
                                final distanceText = item.distance < 1000
                                    ? '${item.distance.round()} m away'
                                    : '${(item.distance / 1000).toStringAsFixed(1)} km away';
                                return ExplorerCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 54,
                                            height: 54,
                                            decoration: BoxDecoration(
                                              color: ExplorerColors.goldSoft,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.local_activity_outlined,
                                              color: ExplorerColors.goldDark,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 13),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${voucher['title'] ?? 'Local Reward'}',
                                                  style: const TextStyle(
                                                    color: ExplorerColors.navy,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${voucher['businessName'] ?? voucher['vendorName'] ?? 'Participating vendor'}',
                                                  style: const TextStyle(
                                                    color: ExplorerColors.muted,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          ExplorerStatusBadge(
                                            label: distanceText.toUpperCase(),
                                            tone: ExplorerStatusTone.navy,
                                            icon: Icons.near_me_outlined,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${voucher['description'] ?? ''}',
                                        style: const TextStyle(
                                          color: ExplorerColors.text,
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ExplorerLabeledValue(
                                              label: 'Points Required',
                                              value:
                                                  '${voucher['pointCost'] ?? 0} pts',
                                            ),
                                          ),
                                          Expanded(
                                            child: ExplorerLabeledValue(
                                              label: 'Remaining',
                                              value:
                                                  '${voucher['inventoryRemaining'] ?? 0}',
                                              alignEnd: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      FilledButton.icon(
                                        onPressed: () async {
                                          try {
                                            await AppServices.claimVoucher(
                                              voucherId: item.doc.id,
                                              voucher: voucher,
                                            );
                                            if (context.mounted) {
                                              showMessage(
                                                context,
                                                'Nearby voucher claimed successfully.',
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              showMessage(
                                                context,
                                                e
                                                    .toString()
                                                    .replaceFirst(
                                                      'Exception: ',
                                                      '',
                                                    ),
                                                error: true,
                                              );
                                            }
                                          }
                                        },
                                        style: FilledButton.styleFrom(
                                          minimumSize:
                                              const Size.fromHeight(48),
                                        ),
                                        icon: const Icon(
                                          Icons.card_giftcard_outlined,
                                        ),
                                        label: Text(
                                          'Claim for ${voucher['pointCost'] ?? 0} Points',
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
