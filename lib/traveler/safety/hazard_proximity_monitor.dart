part of '../traveler_pages.dart';

class HazardProximityMonitor extends StatefulWidget {
  const HazardProximityMonitor({super.key, required this.child});
  final Widget child;
  @override
  State<HazardProximityMonitor> createState() => _HazardProximityMonitorState();
}

class _HazardProximityMonitorState extends State<HazardProximityMonitor>
    with WidgetsBindingObserver {
  final _reportService = HazardReportService();
  final _voteService = HazardVoteService();
  final _locationService = const LocationService();
  final _confidenceService = const ConfidenceAnalysisService();
  final _priorityService = const SafetyAlertPriorityService();
  final _cooldownStore = const AlertCooldownStore();
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<List<HazardReport>>? _reportsSub;
  StreamSubscription<AppNotification>? _notificationSub;
  final Map<String, StreamSubscription<List<HazardVote>>> _voteSubs = {};
  final Map<String, List<HazardVote>> _votes = {};
  final Map<String, DateTime> _lastAlertedAt = {};
  final Map<String, double> _lastAlertPriority = {};
  List<HazardReport> _reports = [];
  Position? _position;
  Timer? _timer;
  bool _starting = false;
  bool _refreshingLocation = false;
  bool _showing = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Restore cooldown history persisted from the previous session so the
    // hazard alert cooldown survives app restarts and process kills.
    unawaited(_loadPersistedCooldowns());
    MobileNotificationService.instance.onHazardOpened = _openNotification;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = MobileNotificationService.instance.pendingHazardPayload;
      MobileNotificationService.instance.pendingHazardPayload = null;
      if (pending != null && mounted) _openNotification(pending);
    });
    _reportsSub = _reportService.watchVerifiedReports().listen(
      (reports) {
        _reports = HazardMapService.activeReports(reports);
        final ids = _reports.map((r) => r.id).toSet();
        _lastAlertedAt.removeWhere((id, _) => !ids.contains(id));
        _lastAlertPriority.removeWhere((id, _) => !ids.contains(id));
        unawaited(_cooldownStore.pruneInactive(ids));
        _syncNearby();
      },
      onError: (Object e, StackTrace st) {
        debugPrint('Safety reports unavailable: $e\n$st');
        _reports = [];
        _syncNearby();
      },
    );
    final uid = AppServices.auth.currentUser?.uid;
    if (uid != null) {
      _notificationSub = const NotificationService()
          .watchNewForUser(uid)
          .listen((notification) async {
            try {
              await MobileNotificationService.instance.showStatusUpdate(
                notification,
              );
            } catch (e, st) {
              debugPrint('Status notification failed: $e\n$st');
            }
          }, onError: (Object e) => debugPrint('Status listener failed: $e'));
    }
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_refreshNearby()),
    );
    unawaited(_startLocation());
  }

  Future<void> _startLocation() async {
    if (_starting || _positionSub != null || !_foreground) return;
    _starting = true;
    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted || !_foreground) return;
      _position = position;
      _positionSub = _locationService.watchPosition().listen(
        (position) {
          if (LocationService.isUsablePosition(position)) {
            _position = position;
            _syncNearby();
          }
        },
        onError: (Object e) {
          debugPrint('Safety location unavailable: $e');
          _position = null;
          _syncNearby();
        },
      );
      _syncNearby();
      try {
        await MobileNotificationService.instance.requestPermissions();
      } catch (e) {
        debugPrint('Notification permission unavailable: $e');
      }
    } catch (e) {
      debugPrint('Safety location unavailable: $e');
    } finally {
      _starting = false;
    }
  }

  Future<void> _refreshNearby() async {
    if (!mounted || !_foreground || _refreshingLocation) return;
    // A stationary traveler may not receive movement-filtered GPS updates.
    // Refresh an expired fix so recency and cooldown checks keep working.
    if (_positionSub != null &&
        (_position == null || !LocationService.isUsablePosition(_position!))) {
      _refreshingLocation = true;
      try {
        final position = await _locationService.getCurrentPosition();
        if (mounted && _foreground) _position = position;
      } catch (error) {
        debugPrint('Safety location refresh unavailable: $error');
        _position = null;
      } finally {
        _refreshingLocation = false;
      }
    }
    _syncNearby();
  }

  double _distance(HazardReport r) => _locationService.distanceBetween(
    startLatitude: _position!.latitude,
    startLongitude: _position!.longitude,
    endLatitude: r.latitude,
    endLongitude: r.longitude,
  );

  void _syncNearby() {
    if (!mounted) return;
    final nearby =
        !_foreground ||
            _position == null ||
            !LocationService.isUsablePosition(_position!)
        ? <HazardReport>[]
        : _reports
              .where(
                (r) =>
                    _distance(r) <=
                    SafetyConfig.dangerRadiusForSeverity(r.severity),
              )
              .toList();
    final ids = nearby.map((r) => r.id).toSet();
    for (final id in _voteSubs.keys.toList()) {
      if (!ids.contains(id)) {
        unawaited(_voteSubs.remove(id)!.cancel());
        _votes.remove(id);
      }
    }
    for (final report in nearby) {
      if (_voteSubs.containsKey(report.id)) continue;
      _voteSubs[report.id] = _voteService
          .watchVotes(report.id)
          .listen(
            (votes) {
              _votes[report.id] = votes;
              _evaluate();
            },
            onError: (Object e) {
              debugPrint('Nearby evidence unavailable: $e');
              _votes.remove(report.id);
              _evaluate();
            },
          );
    }
    _evaluate();
  }

  void _evaluate() {
    if (!mounted ||
        !_foreground ||
        _showing ||
        _position == null ||
        !LocationService.isUsablePosition(_position!)) {
      return;
    }
    final candidates = <SafetyAlertCandidate>[];
    for (final report in _reports) {
      final distance = _distance(report);
      if (distance > SafetyConfig.dangerRadiusForSeverity(report.severity)) {
        continue;
      }
      final analysis = _confidenceService.analyze(_votes[report.id] ?? []);
      final priority = _priorityService.calculate(
        severity: report.severity,
        distanceMeters: distance,
        existsConfirmationScore: analysis.totalRecentVotes == 0
            ? null
            : analysis.recentExistsConfirmationScore,
      );
      candidates.add(
        SafetyAlertCandidate(
          report: report,
          distanceMeters: distance,
          priority: priority,
        ),
      );
    }
    final selected = _priorityService.selectAlert(
      candidates,
      lastAlertedAt: _lastAlertedAt,
      lastPriority: _lastAlertPriority,
    );
    if (selected != null) {
      unawaited(
        _show(selected.report, selected.distanceMeters, selected.priority),
      );
    }
  }

  Future<void> _show(
    HazardReport report,
    double distance,
    SafetyAlertPriorityResult priority,
  ) async {
    if (_showing || !mounted || !_foreground) return;
    _showing = true;
    final alertedAt = DateTime.now();
    _lastAlertedAt[report.id] = alertedAt;
    _lastAlertPriority[report.id] = priority.priorityScore;
    unawaited(
      _cooldownStore.recordAlert(
        report.id,
        now: alertedAt,
        priority: priority.priorityScore,
      ),
    );
    try {
      // Check again immediately before presentation; report may have resolved.
      if (!_reports.any((r) => r.id == report.id)) return;
      final result = showSafetyPrioritySheet(
        context: context,
        report: report,
        distanceMeters: distance,
        priority: priority,
      );
      try {
        await MobileNotificationService.instance.showProximityAlert(
          report: report,
          distanceMeters: distance,
        );
      } catch (e) {
        debugPrint('Local safety notification failed: $e');
      }
      if (await result &&
          mounted &&
          _foreground &&
          _reports.any((r) => r.id == report.id)) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                SafetyAlertPage(hazardId: report.id, distanceMeters: distance),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Safety alert failed: $e\n$st');
    } finally {
      _showing = false;
    }
  }

  void _openNotification(String payload) {
    if (!mounted) return;
    final id = payload.substring(payload.indexOf(':') + 1);
    if (id.isEmpty || id.contains('/')) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => payload.startsWith('review:')
            ? SafetyAlertPage(hazardId: id, distanceMeters: double.infinity)
            : HazardDetailPage(hazardId: id, showStatusHistory: true),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera temporarily makes the app inactive; cancel only on background.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      unawaited(_positionSub?.cancel());
      _positionSub = null;
      _position = null;
      _syncNearby();
    } else if (state == AppLifecycleState.resumed) {
      _foreground = true;
      unawaited(
        _loadPersistedCooldowns().then((_) {
          if (mounted && _foreground) {
            unawaited(_startLocation());
          }
        }),
      );
    }
  }

  Future<void> _loadPersistedCooldowns() async {
    try {
      final entries = await _cooldownStore.loadEntries();
      if (!mounted) return;
      for (final entry in entries.entries) {
        final existing = _lastAlertedAt[entry.key];
        if (existing == null || entry.value.timestamp.isAfter(existing)) {
          _lastAlertedAt[entry.key] = entry.value.timestamp;
          if (entry.value.priority != null) {
            _lastAlertPriority[entry.key] = entry.value.priority!;
          }
        }
      }
    } catch (e) {
      debugPrint('Safety cooldown store load error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MobileNotificationService.instance.onHazardOpened = null;
    _timer?.cancel();
    _positionSub?.cancel();
    _reportsSub?.cancel();
    _notificationSub?.cancel();
    for (final subscription in _voteSubs.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
