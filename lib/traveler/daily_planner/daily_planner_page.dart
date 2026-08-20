part of '../traveler_pages.dart';

class GeoapifyPlannerResult {
  const GeoapifyPlannerResult({
    required this.places,
    required this.totalEstimatedMinutes,
    required this.remainingMinutes,
  });

  final List<Map<String, dynamic>> places;
  final int totalEstimatedMinutes;
  final int remainingMinutes;
}

class _GeoapifyArea {
  const _GeoapifyArea({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    required this.placeId,
  });

  final double latitude;
  final double longitude;
  final String displayName;
  final String placeId;
}

class _GeoapifyCachedPlaces {
  const _GeoapifyCachedPlaces({required this.createdAt, required this.places});

  final DateTime createdAt;
  final List<Map<String, dynamic>> places;
}

class _GeoapifyCachedPlaceDetails {
  const _GeoapifyCachedPlaceDetails({
    required this.createdAt,
    required this.details,
  });

  final DateTime createdAt;
  final Map<String, dynamic> details;
}

class GeoapifyPlanner {
  const GeoapifyPlanner._();

  static const String _host = 'api.geoapify.com';
  static const int _searchLimitPerInterest = 60;
  static const int _addPlaceSearchLimit = 120;
  static const double _penangLatitude = 5.4141;
  static const double _penangLongitude = 100.3288;

  static final Map<String, _GeoapifyArea> _geocodeCache = {};
  static final Map<String, _GeoapifyCachedPlaces> _placesCache = {};
  static final Map<String, _GeoapifyCachedPlaceDetails> _detailsCache = {};

  static const Map<String, List<String>> _interestCategories = {
    'Heritage': [
      'heritage',
      'tourism.sights',
      'building.historic',
      'entertainment.museum',
      'religion.place_of_worship',
      'man_made.lighthouse',
    ],
    'Food': [
      'catering.restaurant',
      'catering.cafe',
      'catering.fast_food',
      'catering.food_court',
      'commercial.food_and_drink',
      'commercial.marketplace',
    ],
    'Art': [
      'entertainment.culture.gallery',
      'entertainment.culture.arts_centre',
      'entertainment.museum',
      'tourism.attraction.artwork',
      'commercial.art',
    ],
    'Culture': [
      'entertainment.culture',
      'entertainment.museum',
      'religion',
      'tourism.sights',
      'tourism.sights.place_of_worship',
    ],
    'Nature': [
      'leisure.park',
      'natural',
      'beach',
      'tourism.attraction.viewpoint',
      'tourism.attraction',
    ],
  };

  static Future<GeoapifyPlannerResult> generate({
    required String area,
    required double availableHours,
    required List<String> interests,
    required String budgetLevel,
    required String travelPace,
  }) async {
    final normalizedArea = _normalisePenangArea(area);
    if (normalizedArea.isEmpty) {
      throw Exception('Enter an area before generating the itinerary.');
    }
    if (interests.isEmpty) {
      throw Exception('Select at least one travel interest.');
    }

    _GeoapifyArea? locatedArea;
    if (GeoapifyConfig.isConfigured) {
      try {
        locatedArea = await _geocodeArea(normalizedArea);
      } catch (_) {
        // Vendor coordinates still allow itinerary generation.
      }
    }

    final vendors = await _loadVerifiedVendors(normalizedArea);
    final culturalTasks = await _loadActiveCulturalTasks();
    final reviewStats = await _loadReviewStats();
    final voucherMap = await _loadActiveVendorVouchers();

    final candidates = vendors
        .map((vendor) {
          final vendorId = '${vendor['vendorId'] ?? ''}';
          final placeId = '${vendor['placeId'] ?? ''}';
          final stats =
              reviewStats[placeId] ??
              reviewStats['vendor:$vendorId'] ??
              const <String, dynamic>{};
          final task = _matchCulturalTask(vendor, culturalTasks);
          final vouchers =
              voucherMap[vendorId] ?? const <Map<String, dynamic>>[];
          final matchedInterest = _bestVendorInterest(vendor, interests);
          final interestMatchScore = _interestMatchScore(vendor, interests);
          final vendorLocation = _coordinateMap(vendor['location']);
          final distanceMeters = locatedArea == null || vendorLocation == null
              ? 0.0
              : _haversineKm(
                      locatedArea.latitude,
                      locatedArea.longitude,
                      vendorLocation['latitude']!,
                      vendorLocation['longitude']!,
                    ) *
                    1000;
          return <String, dynamic>{
            ...vendor,
            'distanceMeters': distanceMeters,
            'category': matchedInterest,
            'matchedInterest': matchedInterest,
            'interestMatchScore': interestMatchScore,
            'score': stats['averageRating'] ?? 0,
            'inAppAverageRating': stats['averageRating'] ?? 0,
            'inAppReviewCount': stats['validCount'] ?? 0,
            'flaggedReviewCount': stats['flaggedCount'] ?? 0,
            'trustLabel': stats['trustLabel'] ?? 'Insufficient Data',
            'activeVouchers': vouchers.take(3).toList(),
            'activeVoucherCount': vouchers.length,
            if (task != null) 'culturalTask': task,
          };
        })
        .where((vendor) {
          return _vendorMatchesInterests(vendor, interests) &&
              _budgetAllowed(
                userBudget: budgetLevel,
                placeBudget: '${vendor['budgetLevel'] ?? 'Medium'}',
              );
        })
        .toList();

    if (candidates.isEmpty) {
      return GeoapifyPlannerResult(
        places: const [],
        totalEstimatedMinutes: 0,
        remainingMinutes: (availableHours * 60).round(),
      );
    }

    final built = await _buildItinerary(
      candidates: candidates,
      availableMinutes: (availableHours * 60).round(),
      pace: travelPace,
      selectedInterests: interests,
      origin: locatedArea == null
          ? null
          : {
              'latitude': locatedArea.latitude,
              'longitude': locatedArea.longitude,
            },
    );

    final enriched = await Future.wait(
      built.places.map((place) async {
        try {
          return await ItineraryImageResolver.resolveStop(place);
        } catch (_) {
          return place;
        }
      }),
    );

    return GeoapifyPlannerResult(
      places: enriched,
      totalEstimatedMinutes: built.totalEstimatedMinutes,
      remainingMinutes: built.remainingMinutes,
    );
  }

  static Future<List<Map<String, dynamic>>> searchPlacesForAdding({
    required String area,
    required List<String> interests,
    required String budgetLevel,
    String query = '',
    List<String> excludedPlaceIds = const <String>[],
    int limit = _addPlaceSearchLimit,
  }) async {
    final normalisedArea = _normalisePenangArea(area);
    final vendors = await _loadVerifiedVendors(normalisedArea);
    final culturalTasks = await _loadActiveCulturalTasks();
    final reviewStats = await _loadReviewStats();
    final voucherMap = await _loadActiveVendorVouchers();
    final excluded = excludedPlaceIds.toSet();
    final queryKey = _normalize(query);

    final candidates = vendors
        .map((vendor) {
          final vendorId = '${vendor['vendorId'] ?? ''}';
          final placeId = '${vendor['placeId'] ?? ''}';
          final stats =
              reviewStats[placeId] ??
              reviewStats['vendor:$vendorId'] ??
              const <String, dynamic>{};
          final task = _matchCulturalTask(vendor, culturalTasks);
          final vouchers =
              voucherMap[vendorId] ?? const <Map<String, dynamic>>[];
          final matchedInterest = _bestVendorInterest(vendor, interests);
          final interestMatchScore = _interestMatchScore(vendor, interests);
          final enriched = <String, dynamic>{
            ...vendor,
            'category': matchedInterest,
            'matchedInterest': matchedInterest,
            'interestMatchScore': interestMatchScore,
            'score': stats['averageRating'] ?? 0,
            'inAppAverageRating': stats['averageRating'] ?? 0,
            'inAppReviewCount': stats['validCount'] ?? 0,
            'flaggedReviewCount': stats['flaggedCount'] ?? 0,
            'trustLabel': stats['trustLabel'] ?? 'Insufficient Data',
            'activeVouchers': vouchers.take(3).toList(),
            'activeVoucherCount': vouchers.length,
            if (task != null) 'culturalTask': task,
          };
          enriched['suggestionReason'] = _suggestionReason(enriched);
          return enriched;
        })
        .where((vendor) {
          final placeId = '${vendor['placeId'] ?? ''}';
          if (placeId.isEmpty || excluded.contains(placeId)) return false;
          if (queryKey.isEmpty) {
            return interests.isEmpty ||
                _vendorMatchesInterests(vendor, interests);
          }
          final searchable = _normalize(
            '${vendor['name'] ?? ''} ${vendor['formattedAddress'] ?? ''} '
            '${vendor['businessCategory'] ?? ''} '
            '${(vendor['tags'] as List?)?.join(' ') ?? ''}',
          );
          return _matchesSearchQuery(query, searchable);
        })
        .toList();

    candidates.sort((first, second) {
      final firstScore = _addPlaceRank(
        first,
        queryKey: queryKey,
        selectedInterests: interests,
        budgetLevel: budgetLevel,
      );
      final secondScore = _addPlaceRank(
        second,
        queryKey: queryKey,
        selectedInterests: interests,
        budgetLevel: budgetLevel,
      );
      return secondScore.compareTo(firstScore);
    });

    final selected = candidates.take(limit).toList();
    return Future.wait(
      selected.map((vendor) async {
        try {
          return await ItineraryImageResolver.resolveStop(vendor);
        } catch (_) {
          return vendor;
        }
      }),
    );
  }

  static List<String> _searchQueryVariants(String query) {
    final value = query.trim();
    final key = _normalize(value);
    final variants = <String>{value};

    void addWhen(bool condition, Iterable<String> values) {
      if (condition) variants.addAll(values);
    }

    addWhen(key.contains('clan jett') || key.contains('chew jett'), const [
      'Clan Jetties of Penang',
      'Chew Jetty',
    ]);
    addWhen(key.contains('blue mansion') || key.contains('cheong fatt'), const [
      'Cheong Fatt Tze Mansion',
      'The Blue Mansion',
    ]);
    addWhen(key.contains('peranakan') || key.contains('pinang mansion'), const [
      'Pinang Peranakan Mansion',
    ]);
    addWhen(key.contains('botanic'), const [
      'Penang Botanic Gardens',
      'Penang Botanical Gardens',
    ]);
    addWhen(key.contains('kek lok'), const ['Kek Lok Si Temple']);
    addWhen(key.contains('armenian'), const [
      'Armenian Street',
      'Lebuh Armenian',
    ]);

    return variants.take(4).toList();
  }

  static bool _matchesSearchQuery(String query, String searchable) {
    final searchableKey = _normalize(searchable);
    if (searchableKey.isEmpty) return false;

    for (final variant in _searchQueryVariants(query)) {
      final queryKey = _normalize(variant);
      if (queryKey.isEmpty) continue;
      if (searchableKey.contains(queryKey)) return true;

      final queryTokens = queryKey
          .split(' ')
          .where((token) => token.length > 1)
          .toList();
      final searchableTokens = searchableKey
          .split(' ')
          .where((token) => token.length > 1)
          .toList();

      final prefixMatch =
          queryTokens.isNotEmpty &&
          queryTokens.every(
            (queryToken) => searchableTokens.any(
              (candidate) =>
                  candidate.startsWith(queryToken) ||
                  queryToken.startsWith(candidate),
            ),
          );
      if (prefixMatch) return true;

      if (_querySimilarity(queryKey, searchableKey) >= 0.20) {
        return true;
      }
    }
    return false;
  }

  static double _addPlaceRank(
    Map<String, dynamic> place, {
    required String queryKey,
    required List<String> selectedInterests,
    required String budgetLevel,
  }) {
    final nameKey = _normalize('${place['name'] ?? ''}');
    var queryBonus = 0.0;
    if (queryKey.isNotEmpty) {
      if (nameKey == queryKey) {
        queryBonus = 3.0;
      } else if (nameKey.startsWith(queryKey)) {
        queryBonus = 2.2;
      } else if (nameKey.contains(queryKey)) {
        queryBonus = 1.6;
      } else {
        queryBonus = _querySimilarity(queryKey, nameKey) * 1.4;
      }
    }

    final interestBonus =
        ((place['interestMatchScore'] as num?)?.toDouble() ??
            _interestMatchScore(place, selectedInterests)) *
        0.85;
    final budgetBonus =
        _budgetAllowed(
          userBudget: budgetLevel,
          placeBudget: '${place['budgetLevel'] ?? 'Low'}',
        )
        ? 0.20
        : -0.10;

    return _rank(place) + queryBonus + interestBonus + budgetBonus;
  }

