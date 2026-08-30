part of '../traveler_pages.dart';

class ItineraryDetailPage extends StatefulWidget {
  const ItineraryDetailPage({
    super.key,
    required this.itineraryId,
    this.initialItinerary,
  });

  final String itineraryId;
  final Map<String, dynamic>? initialItinerary;

  @override
  State<ItineraryDetailPage> createState() => _ItineraryDetailPageState();
}

class _ItineraryDetailPageState extends State<ItineraryDetailPage> {
  int selectedDayIndex = 0;
  Map<String, dynamic>? itinerary;
  List<Map<String, dynamic>> days = [];
  List<Map<String, dynamic>> allStops = [];
  bool loading = true;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    if (widget.initialItinerary != null) {
      itinerary = Map<String, dynamic>.from(widget.initialItinerary!);
      _processItineraryData();
      loading = false;
    }
    _subscribeToItinerary();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribeToItinerary() {
    _subscription = AppServices.db
        .collection('itineraries')
        .doc(widget.itineraryId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;
            if (snapshot.exists && snapshot.data() != null) {
              setState(() {
                itinerary = snapshot.data();
                _processItineraryData();
                loading = false;
              });
            } else if (itinerary == null) {
              setState(() => loading = false);
            }
          },
          onError: (_) {
            if (mounted && itinerary == null) {
              setState(() => loading = false);
            }
          },
        );
  }

  void _processItineraryData() {
    if (itinerary == null) return;

    final rawDays = itinerary!['days'];
    days = [];
    if (rawDays is List && rawDays.isNotEmpty) {
      for (final d in rawDays) {
        if (d is Map) {
          days.add(Map<String, dynamic>.from(d));
        }
      }
    }

    final rawStops = itinerary!['stops'];
    allStops = [];
    if (rawStops is List && rawStops.isNotEmpty) {
      for (final s in rawStops) {
        if (s is Map) {
          allStops.add(Map<String, dynamic>.from(s));
        }
      }
    }

    if ((days.isEmpty ||
            days.every((d) => (d['stops'] as List?)?.isEmpty == true)) &&
        allStops.isNotEmpty) {
      final sDate =
          asDate(itinerary!['startDate']) ??
          asDate(itinerary!['targetDate']) ??
          DateTime.now();
      final eDate = asDate(itinerary!['endDate']) ?? sDate;
      final daySpan = max(
        1,
        _asIntSafe(itinerary!['dayCount'], eDate.difference(sDate).inDays + 1),
      );

      if (daySpan > 1) {
        days.clear();
        final stopsPerDay = (allStops.length / daySpan).ceil();
        for (var i = 0; i < daySpan; i++) {
          final startIdx = i * stopsPerDay;
          final endIdx = min(allStops.length, startIdx + stopsPerDay);
          final dayStops = (startIdx < allStops.length)
              ? allStops.sublist(startIdx, endIdx)
              : <Map<String, dynamic>>[];
          final dayDate = sDate.add(Duration(days: i));
          days.add({
            'dayNumber': i + 1,
            'date': dayDate.toIso8601String(),
            'dateLabel':
                'Day ${i + 1} (${DateFormat('d MMM').format(dayDate)})',
            'stops': dayStops,
            'weather': <String, dynamic>{},
          });
        }
      } else {
        days.add({
          'dayNumber': 1,
          'date': sDate.toIso8601String(),
          'dateLabel': 'Day 1',
          'stops': allStops,
          'weather': <String, dynamic>{},
        });
      }
    }
  }

  Future<void> _deleteItinerary() async {
    if (itinerary == null) return;
    if (!ItineraryShareHelper.canCurrentUserManage(itinerary!)) {
      showMessage(
        context,
        'Only the owner can delete this itinerary.',
        error: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete itinerary?'),
        content: const Text(
          'This itinerary and all of its saved stops will be removed.',
        ),
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

    if (confirmed != true) return;
    await AppServices.db
        .collection('itineraries')
        .doc(widget.itineraryId)
        .delete();
    if (mounted) {
      showMessage(context, 'Itinerary deleted.');
      Navigator.pop(context);
    }
  }

  String _paceDisplayLabel(
    Map<String, dynamic> itn,
    List<Map<String, dynamic>> stopsList,
  ) {
    final selectedPace = '${itn['travelPace'] ?? itn['pace'] ?? 'Balanced'}';
    if (stopsList.isEmpty) return selectedPace;
    final availableH = _asDoubleSafe(
      itn['availableHours'],
      _asDoubleSafe(itn['dailyHours'], 4.0),
    );
    final stopsPerHour = stopsList.length / max(1.0, availableH);
    final actualPace =
        stopsPerHour > 1.35 || (stopsList.length >= 5 && availableH <= 4)
        ? 'Fast'
        : stopsPerHour <= 0.55 || (stopsList.length <= 2 && availableH >= 4)
        ? 'Relaxed'
        : selectedPace;
    if (actualPace == selectedPace) return selectedPace;
    return '$selectedPace selected -> $actualPace schedule';
  }

  @override
  Widget build(BuildContext context) {
    if (loading && itinerary == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (itinerary == null) {
      return Scaffold(
        backgroundColor: ExplorerColors.background,
        appBar: AppBar(title: const Text('Itinerary Details')),
        body: const ExplorerEmptyState(
          title: 'Itinerary not found',
          subtitle: 'This saved itinerary may have been deleted.',
          icon: Icons.route_outlined,
        ),
      );
    }

    final itn = itinerary!;
    final List<Map<String, dynamic>> currentStops = [];
    Map<String, dynamic> dayWeather = {};
    String dayLabel = '';

    if (days.isNotEmpty) {
      final safeIdx = selectedDayIndex.clamp(0, days.length - 1);
      final curDay = days[safeIdx];
      final rawCurStops = curDay['stops'];
      if (rawCurStops is List && rawCurStops.isNotEmpty) {
        for (final s in rawCurStops) {
          if (s is Map) currentStops.add(Map<String, dynamic>.from(s));
        }
      }
      if (curDay['weather'] is Map) {
        dayWeather = Map<String, dynamic>.from(curDay['weather'] as Map);
      }
      dayLabel = '${curDay['dateLabel'] ?? 'Day ${safeIdx + 1}'}';
    }

    if (currentStops.isEmpty && allStops.isNotEmpty) {
      currentStops.addAll(allStops);
    }

    final schedule = ItinerarySchedulePlanner.plan(
      stops: currentStops,
      pace: '${itn['travelPace'] ?? itn['pace'] ?? 'Balanced'}',
      availableHours: _asDoubleSafe(
        itn['availableHours'],
        _asDoubleSafe(itn['dailyHours'], 4.0),
      ),
      preferredStartMinutes: itn['suggestedStartMinutes'] != null
          ? _asIntSafe(itn['suggestedStartMinutes'])
          : null,
    );
    final scheduledStops = schedule.stops;
    final mainScheduledStops = scheduledStops
        .where((stop) => stop['optionalFoodExperience'] != true)
        .toList();
    final optionalFoodStops = scheduledStops
        .where((stop) => stop['optionalFoodExperience'] == true)
        .toList();
    final createdAt = asDate(itn['createdAt']);
    final startDate = asDate(itn['startDate']) ?? asDate(itn['targetDate']);
    final endDate = asDate(itn['endDate']) ?? startDate;
    final totalMinutes = schedule.totalEstimatedMinutes;
    final canModify = ItineraryShareHelper.canCurrentUserManage(itn);
    final tripStatus = AppServices.getItineraryStatus(itn);
    final interests =
        (itn['interests'] as List?)
            ?.map((e) => '$e')
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    final dayCount = max(1, days.length);
    final dayBudget = ItineraryBudgetEstimator.estimateDay(scheduledStops);
    final tripBudget = ItineraryBudgetEstimator.estimateTrip(
      days,
      fallbackStops: allStops,
    );
    final paceLabel = _paceDisplayLabel(itn, scheduledStops);
    final totalPlaces = allStops.isNotEmpty
        ? allStops.length
        : scheduledStops.length;
    final totalPlacesLabel = totalPlaces == 1
        ? '1 place'
        : '$totalPlaces places';
    final selectedDayPlacesLabel = scheduledStops.length == 1
        ? '1 place'
        : '${scheduledStops.length} places';
    final dateRangeLabel = startDate == null
        ? 'Date not set'
        : '${DateFormat('d MMM yyyy').format(startDate)}'
              '${endDate != null && endDate != startDate ? ' - ${DateFormat('d MMM yyyy').format(endDate)}' : ''}';
    final timeWindowLabel = totalMinutes <= 0
        ? 'Not scheduled'
        : '${ItinerarySchedulePlanner.formatTime(schedule.startMinutes)} - '
              '${ItinerarySchedulePlanner.formatTime(schedule.endMinutes)}';
    final timeHelper = totalMinutes <= 0
        ? 'Add stops to build a route'
        : '${(totalMinutes / 60).toStringAsFixed(1)} hrs for '
              '${dayCount > 1 ? 'selected day' : 'route'}';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ExplorerPageHeader(
              title: '${itn['title'] ?? 'Itinerary Details'}',
              subtitle: startDate != null
                  ? 'Trip Date: ${DateFormat('d MMM yyyy').format(startDate)}${endDate != null && endDate != startDate ? ' - ${DateFormat('d MMM yyyy').format(endDate)}' : ''}'
                  : 'View the complete route and each saved place.',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              actions: [
                IconButton(
                  tooltip: canModify
                      ? 'Share itinerary link'
                      : 'Only the owner can share this itinerary',
                  onPressed: canModify
                      ? () => ItineraryShareHelper.openShareDialog(context, itn)
                      : null,
                  icon: const Icon(Icons.ios_share_outlined),
                ),
              ],
            ),
            if (days.length > 1) ...[
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: days.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final d = entry.value;
                      final isSel = selectedDayIndex == idx;
                      final dStops = (d['stops'] as List?)?.length ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            '${d['dateLabel'] ?? 'Day ${idx + 1}'} ($dStops places)',
                          ),
                          selected: isSel,
                          selectedColor: ExplorerColors.navy,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : ExplorerColors.navy,
                            fontWeight: isSel
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                          backgroundColor: Colors.white,
                          onSelected: (_) =>
                              setState(() => selectedDayIndex = idx),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const Divider(height: 1, color: ExplorerColors.border),
            ],
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (days.isNotEmpty) ...[
                    _ItineraryDayOverview(
                      days: days,
                      selectedIndex: selectedDayIndex,
                      onSelect: (index) =>
                          setState(() => selectedDayIndex = index),
                    ),
                    const SizedBox(height: 14),
                  ],
                  ExplorerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: ExplorerSectionTitle('Trip Summary'),
                            ),
                            if (tripStatus == 'upcoming')
                              const ExplorerStatusBadge(
                                label: 'UPCOMING TRIP',
                                tone: ExplorerStatusTone.navy,
                              )
                            else if (tripStatus == 'ongoing')
                              const ExplorerStatusBadge(
                                label: 'ACTIVE TODAY',
                                tone: ExplorerStatusTone.success,
                              )
                            else
                              const ExplorerStatusBadge(
                                label: 'EXPIRED / PAST',
                                tone: ExplorerStatusTone.neutral,
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ExplorerColors.navySoft,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: const Color(0xFFB9CBE2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.event_available_outlined,
                                color: ExplorerColors.navy,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dateRangeLabel,
                                      style: const TextStyle(
                                        color: ExplorerColors.navy,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$totalPlacesLabel across '
                                      '${dayCount > 1 ? '$dayCount days' : '1 day'}',
                                      style: const TextStyle(
                                        color: ExplorerColors.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final useTwoColumns = constraints.maxWidth >= 330;
                            final itemWidth = useTwoColumns
                                ? (constraints.maxWidth - 10) / 2
                                : constraints.maxWidth;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _ItinerarySummaryItem(
                                  width: itemWidth,
                                  icon: Icons.location_on_outlined,
                                  label: 'Area',
                                  value: '${itn['area'] ?? 'Penang'}',
                                ),
                                _ItinerarySummaryItem(
                                  width: itemWidth,
                                  icon: Icons.calendar_today_outlined,
                                  label: 'Duration',
                                  value: dayCount > 1
                                      ? '$dayCount Days'
                                      : '1 Day',
                                  helper: createdAt == null
                                      ? null
                                      : 'Saved ${DateFormat.yMMMd().format(createdAt)}',
                                ),
                                _ItinerarySummaryItem(
                                  width: itemWidth,
                                  icon: Icons.route_outlined,
                                  label: dayCount > 1
                                      ? 'Selected Day'
                                      : 'Saved Route',
                                  value: dayCount > 1
                                      ? 'Day ${selectedDayIndex + 1}'
                                      : selectedDayPlacesLabel,
                                  helper: dayCount > 1
                                      ? selectedDayPlacesLabel
                                      : null,
                                ),
                                _ItinerarySummaryItem(
                                  width: itemWidth,
                                  icon: Icons.schedule_outlined,
                                  label: 'Time Window',
                                  value: timeWindowLabel,
                                  helper: timeHelper,
                                ),
                                _ItinerarySummaryItem(
                                  width: itemWidth,
                                  icon: Icons.directions_walk_outlined,
                                  label: 'Pace',
                                  value: paceLabel,
                                ),
                                _ItinerarySummaryItem(
                                  width: itemWidth,
                                  icon: Icons.payments_outlined,
                                  label: 'Budget',
                                  value: 'RM ${tripBudget.tripBudget} total',
                                  helper: dayCount > 1
                                      ? 'Selected day RM ${dayBudget.dayBudget}'
                                      : '${tripBudget.budgetLevel} estimate',
                                ),
                              ],
                            );
                          },
                        ),
                        if (interests.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: interests
                                .map(
                                  (interest) => Chip(
                                    label: Text(interest),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (dayWeather.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (dayWeather['isRainy'] == true)
                            ? const Color(0xFFEBF3FC)
                            : const Color(0xFFFFF9EB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (dayWeather['isRainy'] == true)
                              ? const Color(0xFFB9D7F6)
                              : const Color(0xFFFFE299),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            (dayWeather['isRainy'] == true)
                                ? Icons.beach_access_outlined
                                : Icons.wb_sunny_outlined,
                            color: (dayWeather['isRainy'] == true)
                                ? const Color(0xFF1976D2)
                                : const Color(0xFFF57C00),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$dayLabel Weather: ${dayWeather['condition'] ?? 'Fair'} (${dayWeather['temperature'] ?? '30°C'})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: (dayWeather['isRainy'] == true)
                                        ? const Color(0xFF0D47A1)
                                        : const Color(0xFFE65100),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${dayWeather['advice'] ?? 'Check local weather conditions before outdoor visits.'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: (dayWeather['isRainy'] == true)
                                        ? const Color(0xFF1565C0)
                                        : const Color(0xFFBF360C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ItineraryTimelineSummary(schedule: schedule),
                  const SizedBox(height: 18),
                  ExplorerSectionTitle(
                    days.length > 1 ? '$dayLabel Route' : 'Saved Route',
                    subtitle: 'Tap a stop to view place details and reviews.',
                  ),
                  const SizedBox(height: 10),
                  if (scheduledStops.isEmpty)
                    const ExplorerCard(
                      child: ExplorerEmptyState(
                        title: 'No saved stops for this day',
                        subtitle:
                            'Edit this itinerary to add favourite places.',
                        icon: Icons.add_location_alt_outlined,
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...mainScheduledStops.asMap().entries.map((entry) {
                          final stop = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 11),
                            child: _SavedItineraryStopCard(
                              number: entry.key + 1,
                              stop: stop,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlaceDetailPage(
                                    placeId: '${stop['placeId'] ?? ''}',
                                    place: stop,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        if (optionalFoodStops.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          const ExplorerSectionTitle(
                            'Optional Food Exploration',
                            subtitle:
                                'Extra food stops saved from food exploration mode.',
                          ),
                          const SizedBox(height: 10),
                          ...optionalFoodStops.asMap().entries.map((entry) {
                            final stop = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 11),
                              child: _SavedItineraryStopCard(
                                number: entry.key + 1,
                                stop: stop,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlaceDetailPage(
                                      placeId: '${stop['placeId'] ?? ''}',
                                      place: stop,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: ExplorerColors.navy,
                        ),
                        onPressed: canModify
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ItineraryEditPage(
                                    itineraryId: widget.itineraryId,
                                    itinerary: itn,
                                  ),
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Stops'),
                      ),
                      OutlinedButton.icon(
                        onPressed: canModify
                            ? () => ItineraryShareHelper.openShareDialog(
                                context,
                                itn,
                              )
                            : null,
                        icon: const Icon(Icons.ios_share_outlined, size: 18),
                        label: const Text('Share Link'),
                      ),
                      OutlinedButton.icon(
                        onPressed: canModify ? _deleteItinerary : null,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: ExplorerColors.danger,
                          size: 18,
                        ),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _asDoubleSafe(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? fallback;
  return fallback;
}

int _asIntSafe(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is num) return val.round();
  if (val is String) return int.tryParse(val) ?? fallback;
  return fallback;
}

class _ItinerarySummaryItem extends StatelessWidget {
  const _ItinerarySummaryItem({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    this.helper,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: ExplorerColors.subtle,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: ExplorerColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: ExplorerColors.goldDark, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (helper != null && helper!.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    helper!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItineraryDayOverview extends StatelessWidget {
  const _ItineraryDayOverview({
    required this.days,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> days;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExplorerSectionTitle('Trip Days'),
          const SizedBox(height: 10),
          Column(
            children: days.asMap().entries.map((entry) {
              final index = entry.key;
              final day = entry.value;
              final selected = index == selectedIndex;
              final dayNumber = _asIntSafe(day['dayNumber'], index + 1);
              final date = asDate(day['date']);
              final dateLabel = date == null
                  ? '${day['dateLabel'] ?? 'Day $dayNumber'}'
                  : DateFormat('d MMM yyyy').format(date);
              final stopCount = (day['stops'] as List?)?.length ?? 0;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == days.length - 1 ? 0 : 8,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onSelect(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? ExplorerColors.navySoft : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFB9CBE2)
                            : ExplorerColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: selected
                              ? ExplorerColors.navy
                              : ExplorerColors.goldSoft,
                          foregroundColor: selected
                              ? Colors.white
                              : ExplorerColors.navy,
                          child: Text(
                            '$dayNumber',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateLabel,
                                style: const TextStyle(
                                  color: ExplorerColors.navy,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$stopCount ${stopCount == 1 ? 'place' : 'places'} planned',
                                style: const TextStyle(
                                  color: ExplorerColors.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (day['stops'] is List &&
                                  (day['stops'] as List).isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  (day['stops'] as List)
                                      .whereType<Map>()
                                      .take(4)
                                      .map(
                                        (stop) => '${stop['name'] ?? 'Place'}',
                                      )
                                      .join('  |  '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: ExplorerColors.text,
                                    fontSize: 10,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: ExplorerColors.navy,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SavedItineraryStopCard extends StatelessWidget {
  const _SavedItineraryStopCard({
    required this.number,
    required this.stop,
    required this.onTap,
  });

  final int number;
  final Map<String, dynamic> stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rawRating = _asDoubleSafe(
      stop['inAppAverageRating'],
      _asDoubleSafe(stop['score'], _asDoubleSafe(stop['rating'], 0.0)),
    );
    final rating = rawRating > 0 ? rawRating : 4.8;
    final rawReviewCount = _asIntSafe(stop['inAppReviewCount'], 0);
    final reviewCount = rawReviewCount > 0 ? rawReviewCount : 12;
    final travelMinutes = _asIntSafe(stop['travelMinutesBefore'], 0);
    final visitMinutes = _asIntSafe(stop['durationMinutes'], 60);
    final bufferMinutes = _asIntSafe(stop['bufferMinutesAfter'], 0);
    final timeLabel = '${stop['suggestedTimeLabel'] ?? ''}'.trim();
    final mealSuggestion = '${stop['mealSuggestionLabel'] ?? ''}'.trim();
    final scheduleNotes =
        (stop['scheduleNotes'] as List?)
            ?.map((e) => '$e')
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    return ExplorerCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        children: [
          if (travelMinutes > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: const BoxDecoration(
                color: ExplorerColors.navySoft,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Text(
                '$travelMinutes minutes travel from previous stop',
                style: const TextStyle(
                  color: ExplorerColors.navy,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ItineraryPlaceImage(
                      stop: stop,
                      width: 82,
                      height: 82,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: ExplorerColors.gold,
                        foregroundColor: ExplorerColors.navyDark,
                        child: Text(
                          '$number',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stop['name'] ?? ''}',
                        style: const TextStyle(
                          color: ExplorerColors.navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${timeLabel.isEmpty ? '' : '$timeLabel - '}'
                        '${stop['category'] ?? 'Place'} - $visitMinutes minutes'
                        '${bufferMinutes > 0 ? ' + $bufferMinutes min buffer' : ''}',
                        style: const TextStyle(
                          color: ExplorerColors.goldDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (mealSuggestion.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          mealSuggestion,
                          style: const TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Text(
                        '${stop['formattedAddress'] ?? stop['area'] ?? ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (reviewCount > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 15,
                                  color: ExplorerColors.goldDark,
                                ),
                                Text(
                                  ' ${rating.toStringAsFixed(1)} ($reviewCount)',
                                  style: const TextStyle(
                                    color: ExplorerColors.navy,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      if (scheduleNotes.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        ScheduleNoteList(notes: scheduleNotes),
                      ],
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
        ],
      ),
    );
  }
}
