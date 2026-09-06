part of '../traveler_pages.dart';

class SafetyAlertPage extends StatefulWidget {
  const SafetyAlertPage({
    super.key,
    required this.hazardId,
    required this.distanceMeters,
    this.reportService,
    this.voteService,
    this.locationService,
  });

  final String hazardId;
  final double distanceMeters;
  final HazardReportService? reportService;
  final HazardVoteService? voteService;
  final LocationService? locationService;

  @override
  State<SafetyAlertPage> createState() => _SafetyAlertPageState();
}

class _SafetyAlertPageState extends State<SafetyAlertPage> {
  late final _reportService = widget.reportService ?? HazardReportService();
  late final _voteService = widget.voteService ?? HazardVoteService();
  final _confidenceService = const ConfidenceAnalysisService();
  late final _locationService =
      widget.locationService ?? const LocationService();
  bool voting = false;
  bool _locating = false;
  double? _validatedDistance;
  Uint8List? _photoBytes;
  EvidenceValidationResult? _photoValidation;
  String? _photoCheckError;
  bool _validatingPhoto = false;
  String? _locatedHazardId;
  bool _pickingPhoto = false;
  String _evidenceSource = EvidenceSource.camera;
  Timer? _analysisTimer;
  late Stream<HazardReport?> _reportStream;
  late Stream<List<HazardVote>> _voteStream;

  @override
  void initState() {
    super.initState();
    _reportStream = _reportService.watchReport(widget.hazardId);
    _voteStream = _voteService.watchVotes(widget.hazardId);
    _analysisTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    super.dispose();
  }

  String get _proximityBand =>
      SafetyConfig.proximityBand(_validatedDistance ?? double.infinity);

