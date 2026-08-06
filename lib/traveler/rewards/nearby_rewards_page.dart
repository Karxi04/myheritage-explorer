part of '../traveler_pages.dart';

class NearbyRewardsPage extends StatefulWidget {
  const NearbyRewardsPage({super.key});

  @override
  State<NearbyRewardsPage> createState() =>
      _NearbyRewardsPageState();
}

class _NearbyRewardsPageState extends State<NearbyRewardsPage> {
  bool loading = true;
  String? error;

  List<
      ({
        QueryDocumentSnapshot<Map<String, dynamic>> doc,
        double distance,
      })> nearby = const [];

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

      final results = <
          ({
            QueryDocumentSnapshot<Map<String, dynamic>> doc,
            double distance,
          })>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final location = data['location'];
        final expiry = asDate(data['expiresAt']);
        final cost =
            (data['pointCost'] as num?)?.toInt() ?? 0;

        if (location is! GeoPoint ||
            cost <= 0 ||
            '${data['vendorId'] ?? ''}'.trim().isEmpty ||
            (expiry != null &&
                expiry.isBefore(DateTime.now()))) {
          continue;
        }

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          location.latitude,
          location.longitude,
        );

        final radius =
            ((data['notificationRadiusMeters'] ?? 750.0)
                    as num)
                .toDouble();

        final inventory =
            (data['inventoryRemaining'] as num?)?.toInt() ??
                0;

        if (distance <= radius && inventory > 0) {
          results.add((doc: doc, distance: distance));
        }
      }

      results.sort(
        (first, second) =>
            first.distance.compareTo(second.distance),
      );

      if (!mounted) return;
      setState(() {
        nearby = results;
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception
            .toString()
            .replaceFirst('Exception: ', '');
        loading = false;
      });
    }
  }

  String _claimLabel({
    required int points,
    required int cost,
  }) {
    if (cost <= 0) return 'Voucher unavailable';
    if (points < cost) {
      return 'Need ${cost - points} more points';
    }
    return 'Claim for $cost points';
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Rewards'),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: AppServices.travelerRef(uid).snapshots(),
        builder: (context, travelerSnapshot) {
          if (!travelerSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final points = (travelerSnapshot.data
                      ?.data()?['points'] as num?)
                  ?.toInt() ??
              0;

          if (loading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (nearby.isEmpty) {
            return emptyState(
              'No nearby rewards',
              'Move closer to a participating vendor or check the full reward catalogue.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: nearby.length + 1,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Card(
                  child: ListTile(
                    leading:
                        const Icon(Icons.stars_rounded),
                    title: const Text('Your reward points'),
                    trailing: Text(
                      '$points pts',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                );
              }

              final item = nearby[index - 1];
              final voucher = item.doc.data();
              final cost =
                  (voucher['pointCost'] as num?)?.toInt() ??
                      0;
              final canClaim = points >= cost && cost > 0;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
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
                          Chip(
                            label: Text(
                              item.distance < 1000
                                  ? '${item.distance.round()} m'
                                  : '${(item.distance / 1000).toStringAsFixed(1)} km',
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Vendor: '
                        '${voucher['vendorName'] ?? 'Registered vendor'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${voucher['description'] ?? ''}'),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canClaim
                              ? () async {
                                  try {
                                    await AppServices
                                        .claimVoucher(
                                      voucherId: item.doc.id,
                                      voucher: voucher,
                                    );

                                    if (context.mounted) {
                                      showMessage(
                                        context,
                                        'Nearby voucher claimed successfully.',
                                      );
                                    }
                                  } catch (exception) {
                                    if (context.mounted) {
                                      showMessage(
                                        context,
                                        exception
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
                              : null,
                          child: Text(
                            _claimLabel(
                              points: points,
                              cost: cost,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
