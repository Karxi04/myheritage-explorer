import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/explorer_ui.dart';
import '../../../core/safety_config.dart';
import '../../../models/navigation_stop.dart';
import '../../../services/place_geocoding_service.dart';

String _normalizeText(String input) {
  return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Evaluates which matching tier a [stop] belongs to for a given [query].
///
/// Tiers:
/// 1: Full display name starts with query (e.g. "g" -> "Gurney Paragon")
/// 2: Any token/word in display name starts with query (e.g. "par" -> "Gurney Paragon")
/// 3: Any token/word in address/area starts with query (e.g. "pul" -> "Pulau Tikus")
/// 4: Display name contains query anywhere
/// 5: Address contains query anywhere
/// 6: No match
@visibleForTesting
int matchTier(NavigationStop stop, String query) {
  final cleanQuery = _normalizeText(query);
  if (cleanQuery.isEmpty) return 1;

  final name = _normalizeText(stop.displayName);
  final address = stop.address != null ? _normalizeText(stop.address!) : '';

  // Tier 1: Full display name starts with query
  if (name.startsWith(cleanQuery)) return 1;

  // Split tokens by spaces and common punctuation
  final nameTokens = name
      .split(RegExp(r'[\s,\.\-_]+'))
      .where((t) => t.isNotEmpty);

  // Tier 2: Any word/token in display name starts with query
  if (nameTokens.any((t) => t.startsWith(cleanQuery))) return 2;

  final addressTokens = address
      .split(RegExp(r'[\s,\.\-_]+'))
      .where((t) => t.isNotEmpty);

  // Tier 3: Important address/area token starts with query
  if (addressTokens.any((t) => t.startsWith(cleanQuery))) return 3;

  // Tier 4: Display name contains query
  if (name.contains(cleanQuery)) return 4;

  // Tier 5: Address contains query
  if (address.contains(cleanQuery)) return 5;

  // Tier 6: Unmatched
  return 6;
}

/// Checks whether two navigation stops represent the same real-world location.
@visibleForTesting
bool areStopsDuplicate(NavigationStop a, NavigationStop b) {
  if (a.id.isNotEmpty && b.id.isNotEmpty && a.id == b.id) return true;

  final normA = _normalizeText(
    a.displayName.replaceAll(RegExp(r'[\.,\-_]'), ''),
  );
  final normB = _normalizeText(
    b.displayName.replaceAll(RegExp(r'[\.,\-_]'), ''),
  );

  final nameMatches =
      normA == normB ||
      (normA.length >= 4 && normB.startsWith(normA)) ||
      (normB.length >= 4 && normA.startsWith(normB));

  if (!nameMatches) return false;

  final dist = const Distance().as(LengthUnit.Meter, a.location, b.location);
  return dist <= 250;
}

/// Deduplicates a list of stops while preserving the first encountered instance.
@visibleForTesting
List<NavigationStop> deduplicateStops(List<NavigationStop> stops) {
  final unique = <NavigationStop>[];
  for (final stop in stops) {
    if (!unique.any((existing) => areStopsDuplicate(existing, stop))) {
      unique.add(stop);
    }
  }
  return unique;
}

/// Ranks search results with tier-based prefix priority, proximity bias,
/// and provider ordering.
///
/// Priority:
/// 1. Match Tier (1: full-name prefix, 2: token prefix, 3: address prefix, 4: name substring, 5: address substring)
/// 2. Geodesic distance to [proximity] if available (nearest first within the same tier)
/// 3. Original provider relevance order (preserves API index ranking for ties)
@visibleForTesting
List<NavigationStop> rankSearchResults(
  List<NavigationStop> results, {
  required String query,
  LatLng? proximity,
}) {
  final cleanQuery = _normalizeText(query);
  if (results.isEmpty) return results;

  // Filter out Tier 6 (unmatched) items when query is non-empty
  final matching = cleanQuery.isEmpty
      ? results.toList()
      : results.where((stop) => matchTier(stop, cleanQuery) <= 5).toList();

  final deduped = deduplicateStops(matching);
  final indexed = deduped.asMap().entries.toList();

  indexed.sort((a, b) {
    final stopA = a.value;
    final stopB = b.value;

    if (cleanQuery.isNotEmpty) {
      final tierA = matchTier(stopA, cleanQuery);
      final tierB = matchTier(stopB, cleanQuery);
      if (tierA != tierB) {
        return tierA.compareTo(tierB);
      }
    }

    // Within the same tier: closer to proximity first
    if (proximity != null &&
        SafetyConfig.validCoordinates(
          proximity.latitude,
          proximity.longitude,
        )) {
      final distA = const Distance().as(
        LengthUnit.Meter,
        proximity,
        stopA.location,
      );
      final distB = const Distance().as(
        LengthUnit.Meter,
        proximity,
        stopB.location,
      );
      final distCompare = distA.compareTo(distB);
      if (distCompare != 0) return distCompare;
    }

    // Preserve provider / original order for ties
    return a.key.compareTo(b.key);
  });

  return indexed.map((e) => e.value).toList();
}

/// Full-screen destination search page with hybrid nearby POI discovery,
/// instant local prefix autocomplete, and remote Geoapify result merging.
class DestinationSearchPage extends StatefulWidget {
  const DestinationSearchPage({
    super.key,
    required this.geocodingService,
    this.proximity,
  });

  final PlaceGeocodingService geocodingService;
  final LatLng? proximity;

  /// Clears session-level query and nearby caches (useful in unit tests).
  @visibleForTesting
  static void clearSessionCache() {
    _sessionCache.clear();
    _nearbyCache.clear();
  }

  static final Map<String, List<NavigationStop>> _sessionCache = {};
  static final Map<String, List<NavigationStop>> _nearbyCache = {};

  @override
  State<DestinationSearchPage> createState() => _DestinationSearchPageState();
}

class _DestinationSearchPageState extends State<DestinationSearchPage> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  int _searchRequestId = 0;
  bool _searching = false;
  List<NavigationStop> _searchResults = const [];
  List<NavigationStop> _cachedNearbyPlaces = const [];
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _initNearbyPlaces();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initNearbyPlaces() async {
    final proximity = widget.proximity;
    if (proximity == null ||
        !SafetyConfig.validCoordinates(
          proximity.latitude,
          proximity.longitude,
        )) {
      return;
    }

    final proximityKey =
        '${proximity.latitude.toStringAsFixed(3)},${proximity.longitude.toStringAsFixed(3)}';

    if (DestinationSearchPage._nearbyCache.containsKey(proximityKey)) {
      _cachedNearbyPlaces = DestinationSearchPage._nearbyCache[proximityKey]!;
      if (mounted && _searchController.text.trim().isEmpty) {
        setState(() {
          _searchResults = _cachedNearbyPlaces;
        });
      }
      return;
    }

    try {
      final nearby = await widget.geocodingService.searchNearbyPlaces(
        proximity,
        limit: 30,
      );
      DestinationSearchPage._nearbyCache[proximityKey] = nearby;
      if (mounted) {
        _cachedNearbyPlaces = nearby;
        if (_searchController.text.trim().isEmpty) {
          setState(() {
            _searchResults = nearby;
          });
        }
      }
    } catch (_) {
      // Graceful fallback: nearby discovery failure does not break autocomplete.
    }
  }

  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      _searchRequestId++;
      if (mounted) {
        setState(() {
          _searching = false;
          _searchError = null;
          _searchResults = _cachedNearbyPlaces;
        });
      }
      return;
    }

    // Instantly filter cached nearby POIs with local prefix ranking
    final localMatches = rankSearchResults(
      _cachedNearbyPlaces,
      query: query,
      proximity: widget.proximity,
    );

    if (mounted) {
      setState(() {
        if (localMatches.isNotEmpty) {
          _searchResults = localMatches;
          _searchError = null;
        }
        _searching = true;
      });
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _executeRemoteSearch(query, localMatches);
    });
  }

  Future<void> _executeRemoteSearch(
    String query,
    List<NavigationStop> localMatches,
  ) async {
    final currentRequestId = ++_searchRequestId;

    try {
      final cacheKey =
          '${widget.proximity?.latitude},${widget.proximity?.longitude}|$query';
      List<NavigationStop> remoteResults;
      if (DestinationSearchPage._sessionCache.containsKey(cacheKey)) {
        remoteResults = DestinationSearchPage._sessionCache[cacheKey]!;
      } else {
        remoteResults = await widget.geocodingService.searchPlaces(
          query,
          proximity: widget.proximity,
          limit: 10,
        );
        if (!widget.geocodingService.lastSearchFailed) {
          DestinationSearchPage._sessionCache[cacheKey] = remoteResults;
        }
      }

      if (!mounted || currentRequestId != _searchRequestId) return;

      final currentLocal = rankSearchResults(
        _cachedNearbyPlaces,
        query: query,
        proximity: widget.proximity,
      );
      final effectiveLocal = currentLocal.isNotEmpty
          ? currentLocal
          : localMatches;

      final combined = <NavigationStop>[...effectiveLocal, ...remoteResults];
      final ranked = rankSearchResults(
        combined,
        query: query,
        proximity: widget.proximity,
      );

      if (ranked.isNotEmpty) {
        setState(() {
          _searching = false;
          _searchResults = ranked;
          _searchError = null;
        });
      } else {
        // Both local and remote have no results
        setState(() {
          _searching = false;
          _searchResults = const [];
          if (widget.geocodingService.lastSearchFailed) {
            _searchError = 'Unable to search places right now. Try again.';
          } else {
            _searchError = 'No matching places found.';
          }
        });
      }
    } catch (_) {
      if (!mounted || currentRequestId != _searchRequestId) return;
      final currentLocal = rankSearchResults(
        _cachedNearbyPlaces,
        query: query,
        proximity: widget.proximity,
      );
      final effectiveLocal = currentLocal.isNotEmpty
          ? currentLocal
          : localMatches;

      if (effectiveLocal.isNotEmpty) {
        // Remote failure retains local results!
        setState(() {
          _searching = false;
          _searchResults = effectiveLocal;
          _searchError = null;
        });
      } else {
        setState(() {
          _searching = false;
          _searchResults = const [];
          _searchError = 'Unable to search places right now. Try again.';
        });
      }
    }
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final isQueryEmpty = _searchController.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('safe-navigation-search-back'),
          icon: const Icon(Icons.arrow_back, color: ExplorerColors.navy),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Search destination',
          style: TextStyle(
            color: ExplorerColors.navy,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('safe-navigation-search-input'),
                      controller: _searchController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: _onQueryChanged,
                      onSubmitted: (value) {
                        _debounceTimer?.cancel();
                        final local = rankSearchResults(
                          _cachedNearbyPlaces,
                          query: value.trim(),
                          proximity: widget.proximity,
                        );
                        _executeRemoteSearch(value.trim(), local);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search place name or address in Malaysia…',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: ExplorerColors.muted,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: ExplorerColors.navy,
                            width: 1.5,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: ExplorerColors.navy,
                        ),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    key: ValueKey(
                                      'safe-navigation-search-loading',
                                    ),
                                  ),
                                ),
                              )
                            : (_searchController.text.isNotEmpty
                                  ? IconButton(
                                      key: const ValueKey(
                                        'safe-navigation-search-clear',
                                      ),
                                      icon: const Icon(
                                        Icons.clear,
                                        size: 18,
                                        color: ExplorerColors.muted,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onQueryChanged('');
                                      },
                                    )
                                  : null),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('safe-navigation-search-submit'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ExplorerColors.navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _searching
                        ? null
                        : () {
                            _debounceTimer?.cancel();
                            final query = _searchController.text.trim();
                            final local = rankSearchResults(
                              _cachedNearbyPlaces,
                              query: query,
                              proximity: widget.proximity,
                            );
                            _executeRemoteSearch(query, local);
                          },
                    child: _searching
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Search'),
                  ),
                ],
              ),
            ),
            if (_searchResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isQueryEmpty
                        ? 'Nearby Places'
                        : (widget.proximity != null
                              ? 'Nearby matching places'
                              : 'Search Results'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ExplorerColors.muted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_searchResults.isNotEmpty) {
      return ListView.separated(
        key: const ValueKey('safe-navigation-search-results-list'),
        itemCount: _searchResults.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, index) {
          final place = _searchResults[index];
          return _buildResultTile(context, place, index);
        },
      );
    }

    if (_searchError != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: ExplorerColors.muted,
              ),
              const SizedBox(height: 12),
              Text(
                _searchError!,
                key: const ValueKey('safe-navigation-search-error'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ExplorerColors.muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ExplorerColors.navy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.travel_explore,
                size: 40,
                color: ExplorerColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Search Destinations',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ExplorerColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Type a place name or address in Malaysia to find nearby locations.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ExplorerColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(
    BuildContext context,
    NavigationStop place,
    int index,
  ) {
    final proximity = widget.proximity;
    final distanceText =
        (proximity != null &&
            SafetyConfig.validCoordinates(
              proximity.latitude,
              proximity.longitude,
            ))
        ? '${_formatDistance(const Distance().as(LengthUnit.Meter, proximity, place.location))} away'
        : null;

    return ListTile(
      key: ValueKey('safe-navigation-search-result-$index'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ExplorerColors.navy.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.location_on_outlined,
          color: ExplorerColors.navy,
          size: 22,
        ),
      ),
      title: Text(
        place.displayName,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: ExplorerColors.navy,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (place.address != null && place.address!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              place.address!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: ExplorerColors.muted,
                height: 1.2,
              ),
            ),
          ],
          if (distanceText != null) ...[
            const SizedBox(height: 3),
            Text(
              distanceText,
              key: ValueKey('safe-navigation-search-result-distance-$index'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ExplorerColors.navy,
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        Navigator.of(context).pop(place);
      },
    );
  }
}
