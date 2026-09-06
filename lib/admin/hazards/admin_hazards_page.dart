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
  late final _reportsStream = _reportService.watchAllReports();

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
      stream: _reportsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ExplorerEmptyState(
            title: 'Unable to load hazard reports',
            subtitle: friendlySafetyError(
              snapshot.error,
              subject: 'hazard reports',
            ),
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
        final rejected = reports
            .where((r) => r.status == HazardReportStatus.rejected)
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
                  _AdminHazardMetricGrid(
                    pending: pending,
                    verified: verified,
                    resolved: resolved,
                    rejected: rejected,
                  ),
                  const SizedBox(height: 18),
                  TabBar(
                    controller: _tabController,
                    labelColor: ExplorerColors.navy,
                    indicatorColor: ExplorerColors.gold,
                    tabs: [
                      Tab(text: 'Pending Reports ($pending)'),
                      Tab(text: 'Verified Hazards ($verified)'),
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

class _AdminHazardMetricGrid extends StatelessWidget {
  const _AdminHazardMetricGrid({
    required this.pending,
    required this.verified,
    required this.resolved,
    required this.rejected,
  });

  final int pending;
  final int verified;
  final int resolved;
  final int rejected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 4
            : constraints.maxWidth >= 480
            ? 2
            : 2;
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
        final cards = [
          ExplorerMetricCard(
            label: 'Pending Review',
            value: '$pending',
            icon: Icons.pending_actions_outlined,
          ),
          ExplorerMetricCard(
            label: 'Verified Hazards',
            value: '$verified',
            icon: Icons.warning_amber_rounded,
          ),
          ExplorerMetricCard(
            label: 'Resolved Reports',
            value: '$resolved',
            icon: Icons.task_alt_outlined,
          ),
          ExplorerMetricCard(
            label: 'Rejected Reports',
            value: '$rejected',
            icon: Icons.cancel_outlined,
          ),
        ];
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}
