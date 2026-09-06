part of '../traveler_pages.dart';

class HazardDetailPage extends StatefulWidget {
  const HazardDetailPage({
    super.key,
    required this.hazardId,
    this.showStatusHistory = false,
    this.reportService,
  });

  final String hazardId;
  final bool showStatusHistory;
  final HazardReportService? reportService;

  @override
  State<HazardDetailPage> createState() => _HazardDetailPageState();

  static ExplorerStatusTone _statusTone(String status) =>
      _HazardDetailPageState._statusTone(status);
}

class _HazardDetailPageState extends State<HazardDetailPage> {
  late final reportService = widget.reportService ?? HazardReportService();
  late Stream<HazardReport?> _stream;
  @override
  void initState() {
    super.initState();
    _stream = reportService.watchReport(widget.hazardId);
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const Text('Hazard Details')),
      body: SafeArea(
        child: StreamBuilder<HazardReport?>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SafetyErrorState(
                title: 'Unable to load hazard report',
                message: friendlySafetyError(
                  snapshot.error,
                  subject: 'this hazard report',
                ),
                onRetry: () => setState(
                  () => _stream = reportService.watchReport(widget.hazardId),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const SafetyLoadingState(label: 'Loading hazard details…');
            }

            final report = snapshot.data;
            if (report == null) {
              return Column(
                children: [
                  const Expanded(
                    child: ExplorerEmptyState(
                      title: 'Report not found',
                      subtitle: 'This hazard report may have been removed.',
                      icon: Icons.search_off_outlined,
                    ),
                  ),
                ],
              );
            }

            final isOwner = uid != null && report.userId == uid;
            final displayHistory = widget.showStatusHistory || isOwner;

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                    children: [
                      if (report.hasPhoto)
                        ExplorerCard(
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: HazardEvidenceImage(
                              report: report,
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.cover,
                              placeholderBuilder: (_) => Container(
                                height: 180,
                                color: ExplorerColors.subtle,
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: ExplorerColors.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (report.hasPhoto) const SizedBox(height: 12),
                      ExplorerCard(
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
                                      fontSize: 18,
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
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ExplorerStatusBadge(
                                  label: report.severity.toUpperCase(),
                                  tone: report.severity == 'High'
                                      ? ExplorerStatusTone.danger
                                      : report.severity == 'Medium'
                                      ? ExplorerStatusTone.warning
                                      : ExplorerStatusTone.success,
                                ),
                                if (report.createdAt != null)
                                  _DetailChip(
                                    icon: Icons.schedule_outlined,
                                    label: DateFormat.yMMMd().add_jm().format(
                                      report.createdAt!,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ExplorerCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ExplorerSectionTitle('Description'),
                            const SizedBox(height: 8),
                            Text(
                              report.description.isEmpty
                                  ? 'No description provided.'
                                  : report.description,
                              style: const TextStyle(
                                color: ExplorerColors.text,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ExplorerCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ExplorerSectionTitle('Location'),
                            const SizedBox(height: 10),
                            if (report.hasValidLocation)
                              SizedBox(
                                height: 160,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: fm.FlutterMap(
                                    options: fm.MapOptions(
                                      initialCenter: latlng.LatLng(
                                        report.latitude,
                                        report.longitude,
                                      ),
                                      initialZoom: 15,
                                      interactionOptions:
                                          const fm.InteractionOptions(
                                            flags: fm.InteractiveFlag.none,
                                          ),
                                    ),
                                    children: [
                                      fm.TileLayer(
                                        urlTemplate:
                                            HazardMapService.osmTileUrl,
                                        userAgentPackageName:
                                            'com.myheritage.explorer',
                                      ),
                                      const fm.SimpleAttributionWidget(
                                        source: Text(
                                          '© OpenStreetMap contributors',
                                        ),
                                      ),
                                      fm.MarkerLayer(
                                        markers: [
                                          fm.Marker(
                                            point: latlng.LatLng(
                                              report.latitude,
                                              report.longitude,
                                            ),
                                            width: 36,
                                            height: 36,
                                            child: const Icon(
                                              Icons.location_on,
                                              color: ExplorerColors.danger,
                                              size: 34,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: ExplorerColors.muted,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Approximate report location',
                                  style: TextStyle(
                                    color: ExplorerColors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (displayHistory) ...[
                        const SizedBox(height: 12),
                        _StatusHistorySection(report: report),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
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

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ExplorerColors.subtle,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ExplorerColors.muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: ExplorerColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _StatusHistorySection extends StatelessWidget {
  const _StatusHistorySection({required this.report});

  final HazardReport report;

  @override
  Widget build(BuildContext context) {
    final entries = report.statusHistory.isEmpty
        ? [
            HazardStatusHistoryEntry(
              status: report.status,
              note: 'Current status',
            ),
          ]
        : report.statusHistory;

    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExplorerSectionTitle('Status History'),
          const SizedBox(height: 12),
          ...entries.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == entries.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: ExplorerColors.navy,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 36,
                        color: ExplorerColors.border,
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ExplorerStatusBadge(
                              label: item.status.toUpperCase(),
                              tone: HazardDetailPage._statusTone(item.status),
                            ),
                            if (item.changedAt != null)
                              Text(
                                DateFormat.yMMMd().add_jm().format(
                                  item.changedAt!,
                                ),
                                style: const TextStyle(
                                  color: ExplorerColors.muted,
                                  fontSize: 9,
                                ),
                              ),
                          ],
                        ),
                        if ((item.note ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.note!,
                            style: const TextStyle(
                              color: ExplorerColors.text,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
