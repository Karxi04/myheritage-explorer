part of '../admin_pages.dart';

class AdminHazardsPage extends StatefulWidget {
  const AdminHazardsPage({
    super.key,
    this.initialStatusFilter,
    this.reportService,
    this.voteService,
  });

  final String? initialStatusFilter;
  final HazardReportService? reportService;
  final HazardVoteService? voteService;

  @override
  State<AdminHazardsPage> createState() => _AdminHazardsPageState();
}

int _statusToHazardTabIndex(String? status) {
  if (status == null) return 0;
  final lower =
      status.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  return switch (lower) {
    'pending' || 'pending_review' || 'pendingreview' => 0,
    'verified' => 1,
    'resolved' => 2,
    'rejected' => 3,
    _ => 0,
  };
}

class _AdminHazardsPageState extends State<AdminHazardsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final _reportService = widget.reportService ?? HazardReportService();
  late final _reportsStream = _reportService.watchAllReports();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _statusToHazardTabIndex(widget.initialStatusFilter);
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: _selectedIndex,
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_selectedIndex != _tabController.index) {
      setState(() {
        _selectedIndex = _tabController.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    _tabController.animateTo(index);
    setState(() {
      _selectedIndex = index;
    });
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
                    selectedIndex: _selectedIndex,
                    onSelectTab: _selectTab,
                  ),
                  const SizedBox(height: 18),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: ExplorerColors.navy,
                    indicatorColor: ExplorerColors.gold,
                    tabs: [
                      Tab(text: 'Pending Reports ($pending)'),
                      Tab(text: 'Verified Hazards ($verified)'),
                      Tab(text: 'Resolved Reports ($resolved)'),
                      Tab(text: 'Rejected Reports ($rejected)'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  AdminPendingReportsTab(reportService: _reportService),
                  AdminVerifiedReportsTab(
                    reportService: _reportService,
                    voteService: widget.voteService,
                  ),
                  AdminHazardStatusListTab(
                    status: HazardReportStatus.resolved,
                    title: 'Resolved Reports',
                    emptyTitle: 'No resolved hazards',
                    emptySubtitle:
                        'Resolved hazard reports will be archived here.',
                    statusLabel: 'RESOLVED',
                    statusTone: ExplorerStatusTone.neutral,
                    reportService: _reportService,
                  ),
                  AdminHazardStatusListTab(
                    status: HazardReportStatus.rejected,
                    title: 'Rejected Reports',
                    emptyTitle: 'No rejected reports',
                    emptySubtitle:
                        'Rejected hazard reports will appear here for audit purposes.',
                    statusLabel: 'REJECTED',
                    statusTone: ExplorerStatusTone.danger,
                    reportService: _reportService,
                  ),
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
    required this.selectedIndex,
    required this.onSelectTab,
  });

  final int pending;
  final int verified;
  final int resolved;
  final int rejected;
  final int selectedIndex;
  final ValueChanged<int> onSelectTab;

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
            isSelected: selectedIndex == 0,
            onTap: () => onSelectTab(0),
          ),
          ExplorerMetricCard(
            label: 'Verified Hazards',
            value: '$verified',
            icon: Icons.warning_amber_rounded,
            isSelected: selectedIndex == 1,
            onTap: () => onSelectTab(1),
          ),
          ExplorerMetricCard(
            label: 'Resolved Reports',
            value: '$resolved',
            icon: Icons.task_alt_outlined,
            isSelected: selectedIndex == 2,
            onTap: () => onSelectTab(2),
          ),
          ExplorerMetricCard(
            label: 'Rejected Reports',
            value: '$rejected',
            icon: Icons.cancel_outlined,
            isSelected: selectedIndex == 3,
            onTap: () => onSelectTab(3),
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
