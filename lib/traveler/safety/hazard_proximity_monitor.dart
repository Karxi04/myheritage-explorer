part of '../traveler_pages.dart';

class HazardProximityMonitor extends StatefulWidget {
  const HazardProximityMonitor({super.key, required this.child});

  final Widget child;

  @override
  State<HazardProximityMonitor> createState() => _HazardProximityMonitorState();
}

class _HazardProximityMonitorState extends State<HazardProximityMonitor> {
  final _reportService = HazardReportService();
  final _locationService = const LocationService();
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<List<HazardReport>>? _reportsSub;
  StreamSubscription<AppNotification>? _notificationSub;
  List<HazardReport> _verifiedReports = [];
  Position? _lastPosition;
  final Map<String, DateTime> _lastAlertedAt = {};
  final Map<String, double> _lastAlertPriority = {};
  final _voteService = HazardVoteService();
  final _confidenceService = const ConfidenceAnalysisService();
  final _priorityService = const SafetyAlertPriorityService();
  String? _activeAlertHazardId;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _reportsSub = _reportService.watchVerifiedReports().listen((reports) {
      _verifiedReports = reports.where((report) => report.isVerified).toList();
      final activeIds = _verifiedReports.map((report) => report.id).toSet();
      _lastAlertedAt.removeWhere(
        (hazardId, _) => !activeIds.contains(hazardId),
      );
      unawaited(_evaluateProximity());
    });
    final uid = AppServices.auth.currentUser?.uid;
    if (uid != null) {
      unawaited(MobileNotificationService.instance.requestPermissions());
      _notificationSub = const NotificationService()
          .watchNewForUser(uid)
          .listen((notification) {
            unawaited(
              MobileNotificationService.instance.showStatusUpdate(notification),
            );
          });
    }
    _startLocationWatch();
  }

  Future<void> _startLocationWatch() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      _positionSub = _locationService
          .watchPosition(
            distanceFilterMeters: SafetyConfig.locationDistanceFilterMeters,
          )
          .listen((position) {
            _lastPosition = position;
            unawaited(_evaluateProximity());
          });
    } catch (_) {
      // Location unavailable.
    }
  }

  Future<void> _evaluateProximity() async {
    if (_checking || _lastPosition == null || _verifiedReports.isEmpty) return;
    if (!mounted || _activeAlertHazardId != null) return;

    _checking = true;
    try {
      HazardReport? nearest;
      var nearestMeters = double.infinity;

      for (final report in _verifiedReports) {
        if (!report.isVerified) continue;

        final distance = _locationService.distanceBetween(
          startLatitude: _lastPosition!.latitude,
          startLongitude: _lastPosition!.longitude,
          endLatitude: report.latitude,
          endLongitude: report.longitude,
        );

        if (distance <= SafetyConfig.dangerRadiusForSeverity(report.severity) &&
            distance < nearestMeters) {
          nearestMeters = distance;
          nearest = report;
        }
      }

      if (nearest != null) {
        final votes = await _voteService.watchVotes(nearest.id).first;
        final community = _confidenceService.analyze(votes).recentExistsConfirmationScore;
        final priority = _priorityService.calculate(severity: nearest.severity, distanceMeters: nearestMeters, existsConfirmationScore: community);
        final previousScore = _lastAlertPriority[nearest.id];
        final escalated = previousScore != null && priority.priorityScore - previousScore >= SafetyConfig.alertEscalationDelta;
        if (!_isCoolingDown(nearest.id) || escalated) {
          await _showSafetyAlert(nearest, nearestMeters, priority);
        }
      }
    } finally {
      _checking = false;
    }
  }

  bool _isCoolingDown(String hazardId) {
    final lastAlertedAt = _lastAlertedAt[hazardId];
    if (lastAlertedAt == null) return false;
    return DateTime.now().difference(lastAlertedAt) <
        SafetyConfig.alertCooldown;
  }

  Future<void> _showSafetyAlert(
    HazardReport report,
    double distanceMeters,
    SafetyAlertPriorityResult priority,
  ) async {
    if (!mounted || _activeAlertHazardId != null) return;
    _activeAlertHazardId = report.id;
    _lastAlertedAt[report.id] = DateTime.now();
    _lastAlertPriority[report.id] = priority.priorityScore;

    await MobileNotificationService.instance.showProximityAlert(
      report: report,
      distanceMeters: distanceMeters,
    );
    if (!mounted ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      _activeAlertHazardId = null;
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: ExplorerColors.danger,
          size: 36,
        ),
        title: Text('${priority.priorityLevel} Safety Alert'),
        content: Text(
          'You are approaching a verified hazard:\n\n'
          '${report.category} (${report.severity})\n'
          '${distanceMeters < 1000 ? '${distanceMeters.round()} m' : '${(distanceMeters / 1000).toStringAsFixed(1)} km'} away\n\n'
          'Priority score: ${(priority.priorityScore * 100).round()}%\n\n'
          '${report.description}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Dismiss'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SafetyAlertPage(
                    hazardId: report.id,
                    distanceMeters: distanceMeters,
                  ),
                ),
              );
            },
            child: const Text('Review hazard'),
          ),
        ],
      ),
    );

    if (mounted) setState(() => _activeAlertHazardId = null);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _reportsSub?.cancel();
    _notificationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