  static double _querySimilarity(String first, String second) {
    final firstTokens = first
        .split(' ')
        .where((token) => token.length > 1)
        .toSet();
    final secondTokens = second
        .split(' ')
        .where((token) => token.length > 1)
        .toSet();
    if (firstTokens.isEmpty || secondTokens.isEmpty) return 0;
    final intersection = firstTokens.intersection(secondTokens).length;
    final union = firstTokens.union(secondTokens).length;
    return union == 0 ? 0 : intersection / union;
  }

  static String _normalisePenangArea(String area) {
    final value = area.trim();
    if (value.isEmpty) return 'George Town, Penang, Malaysia';

    final lower = value.toLowerCase();
    if (lower == 'penang' ||
        lower == 'pulau pinang' ||
        lower == 'penang island') {
      return 'George Town, Penang, Malaysia';
    }
    if (lower.contains('malaysia')) return value;
    if (lower.contains('penang') || lower.contains('pulau pinang')) {
      return '$value, Malaysia';
    }
    return '$value, Penang, Malaysia';
  }

  static bool _isPenangArea(String value) {
    final lower = value.toLowerCase();
    return lower.contains('penang') ||
        lower.contains('pulau pinang') ||
        lower.contains('george town') ||
        lower.contains('air itam') ||
        lower.contains('batu ferringhi') ||
        lower.contains('tanjung bungah') ||
        lower.contains('tanjung tokong') ||
        lower.contains('teluk bahang') ||
        lower.contains('balik pulau') ||
        lower.contains('bayan lepas') ||
        lower.contains('jelutong') ||
        lower.contains('gelugor');
  }

  static bool _isPenangAddress(String value) {
    final lower = value.toLowerCase();
    const terms = [
      'penang',
      'pulau pinang',
      'george town',
      'air itam',
      'ayer itam',
      'batu ferringhi',
      'tanjung bungah',
      'tanjung tokong',
      'teluk bahang',
      'balik pulau',
      'bayan lepas',
      'jelutong',
      'gelugor',
      'butterworth',
      'bukit mertajam',
    ];
    return terms.any(lower.contains);
  }

  static String _categoryFromSearchText(
    String value,
    List<String> selectedInterests,
  ) {
    final lower = value.toLowerCase();

    bool selected(String interest) =>
        selectedInterests.isEmpty || selectedInterests.contains(interest);

    if (selected('Food') &&
        [
          'restaurant',
          'cafe',
          'coffee',
          'food',
          'hawker',
          'market',
          'bakery',
          'nasi kandar',
        ].any(lower.contains)) {
      return 'Food';
    }
    if (selected('Nature') &&
        [
          'hill',
          'garden',
          'park',
          'beach',
          'forest',
          'national park',
          'nature',
          'spice garden',
        ].any(lower.contains)) {
      return 'Nature';
    }
    if (selected('Art') &&
        [
          'art',
          'gallery',
          'museum',
          'depot',
          'street art',
        ].any(lower.contains)) {
      return 'Art';
    }
    if (selected('Heritage') &&
        [
          'heritage',
          'mansion',
          'fort',
          'kongsi',
          'church',
          'historic',
          'clan',
        ].any(lower.contains)) {
      return 'Heritage';
    }
    if (selected('Culture') &&
        [
          'temple',
          'mosque',
          'church',
          'museum',
          'cultural',
          'jetty',
        ].any(lower.contains)) {
      return 'Culture';
    }
    return selectedInterests.isNotEmpty ? selectedInterests.first : 'Culture';
  }

