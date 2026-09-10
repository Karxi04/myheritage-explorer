part of '../admin_pages.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Header Banner & Live Status Bar
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Dashboard & System Overview',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: ExplorerColors.navy,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Real-time management of platform accounts, vendor verifications, safety hazards, and cultural experience moderation.',
                    style: TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: AppServices.db
                  .collection('emergency_alerts')
                  .where('status', isEqualTo: 'active')
                  .snapshots(),
              builder: (context, snapshot) {
                final activeSosCount = snapshot.data?.docs.length ?? 0;
                final isCritical = activeSosCount > 0;

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCritical
                        ? ExplorerColors.dangerSoft
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCritical
                          ? ExplorerColors.danger
                          : const Color(0xFF10B981),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCritical ? Icons.sos : Icons.check_circle_outline,
                        color: isCritical
                            ? ExplorerColors.danger
                            : const Color(0xFF059669),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCritical
                                ? '$activeSosCount Emergency SOS Active'
                                : 'Emergency System Clear',
                            style: TextStyle(
                              color: isCritical
                                  ? ExplorerColors.danger
                                  : const Color(0xFF047857),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            isCritical ? 'Immediate Action' : '0 Emergency Alerts',
                            style: TextStyle(
                              color: isCritical
                                  ? ExplorerColors.danger
                                  : const Color(0xFF059669),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 28),

        // SECTION 1: ACTION REQUIRED (PENDING MODERATION QUEUES)
        const Text(
          'PENDING ACTION QUEUES',
          style: TextStyle(
            color: ExplorerColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 12),

        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width > 1200 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 2.3,
          children: [
            _dashboardMetricCard(
              label: 'Vendor Verification Approvals',
              badge: 'Requires Review',
              icon: Icons.storefront_outlined,
              iconBg: ExplorerColors.goldSoft,
              iconFg: ExplorerColors.goldDark,
              accentColor: ExplorerColors.goldDark,
              query: AppServices.db
                  .collection('vendors')
                  .where('vendorStatus', isEqualTo: 'pending'),
            ),
            _dashboardMetricCard(
              label: 'Pending Hazard Reports',
              badge: 'Needs Inspection',
              icon: Icons.warning_amber_rounded,
              iconBg: const Color(0xFFFFF3E0),
              iconFg: const Color(0xFFE65100),
              accentColor: const Color(0xFFE65100),
              query: AppServices.db
                  .collection('hazards')
                  .where('status', isEqualTo: 'pending'),
            ),
            _dashboardMetricCard(
              label: 'User & Vendor Reports',
              badge: 'Moderation Needed',
              icon: Icons.report_problem_outlined,
              iconBg: ExplorerColors.dangerSoft,
              iconFg: ExplorerColors.danger,
              accentColor: ExplorerColors.danger,
              query: AppServices.db
                  .collection('reports')
                  .where('status', isEqualTo: 'pending'),
            ),
            _dashboardMetricCard(
              label: 'Flagged Community Reviews',
              badge: 'AI Moderated',
              icon: Icons.flag_outlined,
              iconBg: const Color(0xFFFCE4EC),
              iconFg: const Color(0xFFC2185B),
              accentColor: const Color(0xFFC2185B),
              query: AppServices.db
                  .collection('reviews')
                  .where('status', isEqualTo: 'flagged'),
            ),
            _dashboardMetricCard(
              label: 'Pending Cultural Proofs',
              badge: 'Photo Verification',
              icon: Icons.camera_alt_outlined,
              iconBg: ExplorerColors.navySoft,
              iconFg: ExplorerColors.navy,
              accentColor: ExplorerColors.navy,
              query: AppServices.db
                  .collection('task_submissions')
                  .where('status', isEqualTo: 'pending'),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // SECTION 2: PLATFORM ECOSYSTEM & ACCOUNTS
        const Text(
          'PLATFORM ACCOUNT ECOSYSTEM',
          style: TextStyle(
            color: ExplorerColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 12),

        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width > 1200 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 2.3,
          children: [
            _dashboardMetricCard(
              label: 'Registered Tourists / Travelers',
              badge: 'Active Travelers',
              icon: Icons.explore_outlined,
              iconBg: ExplorerColors.navySoft,
              iconFg: ExplorerColors.navy,
              accentColor: ExplorerColors.navy,
              query: AppServices.db.collection('travelers'),
            ),
            _dashboardMetricCard(
              label: 'Total Platform Vendors',
              badge: 'Business Ecosystem',
              icon: Icons.storefront,
              iconBg: ExplorerColors.goldSoft,
              iconFg: ExplorerColors.goldDark,
              accentColor: ExplorerColors.goldDark,
              query: AppServices.db.collection('vendors'),
            ),
            _dashboardMetricCard(
              label: 'Platform Administrators',
              badge: 'Security Access',
              icon: Icons.admin_panel_settings_outlined,
              iconBg: const Color(0xFFF3E5F5),
              iconFg: const Color(0xFF7B1FA2),
              accentColor: const Color(0xFF7B1FA2),
              query: AppServices.db.collection('admins'),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // SECTION 3: RECENT PLATFORM AUDIT & ACTIVITY STREAM
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'RECENT PLATFORM ACTIVITY & AUDIT STREAM',
              style: TextStyle(
                color: ExplorerColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
              ),
            ),
            Text(
              'Live Firestore Stream',
              style: TextStyle(
                color: ExplorerColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: AppServices.db
              .collection('notifications')
              .limit(25)
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
              return emptyState('No platform activity records found.');
            }

            return Column(
              children: docs.take(8).map((doc) {
                final data = doc.data();
                final title = '${data['title'] ?? 'Platform Event'}';
                final message = '${data['message'] ?? ''}';
                final type = '${data['type'] ?? 'general'}'.toLowerCase();
                final date = asDate(data['createdAt']);

                final (icon, color) = switch (type) {
                  'hazard' || 'danger' => (Icons.warning_amber_rounded, Colors.orange),
                  'vendor' || 'business' => (Icons.storefront, ExplorerColors.goldDark),
                  'sos' || 'emergency' => (Icons.sos, Colors.red),
                  'report' || 'flag' => (Icons.flag_outlined, Colors.purple),
                  _ => (Icons.notifications_none_rounded, ExplorerColors.navy),
                };

                return ExplorerCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.12),
                      foregroundColor: color,
                      child: Icon(icon, size: 22),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: ExplorerColors.navy,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ExplorerColors.muted,
                            height: 1.3,
                          ),
                        ),
                        if (date != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            DateFormat.yMMMd().add_jm().format(date),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF98A2B3),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _dashboardMetricCard({
    required String label,
    required String badge,
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required Color accentColor,
    required Query<Map<String, dynamic>> query,
  }) {
    return ExplorerCard(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
          final isPendingAlert = badge.contains('Review') ||
              badge.contains('Inspection') ||
              badge.contains('Moderation') ||
              badge.contains('Action');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: iconBg,
                    foregroundColor: iconFg,
                    child: Icon(icon, size: 20),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isPendingAlert && count > 0)
                          ? accentColor.withOpacity(0.12)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: (isPendingAlert && count > 0)
                            ? accentColor
                            : ExplorerColors.muted,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: (isPendingAlert && count > 0)
                      ? accentColor
                      : ExplorerColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: ExplorerColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
