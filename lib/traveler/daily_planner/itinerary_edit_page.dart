part of '../traveler_pages.dart';

class ItineraryEditPage extends StatefulWidget {
  const ItineraryEditPage({
    super.key,
    required this.itineraryId,
    required this.itinerary,
  });

  final String itineraryId;
  final Map<String, dynamic> itinerary;

  @override
  State<ItineraryEditPage> createState() => _ItineraryEditPageState();
}

class _ItineraryEditPageState extends State<ItineraryEditPage> {
  late List<Map<String, dynamic>> stops;
  bool saving = false;
  bool loadingPlaces = false;

  String _stopIdentity(Map<String, dynamic> stop) {
    final vendorId = '${stop['vendorId'] ?? ''}'.trim();
    if (vendorId.isNotEmpty) return 'vendor:$vendorId';
    final placeId = '${stop['placeId'] ?? ''}'.trim();
    if (placeId.isNotEmpty) return 'place:$placeId';
    final geoapifyPlaceId = '${stop['geoapifyPlaceId'] ?? ''}'.trim();
    if (geoapifyPlaceId.isNotEmpty) return 'geo:$geoapifyPlaceId';
    return 'name:${GeoapifyPlanner.reviewKeyFor(stop)}';
  }

  bool _hasDuplicateStops(Iterable<Map<String, dynamic>> values) {
    final seen = <String>{};
    for (final stop in values) {
      final key = _stopIdentity(stop);
      if (key.endsWith(':')) continue;
      if (!seen.add(key)) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    stops = List<Map<String, dynamic>>.from(
      (widget.itinerary['stops'] ?? const []).map(
        (item) => Map<String, dynamic>.from(item),
      ),
    );
  }

  Future<void> addStop() async {
    setState(() => loadingPlaces = true);
    try {
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AddItineraryStopDialog(
          itinerary: widget.itinerary,
          existingPlaceIds: stops
              .map((stop) => '${stop['placeId'] ?? ''}')
              .where((id) => id.isNotEmpty)
              .toList(),
        ),
      );
      if (selected == null || !mounted) return;
      final selectedKey = _stopIdentity(selected);
      if (stops.any((stop) => _stopIdentity(stop) == selectedKey)) {
        showMessage(
          context,
          'This stop is already in the itinerary.',
          error: true,
        );
        return;
      }

      Map<String, dynamic> detailed = selected;
      try {
        detailed = await GeoapifyPlanner.loadPlaceDetails(selected);
      } catch (_) {
        // The search result already contains enough information to add it.
      }
      detailed = await ItineraryImageResolver.resolveStop(detailed);
      if (!mounted) return;

      final detailedKey = _stopIdentity(detailed);
      if (stops.any((stop) => _stopIdentity(stop) == detailedKey)) {
        showMessage(
          context,
          'This stop is already in the itinerary.',
          error: true,
        );
        return;
      }

      final task = detailed['culturalTask'] is Map
          ? Map<String, dynamic>.from(detailed['culturalTask'] as Map)
          : null;
      setState(() {
        stops.add({
          'placeId': detailed['placeId'],
          'geoapifyPlaceId': detailed['geoapifyPlaceId'],
          'vendorId': detailed['vendorId'],
          'mapUrl': detailed['mapUrl'],
          'source': detailed['source'],
          'sequence': stops.length + 1,
          'name': detailed['name'],
          'description': detailed['description'],
          'area': detailed['area'],
          'category': detailed['category'],
          'formattedAddress': detailed['formattedAddress'],
          'durationMinutes': detailed['durationMinutes'] ?? 60,
          'travelMinutesBefore': detailed['travelMinutesBefore'] ?? 0,
          'budgetLevel': detailed['budgetLevel'],
          'score': detailed['score'],
          'inAppAverageRating': detailed['inAppAverageRating'],
          'inAppReviewCount': detailed['inAppReviewCount'],
          'flaggedReviewCount': detailed['flaggedReviewCount'],
          'trustLabel': detailed['trustLabel'],
          'location': detailed['location'],
          'imageUrl': '${detailed['imageUrl'] ?? ''}',
          'fallbackImageUrl':
              '${detailed['fallbackImageUrl'] ?? detailed['mapPreviewUrl'] ?? ''}',
          'imageType': detailed['imageType'],
          'mapPreviewUrl':
              '${detailed['mapPreviewUrl'] ?? detailed['fallbackImageUrl'] ?? ''}',
          'openingHours': detailed['openingHours'],
          'phone': detailed['phone'],
          'website': detailed['website'],
          'cuisine': detailed['cuisine'],
          'suggestionReason': detailed['suggestionReason'],
          'culturalTask': task,
          'culturalTaskId': task?['id'] ?? detailed['activeCulturalTaskId'],
          'culturalTaskTitle': task?['title'],
          'culturalTaskRewardPoints': task?['rewardPoints'],
          'activeVouchers': detailed['activeVouchers'],
          'activeVoucherCount': detailed['activeVoucherCount'],
        });
      });
      showMessage(context, '${detailed['name']} added to the itinerary.');
    } on TimeoutException {
      if (mounted) {
        showMessage(
          context,
          'The vendor search took too long. Please try again.',
          error: true,
        );
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => loadingPlaces = false);
    }
  }

