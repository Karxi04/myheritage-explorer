part of '../traveler_pages.dart';

class SafetyPage extends StatefulWidget {
  const SafetyPage({super.key});
  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  final _service = HazardReportService();
  late Stream<List<HazardReport>> _reports;
  @override
  void initState() {
    super.initState();
    _reports = _service.watchVerifiedReports();
  }

  void _retry() => setState(() => _reports = _service.watchVerifiedReports());
  void _create() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CreateHazardPage()),
  );
  void _myReports() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const MyHazardReportsPage()),
  );
  void _safeNavigation() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SafeNavigationPage(
        onViewHazard: (navigationContext, hazard) {
          Navigator.of(navigationContext).push(
            MaterialPageRoute<void>(
              builder: (_) => HazardDetailPage(hazardId: hazard.id),
            ),
          );
        },
      ),
    ),
  );
  Future<void> _preview(HazardReport report) async {
    final open = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.category,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ExplorerStatusBadge(
                label: '${report.severity} severity',
                tone: _tone(report),
              ),
              const SizedBox(height: 12),
              Text(
                report.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('View Hazard Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (open == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HazardDetailPage(hazardId: report.id),
        ),
      );
    }
  }

  ExplorerStatusTone _tone(HazardReport r) => r.severity == 'High'
      ? ExplorerStatusTone.danger
      : r.severity == 'Medium'
      ? ExplorerStatusTone.warning
      : ExplorerStatusTone.navy;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ExplorerColors.background,
    appBar: AppBar(
      title: const Text('Safety'),
      actions: [
        IconButton(
          tooltip: 'My reports',
          onPressed: _myReports,
          icon: const Icon(Icons.assignment_outlined),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          ),
          icon: const Icon(Icons.notifications_none),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            const ExplorerSectionTitle(
              'Explore with awareness',
              subtitle: 'See verified reports and share hazards you encounter.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add_alert_outlined),
                label: const Text('Report a Hazard'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _safeNavigation,
                icon: const Icon(Icons.route_outlined),
                label: const Text('Safe Navigation'),
              ),
            ),
            const SizedBox(height: 16),
            const _AutoSafetyAlertSection(),
            const SizedBox(height: 8),
            StreamBuilder<List<HazardReport>>(
              stream: _reports,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SafetyErrorState(
                    title: 'Unable to load danger zones',
                    message: friendlySafetyError(
                      snapshot.error,
                      subject: 'danger zones',
                    ),
                    onRetry: _retry,
                  );
                }
                if (!snapshot.hasData) {
                  return const SafetyLoadingState(
                    label: 'Loading danger zones…',
                  );
                }
                final reports = HazardMapService.activeReports(snapshot.data!);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExplorerSectionTitle(
                      'Danger Zone Map',
                      subtitle: '${reports.length} verified reports',
                      trailing: IconButton(
                        tooltip: 'Open full map',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _FullSafetyMapPage(),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_full),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DangerZoneMapPage(
                      reports: reports,
                      height: 350,
                      onReportSelected: _preview,
                    ),
                    const SizedBox(height: 24),
                    const ExplorerSectionTitle('Verified reports'),
                    const SizedBox(height: 12),
                    if (reports.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Verified reports will appear here as they are reviewed.',
                          style: TextStyle(color: ExplorerColors.muted),
                        ),
                      ),
                    for (final report in reports)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ExplorerCard(
                          onTap: () => _preview(report),
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            report.category,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: ExplorerColors.navy,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ExplorerStatusBadge(
                                          label:
                                              '${report.severity.toUpperCase()} SEVERITY',
                                          tone: _tone(report),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      report.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: ExplorerColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        const ExplorerStatusBadge(
                                          label: 'VERIFIED',
                                          tone: ExplorerStatusTone.success,
                                        ),
                                        if (report.createdAt != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.schedule_outlined,
                                                size: 13,
                                                color: ExplorerColors.muted,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                DateFormat.yMMMd().format(
                                                  report.createdAt!,
                                                ),
                                                style: const TextStyle(
                                                  color: ExplorerColors.muted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  color: ExplorerColors.muted,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            TextButton(
              onPressed: _myReports,
              child: const Text('Track my reports'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FullSafetyMapPage extends StatefulWidget {
  const _FullSafetyMapPage();
  @override
  State<_FullSafetyMapPage> createState() => _FullSafetyMapPageState();
}

class _FullSafetyMapPageState extends State<_FullSafetyMapPage> {
  late Stream<List<HazardReport>> _stream;
  @override
  void initState() {
    super.initState();
    _stream = HazardReportService().watchVerifiedReports();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Danger Zone Map')),
    body: StreamBuilder<List<HazardReport>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SafetyErrorState(
            title: 'Unable to load danger zones',
            message: 'Check your connection and retry.',
            onRetry: () => setState(
              () => _stream = HazardReportService().watchVerifiedReports(),
            ),
          );
        }
        if (!snapshot.hasData) return const SafetyLoadingState();
        return LayoutBuilder(
          builder: (context, constraints) => DangerZoneMapPage(
            reports: snapshot.data!,
            height: constraints.maxHeight,
            onReportSelected: (report) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HazardDetailPage(hazardId: report.id),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _AutoSafetyAlertSection extends StatefulWidget {
  const _AutoSafetyAlertSection();

  @override
  State<_AutoSafetyAlertSection> createState() =>
      _AutoSafetyAlertSectionState();
}

class _AutoSafetyAlertSectionState extends State<_AutoSafetyAlertSection>
    with WidgetsBindingObserver {
  static const _permissionService = BackgroundLocationPermissionService();
  bool _hasBackgroundLocation = false;
  bool _hasNotifications = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final locationGranted = await _permissionService.hasBackgroundPermission();
    final notificationsGranted = await MobileNotificationService.instance
        .areNotificationsEnabled();
    if (mounted) {
      final wasFullyEnabled = _hasBackgroundLocation && _hasNotifications;
      final isFullyEnabled = locationGranted && notificationsGranted;
      setState(() {
        _hasBackgroundLocation = locationGranted;
        _hasNotifications = notificationsGranted;
        _checked = true;
      });
      if (!wasFullyEnabled && isFullyEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Background hazard alerts enabled.'),
            backgroundColor: ExplorerColors.success,
          ),
        );
      }
    }
  }

  Future<void> _fixNotifications() async {
    await MobileNotificationService.instance.requestPermissions();
    if (mounted) {
      final enabled = await MobileNotificationService.instance
          .areNotificationsEnabled();
      if (!enabled) {
        await _permissionService.openLocationSettings();
      }
      await _checkPermission();
    }
  }

  Future<void> _requestUpgrade() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Background Safety Alerts'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Allow background location to receive nearby verified hazard alerts even while MyHeritage Explorer is closed.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              'Android requires you to enable this in App Settings:\n'
              '1. Tap "Permissions"\n'
              '2. Tap "Location"\n'
              '3. Select "Allow all the time"',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ExplorerColors.navy,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;

    await _permissionService.openLocationSettings();
    if (mounted) {
      await _checkPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    if (!_checked) return const SizedBox.shrink();

    final isFullyActive = _hasBackgroundLocation && _hasNotifications;
    final isNotificationMissing = _hasBackgroundLocation && !_hasNotifications;

    final iconData = isFullyActive
        ? Icons.shield_rounded
        : isNotificationMissing
        ? Icons.notifications_off_outlined
        : Icons.shield_outlined;

    final iconColor = isFullyActive
        ? ExplorerColors.success
        : isNotificationMissing
        ? ExplorerColors.warning
        : ExplorerColors.navy;

    final iconBgColor = isFullyActive
        ? ExplorerColors.success.withValues(alpha: 0.12)
        : isNotificationMissing
        ? ExplorerColors.warningSoft
        : ExplorerColors.navy.withValues(alpha: 0.08);

    final subtitle = isFullyActive
        ? 'Active when app is closed'
        : isNotificationMissing
        ? 'Notifications disabled; alerts cannot be posted'
        : 'Alerts active in foreground only';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ExplorerCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Auto Safety Alerts',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ExplorerColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ExplorerColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (isFullyActive)
              const ExplorerStatusBadge(
                label: 'ENABLED',
                tone: ExplorerStatusTone.success,
              )
            else if (isNotificationMissing)
              TextButton(onPressed: _fixNotifications, child: const Text('Fix'))
            else
              TextButton(
                onPressed: _requestUpgrade,
                child: const Text('Enable'),
              ),
          ],
        ),
      ),
    );
  }
}
