part of '../admin_pages.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

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
            label: 'Pending vendors',
            icon: Icons.storefront_outlined,
            query: AppServices.db
                .collection('vendors')
                .where('vendorStatus', isEqualTo: 'pending'),
          ),
          (
            label: 'Pending hazards',
            icon: Icons.warning_amber_outlined,
            query: AppServices.db
                .collection('hazard_reports')
                .where('status', isEqualTo: HazardReportStatus.pendingReview),
          ),
          (
            label: 'Pending tasks',
            icon: Icons.camera_alt_outlined,
            query: AppServices.db
                .collection('task_submissions')
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
        const Text(
          'System Overview',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Administrators, travelers and vendors are stored separately.',
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