  Future<void> save() async {
    if (!ItineraryShareHelper.canCurrentUserManage(widget.itinerary)) {
      showMessage(
        context,
        'Only the owner can edit this itinerary.',
        error: true,
      );
      return;
    }
    if (_hasDuplicateStops(stops)) {
      showMessage(
        context,
        'Remove duplicate stops before saving this itinerary.',
        error: true,
      );
      return;
    }

    setState(() => saving = true);
    try {
      final updatedStops = await Future.wait(
        stops.asMap().entries.map((entry) async {
          final resolved = await ItineraryImageResolver.resolveStop(
            Map<String, dynamic>.from(entry.value),
          );
          final fallback =
              '${resolved['fallbackImageUrl'] ?? resolved['mapPreviewUrl'] ?? ''}'
                  .trim();
          return <String, dynamic>{
            ...resolved,
            'sequence': entry.key + 1,
            'imageUrl': '${resolved['imageUrl'] ?? ''}',
            'fallbackImageUrl': fallback,
            'mapPreviewUrl': '${resolved['mapPreviewUrl'] ?? fallback}',
          };
        }),
      );
      await AppServices.db
          .collection('itineraries')
          .doc(widget.itineraryId)
          .update({
            'stops': updatedStops,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        showMessage(context, 'Itinerary updated successfully.');
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loadingPlaces ? null : addStop,
        icon: loadingPlaces
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_location_alt_outlined),
        label: Text(loadingPlaces ? 'Opening Search...' : 'Add Stop'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            ExplorerPageHeader(
              title: 'Edit Itinerary',
              subtitle:
                  'Search favourite places, add new stops and drag to reorder.',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              actions: [
                TextButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            ),
            Expanded(
              child: stops.isEmpty
                  ? const ExplorerEmptyState(
                      title: 'No itinerary stops',
                      subtitle: 'Add a place to start building your route.',
                      icon: Icons.route_outlined,
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                      itemCount: stops.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = stops.removeAt(oldIndex);
                          stops.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final stop = stops[index];
                        return Padding(
                          key: ValueKey('${stop['placeId']}_$index'),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ExplorerCard(
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: SizedBox(
                                    width: 58,
                                    height: 58,
                                    child: ItineraryPlaceImage(
                                      stop: stop,
                                      width: 58,
                                      height: 58,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                CircleAvatar(
                                  radius: 19,
                                  backgroundColor: ExplorerColors.goldSoft,
                                  foregroundColor: ExplorerColors.goldDark,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${stop['name'] ?? ''}',
                                        style: const TextStyle(
                                          color: ExplorerColors.navy,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${stop['category'] ?? ''} • '
                                        '${stop['durationMinutes'] ?? 60} minutes',
                                        style: const TextStyle(
                                          color: ExplorerColors.muted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove stop',
                                  onPressed: stops.length <= 1
                                      ? () => showMessage(
                                          context,
                                          'Cannot remove the only location. '
                                          'Delete the full itinerary instead.',
                                          error: true,
                                        )
                                      : () => setState(
                                          () => stops.removeAt(index),
                                        ),
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: ExplorerColors.danger,
                                  ),
                                ),
                                const Icon(
                                  Icons.drag_indicator_rounded,
                                  color: ExplorerColors.muted,
                                ),
                              ],
                            ),
                          ),
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

class _AddItineraryStopDialog extends StatefulWidget {
  const _AddItineraryStopDialog({
    required this.itinerary,
    required this.existingPlaceIds,
  });

  final Map<String, dynamic> itinerary;
  final List<String> existingPlaceIds;

  @override
  State<_AddItineraryStopDialog> createState() =>
      _AddItineraryStopDialogState();
}

class _AddItineraryStopDialogState extends State<_AddItineraryStopDialog> {
  final search = TextEditingController();
  Timer? debounce;
  List<Map<String, dynamic>> results = const [];
  bool loading = true;
  String? error;
  String category = 'All';
  String lastQuery = '';

  static const categories = <String>[
    'All',
    'Heritage',
    'Food',
    'Art',
    'Culture',
    'Nature',
    'Local Business',
  ];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_runSearch);
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  List<String> get _selectedInterests {
    if (category != 'All') return <String>[category];

    // A typed favourite-place search should not be restricted to the
    // itinerary's original interests. This allows a user to search for a
    // restaurant, temple, museum, park or other Penang place directly.
    if (search.text.trim().isNotEmpty) {
      return const <String>[
        'Heritage',
        'Food',
        'Art',
        'Culture',
        'Nature',
        'Local Business',
      ];
    }

    final saved = List<String>.from(
      widget.itinerary['interests'] ?? const <String>[],
    );
    return saved.isEmpty
        ? const <String>['Heritage', 'Food', 'Art', 'Culture', 'Nature']
        : saved;
  }

  void _scheduleSearch(String value) {
    debounce?.cancel();
    final typed = value.trim();

    if (typed.isEmpty) {
      debounce = Timer(const Duration(milliseconds: 250), _runSearch);
      return;
    }

    if (typed.length < 2) {
      setState(() {
        loading = false;
        error = null;
        results = const [];
        lastQuery = typed;
      });
      return;
    }

    debounce = Timer(const Duration(milliseconds: 500), _runSearch);
  }

  Future<void> _runSearch() async {
    final typedQuery = search.text.trim();
    if (typedQuery.isNotEmpty && typedQuery.length < 2) {
      setState(() {
        loading = false;
        error = null;
        results = const [];
        lastQuery = typedQuery;
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
      lastQuery = typedQuery;
    });
    try {
      final places = await GeoapifyPlanner.searchPlacesForAdding(
        area: '${widget.itinerary['area'] ?? 'George Town, Penang'}',
        interests: _selectedInterests,
        budgetLevel: '${widget.itinerary['budgetLevel'] ?? 'Medium'}',
        query: typedQuery,
        excludedPlaceIds: widget.existingPlaceIds,
      );
      if (!mounted) return;
      setState(() => results = places);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString().replaceFirst('Exception: ', '');
        results = const [];
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: min(screen.height * .90, 720.0),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add a Favourite Place',
                          style: TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Browse suggestions or search a place by name.',
                          style: TextStyle(
                            color: ExplorerColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: search,
                autofocus: false,
                textInputAction: TextInputAction.search,
                onChanged: _scheduleSearch,
                onSubmitted: (_) => _runSearch(),
                decoration: InputDecoration(
                  hintText:
                      'Search a Penang restaurant, museum, temple, park or attraction...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (search.text.trim().isNotEmpty)
                        IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            search.clear();
                            _runSearch();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      IconButton(
                        tooltip: 'Search',
                        onPressed: _runSearch,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final value = categories[index];
                  return ChoiceChip(
                    label: Text(value),
                    selected: category == value,
                    onSelected: (_) {
                      setState(() => category = value);
                      _runSearch();
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? ExplorerEmptyState(
                      title: 'Unable to search registered vendors',
                      subtitle: error,
                      icon: Icons.cloud_off_outlined,
                      action: OutlinedButton.icon(
                        onPressed: _runSearch,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try Again'),
                      ),
                    )
                  : results.isEmpty
                  ? ExplorerEmptyState(
                      title: lastQuery.length == 1
                          ? 'Type at least 2 characters'
                          : 'No matching registered vendors found',
                      subtitle: lastQuery.length == 1
                          ? 'Continue typing the place name, for example “Clan Jetties”.'
                          : lastQuery.isEmpty
                          ? 'No suggestions are available for this filter. Try another category.'
                          : 'No Penang place matched “$lastQuery”. Check the spelling or use a shorter keyword.',
                      icon: Icons.search_off_rounded,
                      action: lastQuery.length >= 2
                          ? OutlinedButton.icon(
                              onPressed: _runSearch,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Try Again'),
                            )
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final place = results[index];
                        return _AddPlaceResultCard(
                          place: place,
                          onAdd: () => Navigator.pop(context, place),
                        );
                      },
                    ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: Text(
                'Registered vendors from MyHeritage | Maps by Geoapify and © OpenStreetMap contributors',
                style: TextStyle(color: ExplorerColors.muted, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPlaceResultCard extends StatelessWidget {
  const _AddPlaceResultCard({required this.place, required this.onAdd});

  final Map<String, dynamic> place;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final rating = (place['inAppAverageRating'] as num?)?.toDouble() ?? 0;
    final reviewCount = (place['inAppReviewCount'] as num?)?.round() ?? 0;
    final distance = (place['distanceMeters'] as num?)?.round();
    final distanceText = distance == null
        ? ''
        : distance < 1000
        ? '$distance m'
        : '${(distance / 1000).toStringAsFixed(1)} km';

    return ExplorerCard(
      padding: const EdgeInsets.all(11),
      onTap: onAdd,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 92,
              height: 92,
              child: ItineraryPlaceImage(
                stop: place,
                width: 92,
                height: 92,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${place['name'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${place['category'] ?? ''}'
                  '${distanceText.isEmpty ? '' : ' • $distanceText'}',
                  style: const TextStyle(
                    color: ExplorerColors.goldDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${place['formattedAddress'] ?? place['area'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
