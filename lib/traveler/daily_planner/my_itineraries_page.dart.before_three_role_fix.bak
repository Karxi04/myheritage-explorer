part of '../traveler_pages.dart';

class MyItinerariesPage extends StatelessWidget {
  const MyItinerariesPage({super.key});

  Future<void> _delete(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete itinerary?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await reference.delete();
      if (context.mounted) {
        showMessage(context, 'Itinerary deleted.');
      }
    }
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
              title: 'My Itinerary Plans',
              subtitle:
                  'Tap an itinerary to view its full route and place details.',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppServices.db
                    .collection('itineraries')
                    .where('userId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final documents = snapshot.data!.docs.toList()
                    ..sort(
                      (first, second) =>
                          (asDate(second.data()['updatedAt']) ??
                                  asDate(second.data()['createdAt']) ??
                                  DateTime(2000))
                              .compareTo(
                        asDate(first.data()['updatedAt']) ??
                            asDate(first.data()['createdAt']) ??
                            DateTime(2000),
                      ),
                    );

                  if (documents.isEmpty) {
                    return const ExplorerEmptyState(
                      title: 'No saved itineraries',
                      subtitle:
                          'Generate and save a Penang itinerary to view it here.',
                      icon: Icons.route_outlined,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                    itemCount: documents.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final document = documents[index];
                      final itinerary = document.data();
                      final stops = List<Map<String, dynamic>>.from(
                        (itinerary['stops'] ?? const []).map(
                          (item) => Map<String, dynamic>.from(item),
                        ),
                      );
                      final createdAt =
                          asDate(itinerary['createdAt']);

                      void openDetails() {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ItineraryDetailPage(
                              itineraryId: document.id,
                            ),
                          ),
                        );
                      }

                      return ExplorerCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            InkWell(
                              onTap: openDetails,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(14),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 72,
                                      height: 72,
                                      child: stops.isEmpty
                                          ? Container(
                                              decoration: BoxDecoration(
                                                color: ExplorerColors.navySoft,
                                                borderRadius:
                                                    BorderRadius.circular(11),
                                              ),
                                              child: const Icon(
                                                Icons.map_outlined,
                                                color: ExplorerColors.navy,
                                                size: 30,
                                              ),
                                            )
                                          : ItineraryPlaceImage(
                                              stop: stops.first,
                                              width: 72,
                                              height: 72,
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                            ),
                                    ),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${itinerary['title'] ?? 'Saved Itinerary'}',
                                            style: const TextStyle(
                                              color: ExplorerColors.navy,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '${stops.length} stops • '
                                            '${itinerary['travelPace'] ?? 'Balanced'} pace',
                                            style: const TextStyle(
                                              color:
                                                  ExplorerColors.goldDark,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${itinerary['area'] ?? 'Penang'}'
                                            '${createdAt == null ? '' : ' • ${DateFormat.yMMMd().format(createdAt)}'}',
                                            style: const TextStyle(
                                              color: ExplorerColors.muted,
                                              fontSize: 10,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          const Text(
                                            'Tap to view full itinerary details',
                                            style: TextStyle(
                                              color: ExplorerColors.navy,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: ExplorerColors.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                12,
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    onPressed: openDetails,
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 17,
                                    ),
                                    label: const Text('View Details'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        ItineraryShareHelper.openShareDialog(
                                      context,
                                      itinerary,
                                    ),
                                    icon: const Icon(
                                      Icons.link_rounded,
                                      size: 17,
                                    ),
                                    label: const Text('Share Link'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ItineraryEditPage(
                                          itineraryId: document.id,
                                          itinerary: itinerary,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 17,
                                    ),
                                    label: const Text('Edit'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _delete(context, document.reference),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 17,
                                      color: ExplorerColors.danger,
                                    ),
                                    label: const Text('Delete'),
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
