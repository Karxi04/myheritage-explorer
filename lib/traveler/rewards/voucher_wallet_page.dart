
part of '../traveler_pages.dart';

class VoucherWalletPage extends StatelessWidget {
  const VoucherWalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const Text('Voucher Wallet')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppServices.db
            .collection('claimed_vouchers')
            .where('userId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.toList()
            ..sort(
              (a, b) =>
                  (asDate(b.data()['claimedAt']) ?? DateTime(2000))
                      .compareTo(
                asDate(a.data()['claimedAt']) ?? DateTime(2000),
              ),
            );

          if (docs.isEmpty) {
            return const ExplorerEmptyState(
              title: 'No claimed vouchers',
              subtitle:
                  'Claim an active reward and it will appear in your wallet.',
              icon: Icons.account_balance_wallet_outlined,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            children: [
              const ExplorerSectionTitle(
                'My Reward Vouchers',
                subtitle:
                    'Present the QR code to the vendor during checkout.',
              ),
              const SizedBox(height: 12),
              ...docs.map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _claimCard(doc),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _claimCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final claim = doc.data();
    final status = '${claim['status'] ?? 'claimed'}';
    final active = status == 'claimed';
    final expiry = asDate(claim['expiresAt']);

    return ExplorerCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 7,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: active
                ? ExplorerColors.goldSoft
                : ExplorerColors.subtle,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.local_activity_outlined,
            color: active
                ? ExplorerColors.goldDark
                : ExplorerColors.muted,
          ),
        ),
        title: Text(
          '${claim['title'] ?? 'Voucher'}',
          style: const TextStyle(
            color: ExplorerColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${claim['pointCost'] ?? 0} points'
          '${expiry == null ? '' : ' • ${DateFormat.yMMMd().format(expiry)}'}',
          style: const TextStyle(
            color: ExplorerColors.muted,
            fontSize: 10,
          ),
        ),
        trailing: ExplorerStatusBadge(
          label: status.toUpperCase(),
          tone: active
              ? ExplorerStatusTone.success
              : ExplorerStatusTone.neutral,
        ),
        children: [
          if (active) ...[
            const Text(
              'Scan at checkout',
              style: TextStyle(
                color: ExplorerColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ExplorerColors.border),
              ),
              child: QrImageView(
                data: '${doc.id}|${claim['token']}',
                size: 210,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'CODE: ${doc.id.toUpperCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ExplorerColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'This voucher has already been redeemed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ExplorerColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}
