part of '../admin_pages.dart';

class AdminVerifiedReportsTab extends StatefulWidget {
  const AdminVerifiedReportsTab({super.key});

  @override
  State<AdminVerifiedReportsTab> createState() =>
      _AdminVerifiedReportsTabState();
}

class _AdminVerifiedReportsTabState extends State<AdminVerifiedReportsTab> {
  final _reportService = HazardReportService();
  late var _reportsStream = _reportService.watchVerifiedUnresolvedReports();
  final _voteService = HazardVoteService();
  final Map<String, Stream<List<HazardVote>>> _voteStreams = {};
  final _confidenceService = const ConfidenceAnalysisService();

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
          return SafetyErrorState(
            title: 'Unable to load verified hazards',
            message: friendlySafetyError(
              snapshot.error,
              subject: 'verified hazards',
            ),
            onRetry: () => setState(
              () => _reportsStream = _reportService
                  .watchVerifiedUnresolvedReports(),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SafetyLoadingState(label: 'Loading verified hazards…');
        }

        final reports = snapshot.data!;
        if (reports.isEmpty) {
          return const ExplorerCard(
            child: ExplorerEmptyState(
              title: 'No verified hazards',
              subtitle:
                  'Verified but unresolved hazard reports will appear here.',
              icon: Icons.warning_amber_rounded,
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final report = reports[index];
            return StreamBuilder<List<HazardVote>>(
              stream: _voteStreams.putIfAbsent(
                report.id,
                () => _voteService.watchVotes(report.id),
              ),
              builder: (context, voteSnapshot) {
                if (voteSnapshot.hasError) {
                  return ExplorerCard(
                    child: SafetyErrorState(
                      title: report.category,
                      message: 'Community evidence could not be loaded.',
                      onRetry: () =>
                          setState(() => _voteStreams.remove(report.id)),
                    ),
                  );
                }
                if (!voteSnapshot.hasData) {
                  return const SafetyLoadingState(
                    label: 'Loading community evidence…',
                  );
                }
                final analysis = _confidenceService.analyze(
                  voteSnapshot.data ?? const [],
                );

                return ExplorerCard(
                  onTap: () => _openReport(report),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flex(
                        direction: MediaQuery.sizeOf(context).width < 700
                            ? Axis.vertical
                            : Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AdminHazardImage(report: report),
                          const SizedBox(width: 14),
                          Flexible(
                            fit: FlexFit.loose,
                            flex: MediaQuery.sizeOf(context).width < 700
                                ? 0
                                : 1,
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
                                    const ExplorerStatusBadge(
                                      label: 'VERIFIED',
                                      tone: ExplorerStatusTone.success,
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
                                    _HazardInfo(
                                      icon: Icons.how_to_vote_outlined,
                                      text:
                                          '${analysis.totalVotes} total votes',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => _openReport(report),
                            icon: const Icon(Icons.manage_search, size: 17),
                            label: const Text('Manage'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: ExplorerColors.navySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Wrap(
                          spacing: 18,
                          runSpacing: 6,
                          children: [
                            _HazardInfo(
                              icon: Icons.location_on_outlined,
                              text:
                                  '${analysis.gpsValidatedCount} GPS validated',
                            ),
                            _HazardInfo(
                              icon: Icons.analytics_outlined,
                              text:
                                  '${analysis.confidencePercent.toStringAsFixed(1)}% resolution support',
                            ),
                            _HazardInfo(
                              icon: Icons.fact_check_outlined,
                              text: analysis.displayLevel,
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
        );
      },
    );
  }
}
