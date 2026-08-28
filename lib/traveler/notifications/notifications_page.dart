part of '../traveler_pages.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  Future<void> _handleNotificationTap(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic> data,
  ) async {
    await reference.update({'read': true});
    final type = '${data['type'] ?? ''}';
    final itineraryId = '${data['referenceId'] ?? ''}'.trim();
    if (!context.mounted) return;

    final Widget? destination = switch (type) {
      'itinerary' when itineraryId.isNotEmpty => ItineraryDetailPage(
        itineraryId: itineraryId,
      ),
      'voucher_nearby' => const RewardsPage(),
      'voucher_claimed' || 'voucher_redeemed' => const VoucherWalletPage(),
      _ => null,
    };
    if (destination == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ExplorerPageHeader(
              title: 'Notifications',
              subtitle:
                  'Updates about tasks, safety, rewards and your account.',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppServices.db
                    .collection('notifications')
                    .where('userId', isEqualTo: uid)
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
                      title: 'No notifications yet',
                      subtitle: 'Important platform updates will appear here.',
                      icon: Icons.notifications_none_rounded,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final read = data['read'] == true;
                      final createdAt = asDate(data['createdAt']);
                      return ExplorerCard(
                        backgroundColor: read
                            ? Colors.white
                            : ExplorerColors.navySoft,
                        borderColor: read
                            ? ExplorerColors.border
                            : const Color(0xFFB9CBE2),
                        onTap: () => _handleNotificationTap(
                          context,
                          doc.reference,
                          data,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: read
                                  ? ExplorerColors.subtle
                                  : ExplorerColors.navy,
                              foregroundColor: read
                                  ? ExplorerColors.muted
                                  : Colors.white,
                              child: Icon(
                                read
                                    ? Icons.notifications_none
                                    : Icons.notifications_active_outlined,
                                size: 21,
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
                                          '${data['title'] ?? 'Update'}',
                                          style: const TextStyle(
                                            color: ExplorerColors.navy,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (!read)
                                        const ExplorerStatusBadge(
                                          label: 'NEW',
                                          tone: ExplorerStatusTone.navy,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${data['message'] ?? ''}',
                                    style: const TextStyle(
                                      color: ExplorerColors.text,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    createdAt == null
                                        ? 'Recently'
                                        : DateFormat.yMMMd().add_jm().format(
                                            createdAt,
                                          ),
                                    style: const TextStyle(
                                      color: ExplorerColors.muted,
                                      fontSize: 10,
                                    ),
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
}
