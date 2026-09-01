part of '../vendor_pages.dart';

class VendorVoucherHistoryPage extends StatelessWidget {
  const VendorVoucherHistoryPage({
    super.key,
    required this.voucherId,
    required this.voucherTitle,
  });

  final String voucherId;
  final String voucherTitle;

  String _status(Map<String, dynamic> claim) {
    if (claim['status'] == 'redeemed') return 'Redeemed successfully';
    final expiry = asDate(claim['expiresAt']);
    if (expiry != null && !expiry.isAfter(DateTime.now())) {
      return 'Expired before redemption';
    }
    return 'Claimed and awaiting redemption';
  }

  ExplorerStatusTone _tone(String status) => switch (status) {
    'Redeemed successfully' => ExplorerStatusTone.success,
    'Expired before redemption' => ExplorerStatusTone.danger,
    _ => ExplorerStatusTone.navy,
  };

  @override
  Widget build(BuildContext context) {
    final vendorId = AppServices.auth.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Voucher Activity')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppServices.db
            .collection('claimed_vouchers')
            .where('vendorId', isEqualTo: vendorId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ExplorerEmptyState(
              title: 'Unable to load voucher activity',
              subtitle: 'Check your connection and try again.',
              icon: Icons.cloud_off_outlined,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final claims =
              snapshot.data!.docs
                  .where((doc) => doc.data()['voucherId'] == voucherId)
                  .toList()
                ..sort(
                  (a, b) => (asDate(b.data()['claimedAt']) ?? DateTime(2000))
                      .compareTo(
                        asDate(a.data()['claimedAt']) ?? DateTime(2000),
                      ),
                );
          final redeemed = claims
              .where((doc) => doc.data()['status'] == 'redeemed')
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
            children: [
              Text(
                voucherTitle,
                style: const TextStyle(
                  color: ExplorerColors.navy,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Claim and redemption history for this published voucher.',
                style: TextStyle(color: ExplorerColors.muted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _VendorStat(
                      value: '${claims.length}',
                      label: 'TOTAL\nCLAIMS',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _VendorStat(
                      value: '$redeemed',
                      label: 'SUCCESSFUL\nREDEMPTIONS',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (claims.isEmpty)
                const ExplorerEmptyState(
                  title: 'No claims for this voucher yet',
                  subtitle:
                      'Tourist claims and completed redemptions will appear here.',
                  icon: Icons.history,
                )
              else
                ...claims.asMap().entries.map((entry) {
                  final claim = entry.value.data();
                  final status = _status(claim);
                  final claimedAt = asDate(claim['claimedAt']);
                  final redeemedAt = asDate(claim['redeemedAt']);
                  final method = '${claim['redemptionMethod'] ?? ''}';
                  final touristName = '${claim['travelerName'] ?? ''}'.trim();
                  final ownerLabel = touristName.isEmpty
                      ? 'Tourist claim ${entry.key + 1}'
                      : touristName;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ExplorerCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ownerLabel,
                                  style: const TextStyle(
                                    color: ExplorerColors.navy,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              ExplorerStatusBadge(
                                label: status.toUpperCase(),
                                tone: _tone(status),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          if (claimedAt != null)
                            Text(
                              'Claimed on ${DateFormat.yMMMd().add_jm().format(claimedAt)}',
                            ),
                          if (redeemedAt != null)
                            Text(
                              'Redeemed on ${DateFormat.yMMMd().add_jm().format(redeemedAt)}${method.isEmpty ? '' : ' using ${method == 'qr' ? 'the QR code' : 'the 6-digit PIN'}'}',
                            ),
                          if (claim['status'] != 'redeemed')
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'No redemption has been completed for this claim.',
                                style: TextStyle(color: ExplorerColors.muted),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
