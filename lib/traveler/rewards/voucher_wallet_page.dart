part of '../traveler_pages.dart';

class VoucherWalletPage extends StatefulWidget {
  const VoucherWalletPage({super.key});

  @override
  State<VoucherWalletPage> createState() => _VoucherWalletPageState();
}

class _VoucherWalletPageState extends State<VoucherWalletPage> {
  String filter = 'All';
  final Set<String> revealedQrCodes = <String>{};

  String _displayStatus(Map<String, dynamic> claim) {
    if (claim['status'] == 'redeemed') return 'Redeemed';
    final expiry = asDate(claim['expiresAt']);
    if (expiry != null && !expiry.isAfter(DateTime.now())) return 'Expired';
    if (claim['status'] == 'claimed') return 'Active';
    final raw = '${claim['status'] ?? 'Unavailable'}';
    return raw.isEmpty
        ? 'Unavailable'
        : '${raw[0].toUpperCase()}${raw.substring(1)}';
  }

  ExplorerStatusTone _statusTone(String status) => switch (status) {
    'Active' => ExplorerStatusTone.success,
    'Redeemed' => ExplorerStatusTone.navy,
    'Expired' => ExplorerStatusTone.danger,
    _ => ExplorerStatusTone.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Digital Wallet'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Claimed Vouchers'),
              Tab(text: 'Available Rewards'),
            ],
          ),
        ),
        body: Column(
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: AppServices.travelerRef(uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Card(
                      child: ListTile(
                        leading: Icon(Icons.cloud_off_outlined),
                        title: Text('Unable to load wallet data'),
                        subtitle: Text('Please check your connection.'),
                      ),
                    ),
                  );
                }

                final points =
                    (snapshot.data?.data()?['points'] as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.stars_rounded),
                      ),
                      title: const Text(
                        'Your reward points',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: snapshot.hasData
                          ? Text(
                              '$points pts',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildClaimedVouchers(uid),
                  const RewardsPage(embedded: true, showPointsSummary: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimedVouchers(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db
          .collection('claimed_vouchers')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return emptyState('Unable to load your voucher wallet');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data!.docs.toList()
          ..sort(
            (a, b) => (asDate(b.data()['claimedAt']) ?? DateTime(2000))
                .compareTo(asDate(a.data()['claimedAt']) ?? DateTime(2000)),
          );
        final docs = allDocs.where((doc) {
          return filter == 'All' || _displayStatus(doc.data()) == filter;
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            const Text(
              'Claimed rewards and redemption history',
              style: TextStyle(color: ExplorerColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Active', 'Redeemed', 'Expired']
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(item),
                          selected: filter == item,
                          onSelected: (_) => setState(() => filter = item),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 44),
                child: emptyState(
                  allDocs.isEmpty
                      ? 'No claimed vouchers'
                      : 'No $filter vouchers',
                ),
              )
            else
              ...docs.map((doc) {
                final claim = doc.data();
                final status = _displayStatus(claim);
                final claimedAt = asDate(claim['claimedAt']);
                final redeemedAt = asDate(claim['redeemedAt']);
                final expiry = asDate(claim['expiresAt']);
                final token = '${claim['token'] ?? ''}'.trim();
                final canDisplayQr = status == 'Active' && token.isNotEmpty;
                final qrRevealed = revealedQrCodes.contains(doc.id);
                final vendorAddress = '${claim['vendorAddress'] ?? ''}'.trim();
                final location = claim['location'];
                final locationLabel = vendorAddress.isNotEmpty
                    ? vendorAddress
                    : location is GeoPoint
                    ? '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}'
                    : '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ExpansionTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.confirmation_number_outlined),
                      ),
                      title: Text('${claim['title'] ?? 'Voucher'}'),
                      subtitle: Text(
                        '${claim['vendorName'] ?? 'Registered vendor'} - ${claim['pointCost'] ?? 0} points',
                      ),
                      trailing: ExplorerStatusBadge(
                        label: status.toUpperCase(),
                        tone: _statusTone(status),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ('${claim['description'] ?? ''}'.trim().isNotEmpty)
                          Text('${claim['description']}'),
                        if (locationLabel.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Vendor location: $locationLabel'),
                        ],
                        if ('${claim['terms'] ?? ''}'.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Terms: ${claim['terms']}',
                            style: const TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          [
                            if (claimedAt != null)
                              'Claimed ${DateFormat.yMMMd().add_jm().format(claimedAt)}',
                            if (expiry != null)
                              'Expires ${DateFormat.yMMMd().add_jm().format(expiry)}',
                            if (redeemedAt != null)
                              'Redeemed ${DateFormat.yMMMd().add_jm().format(redeemedAt)}',
                          ].join('\n'),
                          style: const TextStyle(
                            color: ExplorerColors.muted,
                            fontSize: 11,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (canDisplayQr && !qrRevealed)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  setState(() => revealedQrCodes.add(doc.id)),
                              icon: const Icon(Icons.qr_code_2),
                              label: const Text('Redeem Voucher'),
                            ),
                          )
                        else if (canDisplayQr) ...[
                          const Center(
                            child: Text(
                              'Show this QR code to the vendor.',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: QrImageView(
                              data: '${doc.id}|$token',
                              size: 220,
                            ),
                          ),
                        ] else
                          Center(
                            child: Text(
                              status == 'Redeemed'
                                  ? 'This voucher has already been redeemed.'
                                  : status == 'Expired'
                                  ? 'This voucher expired before redemption.'
                                  : 'This voucher is unavailable.',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
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
    );
  }
}
