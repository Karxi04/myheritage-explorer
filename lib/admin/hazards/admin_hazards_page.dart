part of '../admin_pages.dart';

class AdminHazardsPage extends StatefulWidget {
  const AdminHazardsPage({super.key});

  @override
  State<AdminHazardsPage> createState() => _AdminHazardsPageState();
}

class _AdminHazardsPageState extends State<AdminHazardsPage> {
  String filter = 'all';

  Future<void> updateHazard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) async {
    final data = doc.data();
    await doc.reference.update({
      'status': status,
      'reviewedBy': AppServices.auth.currentUser!.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final title = status == 'verified'
        ? 'Hazard report verified'
        : status == 'rejected'
            ? 'Hazard report rejected'
            : 'Hazard marked resolved';
    final reporterId = data['reporterId'];
    if (reporterId is String && reporterId.isNotEmpty) {
      await AppServices.notify(
        userId: reporterId,
        title: title,
        message: 'Your ${data['category']} hazard report is now $status.',
        type: 'hazard',
        referenceId: doc.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db.collection('hazards').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allDocs = snapshot.data!.docs.toList()
          ..sort(
            (a, b) => (asDate(b.data()['createdAt']) ?? DateTime(2000))
                .compareTo(asDate(a.data()['createdAt']) ?? DateTime(2000)),
          );
        final docs = allDocs
            .where((doc) => filter == 'all' || doc.data()['status'] == filter)
            .toList();
        final pending = allDocs.where((doc) => doc.data()['status'] == 'pending').length;
        final verified = allDocs.where((doc) => doc.data()['status'] == 'verified').length;
        final resolved = allDocs.where((doc) => doc.data()['status'] == 'resolved').length;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const ExplorerAdminPageTitle(
              title: 'Safety & Hazard Management',
              subtitle:
                  'Verify community hazard reports, monitor active risks and close resolved cases.',
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ExplorerMetricCard(
                    label: 'Pending Verification',
                    value: '$pending',
                    icon: Icons.pending_actions_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ExplorerMetricCard(
                    label: 'Active Verified Hazards',
                    value: '$verified',
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ExplorerMetricCard(
                    label: 'Resolved Reports',
                    value: '$resolved',
                    icon: Icons.task_alt_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            ExplorerCard(
              child: Row(
                children: [
                  const Expanded(
                    child: ExplorerSectionTitle(
                      'Hazard Reports',
                      subtitle: 'Newest reports appear first.',
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      value: filter,
                      decoration: const InputDecoration(
                        labelText: 'Report status',
                        isDense: true,
                      ),
                      items: ['all', 'pending', 'verified', 'resolved', 'rejected']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value == 'all'
                                    ? 'All reports'
                                    : '${value[0].toUpperCase()}${value.substring(1)}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => filter = value!),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (docs.isEmpty)
              const ExplorerCard(
                child: ExplorerEmptyState(
                  title: 'No hazard reports',
                  subtitle: 'Reports matching the selected status will appear here.',
                  icon: Icons.health_and_safety_outlined,
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final geo = data['location'];
                final reportStatus = '${data['status'] ?? 'pending'}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ExplorerCard(
                    padding: const EdgeInsets.all(14),
                    borderColor: reportStatus == 'pending'
                        ? const Color(0xFFF2D390)
                        : ExplorerColors.border,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: (data['imageUrl'] ?? '').toString().isNotEmpty
                              ? Image.network(
                                  '${data['imageUrl']}',
                                  width: 118,
                                  height: 92,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _hazardPlaceholder(),
                                )
                              : _hazardPlaceholder(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${data['category'] ?? 'Hazard Report'}',
                                      style: const TextStyle(
                                        color: ExplorerColors.navy,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  ExplorerStatusBadge(
                                    label: reportStatus.toUpperCase(),
                                    tone: _tone(reportStatus),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${data['description'] ?? 'No description provided.'}',
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
                                    text: 'Severity: ${data['severity'] ?? '-'}',
                                  ),
                                  _HazardInfo(
                                    icon: Icons.place_outlined,
                                    text: geo is GeoPoint
                                        ? '${geo.latitude.toStringAsFixed(5)}, ${geo.longitude.toStringAsFixed(5)}'
                                        : 'No GPS data',
                                  ),
                                  _HazardInfo(
                                    icon: Icons.thumb_up_alt_outlined,
                                    text: '${data['upvoteCount'] ?? 0} confirmations',
                                  ),
                                  _HazardInfo(
                                    icon: Icons.schedule_outlined,
                                    text: asDate(data['createdAt']) == null
                                        ? 'Recently submitted'
                                        : DateFormat.yMMMd()
                                            .add_jm()
                                            .format(asDate(data['createdAt'])!),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            if (reportStatus == 'pending') ...[
                              FilledButton.icon(
                                onPressed: () => updateHazard(doc, 'verified'),
                                icon: const Icon(Icons.verified_outlined, size: 17),
                                label: const Text('Verify'),
                              ),
                              const SizedBox(height: 7),
                              OutlinedButton.icon(
                                onPressed: () => updateHazard(doc, 'rejected'),
                                icon: const Icon(Icons.close, size: 17),
                                label: const Text('Reject'),
                              ),
                            ],
                            if (reportStatus == 'verified')
                              FilledButton.icon(
                                onPressed: () => updateHazard(doc, 'resolved'),
                                icon: const Icon(Icons.task_alt, size: 17),
                                label: const Text('Resolve'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  static Widget _hazardPlaceholder() => Container(
        width: 118,
        height: 92,
        color: ExplorerColors.dangerSoft,
        child: const Icon(
          Icons.warning_amber_rounded,
          color: ExplorerColors.danger,
          size: 42,
        ),
      );

  static ExplorerStatusTone _tone(String status) => switch (status) {
        'verified' || 'resolved' => ExplorerStatusTone.success,
        'pending' => ExplorerStatusTone.warning,
        'rejected' => ExplorerStatusTone.danger,
        _ => ExplorerStatusTone.neutral,
      };
}

class _HazardInfo extends StatelessWidget {
  const _HazardInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: ExplorerColors.muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: ExplorerColors.muted, fontSize: 10),
        ),
      ],
    );
  }
}
