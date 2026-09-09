part of '../admin_pages.dart';

class AdminPendingReportsTab extends StatefulWidget {
  const AdminPendingReportsTab({super.key, this.reportService});

  final HazardReportService? reportService;

  @override
  State<AdminPendingReportsTab> createState() => _AdminPendingReportsTabState();
}

class _AdminPendingReportsTabState extends State<AdminPendingReportsTab> {
  late final _reportService = widget.reportService ?? HazardReportService();
  late var _reportsStream = _reportService.watchPendingReports();

  void _openReport(HazardReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminHazardManagementPage(hazardId: report.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HazardReport>>(
      stream: _reportsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SafetyErrorState(
            title: 'Unable to load pending reports',
            message: friendlySafetyError(
              snapshot.error,
              subject: 'pending hazard reports',
            ),
            onRetry: () => setState(
              () => _reportsStream = _reportService.watchPendingReports(),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SafetyLoadingState(label: 'Loading pending reports…');
        }

        final reports = snapshot.data!;
        if (reports.isEmpty) {
          return const ExplorerCard(
            child: ExplorerEmptyState(
              title: 'No pending hazard reports',
              subtitle: 'All submitted reports have been reviewed.',
              icon: Icons.pending_actions_outlined,
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final report = reports[index];
            return _AdminHazardListCard(
              report: report,
              statusLabel: 'PENDING REVIEW',
              statusTone: ExplorerStatusTone.warning,
              actionLabel: 'Review Report',
              actionIcon: Icons.rate_review_outlined,
              onAction: () => _openReport(report),
              formattedDate: _formatHazardDate(report.createdAt),
            );
          },
        );
      },
    );
  }
}
