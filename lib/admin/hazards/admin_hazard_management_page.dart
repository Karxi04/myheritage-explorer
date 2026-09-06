part of '../admin_pages.dart';

class AdminHazardManagementPage extends StatefulWidget {
  const AdminHazardManagementPage({
    super.key,
    required this.hazardId,
    this.reportService,
    this.voteService,
    this.reporterLoader,
  });
  final HazardReportService? reportService;
  final HazardVoteService? voteService;
  final Future<Map<String, dynamic>?> Function(String)? reporterLoader;

  final String hazardId;

  @override
  State<AdminHazardManagementPage> createState() =>
      _AdminHazardManagementPageState();
}

class _AdminHazardManagementPageState extends State<AdminHazardManagementPage> {
  late final _reportService = widget.reportService ?? HazardReportService();
  late final _voteService = widget.voteService ?? HazardVoteService();
  final _confidenceService = const ConfidenceAnalysisService();
  bool _busy = false;
  bool _confirming = false;
  late Stream<HazardReport?> _reportStream;
  late Stream<List<HazardVote>> _voteStream;
  final Map<String, Future<Map<String, dynamic>?>> _reporters = {};
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _reportStream = _reportService.watchReport(widget.hazardId);
    _voteStream = _voteService.watchVotes(widget.hazardId);
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _changeStatus(HazardReport report, String status) async {
    if (_busy || _confirming) return;
    _confirming = true;
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
    _confirming = false;
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
    } catch (error, stack) {
      debugPrint('Admin hazard decision failed: $error\n$stack');
      if (mounted) {
        showMessage(
          context,
          friendlySafetyActionError(
            error,
            fallback:
                'This report may already have been processed. Refresh it and try again.',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>?> _reporter(String userId) async {
    if (widget.reporterLoader != null) {
      return _reporters.putIfAbsent(
        userId,
        () => widget.reporterLoader!(userId),
      );
    }
    return _reporters.putIfAbsent(
      userId,
      () async => (await AppServices.travelerRef(userId).get()).data(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const Text('Manage Hazard Report')),
      body: StreamBuilder<HazardReport?>(
        stream: _reportStream,
        builder: (context, reportSnapshot) {
          if (reportSnapshot.hasError) {
            return SafetyErrorState(
              title: 'Unable to load hazard report',
              message: friendlySafetyError(
                reportSnapshot.error,
                subject: 'this hazard report',
              ),
              onRetry: () => setState(
                () =>
                    _reportStream = _reportService.watchReport(widget.hazardId),
              ),
            );
          }
          if (reportSnapshot.connectionState == ConnectionState.waiting &&
              !reportSnapshot.hasData) {
            return const SafetyLoadingState(label: 'Loading hazard report…');
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
            stream: _voteStream,
            builder: (context, voteSnapshot) {
              if (voteSnapshot.hasError) {
                return SafetyErrorState(
                  title: 'Unable to load community votes',
                  message: friendlySafetyError(
                    voteSnapshot.error,
                    subject: 'community evidence',
                  ),
                  onRetry: () => setState(
                    () =>
                        _voteStream = _voteService.watchVotes(widget.hazardId),
                  ),
                );
              }
              final analysis = _confidenceService.analyze(
                voteSnapshot.data ?? const [],
              );

              return Column(
                children: [
                  // Inline Community recommendation banner (verified hazards only)
                  if (report.status == HazardReportStatus.verified &&
                      analysis.hasSufficientRecentEvidence)
                    _RecommendationBanner(analysis: analysis),

                  Expanded(
                    child: ListView(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const ExplorerSectionTitle(
                                            'Reporter',
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            '${reporter?['displayName'] ?? 'Tourist'}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            '${reporter?['email'] ?? 'Contact unavailable'}',
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
                                if (report.status ==
                                    HazardReportStatus.verified) ...[
                                  const SizedBox(height: 16),
                                  _ConfidenceAnalysisCard(analysis: analysis),
                                  if ((voteSnapshot.data ??
                                          const <HazardVote>[])
                                      .any(
                                        (vote) => vote.hasPhotoEvidence,
                                      )) ...[
                                    const SizedBox(height: 16),
                                    _VotePhotoEvidenceCard(
                                      hazardId: report.id,
                                      votes: voteSnapshot.data ?? const [],
                                    ),
                                  ],
                                ],
                                // Spacer so content clears the sticky bar.
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sticky bottom action bar
                  _StickyActionBar(
                    report: report,
                    busy: _busy,
                    onChangeStatus: _changeStatus,
                    onClose: () => Navigator.pop(context),
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
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        SizedBox(
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
                '${report.severity} severity • ${report.createdAt == null ? 'Recently submitted' : DateFormat.yMMMd().add_jm().format(report.createdAt!)}',
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
          if (report.evidenceValidation != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                ExplorerStatusBadge(
                  label: report.evidenceValidation!.validationLevel,
                  tone:
                      report.evidenceValidation!.validationLevel ==
                          EvidenceValidationLevel.lowQuality
                      ? ExplorerStatusTone.warning
                      : ExplorerStatusTone.success,
                  icon: Icons.fact_check_outlined,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${report.evidenceValidation!.evidenceSource.toLowerCase()} evidence • quality checked',
                    style: const TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Evidence Details',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              children: [
                _AdminDetailRow(
                  label: 'Resolution',
                  value:
                      '${report.evidenceValidation!.width} × ${report.evidenceValidation!.height}',
                ),
                _AdminDetailRow(
                  label: 'Visibility',
                  value: report.evidenceValidation!.exposureStatus,
                ),
                if (report.evidenceValidation!.warnings.isNotEmpty)
                  _AdminDetailRow(
                    label: 'Notes',
                    value: report.evidenceValidation!.warnings.join(' '),
                  ),
              ],
            ),
          ],
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
            label: 'Location',
            value:
                'GPS captured near ${report.latitude.toStringAsFixed(4)}, '
                '${report.longitude.toStringAsFixed(4)}',
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
}

// ---------------------------------------------------------------------------
// Community recommendation banner
// ---------------------------------------------------------------------------

class _RecommendationBanner extends StatelessWidget {
  const _RecommendationBanner({required this.analysis});
  final ConfidenceAnalysisResult analysis;

  Color get _color => switch (analysis.level) {
    ConfidenceLevel.veryHigh || ConfidenceLevel.high => ExplorerColors.success,
    ConfidenceLevel.medium => ExplorerColors.goldDark,
    _ => ExplorerColors.muted,
  };

  Color get _bgColor => switch (analysis.level) {
    ConfidenceLevel.veryHigh ||
    ConfidenceLevel.high => ExplorerColors.successSoft,
    ConfidenceLevel.medium => ExplorerColors.warningSoft,
    _ => ExplorerColors.subtle,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: _bgColor,
      child: Row(
        children: [
          Icon(Icons.psychology_outlined, color: _color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resolution confidence: ${analysis.displayLevel}',
                  style: TextStyle(
                    color: _color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Resolution support: ${analysis.confidencePercent.toStringAsFixed(1)}% '
                  '(${analysis.validVoteCount} valid votes)',
                  style: TextStyle(color: _color, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky action bar
// ---------------------------------------------------------------------------

class _StickyActionBar extends StatelessWidget {
  const _StickyActionBar({
    required this.report,
    required this.busy,
    required this.onChangeStatus,
    required this.onClose,
  });

  final HazardReport report;
  final bool busy;
  final Future<void> Function(HazardReport, String) onChangeStatus;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: Colors.black12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ExplorerColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: _buildButtons(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    if (report.status == HazardReportStatus.pendingReview) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => onChangeStatus(report, HazardReportStatus.rejected),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => onChangeStatus(report, HazardReportStatus.verified),
              icon: const Icon(Icons.verified_outlined, size: 18),
              label: Text(busy ? 'Updating...' : 'Verify & Publish'),
            ),
          ),
        ],
      );
    }
    if (report.status == HazardReportStatus.verified) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : onClose,
              child: const Text('Keep Verified'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => onChangeStatus(report, HazardReportStatus.resolved),
              icon: const Icon(Icons.task_alt, size: 18),
              label: Text(busy ? 'Updating...' : 'Mark Resolved'),
            ),
          ),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: onClose, child: const Text('Close')),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared detail row
// ---------------------------------------------------------------------------

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
