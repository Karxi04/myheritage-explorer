part of '../admin_pages.dart';

class AdminHazardManagementPage extends StatefulWidget {
  const AdminHazardManagementPage({super.key, required this.hazardId});

  final String hazardId;

  @override
  State<AdminHazardManagementPage> createState() =>
      _AdminHazardManagementPageState();
}

class _AdminHazardManagementPageState extends State<AdminHazardManagementPage> {
  final _reportService = HazardReportService();
  final _voteService = HazardVoteService();
  final _confidenceService = const ConfidenceAnalysisService();
  bool _busy = false;

  Future<void> _changeStatus(HazardReport report, String status) async {
    final action = switch (status) {
      HazardReportStatus.verified => 'Verify',
      HazardReportStatus.rejected => 'Reject',
      HazardReportStatus.resolved => 'Mark as Resolved',
      _ => 'Update',
    };
    final explanation = switch (status) {
      HazardReportStatus.verified =>
        'This will publish the report to the active danger-zone map.',
      HazardReportStatus.rejected =>
        'The report will remain stored but hidden from the danger-zone map.',
      HazardReportStatus.resolved =>
        'The report will remain stored and disappear from active danger zones.',
      _ => 'Confirm this status change.',
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$action hazard report?'),
        content: Text(explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;

    final adminId = AppServices.auth.currentUser?.uid;
    if (adminId == null) {
      showMessage(context, 'Administrator sign-in is required.', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      await _reportService.updateStatus(
        report: report,
        status: status,
        adminId: adminId,
        note: '$action by administrator',
      );
      if (!mounted) return;
      showMessage(
        context,
        'Report updated to $status and the owner was notified.',
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>?> _reporter(String userId) async {
    return (await AppServices.travelerRef(userId).get()).data();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const Text('Manage Hazard Report')),
      body: StreamBuilder<HazardReport?>(
        stream: _reportService.watchReport(widget.hazardId),
        builder: (context, reportSnapshot) {
          if (reportSnapshot.hasError) {
            return ExplorerEmptyState(
              title: 'Unable to load hazard report',
              subtitle: '${reportSnapshot.error}',
              icon: Icons.cloud_off_outlined,
            );
          }
          if (!reportSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final report = reportSnapshot.data;
          if (report == null) {
            return const ExplorerEmptyState(
              title: 'Report not found',
              subtitle: 'This hazard report is no longer available.',
              icon: Icons.search_off_outlined,
            );
          }

          return StreamBuilder<List<HazardVote>>(
            stream: _voteService.watchVotes(report.id),
            builder: (context, voteSnapshot) {
              if (voteSnapshot.hasError) {
                return ExplorerEmptyState(
                  title: 'Unable to load community votes',
                  subtitle: '${voteSnapshot.error}',
                  icon: Icons.cloud_off_outlined,
                );
              }
              final analysis = _confidenceService.analyze(
                voteSnapshot.data ?? const [],
              );

              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1050),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeading(report),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final narrow = constraints.maxWidth < 760;
                              final evidence = _buildEvidence(report);
                              final details = _buildDetails(report);
                              if (narrow) {
                                return Column(
                                  children: [
                                    evidence,
                                    const SizedBox(height: 14),
                                    details,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: evidence),
                                  const SizedBox(width: 16),
                                  Expanded(child: details),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          FutureBuilder<Map<String, dynamic>?>(
                            future: _reporter(report.userId),
                            builder: (context, snapshot) {
                              final reporter = snapshot.data;
                              return ExplorerCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const ExplorerSectionTitle('Reporter'),
                                    const SizedBox(height: 10),
                                    Text(
                                      '${reporter?['displayName'] ?? 'Tourist'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${reporter?['email'] ?? report.userId}',
                                      style: const TextStyle(
                                        color: ExplorerColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          if (report.status == HazardReportStatus.verified) ...[
                            const SizedBox(height: 16),
                            _ConfidenceAnalysisCard(analysis: analysis),
                            if ((voteSnapshot.data ?? const <HazardVote>[]).any(
                              (vote) => vote.hasPhotoEvidence,
                            )) ...[
                              const SizedBox(height: 16),
                              _VotePhotoEvidenceCard(
                                hazardId: report.id,
                                votes: voteSnapshot.data ?? const [],
                              ),
                            ],
                          ],
                          const SizedBox(height: 18),
                          _buildActions(report),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeading(HazardReport report) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.category,
                style: const TextStyle(
                  color: ExplorerColors.navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hazard ID: ${report.id}',
                style: const TextStyle(
                  color: ExplorerColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        ExplorerStatusBadge(
          label: report.status.toUpperCase(),
          tone: report.status == HazardReportStatus.verified
              ? ExplorerStatusTone.success
              : report.status == HazardReportStatus.rejected
              ? ExplorerStatusTone.danger
              : ExplorerStatusTone.warning,
        ),
      ],
    );
  }

  Widget _buildEvidence(HazardReport report) {
    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExplorerSectionTitle('Photo Evidence'),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: HazardEvidenceImage(
              report: report,
              width: double.infinity,
              height: 280,
              placeholderBuilder: (_) => _AdminHazardPlaceholder.image(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(HazardReport report) {
    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExplorerSectionTitle('Report Information'),
          const SizedBox(height: 12),
          _AdminDetailRow(label: 'Category', value: report.category),
          _AdminDetailRow(label: 'Severity', value: report.severity),
          _AdminDetailRow(
            label: 'Submitted',
            value: report.createdAt == null
                ? 'Recently'
                : DateFormat.yMMMd().add_jm().format(report.createdAt!),
          ),
          _AdminDetailRow(
            label: 'GPS location',
            value:
                '${report.latitude.toStringAsFixed(6)}, '
                '${report.longitude.toStringAsFixed(6)}',
          ),
          const Divider(height: 24),
          const Text(
            'Description',
            style: TextStyle(
              color: ExplorerColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(report.description, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildActions(HazardReport report) {
    if (report.status == HazardReportStatus.pendingReview) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _changeStatus(report, HazardReportStatus.rejected),
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _changeStatus(report, HazardReportStatus.verified),
            icon: const Icon(Icons.verified_outlined),
            label: Text(_busy ? 'Updating...' : 'Verify'),
          ),
        ],
      );
    }
    if (report.status == HazardReportStatus.verified) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Leave as Verified'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _changeStatus(report, HazardReportStatus.resolved),
            icon: const Icon(Icons.task_alt),
            label: Text(_busy ? 'Updating...' : 'Mark as Resolved'),
          ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    );
  }
}

class _AdminDetailRow extends StatelessWidget {
  const _AdminDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: ExplorerColors.muted, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: ExplorerColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
