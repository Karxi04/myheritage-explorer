part of '../traveler_pages.dart';

class MyHazardReportsPage extends StatelessWidget {
  const MyHazardReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;
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
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppServices.db
                    .collection('hazards')
                    .where('reporterId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs.toList()
                    ..sort(
                      (a, b) =>
                          (asDate(b.data()['createdAt']) ?? DateTime(2000))
                              .compareTo(
                        asDate(a.data()['createdAt']) ?? DateTime(2000),
                      ),
                    );
                  if (docs.isEmpty) {
                    return const ExplorerEmptyState(
                      title: 'No reports submitted',
                      subtitle:
                          'Your safety reports and their review status will appear here.',
                      icon: Icons.health_and_safety_outlined,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final status = '${data['status'] ?? 'pending'}';
                      final createdAt = asDate(data['createdAt']);
                      return ExplorerCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _toneColor(status),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                status == 'resolved'
                                    ? Icons.task_alt
                                    : Icons.warning_amber_rounded,
                                color: _iconColor(status),
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
                                          '${data['category'] ?? 'Hazard'}',
                                          style: const TextStyle(
                                            color: ExplorerColors.navy,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      ExplorerStatusBadge(
                                        label: status.toUpperCase(),
                                        tone: _statusTone(status),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${data['description'] ?? ''}',
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
                                        createdAt == null
                                            ? 'Recently submitted'
                                            : DateFormat.yMMMd()
                                                .add_jm()
                                                .format(createdAt),
                                        style: const TextStyle(
                                          color: ExplorerColors.muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${data['upvoteCount'] ?? 0} confirmations',
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
        'verified' || 'resolved' => ExplorerStatusTone.success,
        'rejected' => ExplorerStatusTone.danger,
        _ => ExplorerStatusTone.warning,
      };

  static Color _toneColor(String status) => switch (status) {
        'verified' || 'resolved' => ExplorerColors.successSoft,
        'rejected' => ExplorerColors.dangerSoft,
        _ => ExplorerColors.warningSoft,
      };

  static Color _iconColor(String status) => switch (status) {
        'verified' || 'resolved' => ExplorerColors.success,
        'rejected' => ExplorerColors.danger,
        _ => ExplorerColors.goldDark,
      };
}
