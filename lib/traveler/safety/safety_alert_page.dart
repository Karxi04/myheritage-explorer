part of '../traveler_pages.dart';

class SafetyAlertPage extends StatefulWidget {
  const SafetyAlertPage({
    super.key,
    required this.hazardId,
    required this.distanceMeters,
  });

  final String hazardId;
  final double distanceMeters;

  @override
  State<SafetyAlertPage> createState() => _SafetyAlertPageState();
}

class _SafetyAlertPageState extends State<SafetyAlertPage> {
  final _reportService = HazardReportService();
  final _voteService = HazardVoteService();
  final _confidenceService = const ConfidenceAnalysisService();
  final _locationService = const LocationService();
  bool voting = false;
  bool _locating = false;
  double? _validatedDistance;
  Uint8List? _photoBytes;
  String? _locatedHazardId;

  String get _proximityBand {
    final distance = _validatedDistance ?? double.infinity;
    if (distance <= SafetyConfig.strongProximityMeters) return 'STRONG';
    if (distance <= SafetyConfig.normalProximityMeters) return 'NORMAL';
    if (distance <= SafetyConfig.maxHazardConfirmationDistanceMeters) return 'WEAK';
    return 'OUTSIDE';
  }

  Future<void> _validateLocation(HazardReport report) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await _locationService.getCurrentPosition();
      final distance = _locationService.distanceBetween(
        startLatitude: position.latitude, startLongitude: position.longitude,
        endLatitude: report.latitude, endLongitude: report.longitude,
      );
      if (mounted) setState(() => _validatedDistance = distance);
    } catch (error) {
      if (mounted) showMessage(context, error.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 72, maxWidth: 1600);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (mounted) setState(() => _photoBytes = bytes);
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  Future<void> _submitVote(String voteType) async {
    if (voting) return;
    setState(() => voting = true);
    try {
      final uid = AppServices.auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('Please sign in as a tourist first.');
      }
      if (await _voteService.hasUserVoted(widget.hazardId, uid)) {
        throw Exception('You already voted on this hazard.');
      }
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm vote'),
          content: Text(
            voteType == HazardVoteType.hazardExists
                ? 'Confirm that this hazard still exists?'
                : 'Vote that this hazard appears resolved?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit vote'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      await _voteService.submitVote(
        hazardId: widget.hazardId,
        voteType: voteType,
        distanceFromHazardMeters: _validatedDistance!,
        proximityBand: _proximityBand,
        photoBytes: _photoBytes,
      );
      if (mounted) {
        showMessage(context, 'Your vote was recorded. Thank you!');
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => voting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: StreamBuilder<HazardReport?>(
          stream: _reportService.watchReport(widget.hazardId),
          builder: (context, reportSnapshot) {
            if (reportSnapshot.hasError) {
              return ExplorerEmptyState(
                title: 'Unable to load safety alert',
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
                title: 'Hazard not found',
                subtitle: 'This safety alert may no longer be active.',
                icon: Icons.search_off_outlined,
              );
            }
            if (_locatedHazardId != report.id) {
              _locatedHazardId = report.id;
              WidgetsBinding.instance.addPostFrameCallback((_) => _validateLocation(report));
            }

            return StreamBuilder<List<HazardVote>>(
              stream: _voteService.watchVotes(widget.hazardId),
              builder: (context, voteSnapshot) {
                if (voteSnapshot.hasError) {
                  return ExplorerEmptyState(
                    title: 'Unable to load community votes',
                    subtitle: '${voteSnapshot.error}',
                    icon: Icons.cloud_off_outlined,
                  );
                }
                final votes = voteSnapshot.data ?? const [];
                final analysis = _confidenceService.analyze(votes);
                final uid = AppServices.auth.currentUser?.uid;
                final userHasVoted =
                    uid != null && votes.any((vote) => vote.userId == uid);

                return Column(
                  children: [
                    ExplorerPageHeader(
                      title: 'Review Safety Alert',
                      subtitle:
                          'Share community feedback without changing official status.',
                      leading: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                        children: [
                          ExplorerCard(
                            backgroundColor: ExplorerColors.dangerSoft,
                            borderColor: ExplorerColors.danger,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: ExplorerColors.danger,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'You are approximately '
                                    '${_formatDistance(_validatedDistance ?? widget.distanceMeters)} '
                                    'from this verified hazard.',
                                    style: const TextStyle(
                                      color: ExplorerColors.navy,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _HazardSummaryCard(report: report),
                          if (report.hasPhoto) ...[
                            const SizedBox(height: 12),
                            ExplorerCard(
                              padding: EdgeInsets.zero,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: HazardEvidenceImage(
                                  report: report,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholderBuilder: (_) => const SizedBox(
                                    height: 120,
                                    child: Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          ExplorerCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const ExplorerSectionTitle(
                                  'Community Vote Results',
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _VoteStat(
                                        label: 'Hazard Still Exists',
                                        count: analysis.existsVotes,
                                        icon: Icons.thumb_up_alt_outlined,
                                        color: ExplorerColors.danger,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _VoteStat(
                                        label: 'Appears Resolved',
                                        count: analysis.resolvedVotes,
                                        icon: Icons.task_alt_outlined,
                                        color: ExplorerColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${analysis.totalRecentVotes} votes in the last '
                                  '${SafetyConfig.recentVoteWindow.inMinutes} minutes. '
                                  'Recent resolution confidence: '
                                  '${analysis.confidencePercent.toStringAsFixed(1)}%.',
                                  style: const TextStyle(
                                    color: ExplorerColors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (report.status == HazardReportStatus.verified) ...[
                            const SizedBox(height: 12),
                            ExplorerCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const ExplorerSectionTitle(
                                    'Cast Your Vote',
                                    subtitle:
                                        'Your vote does not change the official hazard status.',
                                  ),
                                  const SizedBox(height: 12),
                                  Text(_locating
                                      ? 'Validating your GPS location...'
                                      : _validatedDistance == null
                                          ? 'GPS validation is required before voting.'
                                          : 'GPS proximity: $_proximityBand'),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: voting ? null : _pickPhoto,
                                    icon: const Icon(Icons.add_a_photo_outlined),
                                    label: Text(_photoBytes == null ? 'Add Current Photo - Optional' : 'Current Photo Added'),
                                  ),
                                  const SizedBox(height: 10),
                                  if ((_validatedDistance ?? double.infinity) > SafetyConfig.maxHazardConfirmationDistanceMeters)
                                    const Text('You need to be closer to this hazard to provide a location-validated status confirmation.', style: TextStyle(color: ExplorerColors.danger, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  if (userHasVoted) ...[
                                    const ExplorerStatusBadge(
                                      label: 'VOTE ALREADY SUBMITTED',
                                      tone: ExplorerStatusTone.navy,
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: voting || userHasVoted || _validatedDistance == null || _validatedDistance! > SafetyConfig.maxHazardConfirmationDistanceMeters
                                              ? null
                                              : () => _submitVote(
                                                  HazardVoteType.hazardExists,
                                                ),
                                          icon: const Icon(
                                            Icons.thumb_up_outlined,
                                          ),
                                          label: const Text('Still Exists'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: voting || userHasVoted || _validatedDistance == null || _validatedDistance! > SafetyConfig.maxHazardConfirmationDistanceMeters
                                              ? null
                                              : () => _submitVote(
                                                  HazardVoteType.hazardResolved,
                                                ),
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                          ),
                                          label: const Text('Resolved'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HazardSummaryCard extends StatelessWidget {
  const _HazardSummaryCard({required this.report});

  final HazardReport report;

  @override
  Widget build(BuildContext context) {
    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.category,
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ExplorerStatusBadge(
                label: report.status.toUpperCase(),
                tone: _statusTone(report.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            report.description,
            style: const TextStyle(
              color: ExplorerColors.text,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Severity: ${report.severity}',
            style: const TextStyle(color: ExplorerColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  static ExplorerStatusTone _statusTone(String status) => switch (status) {
    HazardReportStatus.verified ||
    HazardReportStatus.resolved => ExplorerStatusTone.success,
    HazardReportStatus.rejected => ExplorerStatusTone.danger,
    _ => ExplorerStatusTone.warning,
  };
}

class _VoteStat extends StatelessWidget {
  const _VoteStat({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ExplorerColors.subtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ExplorerColors.muted,
              fontSize: 9,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
