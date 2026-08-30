part of '../admin_pages.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool isSyncing = false;

  Future<void> _checkVendorData() async {
    setState(() => isSyncing = true);
    try {
      final vendorsSnapshot = await AppServices.db.collection('vendors').get();
      final vendors = vendorsSnapshot.docs.map((doc) => doc.data()).toList();
      final activeVendors = vendors
          .where((data) => '${data['status'] ?? ''}' == 'active')
          .length;
      final verifiedVendors = vendors
          .where((data) => '${data['vendorStatus'] ?? ''}' == 'verified')
          .length;
      final seededReviewSnapshot = await AppServices.db
          .collection('reviews')
          .where('source', isEqualTo: 'vendor_review_variation_seed_2026_08_29')
          .get();
      final reviewedVendorIds = seededReviewSnapshot.docs
          .map(
            (doc) => '${doc.data()['vendorId'] ?? doc.data()['placeId'] ?? ''}',
          )
          .where((id) => id.isNotEmpty)
          .toSet();
      if (mounted) {
        showMessage(
          context,
          'Vendor data ready: $verifiedVendors verified vendors, $activeVendors active vendors, ${reviewedVendorIds.length} vendors with varied reviews.',
        );
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          'Unable to check vendor data. Please refresh and sign in as administrator.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items =
        <({String label, IconData icon, Query<Map<String, dynamic>> query})>[
          (
            label: 'Administrators',
            icon: Icons.admin_panel_settings_outlined,
            query: AppServices.db.collection('admins'),
          ),
          (
            label: 'Travelers',
            icon: Icons.explore_outlined,
            query: AppServices.db.collection('travelers'),
          ),
          (
            label: 'All Vendors',
            icon: Icons.storefront_outlined,
            query: AppServices.db.collection('vendors'),
          ),
          (
            label: 'Pending vendors',
            icon: Icons.hourglass_top_outlined,
            query: AppServices.db
                .collection('vendors')
                .where('vendorStatus', isEqualTo: 'pending'),
          ),
          (
            label: 'Pending hazards',
            icon: Icons.warning_amber_outlined,
            query: AppServices.db
                .collection('hazards')
                .where('status', isEqualTo: 'pending'),
          ),
          (
            label: 'Flagged reviews',
            icon: Icons.flag_outlined,
            query: AppServices.db
                .collection('reviews')
                .where('status', isEqualTo: 'flagged'),
          ),
        ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Overview',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Administrators, travelers, vendors and reviews in Cloud Firestore.',
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ExplorerColors.navy,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              onPressed: isSyncing ? null : _checkVendorData,
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.fact_check_outlined, size: 18),
              label: Text(
                isSyncing ? 'Checking vendor data...' : 'Check Vendor Data',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width > 1200 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 2.2,
          children: items
              .map(
                (item) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 26, child: Icon(item.icon)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: item.query.snapshots(),
                                builder: (_, snapshot) => Text(
                                  '${snapshot.data?.docs.length ?? 0}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(item.label),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Recent activity',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: AppServices.db
              .collection('notifications')
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs.toList() ?? [];
            docs.sort(
              (first, second) =>
                  (asDate(second.data()['createdAt']) ?? DateTime(2000))
                      .compareTo(
                        asDate(first.data()['createdAt']) ?? DateTime(2000),
                      ),
            );

            if (docs.isEmpty) {
              return emptyState('No platform activity yet');
            }

            return Column(
              children: docs
                  .take(8)
                  .map(
                    (doc) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: Text(doc.data()['title'] ?? ''),
                        subtitle: Text(
                          '${doc.data()['message'] ?? ''}\n'
                          '${asDate(doc.data()['createdAt']) == null ? '' : DateFormat.yMMMd().add_jm().format(asDate(doc.data()['createdAt'])!)}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
