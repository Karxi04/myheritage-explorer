part of '../admin_pages.dart';

class AdminPendingReportsTab extends StatefulWidget {
  const AdminPendingReportsTab({super.key});

  @override
  State<AdminPendingReportsTab> createState() => _AdminPendingReportsTabState();
}

class _AdminPendingReportsTabState extends State<AdminPendingReportsTab> {
  final _reportService = HazardReportService();
  late final _reportsStream = _reportService.watchPendingReports();
  final Map<String, String> _reporterNames = {};

  Future<String> _reporterName(String userId) async {
    if (_reporterNames.containsKey(userId)) return _reporterNames[userId]!;
    final doc = await AppServices.travelerRef(userId).get();
    final name = '${doc.data()?['displayName'] ?? 'Tourist'}';
    _reporterNames[userId] = name;
    return name;
  }

  void _openReport(HazardReport report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminHazardManagementPage(hazardId: report.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HazardReport>>(
      stream: _reportsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ExplorerEmptyState(
            title: 'Unable to load pending reports',
            subtitle: friendlySafetyError(
              snapshot.error,
              subject: 'pending hazard reports',
            ),
            icon: Icons.cloud_off_outlined,
          );
        }
        if (!snapshot.hasData) {
          return const SafetyLoadingState(label: 'Loading pending reports…');
        }

        final reports = snapshot.data!;
        if (reports.isEmpty) {
          return const ExplorerCard(
            child: ExplorerEmptyState(
              title: 'No pending hazard reports',
              subtitle:
                  'New tourist submissions awaiting review will appear here.',
              icon: Icons.pending_actions_outlined,
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final report = reports[index];
            return ExplorerCard(
              onTap: () => _openReport(report),
              padding: const EdgeInsets.all(14),
              borderColor: ExplorerColors.border,
              child: Flex(
                direction: MediaQuery.sizeOf(context).width < 700
                    ? Axis.vertical
                    : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AdminHazardImage(report: report),
                  const SizedBox(width: 14),
                  Flexible(
                    fit: FlexFit.loose,
                    flex: MediaQuery.sizeOf(context).width < 700 ? 0 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.category,
                          style: const TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
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
                        Wrap(
                          spacing: 14,
                          runSpacing: 5,
                          children: [
                            _HazardInfo(
                              icon: Icons.speed_outlined,
                              text: 'Severity: ${report.severity}',
                            ),
                            _HazardInfo(
                              icon: Icons.place_outlined,
                              text: 'GPS location captured',
                            ),
                            FutureBuilder<String>(
                              future: _reporterName(report.userId),
                              builder: (context, snapshot) => _HazardInfo(
                                icon: Icons.person_outline,
                                text: snapshot.data ?? 'Loading reporter...',
                              ),
                            ),
                            _HazardInfo(
                              icon: Icons.schedule_outlined,
                              text: report.createdAt == null
                                  ? 'Recently submitted'
                                  : DateFormat.yMMMd().add_jm().format(
                                      report.createdAt!,
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _openReport(report),
                    icon: const Icon(Icons.rate_review_outlined, size: 17),
                    label: const Text('Review'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
