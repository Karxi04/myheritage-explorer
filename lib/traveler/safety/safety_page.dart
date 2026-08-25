part of '../traveler_pages.dart';

class SafetyPage extends StatefulWidget {
  const SafetyPage({super.key});

  @override
  State<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends State<SafetyPage> {
  final _reportService = HazardReportService();
  final _locationService = const LocationService();

  void _openCreateReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateHazardPage()),
    );
  }

  void _openMyReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyHazardReportsPage()),
    );
  }

  void _openReportDetail(HazardReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HazardDetailPage(hazardId: report.id)),
    );
  }

  Future<void> _checkNearby(List<HazardReport> reports) async {
    try {
      final position = await _locationService.getCurrentPosition();
      HazardReport? nearest;
      var nearestMeters = double.infinity;

      for (final report in reports) {
        final distance = _locationService.distanceBetween(
          startLatitude: position.latitude,
          startLongitude: position.longitude,
          endLatitude: report.latitude,
          endLongitude: report.longitude,
        );
        final dangerRadius = SafetyConfig.dangerRadiusForSeverity(
          report.severity,
        );
        if (distance <= dangerRadius && distance < nearestMeters) {
          nearestMeters = distance;
          nearest = report;
        }
      }

      if (!mounted) return;
      if (nearest == null) {
        showMessage(
          context,
          'No verified hazard was found within '
          '${SafetyConfig.detectionRadiusMeters.round()} m.',
        );
        return;
      }

      await _showSafetyAlertDialog(nearest, nearestMeters);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _showSafetyAlertDialog(
    HazardReport report,
    double distanceMeters,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: ExplorerColors.danger,
          size: 36,
        ),
        title: const Text('Safety Alert'),
        content: Text(
          '${report.category} (${report.severity}) is approximately '
          '${distanceMeters < 1000 ? '${distanceMeters.round()} m' : '${(distanceMeters / 1000).toStringAsFixed(1)} km'} away.\n\n'
          '${report.description}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Text('Safety & Hazard Reporting'),
        actions: [
          IconButton(
            tooltip: 'My reports',
            onPressed: _openMyReports,
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
      body: StreamBuilder<List<HazardReport>>(
        stream: _reportService.watchVerifiedReports(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ExplorerEmptyState(
              title: 'Unable to load danger zones',
              subtitle: '${snapshot.error}',
              icon: Icons.cloud_off_outlined,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            children: [
              ExplorerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ExplorerSectionTitle(
                      'Report a Hazard',
                      subtitle:
                          'Contribute to the safety of our heritage sites.',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: ExplorerColors.dangerSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.report_problem_outlined,
                            color: ExplorerColors.danger,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Use your current GPS location, select the hazard category and severity, then add a clear description and photo.',
                            style: TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 11,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openCreateReport,
                      icon: const Icon(Icons.add_alert_outlined),
                      label: const Text('Create Hazard Report'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ExplorerSectionTitle(
                'Verified Danger Zones',
                subtitle:
                    'OpenStreetMap view of verified and unresolved hazards.',
                trailing: IconButton(
                  tooltip: 'Check nearby hazards',
                  onPressed: () => _checkNearby(reports),
                  icon: const Icon(Icons.radar),
                ),
              ),
              const SizedBox(height: 10),
              ExplorerCard(
                padding: EdgeInsets.zero,
                child: DangerZoneMapPage(
                  reports: reports,
                  onReportSelected: _openReportDetail,
                ),
              ),
              const SizedBox(height: 20),
              const ExplorerSectionTitle('Live Safety Feed'),
              const SizedBox(height: 10),
              if (reports.isEmpty)
                const ExplorerEmptyState(
                  title: 'No verified hazards',
                  subtitle: 'Verified safety updates will appear here.',
                  icon: Icons.health_and_safety_outlined,
                )
              else
                ...reports
                    .take(8)
                    .map(
                      (report) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _hazardCard(report),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _hazardCard(HazardReport report) {
    final high = report.severity == 'High';
    final medium = report.severity == 'Medium';
    final color = high
        ? ExplorerColors.danger
        : medium
        ? ExplorerColors.warning
        : ExplorerColors.success;
    final soft = high
        ? ExplorerColors.dangerSoft
        : medium
        ? ExplorerColors.warningSoft
        : ExplorerColors.successSoft;

    return ExplorerCard(
      onTap: () => _openReportDetail(report),
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
            child: Icon(
              high ? Icons.crisis_alert : Icons.warning_amber_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
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
                          color: ExplorerColors.navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    ExplorerStatusBadge(
                      label: report.severity.toUpperCase(),
                      tone: high
                          ? ExplorerStatusTone.danger
                          : medium
                          ? ExplorerStatusTone.warning
                          : ExplorerStatusTone.success,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  report.description,
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 13,
                      color: ExplorerColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      report.createdAt == null
                          ? 'Recently reported'
                          : DateFormat.yMMMd().add_jm().format(
                              report.createdAt!,
                            ),
                      style: const TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
