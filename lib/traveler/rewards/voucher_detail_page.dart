part of '../traveler_pages.dart';

Future<void> showVoucherClaimReceipt(
  BuildContext context,
  VoucherClaimReceipt receipt,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.check_circle, color: ExplorerColors.success),
          SizedBox(width: 10),
          Text('Claim successful'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            receipt.voucherTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(receipt.vendorName),
          const Divider(height: 24),
          Text('Points deducted: ${receipt.pointsSpent}'),
          Text('Remaining balance: ${receipt.pointsRemaining} points'),
          if (receipt.expiresAt != null)
            Text(
              'Expiry: ${DateFormat.yMMMd().add_jm().format(receipt.expiresAt!)}',
            ),
          const SizedBox(height: 10),
          Text(
            'Claim reference: ${receipt.claimId}',
            style: const TextStyle(color: ExplorerColors.muted, fontSize: 11),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('View in Wallet'),
        ),
      ],
    ),
  );
}

class VoucherDetailPage extends StatelessWidget {
  const VoucherDetailPage({super.key, required this.voucherId});

  final String voucherId;

  Future<void> _toggleFavourite(String uid, bool favourite) async {
    await AppServices.travelerRef(uid).update({
      'favoriteVoucherIds': favourite
          ? FieldValue.arrayRemove([voucherId])
          : FieldValue.arrayUnion([voucherId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _claim(
    BuildContext context,
    Map<String, dynamic> voucher,
  ) async {
    final cost = (voucher['pointCost'] as num?)?.toInt() ?? 0;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Claim this reward?'),
            content: Text(
              '${voucher['title'] ?? 'This voucher'} will use $cost reward points.',
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
    if (!confirmed || !context.mounted) return;

    try {
      final receipt = await AppServices.claimVoucher(
        voucherId: voucherId,
        voucher: voucher,
      );
      if (context.mounted) await showVoucherClaimReceipt(context, receipt);
    } catch (error) {
      if (context.mounted) {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Reward Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: AppServices.db
            .collection('vouchers')
            .doc(voucherId)
            .snapshots(),
        builder: (context, voucherSnapshot) {
          if (voucherSnapshot.hasError) {
            return emptyState('Unable to load this reward');
          }
          if (!voucherSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!voucherSnapshot.data!.exists) {
            return emptyState('This reward is no longer available');
          }
          final voucher = voucherSnapshot.data!.data()!;

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: AppServices.travelerRef(uid).snapshots(),
            builder: (context, travelerSnapshot) {
              final traveler = travelerSnapshot.data?.data();
              final points = (traveler?['points'] as num?)?.toInt() ?? 0;
              final rawFavourites = traveler?['favoriteVoucherIds'];
              final favourites = rawFavourites is Iterable
                  ? rawFavourites.map((value) => '$value').toSet()
                  : <String>{};
              final favourite = favourites.contains(voucherId);

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppServices.db
                    .collection('claimed_vouchers')
                    .where('userId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, claimSnapshot) {
                  final claimedCount =
                      claimSnapshot.data?.docs
                          .where((doc) => doc.data()['voucherId'] == voucherId)
                          .length ??
                      0;
                  final claimLimit =
                      ((voucher['perTouristClaimLimit'] as num?)?.toInt() ?? 1)
                          .clamp(1, 10);
                  final cost = (voucher['pointCost'] as num?)?.toInt() ?? 0;
                  final inventory =
                      (voucher['inventoryRemaining'] as num?)?.toInt() ?? 0;
                  final startsAt = asDate(voucher['startsAt']);
                  final expiry = asDate(voucher['expiresAt']);
                  final now = DateTime.now();
                  final scheduled = startsAt != null && startsAt.isAfter(now);
                  final expired = expiry != null && !expiry.isAfter(now);
                  final canClaim =
                      voucher['status'] == 'active' &&
                      !scheduled &&
                      !expired &&
                      inventory > 0 &&
                      cost > 0 &&
                      points >= cost &&
                      claimedCount < claimLimit;
                  final location = voucher['location'];

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${voucher['title'] ?? 'Voucher'}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: favourite
                                        ? 'Remove from favourites'
                                        : 'Add to favourites',
                                    onPressed: traveler == null
                                        ? null
                                        : () =>
                                              _toggleFavourite(uid, favourite),
                                    icon: Icon(
                                      favourite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: favourite ? Colors.red : null,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${voucher['vendorName'] ?? 'Registered vendor'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if ('${voucher['vendorAddress'] ?? ''}'
                                  .trim()
                                  .isNotEmpty)
                                Text('${voucher['vendorAddress']}'),
                              if ('${voucher['vendorAddress'] ?? ''}'
                                      .trim()
                                      .isEmpty &&
                                  location is GeoPoint)
                                Text(
                                  '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                                ),
                              const SizedBox(height: 16),
                              Text('${voucher['description'] ?? ''}'),
                              if ('${voucher['terms'] ?? ''}'
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 14),
                                const Text(
                                  'Terms and conditions',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('${voucher['terms']}'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.stars_rounded),
                                title: const Text('Point cost'),
                                trailing: Text('$cost points'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.inventory_2_outlined),
                                title: const Text('Inventory remaining'),
                                trailing: Text('$inventory'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: const Text('Your claim allowance'),
                                trailing: Text('$claimedCount / $claimLimit'),
                              ),
                              if (startsAt != null)
                                ListTile(
                                  leading: const Icon(Icons.event_available),
                                  title: const Text('Available from'),
                                  trailing: Text(
                                    DateFormat.yMMMd().format(startsAt),
                                  ),
                                ),
                              if (expiry != null)
                                ListTile(
                                  leading: const Icon(Icons.timer_outlined),
                                  title: Text(expiryCountdownLabel(expiry)),
                                  subtitle: Text(
                                    DateFormat.yMMMd().add_jm().format(expiry),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canClaim
                              ? () => _claim(context, voucher)
                              : null,
                          child: Text(
                            scheduled
                                ? 'Available ${DateFormat.yMMMd().format(startsAt)}'
                                : expired
                                ? 'Voucher expired'
                                : inventory <= 0
                                ? 'Fully claimed'
                                : claimedCount >= claimLimit
                                ? 'Claim limit reached'
                                : points < cost
                                ? 'Need ${cost - points} more points'
                                : 'Claim for $cost points',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
