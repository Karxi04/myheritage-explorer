part of '../admin_pages.dart';

class AdminHazardManagementPage extends StatefulWidget {
  const AdminHazardManagementPage({
    super.key,
    this.hazardId,
    this.initialStatusFilter,
    this.reportService,
    this.voteService,
    this.reporterLoader,
    this.currentAdminId,
    this.currentAdminName,
  });
  final HazardReportService? reportService;
  final HazardVoteService? voteService;
  final Future<Map<String, dynamic>?> Function(String)? reporterLoader;
  final String? currentAdminId;
  final String? currentAdminName;

  final String? hazardId;
  final String? initialStatusFilter;

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
  late Stream<List<HazardAuditEntry>> _auditTrailStream;
  final Map<String, Future<Map<String, dynamic>?>> _reporters = {};
  Timer? _clock;
  HazardAddressDetails? _hazardAddress;
  String? _resolvedCoordinateKey;

  void _maybeResolveAddress(double lat, double lon) {
    if (!SafetyConfig.validCoordinates(lat, lon)) return;
    final key = HazardAddressResolver.coordinateKey(lat, lon);
    if (_resolvedCoordinateKey == key) return;
    _resolvedCoordinateKey = key;
    HazardAddressResolver.resolve(latitude: lat, longitude: lon).then((
      details,
    ) {
      if (mounted) {
        setState(() => _hazardAddress = details);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final id = widget.hazardId;
    if (id != null && id.isNotEmpty) {
      _reportStream = _reportService.watchReport(id);
      _voteStream = _voteService.watchVotes(id);
      _auditTrailStream = _reportService.watchAuditTrail(id);
      _clock = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
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

    final currentUser = AppServices.auth.currentUser;
    final adminId = widget.currentAdminId ?? currentUser?.uid;
    if (adminId == null) {
      showMessage(context, 'Administrator sign-in is required.', error: true);
      return;
    }
    final adminName =
        widget.currentAdminName ?? currentUser?.displayName ?? 'Administrator';

    setState(() => _busy = true);
    try {
      await _reportService.updateStatus(
        report: report,
        status: status,
        adminId: adminId,
        adminName: adminName,
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

  Future<void> _handleKeepVerified(HazardReport report) async {
    if (_busy || _confirming) return;
    _confirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keep hazard verified?'),
        content: const Text(
          'This will record an administrative review log confirming this hazard remains active. The report will remain published.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm Review'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (confirmed != true || !mounted || _busy) return;

    final currentUser = AppServices.auth.currentUser;
    final adminId = widget.currentAdminId ?? currentUser?.uid;
    if (adminId == null) {
      showMessage(context, 'Administrator sign-in is required.', error: true);
      return;
    }
    final adminName =
        widget.currentAdminName ?? currentUser?.displayName ?? 'Administrator';

    setState(() => _busy = true);
    try {
      await _reportService.keepVerified(
        report: report,
        adminId: adminId,
        adminName: adminName,
        note: 'Reviewed and kept verified by administrator',
      );
      if (!mounted) return;
      showMessage(context, 'Review recorded: Hazard kept verified.');
    } catch (error, stack) {
      debugPrint('Admin keep verified failed: $error\n$stack');
      if (mounted) {
        showMessage(
          context,
          friendlySafetyActionError(
            error,
            fallback: 'Failed to record review. Refresh it and try again.',
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
    if (widget.hazardId == null || widget.hazardId!.isEmpty) {
      return Scaffold(
        body: AdminHazardsPage(
          initialStatusFilter: widget.initialStatusFilter,
          reportService: widget.reportService,
          voteService: widget.voteService,
        ),
      );
    }

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
              onRetry: () => setState(() {
                _reportStream = _reportService.watchReport(widget.hazardId!);
                _auditTrailStream = _reportService.watchAuditTrail(
                  widget.hazardId!,
                );
              }),
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
                        _voteStream = _voteService.watchVotes(widget.hazardId!),
                  ),
                );
              }
              final votes = voteSnapshot.data ?? const <HazardVote>[];
              final clientAnalysis = _confidenceService.analyze(votes);
              final serverSummary = report.serverConfidence;
              final useServerConfidence = serverSummary?.isFresh() == true;
              final analysis = useServerConfidence
                  ? ConfidenceAnalysisResult.fromServerSummary(serverSummary!)
                  : clientAnalysis;

              return Column(
                children: [
                  // Top quick recommendation banner (verified hazards with sufficient evidence)
                  if (report.status == HazardReportStatus.verified &&
                      analysis.hasSufficientRecentEvidence)
                    _RecommendationBanner(analysis: analysis),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1050),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Hazard Overview
                                _buildHazardOverview(report),
                                const SizedBox(height: 16),

                                // 2. Original Hazard Evidence
                                _OriginalHazardEvidenceCard(report: report),

                                // 3-6: Community Verification & Confidence sections (Verified Hazards)
                                if (report.status ==
                                    HazardReportStatus.verified) ...[
                                  const SizedBox(height: 16),
                                  // 3. Community Confirmation Summary
                                  _CommunityConfirmationSummaryCard(
                                    analysis: analysis,
                                  ),
                                  const SizedBox(height: 16),
                                  // 4. Community Evidence Section (photos + AI analysis)
                                  _CommunityEvidenceSection(
                                    hazardId: report.id,
                                    votes: votes,
                                    voteService: _voteService,
                                  ),
                                  const SizedBox(height: 16),
                                  // 5. Aggregated AI Evidence Summary (if AI votes exist)
                                  _AggregatedAiEvidenceCard(votes: votes),
                                  const SizedBox(height: 16),
                                  // 6. Resolution Confidence Panel
                                  _ConfidenceAnalysisCard(
                                    analysis: analysis,
                                    serverCalculated: useServerConfidence,
                                  ),
                                ],

                                const SizedBox(height: 16),
                                // 7. Administrative History (Audit Trail)
                                _AdministrativeHistoryCard(
                                  report: report,
                                  auditTrailStream: _auditTrailStream,
                                ),

                                // Bottom padding to clear sticky bar
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 8. Administrator Decision Area (Sticky action bar)
                  _StickyActionBar(
                    report: report,
                    busy: _busy,
                    onChangeStatus: _changeStatus,
                    onKeepVerified: () => _handleKeepVerified(report),
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

  Widget _buildHazardOverview(HazardReport report) {
    if (report.hasValidLocation) {
      _maybeResolveAddress(report.latitude, report.longitude);
    }
    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480;
              final badges = Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ExplorerStatusBadge(
                    label: '${report.severity.toUpperCase()} SEVERITY',
                    tone: switch (report.severity) {
                      'High' => ExplorerStatusTone.danger,
                      'Medium' => ExplorerStatusTone.warning,
                      _ => ExplorerStatusTone.neutral,
                    },
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

              final titleInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.category,
                    style: const TextStyle(
                      color: ExplorerColors.navy,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 13,
                        color: ExplorerColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _hazardAddress?.singleLine ??
                              'Location name unavailable',
                          style: const TextStyle(
                            color: ExplorerColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'GPS: ${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)} • '
                    '${report.createdAt == null ? 'Recently submitted' : DateFormat.yMMMd().add_jm().format(report.createdAt!)}',
                    style: const TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titleInfo, const SizedBox(height: 8), badges],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleInfo),
                  const SizedBox(width: 8),
                  badges,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          const Text(
            'Description',
            style: TextStyle(
              color: ExplorerColors.navy,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            report.description,
            style: const TextStyle(
              height: 1.5,
              fontSize: 13,
              color: ExplorerColors.text,
            ),
          ),
          FutureBuilder<Map<String, dynamic>?>(
            future: _reporter(report.userId),
            builder: (context, snapshot) {
              final reporter = snapshot.data;
              final name = reporter?['displayName'] as String?;
              if (name == null || name.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: ExplorerColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reported by $name',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: ExplorerColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
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
    required this.onKeepVerified,
    required this.onClose,
  });

  final HazardReport report;
  final bool busy;
  final Future<void> Function(HazardReport, String) onChangeStatus;
  final VoidCallback onKeepVerified;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: Colors.black12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ExplorerColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (report.status == HazardReportStatus.verified) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Review the community evidence and confidence analysis before changing the hazard status.',
                        style: TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  _buildButtons(context),
                ],
              ),
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
              onPressed: busy ? null : onKeepVerified,
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