  Future<void> _validateLocation(HazardReport report) async {
    if (_locating) return;
    if (!mounted) return;
    setState(() {
      _locating = true;
      _validatedDistance = null;
    });
    try {
      final position = await _locationService.getCurrentPosition();
      final distance = _locationService.distanceBetween(
        startLatitude: position.latitude,
        startLongitude: position.longitude,
        endLatitude: report.latitude,
        endLongitude: report.longitude,
      );
      if (mounted) setState(() => _validatedDistance = distance);
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Your location could not be validated. Check location access and try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Camera-only photo capture for vote evidence.
  Future<void> _takePhoto([ImageSource source = ImageSource.camera]) async {
    if (_validatingPhoto || voting || _pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _evidenceSource = source == ImageSource.camera
            ? EvidenceSource.camera
            : EvidenceSource.gallery;
      });
      await _checkPhoto();
    } catch (error, stack) {
      debugPrint('Vote photo capture failed: $error\n$stack');
      if (mounted) {
        showMessage(
          context,
          'Could not open or read the camera photo. Check camera access and try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _checkPhoto() async {
    final bytes = _photoBytes;
    if (bytes == null || _validatingPhoto || voting) return;
    setState(() {
      _photoValidation = null;
      _photoCheckError = null;
      _validatingPhoto = true;
    });
    try {
      final validation = await _voteService.validateEvidence(
        imageBytes: bytes,
        evidenceSource: _evidenceSource,
      );
      if (mounted) setState(() => _photoValidation = validation);
    } catch (error, stack) {
      debugPrint('Vote evidence check failed: $error\n$stack');
      if (mounted) {
        setState(() => _photoCheckError = friendlyEvidenceCheckError(error));
      }
    } finally {
      if (mounted) setState(() => _validatingPhoto = false);
    }
  }

  void _removePhoto() {
    if (_validatingPhoto || voting) return;
    setState(() {
      _photoBytes = null;
      _photoValidation = null;
      _photoCheckError = null;
      _validatingPhoto = false;
    });
  }

  String _formatDistance(double meters) {
    if (!meters.isFinite) return 'Distance unavailable';
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  Future<void> _submitVote(String voteType) async {
    if (voting || _locating || _pickingPhoto || _validatingPhoto) return;
    if (_photoBytes != null && _photoValidation?.canSubmit != true) {
      showMessage(
        context,
        _photoCheckError ??
            _photoValidation?.touristMessage ??
            'Wait for the evidence quality check to finish.',
        error: true,
      );
      return;
    }
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
          title: const Text('Confirm current condition'),
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
              child: const Text('Submit confirmation'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final currentReport = await _reportService.getReport(widget.hazardId);
      if (currentReport == null || !currentReport.isVerified) {
        if (mounted) {
          showMessage(
            context,
            'This hazard is no longer active. Refresh to see its latest status.',
          );
        }
        return;
      }
      await _validateLocation(currentReport);
      if (!mounted || _proximityBand == 'OUTSIDE') return;
      await _voteService.submitVote(
        hazardId: widget.hazardId,
        voteType: voteType,
        distanceFromHazardMeters: _validatedDistance!,
        proximityBand: _proximityBand,
        photoBytes: _photoBytes,
        evidenceSource: _evidenceSource,
        evidenceValidation: _photoValidation,
      );
      if (mounted) {
        showMessage(context, 'Your confirmation was recorded. Thank you!');
      }
    } catch (e, stack) {
      debugPrint('Hazard confirmation failed: $e\n$stack');
      if (mounted) {
        showMessage(
          context,
          friendlySafetyActionError(
            e,
            fallback:
                'Your confirmation could not be submitted. Refresh the report and try again.',
          ),
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
      appBar: AppBar(title: const Text('Review Safety Alert')),
      body: SafeArea(
        child: StreamBuilder<HazardReport?>(
          stream: _reportStream,
          builder: (context, reportSnapshot) {
            if (reportSnapshot.hasError) {
              return SafetyErrorState(
                title: 'Unable to load safety alert',
                message: friendlySafetyError(
                  reportSnapshot.error,
                  subject: 'this safety alert',
                ),
                onRetry: () => setState(
                  () => _reportStream = _reportService.watchReport(
                    widget.hazardId,
                  ),
                ),
              );
            }
            if (reportSnapshot.connectionState == ConnectionState.waiting &&
                !reportSnapshot.hasData) {
              return const SafetyLoadingState(
                label: 'Preparing the safety alert…',
              );
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
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _validateLocation(report),
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
                      subject: 'community confirmations',
                    ),
                    onRetry: () => setState(
                      () => _voteStream = _voteService.watchVotes(
                        widget.hazardId,
                      ),
                    ),
                  );
                }
                final votes = voteSnapshot.data ?? const [];
                final analysis = _confidenceService.analyze(votes);
                final priority = const SafetyAlertPriorityService().calculate(
                  severity: report.severity,
                  distanceMeters:
                      (_validatedDistance ?? widget.distanceMeters).isFinite
                      ? (_validatedDistance ?? widget.distanceMeters)
                      : SafetyConfig.detectionRadiusMeters,
                  existsConfirmationScore: analysis.totalRecentVotes == 0
                      ? null
                      : analysis.recentExistsConfirmationScore,
                );
                final tone = _priorityTone(priority.priorityLevel);
                final uid = AppServices.auth.currentUser?.uid;
                final userHasVoted =
                    uid != null && votes.any((vote) => vote.userId == uid);

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                        children: [
                          // Distance alert banner
                          ExplorerCard(
                            backgroundColor: tone.$2,
                            borderColor: tone.$1,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: tone.$1,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    report.isVerified
                                        ? '${priority.priorityLevel} priority • ${_formatDistance(_validatedDistance ?? widget.distanceMeters)}'
                                        : 'This report is ${report.status}. Confirmations are closed.',
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
                          // Community status card
                          ExplorerCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const ExplorerSectionTitle(
                                  'Community Status',
                                  subtitle:
                                      'Location-validated updates from nearby travellers.',
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
                                  'Official status changes remain an administrator decision.',
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
                            EvidencePickerCard(
                              imageBytes: _photoBytes,
                              validation: _photoValidation,
                              validating: _validatingPhoto,
                              checkError: _photoCheckError,
                              onRetry: _checkPhoto,
                              onCamera: _takePhoto,
                              onGallery: () => _takePhoto(ImageSource.gallery),
                              enabled: !voting && !_pickingPhoto,
                              onRemove: _removePhoto,
                            ),
                            const SizedBox(height: 12),
                            ExplorerCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const ExplorerSectionTitle(
                                    'Your Confirmation',
                                    subtitle:
                                        'Your vote does not change the official hazard status.',
                                  ),
                                  const SizedBox(height: 12),
                                  _ProximityStatusBadge(
                                    locating: _locating,
                                    validatedDistance: _validatedDistance,
                                    proximityBand: _proximityBand,
                                  ),
                                  TextButton.icon(
                                    onPressed: voting || _locating
                                        ? null
                                        : () => _validateLocation(report),
                                    icon: const Icon(Icons.my_location),
                                    label: const Text('Refresh location'),
                                  ),
                                  const SizedBox(height: 12),
                                  if (voting) const LinearProgressIndicator(),
                                  if (userHasVoted) ...[
                                    const ExplorerStatusBadge(
                                      label: 'VOTE ALREADY SUBMITTED',
                                      tone: ExplorerStatusTone.navy,
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          voting ||
                                              _locating ||
                                              _pickingPhoto ||
                                              userHasVoted ||
                                              _validatingPhoto ||
                                              (_photoBytes != null &&
                                                  _photoValidation?.canSubmit !=
                                                      true) ||
                                              _validatedDistance == null ||
                                              _validatedDistance! >
                                                  SafetyConfig
                                                      .maxHazardConfirmationDistanceMeters
                                          ? null
                                          : () => _submitVote(
                                              HazardVoteType.hazardExists,
                                            ),
                                      icon: const Icon(
                                        Icons.warning_amber_rounded,
                                      ),
                                      label: const Text('Hazard Still Exists'),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed:
                                          voting ||
                                              _locating ||
                                              _pickingPhoto ||
                                              userHasVoted ||
                                              _validatingPhoto ||
                                              (_photoBytes != null &&
                                                  _photoValidation?.canSubmit !=
                                                      true) ||
                                              _validatedDistance == null ||
                                              _validatedDistance! >
                                                  SafetyConfig
                                                      .maxHazardConfirmationDistanceMeters
                                          ? null
                                          : () => _submitVote(
                                              HazardVoteType.hazardResolved,
                                            ),
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                      ),
                                      label: const Text(
                                        'Hazard Appears Resolved',
                                      ),
                                    ),
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

// ---------------------------------------------------------------------------

class _ProximityStatusBadge extends StatelessWidget {
  const _ProximityStatusBadge({
    required this.locating,
    required this.validatedDistance,
    required this.proximityBand,
  });

  final bool locating;
  final double? validatedDistance;
  final String proximityBand;

  @override
  Widget build(BuildContext context) {
    final tooFar =
        (validatedDistance ?? double.infinity) >
        SafetyConfig.maxHazardConfirmationDistanceMeters;
    final color = locating
        ? ExplorerColors.navy
        : tooFar
        ? ExplorerColors.danger
        : ExplorerColors.success;
    final bg = locating
        ? ExplorerColors.navySoft
        : tooFar
        ? ExplorerColors.dangerSoft
        : ExplorerColors.successSoft;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (locating)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              tooFar ? Icons.location_off_outlined : Icons.my_location_rounded,
              color: color,
              size: 18,
            ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              locating
                  ? 'Validating your GPS location...'
                  : validatedDistance == null
                  ? 'GPS validation is required before voting.'
                  : tooFar
                  ? 'Move closer to this hazard to submit a location-verified vote.'
                  : "You're close enough to provide a location-verified update.",
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

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
          ExplorerStatusBadge(
            label: '${report.severity.toUpperCase()} SEVERITY',
            tone: report.severity == 'High'
                ? ExplorerStatusTone.danger
                : report.severity == 'Medium'
                ? ExplorerStatusTone.warning
                : ExplorerStatusTone.success,
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

// ---------------------------------------------------------------------------

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
