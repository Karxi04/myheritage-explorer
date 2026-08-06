part of '../traveler_pages.dart';

class ItineraryDetailPage extends StatelessWidget {
  const ItineraryDetailPage({
    super.key,
    required this.itineraryId,
  });

  final String itineraryId;

  bool _imageFieldsChanged(
    List<Map<String, dynamic>> oldStops,
    List<Map<String, dynamic>> newStops,
  ) {
    if (oldStops.length != newStops.length) return true;

    for (var index = 0; index < oldStops.length; index++) {
      final oldStop = oldStops[index];
      final newStop = newStops[index];

      for (final key in [
        'imageUrl',
        'fallbackImageUrl',
        'mapPreviewUrl',
        'imageType',
      ]) {
        if ('${oldStop[key] ?? ''}' != '${newStop[key] ?? ''}') {
          return true;
        }
      }

      final oldCandidates = List<String>.from(
        oldStop['imageCandidates'] ?? const <String>[],
      );
      final newCandidates = List<String>.from(
        newStop['imageCandidates'] ?? const <String>[],
      );
      if (oldCandidates.join('|') != newCandidates.join('|')) {
        return true;
      }
    }

    return false;
  }

  Future<void> _saveResolvedImages(
    DocumentReference<Map<String, dynamic>> reference,
    List<Map<String, dynamic>> originalStops,
    List<Map<String, dynamic>> resolvedStops,
  ) async {
    if (!_imageFieldsChanged(originalStops, resolvedStops)) return;

    try {
      await reference.update({
        'stops': resolvedStops,
        'imagesResolvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // The traveler can still view the resolved previews in this session.
    }
  }

  Future<void> _deleteItinerary(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
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
    await reference.delete();
    if (context.mounted) {
      showMessage(context, 'Itinerary deleted.');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reference =
        AppServices.db.collection('itineraries').doc(itineraryId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: reference.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final itinerary = snapshot.data?.data();
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

        final stops = List<Map<String, dynamic>>.from(
          (itinerary['stops'] ?? const []).map(
            (item) => Map<String, dynamic>.from(item),
          ),
        );
        final createdAt = asDate(itinerary['createdAt']);
        final totalMinutes =
            (itinerary['totalEstimatedMinutes'] as num?)?.round() ??
                stops.fold<int>(
                  0,
                  (total, stop) =>
                      total +
                      ((stop['durationMinutes'] as num?)?.round() ?? 60) +
                      ((stop['travelMinutesBefore'] as num?)?.round() ?? 0),
                );

        return Scaffold(
          backgroundColor: ExplorerColors.background,
          body: SafeArea(
            child: Column(
              children: [
                ExplorerPageHeader(
                  title: '${itinerary['title'] ?? 'Itinerary Details'}',
                  subtitle: 'View the complete route and each saved place.',
                  leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Share itinerary link',
                      onPressed: () =>
                          ItineraryShareHelper.openShareDialog(
                        context,
                        itinerary,
                      ),
                      icon: const Icon(Icons.link_rounded),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                    children: [
                      ExplorerCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ExplorerSectionTitle('Trip Summary'),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _ItinerarySummaryItem(
                                  icon: Icons.location_on_outlined,
                                  label: 'Area',
                                  value: '${itinerary['area'] ?? 'Penang'}',
                                ),
                                _ItinerarySummaryItem(
                                  icon: Icons.route_outlined,
                                  label: 'Stops',
                                  value: '${stops.length}',
                                ),
                                _ItinerarySummaryItem(
                                  icon: Icons.schedule_outlined,
                                  label: 'Estimated time',
                                  value: totalMinutes <= 0
                                      ? '-'
                                      : '${(totalMinutes / 60).toStringAsFixed(1)} hours',
                                ),
                                _ItinerarySummaryItem(
                                  icon: Icons.directions_walk_outlined,
                                  label: 'Pace',
                                  value:
                                      '${itinerary['travelPace'] ?? 'Balanced'}',
                                ),
                                _ItinerarySummaryItem(
                                  icon: Icons.payments_outlined,
                                  label: 'Budget',
                                  value:
                                      '${itinerary['budgetLevel'] ?? 'Medium'}',
                                ),
                                if (createdAt != null)
                                  _ItinerarySummaryItem(
                                    icon: Icons.calendar_today_outlined,
                                    label: 'Saved',
                                    value:
                                        DateFormat.yMMMd().format(createdAt),
                                  ),
                              ],
                            ),
                            if ((itinerary['interests'] as List?)
                                    ?.isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: List<String>.from(
                                  itinerary['interests'],
                                )
                                    .map(
                                      (interest) => Chip(
                                        label: Text(interest),
                                        visualDensity:
                                            VisualDensity.compact,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const ExplorerSectionTitle(
                        'Saved Route',
                        subtitle:
                            'Tap a stop to view place details and reviews.',
                      ),
                      const SizedBox(height: 10),
                      if (stops.isEmpty)
                        const ExplorerCard(
                          child: ExplorerEmptyState(
                            title: 'No saved stops',
                            subtitle:
                                'Edit this itinerary to add favourite places.',
                            icon: Icons.add_location_alt_outlined,
                          ),
                        )
                      else
                        _PreparedItineraryRoute(
                          stops: stops,
                          onResolved: (resolvedStops) =>
                              _saveResolvedImages(
                            reference,
                            stops,
                            resolvedStops,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                ItineraryShareHelper.openShareDialog(
                              context,
                              itinerary,
                            ),
                            icon: const Icon(Icons.link_rounded),
                            label: const Text('Share Link'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ItineraryEditPage(
                                  itineraryId: itineraryId,
                                  itinerary: itinerary,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit Stops'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _deleteItinerary(context, reference),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: ExplorerColors.danger,
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
      },
    );
  }
}

class _PreparedItineraryRoute extends StatefulWidget {
  const _PreparedItineraryRoute({
    required this.stops,
    required this.onResolved,
  });

  final List<Map<String, dynamic>> stops;
  final Future<void> Function(
    List<Map<String, dynamic>> resolvedStops,
  ) onResolved;

  @override
  State<_PreparedItineraryRoute> createState() =>
      _PreparedItineraryRouteState();
}

class _PreparedItineraryRouteState
    extends State<_PreparedItineraryRoute> {
  Future<List<Map<String, dynamic>>>? preparation;
  String stopSignature = '';
  bool persisted = false;

  String _signature(List<Map<String, dynamic>> stops) {
    return stops.map((stop) {
      return '${stop['placeId'] ?? ''}|'
          '${stop['geoapifyPlaceId'] ?? ''}|'
          '${stop['name'] ?? ''}|'
          '${stop['imageUrl'] ?? ''}';
    }).join('||');
  }

  void _startPreparation() {
    stopSignature = _signature(widget.stops);
    persisted = false;

    preparation = Future.wait(
      widget.stops.map(
        (stop) => ItineraryImageResolver.resolveAndPrecache(
          context,
          stop,
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (preparation == null) {
      _startPreparation();
    }
  }

  @override
  void didUpdateWidget(
    covariant _PreparedItineraryRoute oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final nextSignature = _signature(widget.stops);
    if (nextSignature != stopSignature) {
      setState(_startPreparation);
    }
  }

  Future<void> _retry() async {
    for (final stop in widget.stops) {
      ItineraryImageResolver.invalidateStop(stop);
    }
    if (!mounted) return;
    setState(_startPreparation);
  }

  @override
  Widget build(BuildContext context) {
    final currentPreparation = preparation;
    if (currentPreparation == null) {
      return const _RoutePreviewLoading();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: currentPreparation,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _RoutePreviewLoading();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return ExplorerCard(
            child: ExplorerEmptyState(
              title: 'Unable to load place previews',
              subtitle:
                  'Check the internet connection and try loading the images again.',
              icon: Icons.image_not_supported_outlined,
              action: OutlinedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry Images'),
              ),
            ),
          );
        }

        final resolvedStops = snapshot.data!;

        if (!persisted) {
          persisted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onResolved(resolvedStops);
          });
        }

        return Column(
          children: resolvedStops.asMap().entries.map((entry) {
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
          }).toList(),
        );
      },
    );
  }
}

class _RoutePreviewLoading extends StatelessWidget {
  const _RoutePreviewLoading();

  @override
  Widget build(BuildContext context) {
    return ExplorerCard(
      child: Column(
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'Preparing place previews...',
            style: TextStyle(
              color: ExplorerColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'The itinerary will appear after the available photos or map previews are cached.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ExplorerColors.muted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItinerarySummaryItem extends StatelessWidget {
  const _ItinerarySummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
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
              ],
            ),
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
    final rating =
        (stop['inAppAverageRating'] as num?)?.toDouble() ??
            (stop['score'] as num?)?.toDouble() ??
            0;
    final reviewCount =
        (stop['inAppReviewCount'] as num?)?.round() ?? 0;
    final travelMinutes =
        (stop['travelMinutesBefore'] as num?)?.round() ?? 0;
    final visitMinutes =
        (stop['durationMinutes'] as num?)?.round() ?? 60;

    return ExplorerCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        children: [
          if (travelMinutes > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 7,
              ),
              decoration: const BoxDecoration(
                color: ExplorerColors.navySoft,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
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
                        '${stop['category'] ?? 'Place'} - $visitMinutes minutes',
                        style: const TextStyle(
                          color: ExplorerColors.goldDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                          Text(
                            '${stop['trustLabel'] ?? 'Insufficient Data'}',
                            style: const TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 9,
                            ),
                          ),
                        ],
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
        ],
      ),
    );
  }
}
