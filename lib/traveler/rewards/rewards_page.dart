part of '../traveler_pages.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({
    super.key,
    this.embedded = false,
    this.showPointsSummary = true,
    this.focusVoucherId,
  });

  final bool embedded;
  final bool showPointsSummary;
  final String? focusVoucherId;

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  String searchQuery = '';
  String category = 'All';
  String sortMode = 'Recommended';
  bool favouritesOnly = false;

  String _claimLabel({
    required int points,
    required int cost,
    required int claimedCount,
    required int claimLimit,
  }) {
    if (claimedCount >= claimLimit) return 'Claim limit reached';
    if (cost <= 0) return 'Voucher unavailable';
    if (points < cost) return 'Need ${cost - points} more points';
    return 'Claim for $cost points';
  }

  bool _matchesSearch(Map<String, dynamic> voucher) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final searchable = [
      voucher['title'],
      voucher['description'],
      voucher['vendorName'],
      voucher['vendorCategory'],
      voucher['terms'],
    ].map((value) => '${value ?? ''}'.toLowerCase()).join(' ');
    return searchable.contains(query);
  }

  Future<void> _confirmClaim(
    String voucherId,
    Map<String, dynamic> voucher,
  ) async {
    final cost = (voucher['pointCost'] as num?)?.toInt() ?? 0;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Claim this reward?'),
            content: Text(
              '${voucher['title'] ?? 'This voucher'} will use $cost reward points and be added to your wallet.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirm Claim'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      final receipt = await AppServices.claimVoucher(
        voucherId: voucherId,
        voucher: voucher,
      );
      if (mounted) await showVoucherClaimReceipt(context, receipt);
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;

    if (widget.embedded) return _buildRewardsBody(uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.focusVoucherId == null ? 'Rewards' : 'Reward Details',
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NearbyRewardsPage()),
            ),
            icon: const Icon(Icons.near_me_outlined),
            tooltip: 'Nearby rewards',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VoucherWalletPage()),
            ),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Voucher wallet',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RewardNotificationSettingsPage(),
              ),
            ),
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Reward notification settings',
          ),
        ],
      ),
      body: _buildRewardsBody(uid),
    );
  }

  Widget _buildRewardsBody(String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: AppServices.travelerRef(uid).snapshots(),
      builder: (context, travelerSnapshot) {
        if (travelerSnapshot.hasError) {
          return emptyState('Unable to load your reward balance');
        }
        if (!travelerSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final traveler =
            travelerSnapshot.data?.data() ?? const <String, dynamic>{};
        final points = (traveler['points'] as num?)?.toInt() ?? 0;
        final rawFavourites = traveler['favoriteVoucherIds'];
        final favouriteVoucherIds = rawFavourites is Iterable
            ? rawFavourites.map((value) => '$value').toSet()
            : <String>{};

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: AppServices.db
              .collection('vouchers')
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, voucherSnapshot) {
            if (voucherSnapshot.hasError) {
              return emptyState('Unable to load the reward catalogue');
            }
            if (!voucherSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AppServices.db
                  .collection('claimed_vouchers')
                  .where('userId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, claimSnapshot) {
                final claimedCounts = <String, int>{};
                for (final claim in claimSnapshot.data?.docs ?? const []) {
                  final voucherId = '${claim.data()['voucherId'] ?? ''}';
                  if (voucherId.isNotEmpty) {
                    claimedCounts[voucherId] =
                        (claimedCounts[voucherId] ?? 0) + 1;
                  }
                }
                final now = DateTime.now();
                final available = voucherSnapshot.data!.docs.where((doc) {
                  if (widget.focusVoucherId != null &&
                      doc.id != widget.focusVoucherId) {
                    return false;
                  }
                  final voucher = doc.data();
                  final startsAt = asDate(voucher['startsAt']);
                  final expiry = asDate(voucher['expiresAt']);
                  final inventory =
                      (voucher['inventoryRemaining'] as num?)?.toInt() ?? 0;
                  final cost = (voucher['pointCost'] as num?)?.toInt() ?? 0;
                  return (startsAt == null || !startsAt.isAfter(now)) &&
                      (expiry == null || expiry.isAfter(now)) &&
                      inventory > 0 &&
                      cost > 0 &&
                      '${voucher['vendorId'] ?? ''}'.trim().isNotEmpty;
                }).toList();

                final categories =
                    available
                        .map(
                          (doc) =>
                              '${doc.data()['vendorCategory'] ?? ''}'.trim(),
                        )
                        .where((value) => value.isNotEmpty)
                        .toSet()
                        .toList()
                      ..sort();

                final filtered = available.where((doc) {
                  final voucher = doc.data();
                  final matchesCategory =
                      category == 'All' ||
                      '${voucher['vendorCategory'] ?? ''}' == category;
                  final matchesFavourite =
                      !favouritesOnly || favouriteVoucherIds.contains(doc.id);
                  return matchesCategory &&
                      matchesFavourite &&
                      _matchesSearch(voucher);
                }).toList();

                switch (sortMode) {
                  case 'Lowest points':
                    filtered.sort(
                      (a, b) => ((a.data()['pointCost'] ?? 0) as num).compareTo(
                        (b.data()['pointCost'] ?? 0) as num,
                      ),
                    );
                  case 'Expiring soon':
                    filtered.sort(
                      (a, b) =>
                          (asDate(a.data()['expiresAt']) ?? DateTime(2100))
                              .compareTo(
                                asDate(b.data()['expiresAt']) ?? DateTime(2100),
                              ),
                    );
                  default:
                    filtered.sort(
                      (a, b) => ((b.data()['claimCount'] ?? 0) as num)
                          .compareTo((a.data()['claimCount'] ?? 0) as num),
                    );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    if (widget.showPointsSummary) ...[
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.stars_rounded),
                          ),
                          title: const Text(
                            'Your reward points',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Complete approved cultural tasks to earn more points.',
                          ),
                          trailing: Text(
                            '$points pts',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      onChanged: (value) => setState(() => searchQuery = value),
                      decoration: const InputDecoration(
                        labelText: 'Search rewards or vendors',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              avatar: const Icon(Icons.favorite, size: 16),
                              label: const Text('Favourites'),
                              selected: favouritesOnly,
                              onSelected: (selected) =>
                                  setState(() => favouritesOnly = selected),
                            ),
                          ),
                          ...['All', ...categories].map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(item),
                                selected: category == item,
                                onSelected: (_) =>
                                    setState(() => category = item),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: DropdownButton<String>(
                        value: sortMode,
                        items: const [
                          DropdownMenuItem(
                            value: 'Recommended',
                            child: Text('Recommended'),
                          ),
                          DropdownMenuItem(
                            value: 'Lowest points',
                            child: Text('Lowest points'),
                          ),
                          DropdownMenuItem(
                            value: 'Expiring soon',
                            child: Text('Expiring soon'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => sortMode = value ?? 'Recommended'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: emptyState(
                          widget.focusVoucherId != null
                              ? 'This reward is fully claimed or no longer available'
                              : available.isEmpty
                              ? 'No rewards available at the moment'
                              : 'No rewards match your search',
                        ),
                      )
                    else
                      ...filtered.map((doc) {
                        final voucher = doc.data();
                        final cost =
                            (voucher['pointCost'] as num?)?.toInt() ?? 0;
                        final claimedCount = claimedCounts[doc.id] ?? 0;
                        final claimLimit =
                            ((voucher['perTouristClaimLimit'] as num?)
                                        ?.toInt() ??
                                    1)
                                .clamp(1, 10);
                        final canClaim =
                            claimedCount < claimLimit && points >= cost;
                        final favourite = favouriteVoucherIds.contains(doc.id);
                        final expiry = asDate(voucher['expiresAt']);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${voucher['title'] ?? 'Voucher'}',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: favourite
                                            ? 'Remove from favourites'
                                            : 'Add to favourites',
                                        onPressed: () =>
                                            AppServices.travelerRef(
                                              uid,
                                            ).update({
                                              'favoriteVoucherIds': favourite
                                                  ? FieldValue.arrayRemove([
                                                      doc.id,
                                                    ])
                                                  : FieldValue.arrayUnion([
                                                      doc.id,
                                                    ]),
                                              'updatedAt':
                                                  FieldValue.serverTimestamp(),
                                            }),
                                        icon: Icon(
                                          favourite
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: favourite ? Colors.red : null,
                                        ),
                                      ),
                                      Chip(label: Text('$cost pts')),
                                    ],
                                  ),
                                  Text(
                                    'Vendor: ${voucher['vendorName'] ?? 'Registered vendor'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if ('${voucher['vendorCategory'] ?? ''}'
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      '${voucher['vendorCategory']}',
                                      style: const TextStyle(
                                        color: ExplorerColors.muted,
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  Text('${voucher['description'] ?? ''}'),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${voucher['inventoryRemaining'] ?? 0} remaining'
                                    '${expiry == null ? '' : ' - ${expiryCountdownLabel(expiry)}'}',
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => VoucherDetailPage(
                                                voucherId: doc.id,
                                              ),
                                            ),
                                          ),
                                          child: const Text('View Details'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: canClaim
                                              ? () => _confirmClaim(
                                                  doc.id,
                                                  voucher,
                                                )
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
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
