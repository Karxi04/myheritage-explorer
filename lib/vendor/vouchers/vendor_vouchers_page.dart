
part of '../vendor_pages.dart';

class VendorVouchersPage extends StatefulWidget {
  const VendorVouchersPage({super.key});

  @override
  State<VendorVouchersPage> createState() => _VendorVouchersPageState();
}

class _VendorVouchersPageState extends State<VendorVouchersPage> {
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const ExplorerBrand(compact: true),
        actions: [
          IconButton(
            tooltip: 'Create voucher',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VoucherEditorPage(),
              ),
            ),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const VoucherEditorPage(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Voucher'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppServices.db
            .collection('vouchers')
            .where('vendorId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs.toList()
            ..sort(
              (a, b) => (asDate(b.data()['createdAt']) ?? DateTime(2000))
                  .compareTo(
                asDate(a.data()['createdAt']) ?? DateTime(2000),
              ),
            );

          final filtered = docs.where((doc) {
            final data = doc.data();
            final expiry = asDate(data['expiresAt']);
            return switch (filter) {
              'Active' => data['status'] == 'active' &&
                  (expiry == null || expiry.isAfter(DateTime.now())),
              'Inactive' => data['status'] != 'active',
              'Expired' =>
                expiry != null && expiry.isBefore(DateTime.now()),
              _ => true,
            };
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
            children: [
              const Text(
                'Published Rewards Management',
                style: TextStyle(
                  color: ExplorerColors.navy,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Create, edit and monitor voucher availability.',
                style: TextStyle(
                  color: ExplorerColors.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['All', 'Active', 'Inactive', 'Expired']
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(item),
                            selected: filter == item,
                            onSelected: (_) =>
                                setState(() => filter = item),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const ExplorerEmptyState(
                  title: 'No published vouchers',
                  subtitle:
                      'Create your first reward for MyHeritage explorers.',
                  icon: Icons.confirmation_number_outlined,
                )
              else
                ...filtered.map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _voucherCard(
                      context,
                      doc,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _voucherCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final expiry = asDate(data['expiresAt']);
    final expired =
        expiry != null && expiry.isBefore(DateTime.now());
    final active = data['status'] == 'active' && !expired;
    final remaining = data['inventoryRemaining'] ?? 0;
    final limit = data['inventoryLimit'] ?? 0;

    return ExplorerCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            height: 92,
            decoration: BoxDecoration(
              color: active
                  ? ExplorerColors.goldSoft
                  : ExplorerColors.subtle,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Center(
              child: Icon(
                Icons.local_activity_outlined,
                color: active
                    ? ExplorerColors.goldDark
                    : ExplorerColors.muted,
                size: 42,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 10, 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ExplorerStatusBadge(
                            label: expired
                                ? 'EXPIRED'
                                : active
                                    ? 'ACTIVE'
                                    : 'INACTIVE',
                            tone: expired
                                ? ExplorerStatusTone.danger
                                : active
                                    ? ExplorerStatusTone.success
                                    : ExplorerStatusTone.neutral,
                          ),
                          const Spacer(),
                          Text(
                            '${data['pointCost'] ?? 0} pts',
                            style: const TextStyle(
                              color: ExplorerColors.goldDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${data['title'] ?? 'Voucher'}',
                        style: const TextStyle(
                          color: ExplorerColors.navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${data['description'] ?? ''}',
                        style: const TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$remaining/$limit remaining • ${data['claimCount'] ?? 0} claimed'
                        '${expiry == null ? '' : ' • ${DateFormat.yMMMd().format(expiry)}'}',
                        style: const TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VoucherEditorPage(
                            voucherId: doc.id,
                            voucher: data,
                          ),
                        ),
                      );
                    } else {
                      await doc.reference.update({
                        'status': value,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Voucher'),
                    ),
                    PopupMenuItem(
                      value:
                          data['status'] == 'active' ? 'inactive' : 'active',
                      child: Text(
                        data['status'] == 'active'
                            ? 'Deactivate'
                            : 'Activate',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
