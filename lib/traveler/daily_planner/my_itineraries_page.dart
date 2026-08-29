part of '../traveler_pages.dart';

class MyItinerariesPage extends StatefulWidget {
  const MyItinerariesPage({super.key});

  @override
  State<MyItinerariesPage> createState() => _MyItinerariesPageState();
}

class _MyItinerariesPageState extends State<MyItinerariesPage> {
  String selectedFilter = 'all';

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
              subtitle: 'Manage upcoming, ongoing, and past heritage trips.',
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
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allDocs = snapshot.data!.docs.toList()
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

                  final upcomingCount = allDocs
                      .where(
                        (d) =>
                            AppServices.getItineraryStatus(d.data()) ==
                            'upcoming',
                      )
                      .length;
                  final ongoingCount = allDocs
                      .where(
                        (d) =>
                            AppServices.getItineraryStatus(d.data()) ==
                            'ongoing',
                      )
                      .length;
                  final expiredCount = allDocs
                      .where(
                        (d) =>
                            AppServices.getItineraryStatus(d.data()) ==
                            'expired',
                      )
                      .length;

                  final documents = allDocs.where((doc) {
                    if (selectedFilter == 'all') return true;
                    return AppServices.getItineraryStatus(doc.data()) ==
                        selectedFilter;
                  }).toList();

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: Text('All (${allDocs.length})'),
                                selected: selectedFilter == 'all',
                                selectedColor: ExplorerColors.navy,
                                labelStyle: TextStyle(
                                  color: selectedFilter == 'all'
                                      ? Colors.white
                                      : ExplorerColors.navy,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                                backgroundColor: Colors.white,
                                onSelected: (_) =>
                                    setState(() => selectedFilter = 'all'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text('Upcoming ($upcomingCount)'),
                                selected: selectedFilter == 'upcoming',
                                selectedColor: const Color(0xFF1976D2),
                                labelStyle: TextStyle(
                                  color: selectedFilter == 'upcoming'
                                      ? Colors.white
                                      : const Color(0xFF0D47A1),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                                backgroundColor: Colors.white,
                                onSelected: (_) =>
                                    setState(() => selectedFilter = 'upcoming'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text('Ongoing ($ongoingCount)'),
                                selected: selectedFilter == 'ongoing',
                                selectedColor: const Color(0xFF2E7D32),
                                labelStyle: TextStyle(
                                  color: selectedFilter == 'ongoing'
                                      ? Colors.white
                                      : const Color(0xFF1B5E20),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                                backgroundColor: Colors.white,
                                onSelected: (_) =>
                                    setState(() => selectedFilter = 'ongoing'),
                              ),
                              const SizedBox(width: 8),
                              ChoiceChip(
                                label: Text('Past / Expired ($expiredCount)'),
                                selected: selectedFilter == 'expired',
                                selectedColor: Colors.grey.shade700,
                                labelStyle: TextStyle(
                                  color: selectedFilter == 'expired'
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                                backgroundColor: Colors.white,
                                onSelected: (_) =>
                                    setState(() => selectedFilter = 'expired'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: documents.isEmpty
                            ? ExplorerEmptyState(
                                title: selectedFilter == 'all'
                                    ? 'No saved itineraries'
                                    : 'No $selectedFilter itineraries',
                                subtitle: selectedFilter == 'all'
                                    ? 'Generate and save an itinerary to view it here.'
                                    : 'No trips currently match the "$selectedFilter" filter.',
                                icon: Icons.route_outlined,
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  30,
                                ),
                                itemCount: documents.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final document = documents[index];
                                  final itinerary = document.data();
                                  final stops = List<Map<String, dynamic>>.from(
                                    (itinerary['stops'] ?? const []).map(
                                      (item) => Map<String, dynamic>.from(item),
                                    ),
                                  );
                                  final createdAt = asDate(
                                    itinerary['createdAt'],
                                  );
                                  final startDate = asDate(
                                    itinerary['startDate'],
                                  );
                                  final endDate = asDate(itinerary['endDate']);
                                  final status = AppServices.getItineraryStatus(
                                    itinerary,
                                  );
                                  final days =
                                      (itinerary['days'] as List?)?.length ?? 1;

                                  String dateSubtext = '';
                                  if (startDate != null) {
                                    final startStr = DateFormat(
                                      'd MMM yyyy',
                                    ).format(startDate);
                                    if (endDate != null &&
                                        endDate != startDate) {
                                      final endStr = DateFormat(
                                        'd MMM yyyy',
                                      ).format(endDate);
                                      dateSubtext =
                                          '📅 $startStr - $endStr ($days Days)';
                                    } else {
                                      dateSubtext = '📅 $startStr';
                                    }
                                  } else if (createdAt != null) {
                                    dateSubtext =
                                        'Saved ${DateFormat.yMMMd().format(createdAt)}';
                                  }

                                  String statusLabel = '';
                                  Color statusColor = Colors.grey;
                                  Color statusBg = Colors.grey.shade200;
                                  final canShare =
                                      ItineraryShareHelper.canCurrentUserManage(
                                        itinerary,
                                      );

                                  if (status == 'upcoming') {
                                    final now = DateTime.now();
                                    final today = DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                    );
                                    final startDay = startDate != null
                                        ? DateTime(
                                            startDate.year,
                                            startDate.month,
                                            startDate.day,
                                          )
                                        : today;
                                    final diff = startDay
                                        .difference(today)
                                        .inDays;
                                    statusLabel = diff <= 1
                                        ? 'STARTS TOMORROW'
                                        : 'IN $diff DAYS';
                                    statusColor = const Color(0xFF0D47A1);
                                    statusBg = const Color(0xFFE3F2FD);
                                  } else if (status == 'ongoing') {
                                    statusLabel = 'ACTIVE TODAY';
                                    statusColor = const Color(0xFF1B5E20);
                                    statusBg = const Color(0xFFE8F5E9);
                                  } else {
                                    statusLabel = 'EXPIRED / PAST';
                                    statusColor = Colors.grey.shade700;
                                    statusBg = Colors.grey.shade200;
                                  }

                                  void openDetails() {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ItineraryDetailPage(
                                          itineraryId: document.id,
                                          initialItinerary: itinerary,
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
                                          borderRadius:
                                              const BorderRadius.vertical(
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
                                                            color:
                                                                ExplorerColors
                                                                    .navySoft,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  11,
                                                                ),
                                                          ),
                                                          child: const Icon(
                                                            Icons.map_outlined,
                                                            color:
                                                                ExplorerColors
                                                                    .navy,
                                                            size: 30,
                                                          ),
                                                        )
                                                      : ItineraryPlaceImage(
                                                          stop: stops.first,
                                                          width: 72,
                                                          height: 72,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                11,
                                                              ),
                                                        ),
                                                ),
                                                const SizedBox(width: 13),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              '${itinerary['title'] ?? 'Saved Itinerary'}',
                                                              style: const TextStyle(
                                                                color:
                                                                    ExplorerColors
                                                                        .navy,
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                            ),
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2,
                                                                ),
                                                            decoration:
                                                                BoxDecoration(
                                                                  color:
                                                                      statusBg,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        6,
                                                                      ),
                                                                ),
                                                            child: Text(
                                                              statusLabel,
                                                              style: TextStyle(
                                                                color:
                                                                    statusColor,
                                                                fontSize: 9,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        dateSubtext,
                                                        style: const TextStyle(
                                                          color: ExplorerColors
                                                              .navy,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        '${stops.length} stops • '
                                                        '${itinerary['travelPace'] ?? 'Balanced'} pace • ${itinerary['area'] ?? 'Penang'}',
                                                        style: const TextStyle(
                                                          color: ExplorerColors
                                                              .muted,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      const Text(
                                                        'Tap to view full route & weather',
                                                        style: TextStyle(
                                                          color: ExplorerColors
                                                              .goldDark,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
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
                                                label: const Text(
                                                  'View Details',
                                                ),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: canShare
                                                    ? () =>
                                                          ItineraryShareHelper.openShareDialog(
                                                            context,
                                                            itinerary,
                                                          )
                                                    : null,
                                                icon: const Icon(
                                                  Icons.ios_share_outlined,
                                                  size: 17,
                                                ),
                                                label: const Text('Share Link'),
                                              ),
                                              OutlinedButton.icon(
                                                onPressed: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        ItineraryEditPage(
                                                          itineraryId:
                                                              document.id,
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
                                                onPressed: () => _delete(
                                                  context,
                                                  document.reference,
                                                ),
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
                              ),
                      ),
                    ],
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
