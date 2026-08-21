part of '../traveler_pages.dart';

class SosAlertsReviewPage extends StatefulWidget {
  const SosAlertsReviewPage({
    super.key,
    required this.groupId,
  });

  final String groupId;

  @override
  State<SosAlertsReviewPage> createState() => _SosAlertsReviewPageState();
}

class _SosAlertsReviewPageState extends State<SosAlertsReviewPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const Text('Emergency SOS Alerts')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppServices.db
            .collection('sos_alerts')
            .where('groupId', isEqualTo: widget.groupId)
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error loading alerts'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const ExplorerEmptyState(
              title: 'No Active Alerts',
              subtitle: 'Everything looks safe. No companions have triggered SOS.',
              icon: Icons.security,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final alertId = docs[index].id;
              final senderName = data['senderName'] ?? 'Unknown Member';
              final timestamp = asDate(data['timestamp']);
              final timeStr = timestamp != null ? DateFormat.jm().format(timestamp) : 'Just now';

              return ExplorerCard(
                backgroundColor: ExplorerColors.dangerSoft,
                borderColor: ExplorerColors.danger,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: ExplorerColors.danger,
                          child: Icon(Icons.emergency, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                senderName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: ExplorerColors.danger,
                                ),
                              ),
                              Text(
                                'Triggered at $timeStr',
                                style: const TextStyle(fontSize: 12, color: ExplorerColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This companion needs immediate assistance. Please check their location and contact them.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _resolveAlert(docs[index].reference),
                            style: OutlinedButton.styleFrom(foregroundColor: ExplorerColors.success),
                            child: const Text('Mark Resolved'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RouteGuidancePage(
                                    senderId: data['senderId'],
                                    senderName: senderName,
                                    alertId: alertId,
                                    targetLat: (data['latitude'] as num).toDouble(),
                                    targetLng: (data['longitude'] as num).toDouble(),
                                  ),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(backgroundColor: ExplorerColors.danger),
                            icon: const Icon(Icons.directions_run),
                            label: const Text('Accept & Find'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _resolveAlert(DocumentReference ref) async {
    try {
      await ref.update({'status': 'resolved', 'resolvedAt': FieldValue.serverTimestamp()});
      if (mounted) showMessage(context, 'Alert marked as resolved.');
    } catch (e) {
      if (mounted) showMessage(context, 'Failed to resolve alert.', error: true);
    }
  }
}
