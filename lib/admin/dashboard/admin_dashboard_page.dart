part of '../admin_pages.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final metrics = <({String label, IconData icon, Query<Map<String, dynamic>> query})>[
      (
        label: 'Registered Tourists',
        icon: Icons.explore_outlined,
        query: AppServices.db.collection('users').where('role', isEqualTo: 'traveler'),
      ),
      (
        label: 'Approved Vendors',
        icon: Icons.storefront_outlined,
        query: AppServices.db
            .collection('users')
            .where('role', isEqualTo: 'vendor')
            .where('vendorStatus', isEqualTo: 'verified'),
      ),
      (
        label: 'Pending Actions',
        icon: Icons.pending_actions_outlined,
        query: AppServices.db
            .collection('task_submissions')
            .where('status', isEqualTo: 'pending'),
      ),
      (
        label: 'Active Hazards',
        icon: Icons.health_and_safety_outlined,
        query: AppServices.db
            .collection('hazards')
            .where('status', whereIn: ['pending', 'verified']),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const ExplorerAdminPageTitle(
          title: 'Dashboard Overview',
          subtitle:
              'Monitor platform activity, moderation queues and critical system events.',
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: metrics.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: columns == 4 ? 1.75 : 2.2,
              ),
              itemBuilder: (context, index) {
                final metric = metrics[index];
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: metric.query.snapshots(),
                  builder: (context, snapshot) => ExplorerMetricCard(
                    label: metric.label,
                    value: '${snapshot.data?.docs.length ?? 0}',
                    icon: metric.icon,
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1050;
            final pending = _PendingAdminActions();
            final activity = _AdminRecentActivity();
            if (!wide) {
              return Column(
                children: [
                  pending,
                  const SizedBox(height: 20),
                  activity,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: pending),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: activity),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PendingAdminActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExplorerSectionTitle(
          'Pending Admin Actions',
          subtitle: 'Items requiring immediate review.',
        ),
        const SizedBox(height: 10),
        ExplorerCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _DashboardQueueRow(
                icon: Icons.storefront_outlined,
                title: 'Vendor applications',
                subtitle: 'Business registrations awaiting approval',
                query: AppServices.db
                    .collection('users')
                    .where('role', isEqualTo: 'vendor')
                    .where('vendorStatus', isEqualTo: 'pending'),
                tone: ExplorerStatusTone.warning,
              ),
              const Divider(height: 1),
              _DashboardQueueRow(
                icon: Icons.camera_alt_outlined,
                title: 'Cultural task submissions',
                subtitle: 'Tourist evidence awaiting moderation',
                query: AppServices.db
                    .collection('task_submissions')
                    .where('status', isEqualTo: 'pending'),
                tone: ExplorerStatusTone.navy,
              ),
              const Divider(height: 1),
              _DashboardQueueRow(
                icon: Icons.warning_amber_rounded,
                title: 'Hazard verification',
                subtitle: 'Community reports requiring validation',
                query: AppServices.db
                    .collection('hazards')
                    .where('status', isEqualTo: 'pending'),
                tone: ExplorerStatusTone.danger,
              ),
              const Divider(height: 1),
              _DashboardQueueRow(
                icon: Icons.flag_outlined,
                title: 'Flagged reviews',
                subtitle: 'Suspicious reviews in the moderation queue',
                query: AppServices.db
                    .collection('reviews')
                    .where('status', isEqualTo: 'flagged'),
                tone: ExplorerStatusTone.warning,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardQueueRow extends StatelessWidget {
  const _DashboardQueueRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.query,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Query<Map<String, dynamic>> query;
  final ExplorerStatusTone tone;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: ExplorerColors.navySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: ExplorerColors.navy, size: 20),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              ExplorerStatusBadge(
                label: '$count PENDING',
                tone: count == 0 ? ExplorerStatusTone.success : tone,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminRecentActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExplorerSectionTitle(
          'Recent System Activity',
          subtitle: 'Latest platform notifications.',
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: AppServices.db.collection('notifications').limit(30).snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs.toList() ?? [];
            docs.sort(
              (a, b) => (asDate(b.data()['createdAt']) ?? DateTime(2000))
                  .compareTo(asDate(a.data()['createdAt']) ?? DateTime(2000)),
            );
            return ExplorerCard(
              padding: EdgeInsets.zero,
              child: docs.isEmpty
                  ? const ExplorerEmptyState(
                      title: 'No recent activity',
                      subtitle: 'New system activity will appear here.',
                    )
                  : Column(
                      children: docs.take(6).map((doc) {
                        final data = doc.data();
                        final createdAt = asDate(data['createdAt']);
                        return Column(
                          children: [
                            ListTile(
                              dense: true,
                              leading: const CircleAvatar(
                                radius: 18,
                                backgroundColor: ExplorerColors.goldSoft,
                                foregroundColor: ExplorerColors.goldDark,
                                child: Icon(Icons.notifications_none, size: 18),
                              ),
                              title: Text(
                                '${data['title'] ?? 'System update'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ExplorerColors.navy,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                createdAt == null
                                    ? '${data['message'] ?? ''}'
                                    : '${data['message'] ?? ''}\n${DateFormat.yMMMd().add_jm().format(createdAt)}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                            if (doc != docs.take(6).last) const Divider(height: 1),
                          ],
                        );
                      }).toList(),
                    ),
            );
          },
        ),
      ],
    );
  }
}
