
part of '../traveler_pages.dart';

class RewardsPage extends StatelessWidget {
  const RewardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Text('Rewards'),
        actions: [
          IconButton(
            tooltip: 'Nearby rewards',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NearbyRewardsPage(),
              ),
            ),
            icon: const Icon(Icons.near_me_outlined),
          ),
          IconButton(
            tooltip: 'Voucher wallet',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VoucherWalletPage(),
              ),
            ),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: AppServices.userRef(
          AppServices.auth.currentUser!.uid,
        ).snapshots(),
        builder: (context, userSnapshot) {
          final points = userSnapshot.data?.data()?['points'] ?? 0;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: AppServices.db
                .collection('vouchers')
                .where('status', isEqualTo: 'active')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs.where((doc) {
                final expiry = asDate(doc.data()['expiresAt']);
                final inventory =
                    (doc.data()['inventoryRemaining'] ?? 0) as num;
                return (expiry == null || expiry.isAfter(DateTime.now())) &&
                    inventory > 0;
              }).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  ExplorerCard(
                    backgroundColor: ExplorerColors.navy,
                    borderColor: ExplorerColors.navy,
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.workspace_premium_outlined,
                            color: ExplorerColors.gold,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'AVAILABLE POINTS',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .6,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$points pts',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VoucherWalletPage(),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(90, 42),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                          ),
                          child: const Text('Wallet'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const ExplorerSectionTitle(
                    'Available Rewards',
                    subtitle:
                        'Redeem points for benefits from verified local vendors.',
                  ),
                  const SizedBox(height: 10),
                  if (docs.isEmpty)
                    const ExplorerEmptyState(
                      title: 'No rewards available',
                      subtitle:
                          'New vendor rewards will appear here when published.',
                      icon: Icons.card_giftcard_outlined,
                    )
                  else
                    ...docs.map(
                      (doc) => Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: _voucherCard(
                          context,
                          doc.id,
                          doc.data(),
                          points,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _voucherCard(
    BuildContext context,
    String voucherId,
    Map<String, dynamic> voucher,
    dynamic userPoints,
  ) {
    final cost = (voucher['pointCost'] ?? 0) as num;
    final canClaim = (userPoints as num) >= cost;
    final expiry = asDate(voucher['expiresAt']);

    return ExplorerCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 110,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: ExplorerColors.goldSoft,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: const Icon(
              Icons.local_activity_outlined,
              color: ExplorerColors.goldDark,
              size: 48,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ExplorerStatusBadge(
                      label: 'ACTIVE REWARD',
                      tone: ExplorerStatusTone.success,
                    ),
                    const Spacer(),
                    Text(
                      '$cost pts',
                      style: const TextStyle(
                        color: ExplorerColors.goldDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${voucher['title'] ?? 'Heritage Reward'}',
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${voucher['description'] ?? ''}',
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Remaining: ${voucher['inventoryRemaining'] ?? 0}'
                  '${expiry == null ? '' : ' • Expires ${DateFormat.yMMMd().format(expiry)}'}',
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: !canClaim
                      ? null
                      : () async {
                          try {
                            await AppServices.claimVoucher(
                              voucherId: voucherId,
                              voucher: voucher,
                            );
                            if (context.mounted) {
                              showMessage(
                                context,
                                'Voucher claimed successfully.',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showMessage(
                                context,
                                e
                                    .toString()
                                    .replaceFirst('Exception: ', ''),
                                error: true,
                              );
                            }
                          }
                        },
                  child: Text(
                    canClaim
                        ? 'Claim Reward'
                        : 'Need ${(cost - (userPoints as num)).ceil()} More Points',
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
