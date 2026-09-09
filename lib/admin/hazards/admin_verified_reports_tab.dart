part of '../admin_pages.dart';

class AdminVerifiedReportsTab extends StatefulWidget {
  const AdminVerifiedReportsTab({
    super.key,
    this.reportService,
    this.voteService,
  });

  final HazardReportService? reportService;
  final HazardVoteService? voteService;

  @override
  State<AdminVerifiedReportsTab> createState() =>
      _AdminVerifiedReportsTabState();
}

class _AdminVerifiedReportsTabState extends State<AdminVerifiedReportsTab> {
  late final _reportService = widget.reportService ?? HazardReportService();
  late var _reportsStream = _reportService.watchVerifiedUnresolvedReports();
  late final _voteService = widget.voteService ?? HazardVoteService();
  final Map<String, Stream<List<HazardVote>>> _voteStreams = {};

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
            title: 'Unable to load verified hazards',
            message: friendlySafetyError(
              snapshot.error,
              subject: 'verified hazards',
            ),
            onRetry: () => setState(
              () => _reportsStream = _reportService
                  .watchVerifiedUnresolvedReports(),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SafetyLoadingState(label: 'Loading verified hazards…');
        }

        final reports = snapshot.data!;
        if (reports.isEmpty) {
          return const ExplorerCard(
            child: ExplorerEmptyState(
              title: 'No verified hazards',
              subtitle: 'Verified hazards will appear here after review.',
              icon: Icons.warning_amber_rounded,
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final report = reports[index];
            return StreamBuilder<List<HazardVote>>(
              stream: _voteStreams.putIfAbsent(
                report.id,
                () => _voteService.watchVotes(report.id),
              ),
              builder: (context, voteSnapshot) {
                final votes = voteSnapshot.data ?? const <HazardVote>[];
                final countText = votes.isEmpty
                    ? null
                    : '${votes.length} ${votes.length == 1 ? 'confirmation' : 'confirmations'}';

                final formattedDate = _formatHazardDate(
                  report.reviewedAt ?? report.createdAt,
                  isVerified: report.reviewedAt != null,
                );

                return _AdminHazardListCard(
                  report: report,
                  statusLabel: 'VERIFIED',
                  statusTone: ExplorerStatusTone.success,
                  actionLabel: 'Manage Hazard',
                  actionIcon: Icons.manage_search,
                  onAction: () => _openReport(report),
                  formattedDate: formattedDate,
                  communityVoteCount: countText,
                );
              },
            );
          },
        );
      },
    );
  }
}
