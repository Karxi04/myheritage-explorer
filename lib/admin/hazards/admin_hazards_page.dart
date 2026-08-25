part of '../admin_pages.dart';

class AdminHazardsPage extends StatefulWidget {
  const AdminHazardsPage({super.key});

  @override
  State<AdminHazardsPage> createState() => _AdminHazardsPageState();
}

class _AdminHazardsPageState extends State<AdminHazardsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _reportService = HazardReportService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HazardReport>>(
      stream: _reportService.watchAllReports(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ExplorerEmptyState(
            title: 'Unable to load hazard reports',
            subtitle: '${snapshot.error}',
            icon: Icons.cloud_off_outlined,
          );
        }
        final reports = snapshot.data ?? const [];
        final pending = reports
            .where((r) => r.status == HazardReportStatus.pendingReview)
            .length;
        final verified = reports
            .where((r) => r.status == HazardReportStatus.verified)
            .length;
        final resolved = reports
            .where((r) => r.status == HazardReportStatus.resolved)
            .length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExplorerAdminPageTitle(
                    title: 'Safety & Hazard',
                    subtitle:
                        'Review pending hazard reports and manage verified danger zones.',
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: ExplorerMetricCard(
                          label: 'Pending Review',
                          value: '$pending',
                          icon: Icons.pending_actions_outlined,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ExplorerMetricCard(
                          label: 'Verified Hazards',
                          value: '$verified',
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ExplorerMetricCard(
                          label: 'Resolved Reports',
                          value: '$resolved',
                          icon: Icons.task_alt_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TabBar(
                    controller: _tabController,
                    labelColor: ExplorerColors.navy,
                    indicatorColor: ExplorerColors.gold,
                    tabs: const [
                      Tab(text: 'Pending Hazard Reports'),
                      Tab(text: 'Verified Hazard Reports'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  AdminPendingReportsTab(),
                  AdminVerifiedReportsTab(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
