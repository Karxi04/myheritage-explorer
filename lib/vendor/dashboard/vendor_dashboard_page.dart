part of '../vendor_pages.dart';

class VendorDashboardPage extends StatelessWidget {
  const VendorDashboardPage({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const ExplorerBrand(compact: true),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 15,
              backgroundColor: ExplorerColors.successSoft,
              foregroundColor: ExplorerColors.success,
              child: Text(
                '${profile['businessName'] ?? 'V'}'.trim().isEmpty
                    ? 'V'
                    : '${profile['businessName'] ?? 'V'}'
                          .trim()[0]
                          .toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          Text(
            '${profile['businessName'] ?? 'Verified Vendor'}',
            style: const TextStyle(
              color: ExplorerColors.navy,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              letterSpacing: -.45,
            ),
          ),
          const SizedBox(height: 7),
          const ExplorerStatusBadge(
            label: 'APPROVED',
            tone: ExplorerStatusTone.success,
            icon: Icons.verified,
          ),
          const SizedBox(height: 9),
          const Text(
            'Manage your vendor profile and track active vouchers.',
            style: TextStyle(color: ExplorerColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          ExplorerCard(
            backgroundColor: ExplorerColors.navy,
            borderColor: ExplorerColors.navy,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VendorQrScannerPage()),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 13),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan QR Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Verify and redeem Tourist vouchers instantly.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 11),
          ExplorerCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VoucherEditorPage()),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: ExplorerColors.navySoft,
                  child: Icon(
                    Icons.add_circle_outline,
                    color: ExplorerColors.navy,
                  ),
                ),
                SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Voucher',
                        style: TextStyle(
                          color: ExplorerColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Design new offers for explorers.',
                        style: TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: ExplorerColors.muted),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const ExplorerSectionTitle('Quick Stats'),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: AppServices.db
                .collection('vouchers')
                .where('vendorId', isEqualTo: uid)
                .snapshots(),
            builder: (context, voucherSnapshot) {
              final vouchers = voucherSnapshot.data?.docs ?? const [];
              final active = vouchers
                  .where((doc) => doc.data()['status'] == 'active')
                  .length;
              final claimed = vouchers.fold<num>(
                0,
                (sum, doc) => sum + ((doc.data()['claimCount'] ?? 0) as num),
              );

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppServices.db
                    .collection('redemptions')
                    .where('vendorId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, redemptionSnapshot) {
                  final redeemed = redemptionSnapshot.data?.docs.length ?? 0;
                  return Row(
                    children: [
                      Expanded(
                        child: _VendorStat(
                          value: '$active',
                          label: 'ACTIVE\nVOUCHERS',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _VendorStat(
                          value: '$claimed',
                          label: 'TOTAL\nCLAIMED',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _VendorStat(
                          value: '$redeemed',
                          label: 'TOTAL\nREDEEMED',
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 22),
          const ExplorerSectionTitle('Voucher Claim & Redemption History'),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: AppServices.db
                .collection('vouchers')
                .where('vendorId', isEqualTo: uid)
                .snapshots(),
            builder: (context, voucherSnapshot) {
              if (!voucherSnapshot.hasData) {
                return const ExplorerCard(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              }

              final vouchers = voucherSnapshot.data!.docs.toList()
                ..sort(
                  (a, b) => (asDate(b.data()['createdAt']) ?? DateTime(2000))
                      .compareTo(
                        asDate(a.data()['createdAt']) ?? DateTime(2000),
                      ),
                );

              if (vouchers.isEmpty) {
                return const ExplorerEmptyState(
                  title: 'No published vouchers yet',
                  subtitle:
                      'Publish a voucher to begin tracking claims and redemptions.',
                  icon: Icons.confirmation_number_outlined,
                );
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppServices.db
                    .collection('claimed_vouchers')
                    .where('vendorId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, claimSnapshot) {
                  final claims = claimSnapshot.data?.docs ?? const [];
                  return Column(
                    children: vouchers.map((voucherDoc) {
                      final voucherClaims = claims
                          .where(
                            (claim) =>
                                claim.data()['voucherId'] == voucherDoc.id,
                          )
                          .toList();
                      final redeemed = voucherClaims
                          .where(
                            (claim) => claim.data()['status'] == 'redeemed',
                          )
                          .length;
                      final title =
                          '${voucherDoc.data()['title'] ?? 'Published voucher'}';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: ExplorerCard(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VendorVoucherHistoryPage(
                                voucherId: voucherDoc.id,
                                voucherTitle: title,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: ExplorerColors.goldSoft,
                                foregroundColor: ExplorerColors.goldDark,
                                child: Icon(Icons.history),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: ExplorerColors.navy,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${voucherClaims.length} claims • $redeemed redeemed',
                                      style: const TextStyle(
                                        color: ExplorerColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VendorStat extends StatelessWidget {
  const _VendorStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ExplorerCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: ExplorerColors.navy,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ExplorerColors.muted,
              fontSize: 8,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
