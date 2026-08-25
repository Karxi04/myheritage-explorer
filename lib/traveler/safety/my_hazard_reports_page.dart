part of '../traveler_pages.dart';

class MyHazardReportsPage extends StatelessWidget {
  const MyHazardReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;
    final reportService = HazardReportService();

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ExplorerPageHeader(
              title: 'My Hazard Reports',
              subtitle: 'Track verification and resolution progress.',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              actions: [
                IconButton(
                  tooltip: 'Create report',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateHazardPage()),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<List<HazardReport>>(
                stream: reportService.watchReportsByUser(uid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ExplorerEmptyState(
                      title: 'Unable to load your reports',
                      subtitle: '${snapshot.error}',
                      icon: Icons.cloud_off_outlined,
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final reports = snapshot.data!;
                  if (reports.isEmpty) {
                    return const ExplorerEmptyState(
                      title: 'No reports submitted',
                      subtitle:
                          'Your safety reports and their review status will appear here.',
                      icon: Icons.health_and_safety_outlined,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                    itemCount: reports.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return ExplorerCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HazardDetailPage(
                              hazardId: report.id,
                              showStatusHistory: true,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _toneColor(report.status),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                report.status == HazardReportStatus.resolved
                                    ? Icons.task_alt
                                    : Icons.warning_amber_rounded,
                                color: _iconColor(report.status),
                              ),
                            ),
                            const SizedBox(width: 12),
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
                                            fontSize: 15,
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
                                  const SizedBox(height: 5),
                                  Text(
                                    report.description,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: ExplorerColors.text,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule_outlined,
                                        size: 14,
                                        color: ExplorerColors.muted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        report.createdAt == null
                                            ? 'Recently submitted'
                                            : DateFormat.yMMMd()
                                                  .add_jm()
                                                  .format(report.createdAt!),
                                        style: const TextStyle(
                                          color: ExplorerColors.muted,
                                          fontSize: 10,
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
                    },
                  );
                },
              ),
            ),
          ],
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

  static Color _toneColor(String status) => switch (status) {
    HazardReportStatus.verified ||
    HazardReportStatus.resolved => ExplorerColors.successSoft,
    HazardReportStatus.rejected => ExplorerColors.dangerSoft,
    _ => ExplorerColors.warningSoft,
  };

  static Color _iconColor(String status) => switch (status) {
    HazardReportStatus.verified ||
    HazardReportStatus.resolved => ExplorerColors.success,
    HazardReportStatus.rejected => ExplorerColors.danger,
    _ => ExplorerColors.goldDark,
  };
}
