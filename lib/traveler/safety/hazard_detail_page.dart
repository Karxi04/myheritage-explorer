part of '../traveler_pages.dart';

class HazardDetailPage extends StatelessWidget {
  const HazardDetailPage({
    super.key,
    required this.hazardId,
    this.showStatusHistory = false,
  });

  final String hazardId;
  final bool showStatusHistory;

  @override
  Widget build(BuildContext context) {
    final reportService = HazardReportService();
    final uid = AppServices.auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: StreamBuilder<HazardReport?>(
          stream: reportService.watchReport(hazardId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ExplorerEmptyState(
                title: 'Unable to load hazard report',
                subtitle: '${snapshot.error}',
                icon: Icons.cloud_off_outlined,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final report = snapshot.data;
            if (report == null) {
              return Column(
                children: [
                  ExplorerPageHeader(
                    title: 'Hazard Report Details',
                    leading: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
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
            final displayHistory = showStatusHistory || isOwner;

            return Column(
              children: [
                ExplorerPageHeader(
                  title: 'Hazard Report Details',
                  subtitle: 'View-only hazard information.',
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
                      if (report.hasPhoto)
                        ExplorerCard(
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: HazardEvidenceImage(
                              report: report,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                              placeholderBuilder: (_) => Container(
                                height: 160,
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
                                      urlTemplate: HazardMapService.osmTileUrl,
                                      userAgentPackageName:
                                          'com.myheritage.explorer',
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
                            Text(
                              '${report.latitude.toStringAsFixed(5)}, '
                              '${report.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(
                                color: ExplorerColors.muted,
                                fontSize: 10,
                              ),
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
                        Row(
                          children: [
                            ExplorerStatusBadge(
                              label: item.status.toUpperCase(),
                              tone: HazardDetailPage._statusTone(item.status),
                            ),
                            const Spacer(),
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