  static Future<List<Map<String, dynamic>>> _searchAutocompletePenangPlaces({
    required String query,
    required String area,
    required _GeoapifyArea locatedArea,
    required List<String> selectedInterests,
  }) async {
    final uri = Uri.https(_host, '/v1/geocode/autocomplete', {
      'text': '$query, Penang, Malaysia',
      'type': 'amenity',
      'format': 'json',
      'lang': 'en',
      'limit': '20',
      'filter': 'countrycode:my',
      'bias': 'proximity:${locatedArea.longitude},${locatedArea.latitude}',
      'apiKey': GeoapifyConfig.apiKey,
    });

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));
    final decoded = _decodeObject(response.body);

    if (response.statusCode != 200) {
      throw _apiException(
        response.statusCode,
        decoded,
        operation: 'autocomplete the place name',
      );
    }

    final rawResults = decoded['results'];
    if (rawResults is! List) return const [];

    final results = <Map<String, dynamic>>[];
    for (final raw in rawResults) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final latitude = _asDouble(item['lat']);
      final longitude = _asDouble(item['lon']);
      final placeId = '${item['place_id'] ?? ''}'.trim();
      final name = '${item['name'] ?? item['address_line1'] ?? query}'.trim();
      final formattedAddress =
          '${item['formatted'] ?? item['address_line2'] ?? area}'.trim();

      if (latitude == null ||
          longitude == null ||
          placeId.isEmpty ||
          !_isUsefulPlaceName(name) ||
          !_isPenangAddress(formattedAddress)) {
        continue;
      }

      final category = _categoryFromSearchText(
        '$query ${item['category'] ?? ''} '
        '${item['result_type'] ?? ''} $name',
        selectedInterests,
      );
      final mapPreviewUrl = _staticMapImageUrl(
        latitude: latitude,
        longitude: longitude,
      );
      final distanceMeters =
          (_haversineKm(
                    locatedArea.latitude,
                    locatedArea.longitude,
                    latitude,
                    longitude,
                  ) *
                  1000)
              .round();

      results.add({
        'placeId': 'geoapify_$placeId',
        'geoapifyPlaceId': placeId,
        'source': 'geoapify',
        'name': name,
        'description': _descriptionFor(
          name: name,
          category: category,
          address: formattedAddress,
          categories: const <String>[],
        ),
        'formattedAddress': formattedAddress,
        'area': area,
        'category': category,
        'matchedInterest': category,
        'tags': <String>[category],
        'durationMinutes': _durationForGeoapify(category, const <String>[]),
        'budgetLevel': category == 'Food' ? 'Medium' : 'Low',
        'budgetConfidence': 'estimated',
        'score': 0,
        'distanceMeters': distanceMeters,
        'dataCompletenessScore': 0.50,
        'location': {'latitude': latitude, 'longitude': longitude},
        'mapUrl':
            'https://www.openstreetmap.org/?mlat=$latitude'
            '&mlon=$longitude#map=18/$latitude/$longitude',
        'mapPreviewUrl': mapPreviewUrl,
        'fallbackImageUrl': mapPreviewUrl,
        'imageUrl': mapPreviewUrl,
        'imageType': 'map_preview',
        'trustLabel': 'Insufficient Data',
        'searchMatchScore': 1.20,
      });
    }

    return _deduplicate(results);
  }

  static Future<List<Map<String, dynamic>>> _searchNamedPenangPlaces({
    required String query,
    required String area,
    required _GeoapifyArea locatedArea,
    required List<String> selectedInterests,
  }) async {
    final uri = Uri.https(_host, '/v1/geocode/search', {
      'text': '$query, Penang, Malaysia',
      'format': 'json',
      'lang': 'en',
      'limit': '15',
      'filter': 'countrycode:my',
      'bias': 'proximity:${locatedArea.longitude},${locatedArea.latitude}',
      'apiKey': GeoapifyConfig.apiKey,
    });

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));
    final decoded = _decodeObject(response.body);
    if (response.statusCode != 200) {
      throw _apiException(
        response.statusCode,
        decoded,
        operation: 'search the place name',
      );
    }

    final rawResults = decoded['results'];
    if (rawResults is! List) return const [];

    final results = <Map<String, dynamic>>[];
    for (final raw in rawResults) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final latitude = _asDouble(item['lat']);
      final longitude = _asDouble(item['lon']);
      final placeId = '${item['place_id'] ?? ''}'.trim();
      final name = '${item['name'] ?? item['address_line1'] ?? query}'.trim();
      final formattedAddress =
          '${item['formatted'] ?? item['address_line2'] ?? area}'.trim();

      if (latitude == null ||
          longitude == null ||
          placeId.isEmpty ||
          !_isUsefulPlaceName(name) ||
          !_isPenangAddress(formattedAddress)) {
        continue;
      }

      final category = _categoryFromSearchText(
        '$query ${item['category'] ?? ''} '
        '${item['result_type'] ?? ''} $name',
        selectedInterests,
      );
      final mapPreviewUrl = _staticMapImageUrl(
        latitude: latitude,
        longitude: longitude,
      );
      final distanceMeters =
          (_haversineKm(
                    locatedArea.latitude,
                    locatedArea.longitude,
                    latitude,
                    longitude,
                  ) *
                  1000)
              .round();

      results.add({
        'placeId': 'geoapify_$placeId',
        'geoapifyPlaceId': placeId,
        'source': 'geoapify',
        'name': name,
        'description': _descriptionFor(
          name: name,
          category: category,
          address: formattedAddress,
          categories: const <String>[],
        ),
        'formattedAddress': formattedAddress,
        'area': area,
        'category': category,
        'matchedInterest': category,
        'tags': <String>[category],
        'durationMinutes': _durationForGeoapify(category, const <String>[]),
        'budgetLevel': category == 'Food' ? 'Medium' : 'Low',
        'budgetConfidence': 'estimated',
        'score': 0,
        'distanceMeters': distanceMeters,
        'dataCompletenessScore': 0.45,
        'location': {'latitude': latitude, 'longitude': longitude},
        'mapUrl':
            'https://www.openstreetmap.org/?mlat=$latitude'
            '&mlon=$longitude#map=18/$latitude/$longitude',
        'mapPreviewUrl': mapPreviewUrl,
        'imageUrl': mapPreviewUrl,
        'imageType': 'map_preview',
        'trustLabel': 'Insufficient Data',
        'searchMatchScore': 1.0,
      });
    }

    return _deduplicate(results);
  }

  static Future<_GeoapifyArea> _geocodeArea(String area) async {
    final key = area.trim().toLowerCase();
    final cached = _geocodeCache[key];
    if (cached != null) return cached;

    final query = _normalisePenangArea(area);
    final uri = Uri.https(_host, '/v1/geocode/search', {
      'text': query,
      'format': 'json',
      'lang': 'en',
      'limit': '1',
      'filter': 'countrycode:my',
      'bias': 'proximity:$_penangLongitude,$_penangLatitude',
      'apiKey': GeoapifyConfig.apiKey,
    });

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));
    final decoded = _decodeObject(response.body);

    if (response.statusCode != 200) {
      throw _apiException(
        response.statusCode,
        decoded,
        operation: 'locate the entered area',
      );
    }

    final results = decoded['results'];
    if (results is! List || results.isEmpty || results.first is! Map) {
      throw Exception(
        'Area not found. Try a more specific value such as '
        'George Town, Penang.',
      );
    }

    final first = Map<String, dynamic>.from(results.first as Map);
    final latitude = _asDouble(first['lat']);
    final longitude = _asDouble(first['lon']);
    if (latitude == null || longitude == null) {
      throw Exception('Geoapify returned an invalid area location.');
    }

    final result = _GeoapifyArea(
      latitude: latitude,
      longitude: longitude,
      displayName: '${first['formatted'] ?? area}',
      placeId: '${first['place_id'] ?? ''}',
    );
    _geocodeCache[key] = result;
    return result;
  }

  static Future<List<Map<String, dynamic>>> _searchPlaces({
    required String area,
    required _GeoapifyArea locatedArea,
    required List<String> interests,
    required int radiusMeters,
    bool usePlaceBoundary = false,
    String? name,
    int limitPerInterest = _searchLimitPerInterest,
  }) async {
    final settled = await Future.wait(
      interests.map((interest) async {
        try {
          return await _searchPlacesForInterest(
            area: area,
            locatedArea: locatedArea,
            interest: interest,
            radiusMeters: radiusMeters,
            usePlaceBoundary: usePlaceBoundary,
            name: name,
            limit: limitPerInterest,
          );
        } catch (_) {
          // One unavailable category must not block all Penang results.
          return const <Map<String, dynamic>>[];
        }
      }),
    );

    return _deduplicate(settled.expand((items) => items).toList());
  }

  static Future<List<Map<String, dynamic>>> _searchPlacesForInterest({
    required String area,
    required _GeoapifyArea locatedArea,
    required String interest,
    required int radiusMeters,
    bool usePlaceBoundary = false,
    String? name,
    int limit = _searchLimitPerInterest,
  }) async {
    final categories = _interestCategories[interest] ?? const <String>[];
    if (categories.isEmpty) return const [];

    final longitude = locatedArea.longitude.toStringAsFixed(6);
    final latitude = locatedArea.latitude.toStringAsFixed(6);
    final placeBoundary = locatedArea.placeId.trim();
    final filter = usePlaceBoundary && placeBoundary.isNotEmpty
        ? 'place:$placeBoundary'
        : 'circle:$longitude,$latitude,$radiusMeters';
    final parameters = <String, String>{
      'categories': categories.join(','),
      'conditions': 'named',
      'filter': filter,
      'bias': 'proximity:$longitude,$latitude',
      'limit': '$limit',
      'lang': 'en',
      'apiKey': GeoapifyConfig.apiKey,
    };
    if (name != null && name.trim().isNotEmpty) {
      parameters['name'] = name.trim();
    }
    final uri = Uri.https(_host, '/v2/places', parameters);

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 25));
    final decoded = _decodeObject(response.body);

    if (response.statusCode != 200) {
      throw _apiException(
        response.statusCode,
        decoded,
        operation: 'search $interest places',
      );
    }

    final features = decoded['features'];
    if (features is! List) {
      throw Exception('Geoapify returned an invalid place-search response.');
    }

    final results = <Map<String, dynamic>>[];
    for (final rawFeature in features) {
      if (rawFeature is! Map) continue;
      final feature = Map<String, dynamic>.from(rawFeature);
      final properties = feature['properties'] is Map
          ? Map<String, dynamic>.from(feature['properties'] as Map)
          : <String, dynamic>{};
      final geometry = feature['geometry'] is Map
          ? Map<String, dynamic>.from(feature['geometry'] as Map)
          : <String, dynamic>{};
      final coordinates = geometry['coordinates'];

      double? longitudeValue;
      double? latitudeValue;
      if (coordinates is List && coordinates.length >= 2) {
        longitudeValue = _asDouble(coordinates[0]);
        latitudeValue = _asDouble(coordinates[1]);
      }
      longitudeValue ??= _asDouble(properties['lon']);
      latitudeValue ??= _asDouble(properties['lat']);
      if (latitudeValue == null || longitudeValue == null) continue;

      final categoriesList = List<String>.from(
        properties['categories'] is List
            ? properties['categories'] as List
            : const [],
      );
      final category = _categoryFromGeoapify(
        categoriesList,
        selectedInterests: [interest],
      );
      if (category == null) continue;

      final name = '${properties['name'] ?? properties['address_line1'] ?? ''}'
          .trim();
      if (!_isUsefulPlaceName(name)) continue;

      final geoapifyPlaceId = '${properties['place_id'] ?? ''}'.trim();
      if (geoapifyPlaceId.isEmpty) continue;

      final contact = properties['contact'] is Map
          ? Map<String, dynamic>.from(properties['contact'] as Map)
          : const <String, dynamic>{};
      final datasource = properties['datasource'] is Map
          ? Map<String, dynamic>.from(properties['datasource'] as Map)
          : const <String, dynamic>{};
      final rawSource = datasource['raw'] is Map
          ? Map<String, dynamic>.from(datasource['raw'] as Map)
          : const <String, dynamic>{};
      final media = properties['wiki_and_media'] is Map
          ? Map<String, dynamic>.from(properties['wiki_and_media'] as Map)
          : const <String, dynamic>{};

      final formattedAddress =
          '${properties['formatted'] ?? locatedArea.displayName}'.trim();
      if (formattedAddress.isEmpty) continue;

      if (_isPenangArea(area) && !_isPenangAddress(formattedAddress)) {
        continue;
      }

      final exactImageUrl = _normaliseImageUrl(
        _firstText([media['image'], properties['image'], rawSource['image']]),
      );
      final mapPreviewUrl = _staticMapImageUrl(
        latitude: latitudeValue,
        longitude: longitudeValue,
      );
      final imageUrl = exactImageUrl.isNotEmpty ? exactImageUrl : mapPreviewUrl;
      final imageType = exactImageUrl.isNotEmpty
          ? 'place_photo'
          : 'map_preview';

      final distanceMeters =
          (properties['distance'] as num?)?.round() ??
          (_haversineKm(
                    locatedArea.latitude,
                    locatedArea.longitude,
                    latitudeValue,
                    longitudeValue,
                  ) *
                  1000)
              .round();
      if (!usePlaceBoundary && distanceMeters > radiusMeters + 300) continue;

      final website = _firstText([
        properties['website'],
        contact['website'],
        rawSource['website'],
      ]);
      final phone = _firstText([
        properties['phone'],
        contact['phone'],
        rawSource['phone'],
      ]);
      final openingHours = _firstText([
        properties['opening_hours'],
        rawSource['opening_hours'],
      ]);
      final cuisine = _firstText([properties['cuisine'], rawSource['cuisine']]);

      final completenessScore = _dataCompletenessScore(
        address: formattedAddress,
        website: website,
        phone: phone,
        openingHours: openingHours,
        imageType: imageType,
      );

      final mapUrl =
          'https://www.openstreetmap.org/?mlat='
          '$latitudeValue&mlon=$longitudeValue'
          '#map=18/$latitudeValue/$longitudeValue';

      results.add({
        'placeId': 'geoapify_$geoapifyPlaceId',
        'geoapifyPlaceId': geoapifyPlaceId,
        'source': 'geoapify',
        'name': name,
        'description': _descriptionFor(
          name: name,
          category: category,
          address: formattedAddress,
          categories: categoriesList,
          cuisine: cuisine,
        ),
        'formattedAddress': formattedAddress,
        'area': area,
        'category': category,
        'matchedInterest': interest,
        'tags': _applicationTags(categoriesList, category),
        'durationMinutes': _durationForGeoapify(category, categoriesList),
        'budgetLevel': _estimatedBudget(properties, category),
        'budgetConfidence': _budgetConfidence(properties, categoriesList),
        'score': 0,
        'distanceMeters': distanceMeters,
        'dataCompletenessScore': completenessScore,
        'location': {'latitude': latitudeValue, 'longitude': longitudeValue},
        'mapUrl': mapUrl,
        'mapPreviewUrl': mapPreviewUrl,
        'imageUrl': imageUrl,
        'imageType': imageType,
        'website': website,
        'phone': phone,
        'openingHours': openingHours,
        'cuisine': cuisine,
        'trustLabel': 'Insufficient Data',
      });
    }

    results.sort((first, second) {
      final firstScore = _rank(first);
      final secondScore = _rank(second);
      return secondScore.compareTo(firstScore);
    });
    return results;
  }

  static Future<List<Map<String, dynamic>>> _loadFirestorePlaces({
    required String area,
    required List<String> interests,
  }) async {
    final snapshot = await AppServices.db
        .collection('places')
        .where('status', isEqualTo: 'active')
        .get();
    final areaKey = _normalize(area);
    final interestKeys = interests.map(_normalize).toSet();

    return snapshot.docs
        .map((doc) {
          final data = doc.data();
          final category = '${data['category'] ?? 'Heritage'}';
          final tags = List<String>.from(data['tags'] ?? const []);
          final rawLocation = data['location'];
          Map<String, dynamic>? location;
          if (rawLocation is GeoPoint) {
            location = {
              'latitude': rawLocation.latitude,
              'longitude': rawLocation.longitude,
            };
          } else if (rawLocation is Map) {
            location = Map<String, dynamic>.from(rawLocation);
          }
          return {
            'placeId': doc.id,
            'geoapifyPlaceId': data['geoapifyPlaceId'],
            'source': 'firestore',
            'name': '${data['name'] ?? 'Unnamed place'}',
            'description': '${data['description'] ?? ''}',
            'formattedAddress':
                '${data['formattedAddress'] ?? data['area'] ?? ''}',
            'area': '${data['area'] ?? area}',
            'category': category,
            'tags': tags,
            'durationMinutes':
                (data['durationMinutes'] as num?)?.round() ??
                _defaultDuration(category),
            'budgetLevel': '${data['budgetLevel'] ?? 'Low'}',
            'score': (data['score'] as num?)?.toDouble() ?? 0,
            'imageUrl': '${data['imageUrl'] ?? ''}',
            'imageType': '${data['imageUrl'] ?? ''}'.trim().isEmpty
                ? 'none'
                : 'place_photo',
            'dataCompletenessScore': _dataCompletenessScore(
              address: '${data['formattedAddress'] ?? data['area'] ?? ''}',
              website: '${data['website'] ?? ''}',
              phone: '${data['phone'] ?? ''}',
              openingHours: '${data['openingHours'] ?? ''}',
              imageType: '${data['imageUrl'] ?? ''}'.trim().isEmpty
                  ? 'none'
                  : 'place_photo',
            ),
            'matchedInterest': category,
            'location': location,
            'mapUrl': '${data['mapUrl'] ?? ''}',
            'website': '${data['website'] ?? ''}',
            'phone': '${data['phone'] ?? ''}',
            'openingHours': '${data['openingHours'] ?? ''}',
            'activeCulturalTaskId': data['activeCulturalTaskId'],
            'trustLabel': '${data['trustLabel'] ?? 'Insufficient Data'}',
          };
        })
        .where((place) {
          final placeArea = _normalize('${place['area'] ?? ''}');
          final matchesArea =
              placeArea.isNotEmpty &&
              (placeArea.contains(areaKey) || areaKey.contains(placeArea));
          final values = [
            '${place['category'] ?? ''}',
            ...List<String>.from(place['tags'] ?? const []),
          ].map(_normalize);
          final matchesInterest = values.any(interestKeys.contains);
          return matchesArea && matchesInterest;
        })
        .toList();
  }

  static Future<List<Map<String, dynamic>>> _loadVerifiedVendors(
    String area,
  ) async {
    final snapshot = await AppServices.db
        .collection('vendors')
        .where('status', isEqualTo: 'active')
        .where('vendorStatus', isEqualTo: 'verified')
        .get();

    return snapshot.docs
        .where((doc) {
          final data = doc.data();
          final address = '${data['shopLocation'] ?? ''}';
          final name = '${data['businessName'] ?? data['displayName'] ?? ''}'
              .trim();
          return name.isNotEmpty &&
              (_isPenangAddress(address) ||
                  '${data['state'] ?? ''}'.toLowerCase() == 'penang');
        })
        .map((doc) {
          final data = doc.data();
          final rawLocation = data['location'];
          Map<String, dynamic>? location;
          if (rawLocation is GeoPoint) {
            location = {
              'latitude': rawLocation.latitude,
              'longitude': rawLocation.longitude,
            };
          } else if (rawLocation is Map) {
            location = Map<String, dynamic>.from(rawLocation);
          } else if (data['latitude'] is num && data['longitude'] is num) {
            location = {
              'latitude': (data['latitude'] as num).toDouble(),
              'longitude': (data['longitude'] as num).toDouble(),
            };
          }

          final plannerCategories = _vendorCategories(data);
          final vendorTags = List<String>.from(
            data['tags'] ?? const <String>[],
          ).where((item) => item.trim().isNotEmpty).toList();
          final combinedTags = <String>{
            ...plannerCategories,
            ...vendorTags,
          }.toList();
          final category = plannerCategories.firstWhere(
            (item) => item != 'Local Business',
            orElse: () => 'Local Business',
          );
          final duration = switch (category) {
            'Food' => 60,
            'Nature' => 90,
            'Heritage' || 'Culture' || 'Art' => 75,
            _ => 45,
          };

          final imageUrl = '${data['imageUrl'] ?? ''}'.trim();
          final storedImageCandidates = List<String>.from(
            data['imageCandidates'] ?? const <String>[],
          ).where((url) => url.trim().isNotEmpty).toList();
          final website =
              '${data['website'] ?? data['websiteUrl'] ?? ''}'.trim();
          final mapPreview = location == null
              ? ''
              : ItineraryImageResolver.staticMapPreview(
                  latitude: location['latitude']!,
                  longitude: location['longitude']!,
                );

          return <String, dynamic>{
            'placeId': 'vendor_${doc.id}',
            'vendorId': doc.id,
            'source': 'registered_vendor',
            'name':
                '${data['businessName'] ?? data['displayName'] ?? 'Local business'}',
            'businessCategory': '${data['businessCategory'] ?? ''}',
            'plannerCategories': plannerCategories,
            'description': '${data['businessDescription'] ?? ''}',
            'formattedAddress': '${data['shopLocation'] ?? area}',
            'area': '${data['shopLocation'] ?? area}',
            'areaRelevanceScore': _areaTextRelevance(
              selectedArea: area,
              vendorAddress: '${data['shopLocation'] ?? ''}',
            ),
            'category': category,
            'tags': combinedTags,
            'durationMinutes': duration,
            'budgetLevel': '${data['budgetLevel'] ?? 'Medium'}',
            'score': (data['score'] as num?)?.toDouble() ?? 0,
            'imageUrl': imageUrl.isNotEmpty ? imageUrl : mapPreview,
            'fallbackImageUrl': mapPreview,
            'mapPreviewUrl': mapPreview,
            'imageCandidates': [
              ...storedImageCandidates,
              if (imageUrl.isNotEmpty) imageUrl,
              if (mapPreview.isNotEmpty) mapPreview,
            ],
            'imageType': imageUrl.isNotEmpty
                ? '${data['imageType'] ?? 'vendor_uploaded_photo'}'
                : 'map_preview',
            'dataCompletenessScore': _dataCompletenessScore(
              address: '${data['shopLocation'] ?? area}',
              website: website,
              phone: '${data['contactNumber'] ?? ''}',
              openingHours: '${data['businessHours'] ?? ''}',
              imageType: imageUrl.isNotEmpty
                  ? 'place_photo'
                  : mapPreview.isNotEmpty
                  ? 'map_preview'
                  : 'none',
            ),
            'matchedInterest': category,
            'phone': '${data['contactNumber'] ?? ''}',
            'website': website,
            'openingHours': '${data['businessHours'] ?? ''}',
            'location': location,
            'mapUrl': '${data['mapUrl'] ?? ''}',
            'trustLabel': '${data['trustLabel'] ?? 'Insufficient Data'}',
          };
        })
        .toList();
  }

  static List<String> _vendorCategories(Map<String, dynamic> data) {
    final categories = <String>{'Local Business'};
    categories.addAll(
      List<String>.from(
        data['plannerCategories'] ?? const <String>[],
      ).where((item) => item.trim().isNotEmpty),
    );
    final value = '${data['businessCategory'] ?? ''}'.toLowerCase();
    if (value.contains('food') ||
        value.contains('cafe') ||
        value.contains('restaurant')) {
      categories.add('Food');
    }
    if (value.contains('heritage')) {
      categories.addAll(['Heritage', 'Culture']);
    }
    if (value.contains('craft') ||
        value.contains('workshop') ||
        value.contains('culture')) {
      categories.add('Culture');
    }
    if (value.contains('nature') || value.contains('eco')) {
      categories.add('Nature');
    }
    if (value.contains('art')) {
      categories.addAll(['Art', 'Culture']);
    }
    return categories.toList();
  }

  static double _areaTextRelevance({
    required String selectedArea,
    required String vendorAddress,
  }) {
    final selectedTokens = _normalize(selectedArea)
        .split(' ')
        .where(
          (token) =>
              token.length > 2 &&
              token != 'penang' &&
              token != 'malaysia' &&
              token != 'pulau' &&
              token != 'pinang',
        )
        .toSet();
    if (selectedTokens.isEmpty) return 0;

    final addressTokens = _normalize(
      vendorAddress,
    ).split(' ').where((token) => token.length > 2).toSet();
    if (addressTokens.isEmpty) return 0;

    final matched = selectedTokens.intersection(addressTokens).length;
    return matched / selectedTokens.length;
  }

  static bool _vendorMatchesInterests(
    Map<String, dynamic> vendor,
    List<String> interests,
  ) {
    return _interestMatchScore(vendor, interests) > 0;
  }

  static double _interestMatchScore(
    Map<String, dynamic> vendor,
    List<String> interests,
  ) {
    final selected = interests
        .where((interest) => interest.trim().isNotEmpty)
        .where((interest) => interest != 'Local Business')
        .map(_normalize)
        .toSet();
    if (selected.isEmpty) return 1.0;

    final values = <String>{
      _normalize('${vendor['category'] ?? ''}'),
      _normalize('${vendor['matchedInterest'] ?? ''}'),
      _normalize('${vendor['businessCategory'] ?? ''}'),
      ...List<String>.from(
        vendor['plannerCategories'] ?? const <String>[],
      ).map(_normalize),
      ...List<String>.from(vendor['tags'] ?? const <String>[]).map(_normalize),
    }..remove('');
    if (values.isEmpty) return 0.0;

    final matched = selected.where(values.contains).length;
    return matched / selected.length;
  }

  static String _bestVendorInterest(
    Map<String, dynamic> vendor,
    List<String> interests,
  ) {
    final values = <String>{
      ...List<String>.from(
        vendor['plannerCategories'] ?? vendor['tags'] ?? const <String>[],
      ),
      '${vendor['category'] ?? ''}',
    };
    for (final interest in interests) {
      if (interest != 'Local Business' && values.contains(interest)) {
        return interest;
      }
    }
    return values.firstWhere(
      (value) => value.isNotEmpty && value != 'Local Business',
      orElse: () => 'Local Business',
    );
  }

  static Future<Map<String, List<Map<String, dynamic>>>>
  _loadActiveVendorVouchers() async {
    final snapshot = await AppServices.db
        .collection('vouchers')
        .where('status', isEqualTo: 'active')
        .get();
    final now = DateTime.now();
    final result = <String, List<Map<String, dynamic>>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final vendorId = '${data['vendorId'] ?? ''}'.trim();
      final expiry = asDate(data['expiresAt']);
      final inventory = (data['inventoryRemaining'] as num?)?.round() ?? 0;
      if (vendorId.isEmpty || inventory <= 0) continue;
      if (expiry != null && expiry.isBefore(now)) continue;
      result.putIfAbsent(vendorId, () => []).add({'id': doc.id, ...data});
    }
    return result;
  }

  static Future<List<Map<String, dynamic>>> _loadActiveCulturalTasks() async {
    final snapshot = await AppServices.db
        .collection('cultural_tasks')
        .where('status', isEqualTo: 'active')
        .get();
    final now = DateTime.now();

    return snapshot.docs
        .map((doc) {
          return {'id': doc.id, ...doc.data()};
        })
        .where((task) {
          final deadline = asDate(task['deadline']);
          return deadline == null || !deadline.isBefore(now);
        })
        .toList();
  }

  static Future<Map<String, Map<String, dynamic>>> _loadPlaceContent() async {
    final snapshot = await AppServices.db
        .collection('place_content')
        .where('status', isEqualTo: 'active')
        .get();
    final result = <String, Map<String, dynamic>>{};

    for (final doc in snapshot.docs) {
      final data = <String, dynamic>{'id': doc.id, ...doc.data()};
      final canonicalKey = _normalize(
        '${data['placeNameKey'] ?? data['name'] ?? doc.id}',
      );
      if (canonicalKey.isEmpty) continue;

      final content = <String, dynamic>{...data, 'placeNameKey': canonicalKey};
      result[canonicalKey] = content;

      final aliases = List<String>.from(data['aliases'] ?? const []);
      for (final alias in aliases) {
        final aliasKey = _normalize(alias);
        if (aliasKey.isNotEmpty) {
          result[aliasKey] = content;
        }
      }
    }
    return result;
  }

  static Map<String, dynamic> _mergePlaceContent(
    Map<String, dynamic> original,
    Map<String, dynamic>? content,
  ) {
    final place = Map<String, dynamic>.from(original);
    if (content == null) return place;

    final contentImage = '${content['imageUrl'] ?? ''}'.trim();
    final currentImage = '${place['imageUrl'] ?? ''}'.trim();
    final currentImageType = '${place['imageType'] ?? ''}'.trim();
    final hasExactGeoapifyPhoto = currentImageType == 'place_photo';

    final contentDescription = '${content['description'] ?? ''}'.trim();
    final currentDescription = '${place['description'] ?? ''}'.trim();

    return {
      ...place,
      'contentKey': '${content['placeNameKey'] ?? ''}',
      'description': contentDescription.isNotEmpty
          ? contentDescription
          : currentDescription,
      'imageUrl': hasExactGeoapifyPhoto || contentImage.isEmpty
          ? currentImage
          : contentImage,
      'imageType': hasExactGeoapifyPhoto || contentImage.isEmpty
          ? currentImageType
          : '${content['imageType'] ?? 'curated_place_photo'}',
      'imageAttribution': hasExactGeoapifyPhoto
          ? '${place['imageAttribution'] ?? ''}'
          : '${content['imageAttribution'] ?? ''}',
      'imageSourceUrl': hasExactGeoapifyPhoto
          ? '${place['imageSourceUrl'] ?? ''}'
          : '${content['imageSourceUrl'] ?? ''}',
      'imageNotice': hasExactGeoapifyPhoto
          ? '${place['imageNotice'] ?? ''}'
          : '${content['imageNotice'] ?? ''}',
      'recommendedFor': List<String>.from(
        content['recommendedFor'] ??
            place['recommendedFor'] ??
            const <String>[],
      ),
      'penangPriority':
          content['penangPriority'] ?? place['penangPriority'] ?? 0,
      'officialArea':
          '${content['officialArea'] ?? place['officialArea'] ?? ''}',
    };
  }

  static String reviewKeyFor(Map<String, dynamic> place) {
    final contentKey = _normalize('${place['contentKey'] ?? ''}');
    if (contentKey.isNotEmpty) return contentKey;
    return _normalize('${place['name'] ?? ''}');
  }

  static Future<Map<String, Map<String, dynamic>>> _loadReviewStats() async {
    final snapshot = await AppServices.db.collection('reviews').get();
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final source = '${data['source'] ?? ''}'.toLowerCase();
      final generatedReview =
          data['isDemo'] == true ||
          data['isPrototype'] == true ||
          source.contains('demo') ||
          source.contains('prototype') ||
          source.contains('seed_demo');

      // A real-system rating must only use reviews submitted by actual users.
      if (generatedReview) continue;

      final keys = <String>{};

      final placeId = '${data['placeId'] ?? ''}'.trim();
      if (placeId.isNotEmpty) keys.add(placeId);

      final vendorId = '${data['vendorId'] ?? ''}'.trim();
      if (vendorId.isNotEmpty) keys.add('vendor:$vendorId');

      final placeNameKey = _normalize(
        '${data['placeNameKey'] ?? data['placeName'] ?? ''}',
      );
      if (placeNameKey.isNotEmpty) {
        keys.add('name:$placeNameKey');
      }

      for (final key in keys) {
        grouped.putIfAbsent(key, () => []).add(data);
      }
    }

    final result = <String, Map<String, dynamic>>{};
    grouped.forEach((placeId, reviews) {
      final valid = reviews
          .where((review) => review['status'] == 'valid')
          .toList();
      final flagged = reviews
          .where((review) => review['status'] == 'flagged')
          .toList();
      final average = valid.isEmpty
          ? 0.0
          : valid.fold<double>(
                  0,
                  (sum, review) =>
                      sum + ((review['rating'] as num?)?.toDouble() ?? 0),
                ) /
                valid.length;
      final total = valid.length + flagged.length;
      String trustLabel = 'Insufficient Data';
      if (total >= 3) {
        final flaggedRatio = flagged.length / total;
        trustLabel = flaggedRatio <= 0.10
            ? 'High Trust'
            : flaggedRatio <= 0.30
            ? 'Medium Trust'
            : 'Low Trust';
      }
      result[placeId] = {
        'averageRating': double.parse(average.toStringAsFixed(1)),
        'validCount': valid.length,
        'flaggedCount': flagged.length,
        'trustLabel': trustLabel,
      };
    });
    return result;
  }

  static Map<String, dynamic>? _matchCulturalTask(
    Map<String, dynamic> place,
    List<Map<String, dynamic>> tasks,
  ) {
    final placeId = '${place['placeId'] ?? ''}';
    final vendorId = '${place['vendorId'] ?? ''}';
    final geoapifyPlaceId = '${place['geoapifyPlaceId'] ?? ''}';
    final nameKey = _normalize('${place['name'] ?? ''}');

    for (final task in tasks) {
      if ('${task['vendorId'] ?? ''}' == vendorId && vendorId.isNotEmpty) {
        return _taskView(task);
      }
      if ('${task['placeId'] ?? ''}' == placeId && placeId.isNotEmpty) {
        return _taskView(task);
      }
      if ('${task['geoapifyPlaceId'] ?? ''}' == geoapifyPlaceId &&
          geoapifyPlaceId.isNotEmpty) {
        return _taskView(task);
      }
      final locationKey = _normalize('${task['locationName'] ?? ''}');
      if (locationKey.length >= 4 &&
          (nameKey.contains(locationKey) || locationKey.contains(nameKey))) {
        return _taskView(task);
      }
    }
    return null;
  }

  static Map<String, dynamic> _taskView(Map<String, dynamic> task) {
    return {
      'id': task['id'],
      'title': '${task['title'] ?? 'Cultural Task'}',
      'description': '${task['description'] ?? ''}',
      'rewardPoints': (task['rewardPoints'] as num?)?.round() ?? 0,
      'locationName': '${task['locationName'] ?? ''}',
      'vendorId': '${task['vendorId'] ?? ''}',
      'placeId': '${task['placeId'] ?? ''}',
      'requiredPhotoCategory': '${task['requiredPhotoCategory'] ?? ''}',
      'mapUrl': '${task['mapUrl'] ?? ''}',
      'location': task['location'],
    };
  }

  static Future<GeoapifyPlannerResult> _buildItinerary({
    required List<Map<String, dynamic>> candidates,
    required int availableMinutes,
    required String pace,
    required List<String> selectedInterests,
    required Map<String, double>? origin,
  }) async {
    final paceMultiplier = switch (pace) {
      'Relaxed' => 1.25,
      'Fast' || 'Packed' => 0.80,
      _ => 1.0,
    };

    final remainingCandidates = candidates.map((place) {
      final base = (place['durationMinutes'] as num?)?.round() ?? 60;
      return {
        ...place,
        'durationMinutes': max(30, (base * paceMultiplier).round()),
      };
    }).toList()..sort((first, second) => _rank(second).compareTo(_rank(first)));

    final selected = <Map<String, dynamic>>[];
    final selectedIdentities = <String>{};
    final categoryCounts = <String, int>{};
    var remaining = availableMinutes;

    while (remainingCandidates.isNotEmpty && selected.length < 6) {
      var bestIndex = -1;
      var bestScore = -double.infinity;
      var bestTravelMinutes = 0;

      for (var index = 0; index < remainingCandidates.length; index++) {
        final candidate = remainingCandidates[index];
        final identity = _placeIdentity(candidate);
        if (selectedIdentities.contains(identity)) continue;
        final previousLocation = selected.isEmpty
            ? origin
            : _coordinateMap(selected.last['location']);
        final travelMinutes = previousLocation == null
            ? 0
            : _estimatedTravelMinutes(
                previousLocation,
                candidate['location'],
                pace,
              );
        final visitMinutes =
            (candidate['durationMinutes'] as num?)?.round() ?? 60;
        if (travelMinutes + visitMinutes > remaining) continue;

        final category = '${candidate['category'] ?? ''}';
        final matchedInterest = '${candidate['matchedInterest'] ?? category}';
        final categoryAlreadySelected = (categoryCounts[category] ?? 0) > 0;
        final coverageBonus =
            selectedInterests.contains(matchedInterest) &&
                !categoryAlreadySelected
            ? 0.55
            : 0.0;
        final duplicatePenalty = (categoryCounts[category] ?? 0) * 0.28;
        final travelPenalty = min(travelMinutes / 60, 1.0) * 0.25;
        final adjusted =
            _rank(candidate) + coverageBonus - duplicatePenalty - travelPenalty;

        if (adjusted > bestScore) {
          bestScore = adjusted;
          bestIndex = index;
          bestTravelMinutes = travelMinutes;
        }
      }

      if (bestIndex < 0) break;
      final chosen = remainingCandidates.removeAt(bestIndex);
      chosen['travelMinutesBefore'] = bestTravelMinutes;
      selected.add(chosen);
      selectedIdentities.add(_placeIdentity(chosen));
      remaining -=
          bestTravelMinutes +
          ((chosen['durationMinutes'] as num?)?.round() ?? 60);
      final category = '${chosen['category'] ?? ''}';
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
    }

    _optimiseVisitOrder(selected, origin: origin, pace: pace);

    if (GeoapifyConfig.useRoutingApi) {
      await _applyRoutingTimes(selected);
    }

    var totalEstimatedMinutes = selected.fold<int>(
      0,
      (total, place) =>
          total +
          ((place['durationMinutes'] as num?)?.round() ?? 60) +
          ((place['travelMinutesBefore'] as num?)?.round() ?? 0),
    );

    while (selected.length > 1 && totalEstimatedMinutes > availableMinutes) {
      selected.removeLast();
      totalEstimatedMinutes = selected.fold<int>(
        0,
        (total, place) =>
            total +
            ((place['durationMinutes'] as num?)?.round() ?? 60) +
            ((place['travelMinutesBefore'] as num?)?.round() ?? 0),
      );
    }

    for (final place in selected) {
      place['suggestionReason'] = _suggestionReason(place);
    }

    return GeoapifyPlannerResult(
      places: selected,
      totalEstimatedMinutes: totalEstimatedMinutes,
      remainingMinutes: max(0, availableMinutes - totalEstimatedMinutes),
    );
  }

  static void _optimiseVisitOrder(
    List<Map<String, dynamic>> selected, {
    required Map<String, double>? origin,
    required String pace,
  }) {
    if (selected.length < 2) {
      if (selected.isNotEmpty) {
        selected.first['travelMinutesBefore'] = 0;
      }
      return;
    }

    final unordered = List<Map<String, dynamic>>.from(selected);
    final ordered = <Map<String, dynamic>>[];
    Map<String, double>? current = origin;

    while (unordered.isNotEmpty) {
      var bestIndex = 0;
      var bestDistance = double.infinity;
      for (var index = 0; index < unordered.length; index++) {
        final point = _coordinateMap(unordered[index]['location']);
        if (point == null || current == null) {
          if (bestDistance == double.infinity) bestIndex = index;
          continue;
        }
        final distance = _haversineKm(
          current['latitude']!,
          current['longitude']!,
          point['latitude']!,
          point['longitude']!,
        );
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = index;
        }
      }

      final next = unordered.removeAt(bestIndex);
      next['travelMinutesBefore'] = ordered.isEmpty
          ? 0
          : _estimatedTravelMinutes(
              ordered.last['location'],
              next['location'],
              pace,
            );
      ordered.add(next);
      current = _coordinateMap(next['location']) ?? current;
    }

    selected
      ..clear()
      ..addAll(ordered);
  }

  static Future<void> _applyRoutingTimes(
    List<Map<String, dynamic>> selected,
  ) async {
    if (selected.length < 2) return;

    final points = <Map<String, double>>[];
    for (final place in selected) {
      final coordinates = _coordinateMap(place['location']);
      if (coordinates == null) return;
      points.add(coordinates);
    }

    final waypoints = points
        .map((point) => '${point['latitude']},${point['longitude']}')
        .join('|');
    final uri = Uri.https(_host, '/v1/routing', {
      'waypoints': waypoints,
      'mode': 'walk',
      'format': 'json',
      'lang': 'en',
      'apiKey': GeoapifyConfig.apiKey,
    });

    try {
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) return;

      final decoded = _decodeObject(response.body);
      final results = decoded['results'];
      if (results is! List || results.isEmpty || results.first is! Map) {
        return;
      }
      final route = Map<String, dynamic>.from(results.first as Map);
      final legs = route['legs'];
      if (legs is! List) return;

      selected.first['travelMinutesBefore'] = 0;
      for (
        var index = 0;
        index < legs.length && index + 1 < selected.length;
        index++
      ) {
        if (legs[index] is! Map) continue;
        final leg = Map<String, dynamic>.from(legs[index] as Map);
        final seconds = _asDouble(leg['time']);
        final distance = _asDouble(leg['distance']);
        if (seconds != null) {
          selected[index + 1]['travelMinutesBefore'] = max(
            1,
            (seconds / 60).ceil(),
          );
        }
        if (distance != null) {
          selected[index + 1]['routeDistanceMetersBefore'] = distance.round();
        }
      }
    } catch (_) {
      // The itinerary still works with the local distance estimate.
    }
  }

  static int _estimatedTravelMinutes(Object? from, Object? to, String pace) {
    final fromPoint = _coordinateMap(from);
    final toPoint = _coordinateMap(to);
    if (fromPoint == null || toPoint == null) {
      return switch (pace) {
        'Relaxed' => 15,
        'Fast' || 'Packed' => 8,
        _ => 10,
      };
    }

    final distanceKm = _haversineKm(
      fromPoint['latitude']!,
      fromPoint['longitude']!,
      toPoint['latitude']!,
      toPoint['longitude']!,
    );
    final walkingSpeed = switch (pace) {
      'Relaxed' => 3.5,
      'Fast' || 'Packed' => 5.5,
      _ => 4.5,
    };
    return max(5, min(60, ((distanceKm / walkingSpeed) * 60).round()));
  }

  static Map<String, double>? _coordinateMap(Object? raw) {
    if (raw is GeoPoint) {
      return {'latitude': raw.latitude, 'longitude': raw.longitude};
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final latitude = _asDouble(map['latitude'] ?? map['lat']);
      final longitude = _asDouble(map['longitude'] ?? map['lon']);
      if (latitude != null && longitude != null) {
        return {'latitude': latitude, 'longitude': longitude};
      }
    }
    return null;
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    double radians(double degrees) => degrees * pi / 180;
    final dLat = radians(lat2 - lat1);
    final dLon = radians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(radians(lat1)) * cos(radians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _rank(Map<String, dynamic> place) {
    final score = (place['score'] as num?)?.toDouble() ?? 0;
    final reviewCount = (place['inAppReviewCount'] as num?)?.toDouble() ?? 0;
    final distanceMeters = (place['distanceMeters'] as num?)?.toDouble() ?? 0;
    final completeness =
        (place['dataCompletenessScore'] as num?)?.toDouble() ?? 0;
    final source = '${place['source'] ?? ''}';
    final sourceBonus = source == 'registered_vendor'
        ? 0.52
        : source == 'verified_vendor'
        ? 0.42
        : source == 'firestore'
        ? 0.34
        : 0.16;
    final taskBonus = place['culturalTask'] == null ? 0.0 : 0.32;
    final voucherBonus =
        ((place['activeVoucherCount'] as num?)?.round() ?? 0) > 0 ? 0.14 : 0.0;
    final distanceBonus = distanceMeters <= 0
        ? 0.0
        : max(0.0, 1.0 - distanceMeters / 7000) * 0.18;
    final areaRelevance =
        (place['areaRelevanceScore'] as num?)?.toDouble() ?? 0.0;
    final interestRelevance =
        (place['interestMatchScore'] as num?)?.toDouble() ?? 0.0;
    final imageType = '${place['imageType'] ?? ''}';
    final imageBonus =
        imageType == 'place_photo' || imageType == 'curated_place_photo'
        ? 0.10
        : imageType == 'representative_photo'
        ? 0.04
        : 0.0;
    final openingBonus = '${place['openingHours'] ?? ''}'.trim().isEmpty
        ? 0.0
        : 0.06;
    final penangPriority = (place['penangPriority'] as num?)?.toDouble() ?? 0.0;
    final penangBonus = min(max(penangPriority, 0.0) / 100.0, 1.0) * 0.65;
    return (score / 5) * 0.48 +
        min(reviewCount / 10, 1.0) * 0.18 +
        sourceBonus +
        taskBonus +
        voucherBonus +
        distanceBonus +
        min(max(areaRelevance, 0.0), 1.0) * 0.24 +
        min(max(interestRelevance, 0.0), 1.0) * 0.75 +
        min(completeness, 1.0) * 0.20 +
        imageBonus +
        openingBonus +
        penangBonus;
  }

  static String _placeIdentity(Map<String, dynamic> place) {
    final name = _normalize('${place['name'] ?? ''}');
    final address = _normalize(
      '${place['formattedAddress'] ?? place['address'] ?? place['area'] ?? ''}',
    );
    if (name.isNotEmpty && address.isNotEmpty) {
      return 'name:$name|$address';
    }

    final vendorId = '${place['vendorId'] ?? ''}'.trim();
    if (vendorId.isNotEmpty) return 'vendor:$vendorId';

    final placeId = '${place['placeId'] ?? ''}'.trim();
    if (placeId.isNotEmpty) return 'place:$placeId';

    final geoapifyPlaceId = '${place['geoapifyPlaceId'] ?? ''}'.trim();
    if (geoapifyPlaceId.isNotEmpty) return 'geo:$geoapifyPlaceId';

    return name;
  }

  static List<Map<String, dynamic>> _deduplicate(
    List<Map<String, dynamic>> places,
  ) {
    final unique = <String, Map<String, dynamic>>{};
    for (final place in places) {
      final name = _normalize('${place['name'] ?? ''}');
      if (name.isEmpty) continue;
      final key = _placeIdentity(place);
      final current = unique[key];
      if (current == null || _rank(place) > _rank(current)) {
        unique[key] = place;
      }
    }
    return unique.values.toList();
  }

  static bool _budgetAllowed({
    required String userBudget,
    required String placeBudget,
  }) {
    const rank = {'Low': 1, 'Medium': 2, 'High': 3};
    return (rank[placeBudget] ?? 1) <= (rank[userBudget] ?? 2);
  }

  static String? _categoryFromGeoapify(
    List<String> categories, {
    required List<String> selectedInterests,
  }) {
    bool containsPrefix(String prefix) => categories.any(
      (category) => category == prefix || category.startsWith('$prefix.'),
    );

    if (selectedInterests.contains('Food') &&
        (containsPrefix('catering') ||
            containsPrefix('commercial.food_and_drink') ||
            containsPrefix('commercial.marketplace'))) {
      return 'Food';
    }
    if (selectedInterests.contains('Art') &&
        (containsPrefix('entertainment.culture.gallery') ||
            containsPrefix('entertainment.culture.arts_centre') ||
            containsPrefix('tourism.attraction.artwork') ||
            containsPrefix('commercial.art'))) {
      return 'Art';
    }
    if (selectedInterests.contains('Nature') &&
        (containsPrefix('leisure') ||
            containsPrefix('natural') ||
            containsPrefix('beach') ||
            containsPrefix('tourism.attraction.viewpoint'))) {
      return 'Nature';
    }
    if (selectedInterests.contains('Heritage') &&
        (containsPrefix('heritage') ||
            containsPrefix('tourism.sights') ||
            containsPrefix('building.historic'))) {
      return 'Heritage';
    }
    if (selectedInterests.contains('Culture') &&
        (containsPrefix('entertainment.culture') ||
            containsPrefix('entertainment.museum') ||
            containsPrefix('religion') ||
            containsPrefix('tourism.sights.place_of_worship'))) {
      return 'Culture';
    }
    if (selectedInterests.contains('Heritage') &&
        containsPrefix('entertainment.museum')) {
      return 'Heritage';
    }
    return null;
  }

  static int _radiusForHours(double availableHours) {
    if (availableHours <= 2) return 5000;
    if (availableHours <= 4) return 9000;
    if (availableHours <= 8) return 18000;
    return 30000;
  }

  static bool _isUsefulPlaceName(String name) {
    final value = name.trim();
    if (value.length < 2) return false;
    final lower = value.toLowerCase();
    const blocked = {
      'yes',
      'no',
      'restaurant',
      'cafe',
      'food',
      'shop',
      'building',
      'place',
      'unnamed',
    };
    return !blocked.contains(lower);
  }

  static int _durationForGeoapify(String category, List<String> categories) {
    bool containsPrefix(String prefix) =>
        categories.any((item) => item == prefix || item.startsWith('$prefix.'));
    if (containsPrefix('catering.fast_food')) return 35;
    if (containsPrefix('catering.cafe')) return 45;
    if (containsPrefix('catering.food_court')) return 50;
    if (containsPrefix('entertainment.museum')) return 90;
    if (containsPrefix('entertainment.culture.gallery')) return 60;
    if (containsPrefix('tourism.attraction.viewpoint')) return 45;
    if (containsPrefix('leisure.park.nature_reserve')) return 120;
    return _defaultDuration(category);
  }

  static String _budgetConfidence(
    Map<String, dynamic> properties,
    List<String> categories,
  ) {
    final fee = '${properties['fee'] ?? ''}'.trim();
    if (fee.isNotEmpty) return 'High';
    if (categories.any((item) => item.startsWith('catering.fast_food')) ||
        categories.any((item) => item.startsWith('catering.cafe'))) {
      return 'Medium';
    }
    return 'Low';
  }

  static double _dataCompletenessScore({
    required String address,
    required String website,
    required String phone,
    required String openingHours,
    required String imageType,
  }) {
    var points = 0.0;
    if (address.trim().isNotEmpty) points += 0.25;
    if (website.trim().isNotEmpty) points += 0.20;
    if (phone.trim().isNotEmpty) points += 0.20;
    if (openingHours.trim().isNotEmpty) points += 0.20;
    if (imageType == 'place_photo') points += 0.15;
    return min(points, 1.0);
  }

  static String _staticMapImageUrl({
    required double latitude,
    required double longitude,
  }) {
    final center =
        'lonlat:${longitude.toStringAsFixed(6)},'
        '${latitude.toStringAsFixed(6)}';
    final marker =
        'lonlat:${longitude.toStringAsFixed(6)},'
        '${latitude.toStringAsFixed(6)};'
        'color:#0A2A5E;size:48';
    return Uri.https('maps.geoapify.com', '/v1/staticmap', {
      'style': 'osm-bright',
      'width': '900',
      'height': '450',
      'center': center,
      'zoom': '16',
      'marker': marker,
      'scaleFactor': '1',
      'format': 'png',
      'apiKey': GeoapifyConfig.apiKey,
    }).toString();
  }

  static String _normaliseImageUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    if (value.toLowerCase().startsWith('file:')) {
      final fileName = value.substring(5).trim();
      if (fileName.isEmpty) return '';
      return 'https://commons.wikimedia.org/wiki/'
          'Special:Redirect/file/${Uri.encodeComponent(fileName)}?width=1200';
    }
    return '';
  }

  static String _suggestionReason(Map<String, dynamic> place) {
    final reasons = <String>[];
    final interest = '${place['matchedInterest'] ?? place['category'] ?? ''}';
    if (interest.trim().isNotEmpty) {
      reasons.add('Matches $interest');
    }
    final distance = (place['distanceMeters'] as num?)?.round();
    if (distance != null && distance > 0) {
      if (distance < 1000) {
        reasons.add('${distance} m from the selected area');
      } else {
        reasons.add(
          '${(distance / 1000).toStringAsFixed(1)} km from the selected area',
        );
      }
    }
    if ((place['inAppReviewCount'] as num? ?? 0) > 0) {
      reasons.add('rated by MyHeritage travelers');
    }
    if (place['culturalTask'] != null) {
      reasons.add('includes a cultural task');
    }
    if ('${place['openingHours'] ?? ''}'.trim().isNotEmpty) {
      reasons.add('opening hours available');
    }
    if (reasons.isEmpty) {
      return 'Selected because it fits your trip preferences.';
    }
    return reasons.take(3).join(' - ');
  }

  static int _defaultDuration(String category) {
    return switch (category) {
      'Food' => 60,
      'Nature' => 90,
      'Local Business' => 45,
      'Art' => 60,
      'Culture' => 75,
      _ => 75,
    };
  }

  static String _estimatedBudget(
    Map<String, dynamic> properties,
    String category,
  ) {
    final fee = '${properties['fee'] ?? ''}'.toLowerCase();
    if (fee == 'no' || fee == 'false') return 'Low';
    if (fee == 'yes' || fee == 'true') return 'Medium';
    if (category == 'Food' || category == 'Local Business') {
      return 'Medium';
    }
    if (category == 'Art' || category == 'Culture') {
      return 'Medium';
    }
    return 'Low';
  }

  static List<String> _applicationTags(
    List<String> geoapifyCategories,
    String category,
  ) {
    final result = <String>{category};
    bool containsPrefix(String prefix) => geoapifyCategories.any(
      (item) => item == prefix || item.startsWith('$prefix.'),
    );

    if (containsPrefix('heritage') ||
        containsPrefix('tourism.sights') ||
        containsPrefix('building.historic')) {
      result.add('Heritage');
    }
    if (containsPrefix('catering') ||
        containsPrefix('commercial.food_and_drink') ||
        containsPrefix('commercial.marketplace')) {
      result.add('Food');
    }
    if (containsPrefix('entertainment.culture.gallery') ||
        containsPrefix('tourism.attraction.artwork')) {
      result.add('Art');
    }
    if (containsPrefix('entertainment.culture') ||
        containsPrefix('religion.place_of_worship')) {
      result.add('Culture');
    }
    if (containsPrefix('leisure') ||
        containsPrefix('natural') ||
        containsPrefix('beach')) {
      result.add('Nature');
    }
    return result.toList();
  }

  static String _descriptionFor({
    required String name,
    required String category,
    required String address,
    required List<String> categories,
    String rawDescription = '',
    String cuisine = '',
    String diet = '',
    bool? takeaway,
    bool? delivery,
    bool? outdoorSeating,
  }) {
    if (rawDescription.trim().isNotEmpty) {
      return rawDescription.trim();
    }

    if (category == 'Food') {
      final cuisineText = _prettySeparatedText(cuisine);
      final sentences = <String>[];
      if (cuisineText.isNotEmpty) {
        sentences.add(
          '$name is a ${cuisineText.toLowerCase()} food and dining place.',
        );
      } else {
        sentences.add('$name is a restaurant or food venue.');
      }
      if (address.trim().isNotEmpty) {
        sentences.add('It is located at ${address.trim()}.');
      }

      final services = <String>[];
      if (takeaway == true) services.add('takeaway');
      if (delivery == true) services.add('delivery');
      if (outdoorSeating == true) services.add('outdoor seating');
      if (services.isNotEmpty) {
        sentences.add('Available services include ${_naturalJoin(services)}.');
      }

      final dietText = _prettySeparatedText(diet);
      if (dietText.isNotEmpty) {
        sentences.add('Listed diet options include $dietText.');
      }
      return sentences.join(' ');
    }

    final detail = categories
        .where(
          (categoryName) =>
              !categoryName.startsWith('wheelchair') &&
              !categoryName.startsWith('access'),
        )
        .take(3)
        .map((categoryName) => _prettyValue(categoryName.split('.').last))
        .join(', ');
    if (detail.isNotEmpty) {
      return '$name is a $category place associated with $detail. $address';
    }
    return '$name is a $category place located at $address';
  }

  static Future<Map<String, dynamic>> loadPlaceDetails(
    Map<String, dynamic> originalPlace,
  ) async {
    final original = Map<String, dynamic>.from(originalPlace);
    if ('${original['source'] ?? ''}' != 'geoapify') return original;
    if (!GeoapifyConfig.isConfigured) return original;

    final placeId = '${original['geoapifyPlaceId'] ?? ''}'.trim();
    if (placeId.isEmpty) return original;

    final cached = _detailsCache[placeId];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) <
            const Duration(hours: 6)) {
      return {...original, ...Map<String, dynamic>.from(cached.details)};
    }

    final uri = Uri.https(_host, '/v2/place-details', {
      'id': placeId,
      'features': 'details',
      'lang': 'en',
      'apiKey': GeoapifyConfig.apiKey,
    });

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));
    final decoded = _decodeObject(response.body);

    if (response.statusCode != 200) {
      throw _apiException(
        response.statusCode,
        decoded,
        operation: 'load the place details',
      );
    }

    final features = decoded['features'];
    if (features is! List || features.isEmpty) return original;

    Map<String, dynamic>? properties;
    for (final rawFeature in features) {
      if (rawFeature is! Map) continue;
      final feature = Map<String, dynamic>.from(rawFeature);
      final candidate = feature['properties'];
      if (candidate is! Map) continue;
      final map = Map<String, dynamic>.from(candidate);
      if ('${map['feature_type'] ?? ''}' == 'details') {
        properties = map;
        break;
      }
    }
    properties ??=
        features.first is Map && (features.first as Map)['properties'] is Map
        ? Map<String, dynamic>.from(
            (features.first as Map)['properties'] as Map,
          )
        : null;
    if (properties == null) return original;

    final catering = _asMap(properties['catering']);
    final contact = _asMap(properties['contact']);
    final media = _asMap(properties['wiki_and_media']);
    final paymentOptions = _asMap(properties['payment_options']);

    final cuisine = _firstText([catering['cuisine'], original['cuisine']]);
    final diet = _firstText([catering['diet'], original['diet']]);
    final officialDescription = _firstText([
      properties['description'],
      original['officialDescription'],
    ]);
    final website = _firstText([
      properties['website'],
      contact['website'],
      original['website'],
    ]);
    final phone = _firstText([
      contact['phone'],
      properties['phone'],
      original['phone'],
    ]);
    final email = _firstText([
      contact['email'],
      properties['email'],
      original['email'],
    ]);
    final openingHours = _firstText([
      properties['opening_hours'],
      original['openingHours'],
    ]);
    final exactImageUrl = _normaliseImageUrl(
      _firstText([media['image'], properties['image']]),
    );
    final imageUrl = exactImageUrl.isNotEmpty
        ? exactImageUrl
        : _firstText([original['imageUrl'], original['mapPreviewUrl']]);
    final imageType = exactImageUrl.isNotEmpty
        ? 'place_photo'
        : '${original['imageType'] ?? 'map_preview'}';
    final brand = _firstText([properties['brand'], original['brand']]);
    final operatorName = _firstText([
      properties['operator'],
      original['operator'],
    ]);

    final takeaway = _nullableBool(
      properties['takeaway'] ?? original['takeaway'],
    );
    final delivery = _nullableBool(
      properties['delivery'] ?? original['delivery'],
    );
    final outdoorSeating = _nullableBool(
      properties['outdoor_seating'] ?? original['outdoorSeating'],
    );
    final wheelchair = _nullableBool(
      properties['wheelchair'] ?? original['wheelchair'],
    );
    final internetAccess = _nullableBool(
      properties['internet_access'] ?? original['internetAccess'],
    );
    final airConditioning = _nullableBool(
      properties['air_conditioning'] ?? original['airConditioning'],
    );
    final toilets = _nullableBool(properties['toilets'] ?? original['toilets']);

    final paymentMethods = paymentOptions.entries
        .where((entry) => _nullableBool(entry.value) == true)
        .map((entry) => _prettyValue(entry.key))
        .toList();

    final services = <String>[];
    if (takeaway == true) services.add('Takeaway');
    if (delivery == true) services.add('Delivery');
    if (outdoorSeating == true) services.add('Outdoor seating');

    final facilities = <String>[];
    if (internetAccess == true) facilities.add('Internet access');
    if (airConditioning == true) facilities.add('Air conditioning');
    if (toilets == true) facilities.add('Toilets');

    final details = <String, dynamic>{
      'description': _detailedDescriptionFor(
        name: '${original['name'] ?? properties['name'] ?? 'This place'}',
        category: '${original['category'] ?? ''}',
        address: _firstText([
          properties['formatted'],
          original['formattedAddress'],
        ]),
        officialDescription: officialDescription,
        cuisine: cuisine,
        diet: diet,
        brand: brand,
        reservation: _firstText([catering['reservation']]),
        takeaway: takeaway,
        delivery: delivery,
        outdoorSeating: outdoorSeating,
        wheelchair: wheelchair,
        internetAccess: internetAccess,
        airConditioning: airConditioning,
      ),
      'officialDescription': officialDescription,
      'cuisine': cuisine,
      'diet': diet,
      'capacity': _firstText([catering['capacity']]),
      'reservation': _firstText([catering['reservation']]),
      'brand': brand,
      'operator': operatorName,
      'website': website,
      'phone': phone,
      'email': email,
      'openingHours': openingHours,
      'imageUrl': imageUrl,
      'imageType': imageType,
      'takeaway': takeaway,
      'delivery': delivery,
      'outdoorSeating': outdoorSeating,
      'wheelchair': wheelchair,
      'internetAccess': internetAccess,
      'airConditioning': airConditioning,
      'toilets': toilets,
      'services': services,
      'facilities': facilities,
      'paymentMethods': paymentMethods,
      'placeDetailsLoaded': true,
    };

    _detailsCache[placeId] = _GeoapifyCachedPlaceDetails(
      createdAt: DateTime.now(),
      details: details,
    );

    return {...original, ...details};
  }

  static String _detailedDescriptionFor({
    required String name,
    required String category,
    required String address,
    required String officialDescription,
    required String cuisine,
    required String diet,
    required String brand,
    required String reservation,
    required bool? takeaway,
    required bool? delivery,
    required bool? outdoorSeating,
    required bool? wheelchair,
    required bool? internetAccess,
    required bool? airConditioning,
  }) {
    if (officialDescription.trim().isNotEmpty) {
      return officialDescription.trim();
    }

    final sentences = <String>[];
    final cuisineText = _prettySeparatedText(cuisine);
    final dietText = _prettySeparatedText(diet);

    if (category == 'Food') {
      if (cuisineText.isNotEmpty) {
        sentences.add(
          '$name is a ${cuisineText.toLowerCase()} restaurant or food venue.',
        );
      } else if (brand.trim().isNotEmpty) {
        sentences.add('$name is a ${brand.trim()} food and dining venue.');
      } else {
        sentences.add('$name is a restaurant or food venue.');
      }
    } else {
      sentences.add('$name is a $category attraction or place of interest.');
    }

    if (address.trim().isNotEmpty) {
      sentences.add('It is located at ${address.trim()}.');
    }

    final services = <String>[];
    if (takeaway == true) services.add('takeaway');
    if (delivery == true) services.add('delivery');
    if (outdoorSeating == true) services.add('outdoor seating');
    if (services.isNotEmpty) {
      sentences.add('Available services include ${_naturalJoin(services)}.');
    }

    if (dietText.isNotEmpty) {
      sentences.add('Listed diet options include $dietText.');
    }

    if (reservation.trim().isNotEmpty) {
      sentences.add('Reservation information: ${_prettyValue(reservation)}.');
    }

    final facilities = <String>[];
    if (wheelchair == true) facilities.add('wheelchair access');
    if (internetAccess == true) facilities.add('internet access');
    if (airConditioning == true) facilities.add('air conditioning');
    if (facilities.isNotEmpty) {
      sentences.add('Reported facilities include ${_naturalJoin(facilities)}.');
    }

    return sentences.join(' ');
  }

  static String _rawDietSummary(Map<String, dynamic> rawSource) {
    final values = <String>[];
    for (final entry in rawSource.entries) {
      if (!entry.key.startsWith('diet:')) continue;
      if (_nullableBool(entry.value) != true) continue;
      values.add(_prettyValue(entry.key.substring(5)));
    }
    return values.join(', ');
  }

  static Map<String, dynamic> _asMap(Object? value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = '${value ?? ''}'.trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  static bool? _nullableBool(Object? value) {
    if (value is bool) return value;
    final text = '${value ?? ''}'.trim().toLowerCase();
    if (['yes', 'true', '1', 'only', 'designated'].contains(text)) {
      return true;
    }
    if (['no', 'false', '0'].contains(text)) return false;
    return null;
  }

  static String _prettySeparatedText(String value) {
    final parts = value
        .split(RegExp(r'[;,|]'))
        .map((part) => _prettyValue(part))
        .where((part) => part.isNotEmpty)
        .toSet()
        .toList();
    return _naturalJoin(parts);
  }

  static String _prettyValue(String value) {
    final cleaned = value
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  static String _naturalJoin(List<String> values) {
    final cleaned = values.where((value) => value.trim().isNotEmpty).toList();
    if (cleaned.isEmpty) return '';
    if (cleaned.length == 1) return cleaned.first;
    if (cleaned.length == 2) return '${cleaned.first} and ${cleaned.last}';
    return '${cleaned.sublist(0, cleaned.length - 1).join(', ')}, '
        'and ${cleaned.last}';
  }

  static Map<String, dynamic> _decodeObject(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // The caller will show a generic API response error.
    }
    return <String, dynamic>{};
  }

  static Exception _apiException(
    int statusCode,
    Map<String, dynamic> body, {
    required String operation,
  }) {
    final message =
        '${body['message'] ?? body['error'] ?? body['status'] ?? ''}'.trim();

    if (statusCode == 401 || statusCode == 403) {
      return Exception(
        'Geoapify could not $operation. Check the API key in '
        'lib/core/geoapify_config.dart and its restrictions.',
      );
    }
    if (statusCode == 429) {
      return Exception(
        'The Geoapify free usage or rate limit was reached. '
        'Please wait and try again later.',
      );
    }
    return Exception(
      message.isEmpty
          ? 'Geoapify could not $operation. Error $statusCode.'
          : 'Geoapify could not $operation: $message',
    );
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}

class DailyPlannerPage extends StatefulWidget {
  const DailyPlannerPage({super.key});

  @override
  State<DailyPlannerPage> createState() => _DailyPlannerPageState();
}

class _DailyPlannerPageState extends State<DailyPlannerPage> {
  final area = TextEditingController(text: 'George Town, Penang');
  final selectedInterests = <String>{'Heritage'};
  double availableHours = 4;
  String budgetLevel = 'Medium';
  String pace = 'Balanced';
  bool loading = false;
  int totalEstimatedMinutes = 0;
  int remainingMinutes = 0;
  List<Map<String, dynamic>> results = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final profile = await AppServices.currentProfile();
      if (!mounted || profile == null) return;
      final interests = List<String>.from(
        profile['travelInterests'] ?? const [],
      );
      setState(() {
        if (interests.isNotEmpty) {
          selectedInterests
            ..clear()
            ..addAll(interests);
        }
        final savedBudget = '${profile['budgetPreference'] ?? ''}';
        if (['Low', 'Medium', 'High'].contains(savedBudget)) {
          budgetLevel = savedBudget;
        }
        final savedPace = '${profile['travelPace'] ?? ''}';
        if (['Relaxed', 'Balanced', 'Fast', 'Packed'].contains(savedPace)) {
          pace = savedPace == 'Packed' ? 'Fast' : savedPace;
        }
      });
    } catch (_) {
      // Existing defaults remain available when the profile is unavailable.
    }
  }

  Future<void> generate() async {
    if (area.text.trim().isEmpty || selectedInterests.isEmpty) {
      showMessage(
        context,
        'Complete all required travel preferences.',
        error: true,
      );
      return;
    }

    setState(() => loading = true);
    try {
      final generated = await GeoapifyPlanner.generate(
        area: area.text.trim(),
        availableHours: availableHours,
        interests: selectedInterests.toList(),
        budgetLevel: budgetLevel,
        travelPace: pace,
      );

      // Resolve a real place photograph or a location-map fallback before
      // displaying the generated itinerary. This also prevents unresolved
      // image URLs from being stored later.
      ItineraryImageResolver.clearCache();
      final resolvedPlaces = await Future.wait(
        generated.places.map(
          (place) => ItineraryImageResolver.resolveStop(
            Map<String, dynamic>.from(place),
          ),
        ),
      );

      if (!mounted) return;
      final schedule = ItinerarySchedulePlanner.plan(
        stops: resolvedPlaces,
        pace: pace,
        availableHours: availableHours,
      );
      setState(() {
        results = schedule.stops;
        totalEstimatedMinutes = schedule.totalEstimatedMinutes;
        remainingMinutes = schedule.remainingMinutes;
      });

      final uid = AppServices.auth.currentUser?.uid;
      if (uid != null) {
        await AppServices.travelerRef(uid).set({
          'lastPlannerPreferences': {
            'area': area.text.trim(),
            'availableHours': availableHours,
            'interests': selectedInterests.toList(),
            'budgetLevel': budgetLevel,
            'travelPace': pace,
            'placeSource': 'Registered MyHeritage vendors in Penang',
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (generated.places.isEmpty && mounted) {
        showMessage(
          context,
          'No registered vendor matches the selected interests and budget. Try another Penang area or interest.',
          error: true,
        );
      }
    } on TimeoutException {
      if (mounted) {
        showMessage(
          context,
          'The map-area lookup took too long. Please try again.',
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
      if (mounted) setState(() => loading = false);
    }
  }

  double get budgetAmount {
    return switch (budgetLevel) {
      'Low' => 50,
      'High' => 200,
      _ => 100,
    };
  }

  ItineraryScheduleResult _currentSchedule() {
    return ItinerarySchedulePlanner.plan(
      stops: results,
      pace: pace,
      availableHours: availableHours,
    );
  }

  Future<void> save() async {
    if (results.isEmpty) return;
    final uid = AppServices.auth.currentUser!.uid;
    try {
      showMessage(context, 'Preparing itinerary images...');
      final schedule = _currentSchedule();

      final resolvedStops = await Future.wait(
        schedule.stops.asMap().entries.map((entry) async {
          final data = await ItineraryImageResolver.resolveStop(
            Map<String, dynamic>.from(entry.value),
          );
          final task = data['culturalTask'] is Map
              ? Map<String, dynamic>.from(data['culturalTask'] as Map)
              : null;
          final fallback =
              '${data['fallbackImageUrl'] ?? data['mapPreviewUrl'] ?? ''}'
                  .trim();

          return <String, dynamic>{
            'placeId': data['placeId'],
            'geoapifyPlaceId': data['geoapifyPlaceId'],
            'vendorId': data['vendorId'],
            'mapUrl': data['mapUrl'],
            'source': data['source'],
            'sequence': entry.key + 1,
            'name': data['name'],
            'description': data['description'],
            'imageUrl': '${data['imageUrl'] ?? ''}',
            'fallbackImageUrl': fallback,
            'mapPreviewUrl': '${data['mapPreviewUrl'] ?? fallback}',
            'imageCandidates': List<String>.from(
              data['imageCandidates'] ?? const <String>[],
            ),
            'imageType': data['imageType'],
            'imageAttribution': data['imageAttribution'],
            'imageSourceUrl': data['imageSourceUrl'],
            'suggestionReason': data['suggestionReason'],
            'distanceMeters': data['distanceMeters'],
            'matchedInterest': data['matchedInterest'],
            'area': data['area'],
            'category': data['category'],
            'formattedAddress': data['formattedAddress'],
            'durationMinutes': data['durationMinutes'] ?? 60,
            'travelMinutesBefore': data['travelMinutesBefore'] ?? 0,
            'budgetLevel': data['budgetLevel'],
            'cuisine': data['cuisine'],
            'diet': data['diet'],
            'openingHours': data['openingHours'],
            'phone': data['phone'],
            'website': data['website'],
            'email': data['email'],
            'services': data['services'],
            'facilities': data['facilities'],
            'paymentMethods': data['paymentMethods'],
            'score': data['score'],
            'inAppAverageRating': data['inAppAverageRating'],
            'inAppReviewCount': data['inAppReviewCount'],
            'trustLabel': data['trustLabel'],
            'location': data['location'],
            'culturalTask': task,
            'culturalTaskId': task?['id'] ?? data['activeCulturalTaskId'],
            'culturalTaskTitle': task?['title'],
            'culturalTaskRewardPoints': task?['rewardPoints'],
            'activeVouchers': data['activeVouchers'],
            'activeVoucherCount': data['activeVoucherCount'],
          };
        }),
      );

      await AppServices.db.collection('itineraries').add({
        'userId': uid,
        'title': '${area.text.trim()} Cultural Day',
        'area': area.text.trim(),
        'availableHours': availableHours,
        'budget': budgetAmount,
        'budgetLevel': budgetLevel,
        'interests': selectedInterests.toList(),
        'travelPace': pace,
        'placeSource': 'Registered MyHeritage vendors in Penang',
        'suggestedStartMinutes': schedule.startMinutes,
        'suggestedEndMinutes': schedule.endMinutes,
        'totalEstimatedMinutes': schedule.totalEstimatedMinutes,
        'remainingMinutes': schedule.remainingMinutes,
        'stops': resolvedStops,
        'status': 'saved',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        showMessage(context, 'Itinerary saved with place previews.');
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    }
  }

  @override
  void dispose() {
    area.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _currentSchedule();
    final scheduledResults = schedule.stops;
    final displayTotalMinutes = schedule.totalEstimatedMinutes;
    final displayRemainingMinutes = schedule.remainingMinutes;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const ExplorerBrand(compact: true),
        actions: [
          IconButton(
            tooltip: 'My itineraries',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyItinerariesPage()),
            ),
            icon: const Icon(Icons.bookmark_outline),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          const Text(
            'Daily Planner',
            style: TextStyle(
              color: ExplorerColors.navy,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Curate your perfect heritage journey in George Town.',
            style: TextStyle(color: ExplorerColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          ExplorerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExplorerSectionTitle('Trip Preferences'),
                const SizedBox(height: 16),
                const Text(
                  'Area',
                  style: TextStyle(
                    color: ExplorerColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: area,
                  decoration: const InputDecoration(
                    hintText: 'George Town, Penang',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Time Available',
                  style: TextStyle(
                    color: ExplorerColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<double>(
                  value: availableHours,
                  items: const [
                    DropdownMenuItem(value: 2, child: Text('2 hours')),
                    DropdownMenuItem(
                      value: 4,
                      child: Text('4 hours (Half Day)'),
                    ),
                    DropdownMenuItem(
                      value: 8,
                      child: Text('8 hours (Full Day)'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => availableHours = value ?? 4),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.schedule),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Interests',
                  style: TextStyle(
                    color: ExplorerColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                        'Heritage',
                        'Food',
                        'Art',
                        'Culture',
                        'Nature',
                        'Local Business',
                      ].map((item) {
                        return FilterChip(
                          label: Text(item),
                          selected: selectedInterests.contains(item),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedInterests.add(item);
                              } else {
                                selectedInterests.remove(item);
                              }
                            });
                          },
                        );
                      }).toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: budgetLevel,
                        decoration: const InputDecoration(labelText: 'Budget'),
                        items: const ['Low', 'Medium', 'High']
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => budgetLevel = value ?? budgetLevel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: pace,
                        decoration: const InputDecoration(labelText: 'Pace'),
                        items: const ['Relaxed', 'Balanced', 'Fast']
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => pace = value ?? pace),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: loading ? null : generate,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(loading ? 'Generating...' : 'Generate Itinerary'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ExplorerSectionTitle(
            results.isEmpty ? 'Suggested Places' : 'Suggested Itinerary',
            trailing: results.isEmpty
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Save itinerary',
                        onPressed: save,
                        icon: const Icon(Icons.bookmark_add_outlined),
                      ),
                      IconButton(
                        tooltip: 'Share itinerary link',
                        onPressed: () {
                          final shareSchedule = _currentSchedule();
                          ItineraryShareHelper.openShareDialog(context, {
                            'title':
                                '${GeoapifyPlanner._normalisePenangArea(area.text)} Cultural Day',
                            'area': GeoapifyPlanner._normalisePenangArea(
                              area.text,
                            ),
                            'availableHours': availableHours,
                            'budgetLevel': budgetLevel,
                            'interests': selectedInterests.toList(),
                            'travelPace': pace,
                            'suggestedStartMinutes': shareSchedule.startMinutes,
                            'suggestedEndMinutes': shareSchedule.endMinutes,
                            'totalEstimatedMinutes':
                                shareSchedule.totalEstimatedMinutes,
                            'remainingMinutes': shareSchedule.remainingMinutes,
                            'stops': shareSchedule.stops,
                          });
                        },
                        icon: const Icon(Icons.link_rounded),
                      ),
                    ],
                  ),
          ),
          if (results.isNotEmpty && totalEstimatedMinutes > 0) ...[
            const SizedBox(height: 7),
            Text(
              '${(displayTotalMinutes / 60).toStringAsFixed(1)} hours '
              'planned - $displayRemainingMinutes minutes remaining',
              style: const TextStyle(
                color: ExplorerColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (scheduledResults.isNotEmpty) ...[
            ItineraryTimelineSummary(schedule: schedule),
            const SizedBox(height: 10),
          ],
          if (loading)
            const ExplorerCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (results.isEmpty)
            const ExplorerCard(
              child: ExplorerEmptyState(
                title: 'Generate your itinerary',
                subtitle:
                    'Select your preferences to generate an itinerary using verified Penang vendors registered in MyHeritage.',
                icon: Icons.route_outlined,
              ),
            )
          else
            ...scheduledResults.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: _placeCard(context, entry.value, entry.key + 1),
              ),
            ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Registered vendors from MyHeritage | Maps by Geoapify and © OpenStreetMap contributors',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ExplorerColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeCard(
    BuildContext context,
    Map<String, dynamic> data,
    int sequence,
  ) {
    final placeId = '${data['placeId'] ?? ''}';
    final task = data['culturalTask'] is Map
        ? Map<String, dynamic>.from(data['culturalTask'] as Map)
        : null;
    final scheduleNotes = List<String>.from(
      data['scheduleNotes'] ?? const <String>[],
    );
    final timeLabel = '${data['suggestedTimeLabel'] ?? ''}'.trim();

    return ExplorerCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlaceDetailPage(placeId: placeId, place: data),
        ),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: SizedBox(
              width: double.infinity,
              height: 130,
              child: ItineraryPlaceImage(
                stop: data,
                width: double.infinity,
                height: 130,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: ExplorerColors.navy,
                      foregroundColor: Colors.white,
                      child: Text(
                        '$sequence',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${data['name'] ?? 'Heritage Place'}',
                        style: const TextStyle(
                          color: ExplorerColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                if (timeLabel.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        size: 15,
                        color: ExplorerColors.goldDark,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          color: ExplorerColors.goldDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                ],
                Text(
                  '${data['description'] ?? data['formattedAddress'] ?? ''}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                if (cleanDisplayText(
                  data['suggestionReason'],
                ).trim().isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome_outlined,
                        size: 14,
                        color: ExplorerColors.navy,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          cleanDisplayText(data['suggestionReason']),
                          style: const TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (scheduleNotes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ScheduleNoteList(notes: scheduleNotes),
                ],
                const SizedBox(height: 11),
                Wrap(
                  spacing: 12,
                  runSpacing: 7,
                  children: [
                    _meta(Icons.place_outlined, '${data['area'] ?? area.text}'),
                    _meta(Icons.category_outlined, '${data['category'] ?? ''}'),
                    _meta(
                      Icons.schedule,
                      '${data['durationMinutes'] ?? 60} min',
                    ),
                    if ((data['travelMinutesBefore'] as num?) != null &&
                        (data['travelMinutesBefore'] as num) > 0)
                      _meta(
                        Icons.directions_walk_outlined,
                        '${data['travelMinutesBefore']} min travel',
                      ),
                    _meta(
                      Icons.payments_outlined,
                      '${data['budgetLevel'] ?? 'Low'} budget',
                    ),
                    if ((data['inAppReviewCount'] as num?) != null &&
                        (data['inAppReviewCount'] as num) > 0)
                      _meta(
                        Icons.star_rounded,
                        '${data['score']} MyHeritage '
                        '(${data['inAppReviewCount']})',
                      ),
                  ],
                ),
                if (task != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: ExplorerColors.goldSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.emoji_events_outlined,
                          color: ExplorerColors.goldDark,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${task['title'] ?? 'Cultural Task'}',
                                style: const TextStyle(
                                  color: ExplorerColors.navy,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${task['description'] ?? ''}'
                                '${task['rewardPoints'] == null ? '' : ' - ${task['rewardPoints']} points'}',
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
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 130,
      decoration: const BoxDecoration(
        color: ExplorerColors.navySoft,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: const Icon(
        Icons.account_balance_outlined,
        color: Color(0xFF9EB1CC),
        size: 52,
      ),
    );
  }

  Widget _meta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: ExplorerColors.muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: ExplorerColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
