part of '../traveler_pages.dart';

class PlannerDaySchedule {
  const PlannerDaySchedule({
    required this.dayNumber,
    required this.date,
    required this.dateLabel,
    required this.weather,
    required this.places,
    required this.totalEstimatedMinutes,
    required this.remainingMinutes,
  });

  final int dayNumber;
  final DateTime date;
  final String dateLabel;
  final Map<String, dynamic> weather;
  final List<Map<String, dynamic>> places;
  final int totalEstimatedMinutes;
  final int remainingMinutes;

  Map<String, dynamic> toMap() => {
    'dayNumber': dayNumber,
    'date': date.toIso8601String(),
    'dateLabel': dateLabel,
    'weather': weather,
    'stops': places,
    'totalEstimatedMinutes': totalEstimatedMinutes,
    'remainingMinutes': remainingMinutes,
  };
}

class GeoapifyPlannerResult {
  const GeoapifyPlannerResult({
    required this.places,
    required this.totalEstimatedMinutes,
    required this.remainingMinutes,
    this.days = const [],
    this.startDate,
    this.endDate,
    this.dayCount = 1,
  });

  final List<Map<String, dynamic>> places;
  final int totalEstimatedMinutes;
  final int remainingMinutes;
  final List<PlannerDaySchedule> days;
  final DateTime? startDate;
  final DateTime? endDate;
  final int dayCount;
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

class _TimedCache<T> {
  const _TimedCache({required this.createdAt, required this.value});

  final DateTime createdAt;
  final T value;

  bool isFresh(Duration ttl) => DateTime.now().difference(createdAt) < ttl;
}

class GeoapifyPlanner {
  const GeoapifyPlanner._();

  static const String _host = 'api.geoapify.com';
  static const int _searchLimitPerInterest = 60;
  static const int _addPlaceSearchLimit = 120;
  static const double _penangLatitude = 5.4141;
  static const double _penangLongitude = 100.3288;
  static const Duration _firestoreCacheTtl = Duration(minutes: 5);

  static final Map<String, _GeoapifyArea> _geocodeCache = {};
  static final Map<String, _GeoapifyCachedPlaces> _placesCache = {};
  static final Map<String, _GeoapifyCachedPlaceDetails> _detailsCache = {};
  static final Map<String, _TimedCache<List<Map<String, dynamic>>>>
  _verifiedVendorCache = {};
  static _TimedCache<List<Map<String, dynamic>>>? _culturalTasksCache;
  static _TimedCache<Map<String, List<Map<String, dynamic>>>>?
  _activeVoucherCache;
  static _TimedCache<Map<String, Map<String, dynamic>>>? _reviewStatsCache;

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

  static Future<Map<String, dynamic>> _fetchDayForecast(
    double lat,
    double lng,
    DateTime date,
    int dayIndex,
  ) async {
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': lat.toString(),
        'longitude': lng.toString(),
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum',
        'timezone': 'auto',
        'forecast_days': '7',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final daily = json['daily'] as Map<String, dynamic>?;
        if (daily != null) {
          final codes = List<num>.from(daily['weather_code'] ?? []);
          final temps = List<num>.from(daily['temperature_2m_max'] ?? []);
          final rains = List<num>.from(daily['precipitation_sum'] ?? []);
          final idx = min(dayIndex, codes.length - 1);
          if (idx >= 0 && idx < codes.length) {
            final code = codes[idx].toInt();
            final temp = temps.isNotEmpty ? temps[idx].round() : 30;
            final rain = rains.isNotEmpty ? rains[idx].toDouble() : 0.0;
            final severity = _weatherSeverity(
              weatherCode: code,
              precipitationMm: rain,
              temperatureC: temp,
            );
            final isRainy =
                severity == 'thunderstorm' ||
                severity == 'heavy_rain' ||
                severity == 'moderate_rain' ||
                severity == 'light_showers';
            final weatherCopy = _weatherCopy(
              severity: severity,
              temperatureC: temp,
            );

            return {
              'temperature': '$temp°C',
              'condition': weatherCopy.condition,
              'isRainy': isRainy,
              'advice': weatherCopy.advice,
              'weatherCode': code,
              'weatherSeverity': severity,
              'precipitationMm': rain,
              'outdoorFriendly': weatherCopy.outdoorFriendly,
              'indoorPriority': weatherCopy.indoorPriority,
            };
          }
        }
      }
    } catch (_) {}

    return {
      'temperature': '30°C',
      'condition': 'Partly Cloudy',
      'isRainy': false,
      'advice':
          'Fair tropical weather (30°C) • Keep outdoor heritage walks, with shaded or indoor breaks midday.',
      'weatherCode': 2,
      'weatherSeverity': 'fair',
      'precipitationMm': 0.0,
      'outdoorFriendly': true,
      'indoorPriority': false,
    };
  }

  static String _weatherSeverity({
    required int weatherCode,
    required double precipitationMm,
    required int temperatureC,
  }) {
    if (weatherCode >= 95 || precipitationMm >= 8) return 'thunderstorm';
    if (precipitationMm >= 5 || weatherCode == 82) return 'heavy_rain';
    if (precipitationMm >= 2.5 ||
        (weatherCode >= 61 && weatherCode <= 67) ||
        weatherCode == 81) {
      return 'moderate_rain';
    }
    if (precipitationMm > 0.2 ||
        (weatherCode >= 51 && weatherCode <= 57) ||
        weatherCode == 80) {
      return 'light_showers';
    }
    if (temperatureC >= 34) return 'hot';
    if (weatherCode >= 1 && weatherCode <= 3) return 'cloudy';
    return 'fair';
  }

  static ({
    String condition,
    String advice,
    bool outdoorFriendly,
    bool indoorPriority,
  })
  _weatherCopy({required String severity, required int temperatureC}) {
    return switch (severity) {
      'thunderstorm' => (
        condition: 'Thunderstorms',
        advice:
            'Heavy rain expected ($temperatureC°C) • Choose indoor museums, galleries and covered food courts first.',
        outdoorFriendly: false,
        indoorPriority: true,
      ),
      'heavy_rain' => (
        condition: 'Heavy Rain',
        advice:
            'Heavy rain expected ($temperatureC°C) • Prefer indoor attractions and keep outdoor stops as backups.',
        outdoorFriendly: false,
        indoorPriority: true,
      ),
      'moderate_rain' => (
        condition: 'Rain Showers',
        advice:
            'Rain showers expected ($temperatureC°C) • Mix indoor stops with short outdoor visits between showers.',
        outdoorFriendly: true,
        indoorPriority: false,
      ),
      'light_showers' => (
        condition: 'Light Showers',
        advice:
            'Light showers possible ($temperatureC°C) • Outdoor heritage stops are still okay with indoor backup nearby.',
        outdoorFriendly: true,
        indoorPriority: false,
      ),
      'hot' => (
        condition: 'Hot & Sunny',
        advice:
            'Hot weather ($temperatureC°C) • Keep outdoor sights, add shade, hydration and indoor rest breaks.',
        outdoorFriendly: true,
        indoorPriority: false,
      ),
      'cloudy' => (
        condition: 'Partly Cloudy',
        advice:
            'Pleasant weather ($temperatureC°C) • Good for both outdoor trails and indoor cultural stops.',
        outdoorFriendly: true,
        indoorPriority: false,
      ),
      _ => (
        condition: 'Sunny & Warm',
        advice:
            'Bright skies ($temperatureC°C) • Good for outdoor heritage walks, scenic sights and local food stops.',
        outdoorFriendly: true,
        indoorPriority: false,
      ),
    };
  }

  static Future<GeoapifyPlannerResult> generate({
    required String area,
    required double availableHours,
    required List<String> interests,
    required String budgetLevel,
    required String travelPace,
    int? preferredStartMinutes,
    DateTime? startDate,
    int dayCount = 1,
    bool foodExplorationEnabled = false,
  }) async {
    final normalizedArea = _normalisePenangArea(area);
    if (normalizedArea.isEmpty) {
      throw Exception('Enter an area before generating the itinerary.');
    }
    if (interests.isEmpty) {
      throw Exception('Select at least one travel interest.');
    }

    final tripStartDate =
        startDate ?? DateTime.now().add(const Duration(days: 1));
    final tripEndDate = tripStartDate.add(Duration(days: max(0, dayCount - 1)));

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
    final coveredMealLabels = _coveredMealLabels(
      preferredStartMinutes ?? 9 * 60,
      (availableHours * 60).round(),
    );

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
            ...?task == null ? null : {'culturalTask': task},
          };
        })
        .where((vendor) {
          final supportsMealPlanning =
              coveredMealLabels.isNotEmpty && _isFoodPlace(vendor);
          final matchesPreference =
              _vendorMatchesInterests(vendor, interests) &&
              _budgetAllowed(
                userBudget: budgetLevel,
                placeBudget: '${vendor['budgetLevel'] ?? 'Medium'}',
              );
          return matchesPreference ||
              supportsMealPlanning ||
              (foodExplorationEnabled && _isFoodPlace(vendor));
        })
        .toList();

    if (candidates.isEmpty) {
      return GeoapifyPlannerResult(
        places: const [],
        totalEstimatedMinutes: 0,
        remainingMinutes: (availableHours * 60).round(),
        startDate: tripStartDate,
        endDate: tripEndDate,
        dayCount: dayCount,
      );
    }

    final minimumAreaScore = _minimumAreaTextScore(normalizedArea);
    final areaMatchedCandidates = candidates.where((c) {
      final areaScore = (c['areaRelevanceScore'] as num?)?.toDouble() ?? 0.0;
      return areaScore >= minimumAreaScore;
    }).toList();
    final generationArea = locatedArea;
    final localCandidates = generationArea == null
        ? areaMatchedCandidates
        : candidates
              .where(
                (candidate) => _isLocalCandidate(
                  candidate,
                  locatedArea: generationArea,
                  selectedArea: normalizedArea,
                ),
              )
              .toList();
    final activeCandidates = localCandidates.isNotEmpty
        ? localCandidates
        : areaMatchedCandidates;

    if (activeCandidates.isEmpty) {
      return GeoapifyPlannerResult(
        places: const [],
        totalEstimatedMinutes: 0,
        remainingMinutes: (availableHours * 60).round(),
        startDate: tripStartDate,
        endDate: tripEndDate,
        dayCount: dayCount,
      );
    }

    final daySchedules = <PlannerDaySchedule>[];
    final allEnrichedStops = <Map<String, dynamic>>[];
    final globallyUsedKeys = <String>{};
    final remainingCandidates = List<Map<String, dynamic>>.from(
      activeCandidates,
    );

    final originLat = locatedArea?.latitude ?? _penangLatitude;
    final originLng = locatedArea?.longitude ?? _penangLongitude;

    for (int dayIdx = 0; dayIdx < dayCount; dayIdx++) {
      final currentDayDate = tripStartDate.add(Duration(days: dayIdx));
      final dayForecast = await _fetchDayForecast(
        originLat,
        originLng,
        currentDayDate,
        dayIdx,
      );
      final isRainy = dayForecast['isRainy'] == true;
      final weatherSeverity = '${dayForecast['weatherSeverity'] ?? 'fair'}';

      final availableCandidates = remainingCandidates.where((c) {
        final keys = _allPlaceKeys(c);
        return !keys.any((k) => globallyUsedKeys.contains(k));
      }).toList();

      final poolForDay = availableCandidates.isNotEmpty
          ? availableCandidates
          : activeCandidates.where((c) {
              final keys = _allPlaceKeys(c);
              return !keys.any((k) => globallyUsedKeys.contains(k));
            }).toList();

      final poolToUse = poolForDay.isNotEmpty ? poolForDay : activeCandidates;

      final built = await _buildItinerary(
        candidates: poolToUse,
        availableMinutes: (availableHours * 60).round(),
        pace: travelPace,
        selectedInterests: interests,
        userBudget: budgetLevel,
        preferredStartMinutes: preferredStartMinutes,
        isRainy: isRainy,
        weatherSeverity: weatherSeverity,
        foodExplorationEnabled: foodExplorationEnabled,
        usedKeys: globallyUsedKeys,
        maxLegDistanceKm: locatedArea == null
            ? 18.0
            : min(
                18.0,
                max(7.0, _localSearchRadiusMeters(normalizedArea) / 1000 * .65),
              ),
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

      for (final p in enriched) {
        globallyUsedKeys.addAll(_allPlaceKeys(p));
      }
      remainingCandidates.removeWhere((p) {
        final keys = _allPlaceKeys(p);
        return keys.any((k) => globallyUsedKeys.contains(k));
      });

      final dayLabel = DateFormat('d MMM').format(currentDayDate);
      daySchedules.add(
        PlannerDaySchedule(
          dayNumber: dayIdx + 1,
          date: currentDayDate,
          dateLabel: '$dayLabel (Day ${dayIdx + 1})',
          weather: dayForecast,
          places: enriched,
          totalEstimatedMinutes: built.totalEstimatedMinutes,
          remainingMinutes: built.remainingMinutes,
        ),
      );

      allEnrichedStops.addAll(enriched);
    }

    final totalMinutesAllDays = daySchedules.fold<int>(
      0,
      (sum, d) => sum + d.totalEstimatedMinutes,
    );

    return GeoapifyPlannerResult(
      places: daySchedules.isNotEmpty
          ? daySchedules.first.places
          : allEnrichedStops,
      totalEstimatedMinutes: totalMinutesAllDays,
      remainingMinutes: daySchedules.isNotEmpty
          ? daySchedules.first.remainingMinutes
          : 0,
      days: daySchedules,
      startDate: tripStartDate,
      endDate: tripEndDate,
      dayCount: dayCount,
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
    _GeoapifyArea? locatedArea;
    if (GeoapifyConfig.isConfigured) {
      try {
        locatedArea = await _geocodeArea(normalisedArea);
      } catch (_) {
        // Area text relevance still keeps registered-vendor search local.
      }
    }

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
              ? (vendor['distanceMeters'] as num?)?.toDouble() ?? 0.0
              : _haversineKm(
                      locatedArea.latitude,
                      locatedArea.longitude,
                      vendorLocation['latitude']!,
                      vendorLocation['longitude']!,
                    ) *
                    1000;
          final enriched = <String, dynamic>{
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
            ...?task == null ? null : {'culturalTask': task},
          };
          enriched['suggestionReason'] = _suggestionReason(enriched);
          return enriched;
        })
        .where((vendor) {
          final placeId = '${vendor['placeId'] ?? ''}';
          if (placeId.isEmpty || excluded.contains(placeId)) return false;
          final areaScore =
              (vendor['areaRelevanceScore'] as num?)?.toDouble() ?? 0.0;
          final addSearchArea = locatedArea;
          final localEnough = addSearchArea == null
              ? areaScore >= _minimumAreaTextScore(normalisedArea)
              : _isLocalCandidate(
                  vendor,
                  locatedArea: addSearchArea,
                  selectedArea: normalisedArea,
                );
          if (!localEnough) return false;
          if (queryKey.isEmpty) {
            return interests.isEmpty ||
                _vendorMatchesInterests(vendor, interests);
          }
          final searchable = _normalize(
            '${vendor['name'] ?? ''} ${vendor['formattedAddress'] ?? ''} '
            '${vendor['businessCategory'] ?? ''} '
            '${vendor['description'] ?? ''} ${vendor['area'] ?? ''} '
            '${(vendor['plannerCategories'] as List?)?.join(' ') ?? ''} '
            '${(vendor['tags'] as List?)?.join(' ') ?? ''}',
          );
          return _matchesSearchQuery(query, searchable);
        })
        .toList();

    if (queryKey.isNotEmpty && locatedArea != null) {
      try {
        final mapResults = <Map<String, dynamic>>[];
        for (final variant in _searchQueryVariants(query)) {
          mapResults.addAll(
            await _searchNamedPenangPlaces(
              query: variant,
              area: normalisedArea,
              locatedArea: locatedArea,
              selectedInterests: interests,
            ),
          );
          if (mapResults.length >= 12) break;
          mapResults.addAll(
            await _searchAutocompletePenangPlaces(
              query: variant,
              area: normalisedArea,
              locatedArea: locatedArea,
              selectedInterests: interests,
            ),
          );
          if (mapResults.length >= 12) break;
        }
        for (final place in mapResults) {
          final placeId = '${place['placeId'] ?? ''}';
          if (placeId.isEmpty || excluded.contains(placeId)) continue;
          place['interestMatchScore'] = _interestMatchScore(place, interests);
          place['suggestionReason'] = _suggestionReason(place);
          candidates.add(place);
        }
      } catch (_) {
        // Typed search still returns local registered and curated places.
      }
    }

    final searchResults = _deduplicate(candidates);

    searchResults.sort((first, second) {
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

    final selected = searchResults.take(limit).toList();
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
    addWhen(
      (key.contains('bukit mertajam') || key.contains('bm')) &&
          (key.contains('market') ||
              key.contains('pasar') ||
              key.contains('old street')),
      const [
        'Pekan Bukit Mertajam Old Market Street',
        'Jalan Pasar Bukit Mertajam',
        'BM Old Market Street',
      ],
    );
    addWhen(key.contains('hin') || key.contains('bus depot'), const [
      'Hin Bus Depot',
      'Hin Bus Depot George Town',
    ]);
    addWhen(key.contains('street art') || key.contains('mural'), const [
      'Penang Street Art Armenian Street',
      'Butterworth Art Walk',
    ]);

    return variants.take(6).toList();
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
    return MalaysianAreaSearchEngine.normalise(area);
  }

  static bool _isAreaResultCompatible({
    required String selectedArea,
    required String address,
    required int distanceMeters,
    int maxDistanceMeters = 25000,
  }) {
    final specificDestination = MalaysianAreaSearchEngine.findSpecificSubArea(
      selectedArea,
    );
    if (specificDestination != null) {
      if (MalaysianAreaSearchEngine.matchesSpecificDestination(
        selectedArea: selectedArea,
        vendorAddress: address,
      )) {
        return true;
      }
      return distanceMeters <=
          min(maxDistanceMeters, _localSearchRadiusMeters(selectedArea));
    }

    final areaScore = _areaTextRelevance(
      selectedArea: selectedArea,
      vendorAddress: address,
    );
    return areaScore >= 0.65 || distanceMeters <= maxDistanceMeters;
  }

  static int _localSearchRadiusMeters(String selectedArea) {
    final key = _normalize(selectedArea);
    final specificDestination = MalaysianAreaSearchEngine.findSpecificSubArea(
      selectedArea,
    );
    if (specificDestination != null) {
      final destinationKey = _normalize(specificDestination.name);
      if (destinationKey.contains('langkawi')) return 18000;
      if (destinationKey.contains('cameron highlands') ||
          destinationKey.contains('kundasang') ||
          destinationKey.contains('sekinchan') ||
          destinationKey.contains('balik pulau') ||
          destinationKey.contains('sungai lembing')) {
        return 12000;
      }
      return 7000;
    }
    final isStateWide =
        key == 'malaysia' ||
        [
          'penang',
          'pulau pinang',
          'selangor',
          'perak',
          'kedah',
          'kelantan',
          'terengganu',
          'pahang',
          'johor',
          'sabah',
          'sarawak',
          'melaka',
          'malacca',
          'perlis',
          'labuan',
        ].contains(key);
    if (isStateWide) return 65000;
    if (key.contains('kuala lumpur') || key == 'kl') return 18000;
    return 14000;
  }

  static double _minimumAreaTextScore(String selectedArea) {
    return MalaysianAreaSearchEngine.findSpecificSubArea(selectedArea) == null
        ? 0.65
        : 0.95;
  }

  static bool _isLocalCandidate(
    Map<String, dynamic> candidate, {
    required _GeoapifyArea locatedArea,
    required String selectedArea,
  }) {
    final address =
        '${candidate['formattedAddress'] ?? ''} ${candidate['area'] ?? ''}';
    final specificDestination = MalaysianAreaSearchEngine.findSpecificSubArea(
      selectedArea,
    );
    if (specificDestination != null &&
        MalaysianAreaSearchEngine.matchesSpecificDestination(
          selectedArea: selectedArea,
          vendorAddress: address,
        )) {
      return true;
    }

    final areaScore =
        (candidate['areaRelevanceScore'] as num?)?.toDouble() ??
        _areaTextRelevance(selectedArea: selectedArea, vendorAddress: address);
    if (specificDestination == null && areaScore >= 0.65) return true;

    final candidatePoint = _coordinateMap(candidate['location']);
    if (candidatePoint == null) return false;

    final distanceMeters =
        _haversineKm(
          locatedArea.latitude,
          locatedArea.longitude,
          candidatePoint['latitude']!,
          candidatePoint['longitude']!,
        ) *
        1000;
    candidate['distanceMeters'] = distanceMeters;
    return distanceMeters <= _localSearchRadiusMeters(selectedArea);
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
      'text': '$query, $area',
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
          !_isUsefulPlaceName(name)) {
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
      if (!_isAreaResultCompatible(
        selectedArea: area,
        address: formattedAddress,
        distanceMeters: distanceMeters,
      )) {
        continue;
      }

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
      'text': '$query, $area',
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
          !_isUsefulPlaceName(name)) {
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
      if (!_isAreaResultCompatible(
        selectedArea: area,
        address: formattedAddress,
        distanceMeters: distanceMeters,
      )) {
        continue;
      }

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
    final knownCenter = MalaysianAreaSearchEngine.findKnownCenter(query);
    final parameters = <String, String>{
      'text': query,
      'format': 'json',
      'lang': 'en',
      'limit': '1',
      'filter': 'countrycode:my',
      'apiKey': GeoapifyConfig.apiKey,
    };
    if (knownCenter != null) {
      parameters['bias'] =
          'proximity:${knownCenter['longitude']},${knownCenter['latitude']}';
    }
    final uri = Uri.https(_host, '/v1/geocode/search', parameters);

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
      if (!_isAreaResultCompatible(
        selectedArea: area,
        address: formattedAddress,
        distanceMeters: distanceMeters,
        maxDistanceMeters: radiusMeters + 300,
      )) {
        continue;
      }

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
    final cacheKey = _normalize(area);
    final cached = _verifiedVendorCache[cacheKey];
    if (cached != null && cached.isFresh(_firestoreCacheTtl)) {
      return cached.value
          .map((vendor) => Map<String, dynamic>.from(vendor))
          .toList();
    }

    final firestoreVendors = <Map<String, dynamic>>[];
    try {
      final snapshot = await AppServices.db
          .collection('vendors')
          .where('status', isEqualTo: 'active')
          .where('vendorStatus', isEqualTo: 'verified')
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final address =
            '${data['formattedAddress'] ?? data['shopLocation'] ?? data['area'] ?? ''}';
        final vendorArea =
            '${data['area'] ?? data['city'] ?? (address.isNotEmpty ? address : area)}';
        final name = '${data['businessName'] ?? data['displayName'] ?? ''}'
            .trim();
        if (name.isEmpty) continue;

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
        final website = '${data['website'] ?? data['websiteUrl'] ?? ''}'.trim();
        final mapPreview = location == null
            ? ''
            : ItineraryImageResolver.staticMapPreview(
                latitude: location['latitude']!,
                longitude: location['longitude']!,
              );

        firestoreVendors.add({
          'placeId': 'vendor_${doc.id}',
          'vendorId': doc.id,
          'source': 'registered_vendor',
          'name':
              '${data['businessName'] ?? data['displayName'] ?? 'Local business'}',
          'businessCategory': '${data['businessCategory'] ?? ''}',
          'plannerCategories': plannerCategories,
          'description':
              '${data['description'] ?? data['businessDescription'] ?? ''}',
          'formattedAddress': address.isNotEmpty ? address : vendorArea,
          'area': vendorArea,
          'areaRelevanceScore': _areaTextRelevance(
            selectedArea: area,
            vendorAddress: '$address $vendorArea',
          ),
          'category': category,
          'tags': combinedTags,
          'durationMinutes': duration,
          'budgetLevel': '${data['budgetLevel'] ?? 'Medium'}',
          'score': (data['score'] as num?)?.toDouble() ?? 4.8,
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
            address: address.isNotEmpty ? address : vendorArea,
            website: website,
            phone: '${data['phone'] ?? data['contactNumber'] ?? ''}',
            openingHours:
                '${data['openingHours'] ?? data['businessHours'] ?? ''}',
            imageType: imageUrl.isNotEmpty
                ? 'place_photo'
                : mapPreview.isNotEmpty
                ? 'map_preview'
                : 'none',
          ),
          'matchedInterest': category,
          'phone': '${data['phone'] ?? data['contactNumber'] ?? ''}',
          'website': website,
          'openingHours':
              '${data['openingHours'] ?? data['businessHours'] ?? ''}',
          'location': location,
          'mapUrl': '${data['mapUrl'] ?? ''}',
          'trustLabel': '${data['trustLabel'] ?? 'Verified Vendor'}',
        });
      }
    } catch (_) {
      // Graceful fallback
    }

    final curated = curatedRealPlaces.map((place) {
      final name = '${place['name']}';
      final address = '${place['formattedAddress'] ?? place['address']}';
      final category = '${place['category']}';
      final duration =
          (place['durationMinutes'] as num?)?.round() ??
          switch (category) {
            'Food' => 60,
            'Nature' => 90,
            'Heritage' || 'Culture' || 'Art' => 75,
            _ => 45,
          };
      final location = Map<String, dynamic>.from(place['location'] as Map);
      final lat = (location['latitude'] as num).toDouble();
      final lng = (location['longitude'] as num).toDouble();
      final mapPreview = ItineraryImageResolver.staticMapPreview(
        latitude: lat,
        longitude: lng,
      );
      final googleMapsUrl =
          'https://www.google.com/maps/search/?api=1&query='
          '${Uri.encodeComponent('$name, $address')}';

      return <String, dynamic>{
        'placeId': 'curated_${_normalize(name)}',
        'vendorId': '',
        'source': 'real_map_place',
        'name': name,
        'businessCategory': category,
        'plannerCategories': List<String>.from(
          place['plannerCategories'] ?? [category, 'Local Business'],
        ),
        'description': '${place['description'] ?? ''}',
        'formattedAddress': address,
        'area': '${place['area'] ?? address}',
        'areaRelevanceScore': _areaTextRelevance(
          selectedArea: area,
          vendorAddress: address,
        ),
        'category': category,
        'tags': List<String>.from(place['tags'] ?? [category]),
        'durationMinutes': duration,
        'budgetLevel': '${place['budgetLevel'] ?? 'Medium'}',
        'score': (place['score'] as num?)?.toDouble() ?? 4.8,
        'imageUrl': '${place['imageUrl'] ?? mapPreview}',
        'fallbackImageUrl': mapPreview,
        'mapPreviewUrl': mapPreview,
        'imageCandidates': [
          if ('${place['imageUrl'] ?? ''}'.isNotEmpty) '${place['imageUrl']}',
          if (mapPreview.isNotEmpty) mapPreview,
        ],
        'imageType': '${place['imageUrl'] ?? ''}'.isNotEmpty
            ? 'curated_place_photo'
            : 'map_preview',
        'dataCompletenessScore': 0.95,
        'matchedInterest': category,
        'phone': '${place['phone'] ?? ''}',
        'website': '${place['website'] ?? ''}',
        'openingHours': '${place['openingHours'] ?? ''}',
        'location': {'latitude': lat, 'longitude': lng},
        'mapUrl': '${place['mapUrl'] ?? googleMapsUrl}',
        'trustLabel': 'Real Map Verified',
        if (place['culturalTask'] != null)
          'culturalTask': place['culturalTask'],
      };
    }).toList();

    final result = _deduplicate([...firestoreVendors, ...curated]);
    _verifiedVendorCache[cacheKey] = _TimedCache(
      createdAt: DateTime.now(),
      value: result.map((vendor) => Map<String, dynamic>.from(vendor)).toList(),
    );
    return result;
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
    return MalaysianAreaSearchEngine.calculateAreaRelevance(
      selectedArea: selectedArea,
      vendorAddress: vendorAddress,
    );
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

  static List<String> _matchedSelectedInterests(
    Map<String, dynamic> vendor,
    List<String> interests,
  ) {
    final values = <String>{
      _normalize('${vendor['category'] ?? ''}'),
      _normalize('${vendor['matchedInterest'] ?? ''}'),
      _normalize('${vendor['businessCategory'] ?? ''}'),
      ...List<String>.from(
        vendor['plannerCategories'] ?? const <String>[],
      ).map(_normalize),
      ...List<String>.from(vendor['tags'] ?? const <String>[]).map(_normalize),
    }..remove('');

    return interests
        .where((interest) => interest.trim().isNotEmpty)
        .where((interest) => interest != 'Local Business')
        .where((interest) => values.contains(_normalize(interest)))
        .toList();
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
    final cached = _activeVoucherCache;
    if (cached != null && cached.isFresh(_firestoreCacheTtl)) {
      return cached.value.map(
        (key, value) => MapEntry(
          key,
          value.map((item) => Map<String, dynamic>.from(item)).toList(),
        ),
      );
    }

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
    _activeVoucherCache = _TimedCache(
      createdAt: DateTime.now(),
      value: result.map(
        (key, value) => MapEntry(
          key,
          value.map((item) => Map<String, dynamic>.from(item)).toList(),
        ),
      ),
    );
    return result;
  }

  static Future<List<Map<String, dynamic>>> _loadActiveCulturalTasks() async {
    final cached = _culturalTasksCache;
    if (cached != null && cached.isFresh(_firestoreCacheTtl)) {
      return cached.value
          .map((task) => Map<String, dynamic>.from(task))
          .toList();
    }

    final snapshot = await AppServices.db
        .collection('cultural_tasks')
        .where('status', isEqualTo: 'active')
        .get();
    final now = DateTime.now();

    final result = snapshot.docs
        .map((doc) {
          return {'id': doc.id, ...doc.data()};
        })
        .where((task) {
          final deadline = asDate(task['deadline']);
          return deadline == null || !deadline.isBefore(now);
        })
        .toList();
    _culturalTasksCache = _TimedCache(
      createdAt: DateTime.now(),
      value: result.map((task) => Map<String, dynamic>.from(task)).toList(),
    );
    return result;
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
    final cached = _reviewStatsCache;
    if (cached != null && cached.isFresh(_firestoreCacheTtl)) {
      return cached.value.map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
      );
    }

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
    _reviewStatsCache = _TimedCache(
      createdAt: DateTime.now(),
      value: result.map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
      ),
    );
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
    required String userBudget,
    required int? preferredStartMinutes,
    required Map<String, double>? origin,
    bool isRainy = false,
    String weatherSeverity = 'fair',
    bool foodExplorationEnabled = false,
    double maxLegDistanceKm = 18.0,
    Set<String>? usedKeys,
  }) async {
    final paceMultiplier = switch (pace) {
      'Relaxed' => 1.25,
      'Fast' || 'Packed' => 0.80,
      _ => 1.0,
    };

    final remainingCandidates =
        candidates.map((place) {
          final base = (place['durationMinutes'] as num?)?.round() ?? 60;
          return {
            ...place,
            'durationMinutes': max(30, (base * paceMultiplier).round()),
          };
        }).toList()..sort(
          (first, second) =>
              _rank(
                second,
                userBudget: userBudget,
                preferredStartMinutes: preferredStartMinutes,
                isRainy: isRainy,
                weatherSeverity: weatherSeverity,
              ).compareTo(
                _rank(
                  first,
                  userBudget: userBudget,
                  preferredStartMinutes: preferredStartMinutes,
                  isRainy: isRainy,
                  weatherSeverity: weatherSeverity,
                ),
              ),
        );

    final selected = <Map<String, dynamic>>[];
    final selectedIdentities = <String>{};
    final categoryCounts = <String, int>{};
    final selectedMealLabels = <String>{};
    var optionalFoodCount = 0;
    var remaining = availableMinutes;
    final routeStartMinute = preferredStartMinutes ?? 9 * 60;
    final routeEndMinute = routeStartMinute + availableMinutes;

    final maxStops = availableMinutes <= 150
        ? 2
        : availableMinutes <= 270
        ? 4
        : availableMinutes <= 390
        ? 5
        : 6;

    while (remainingCandidates.isNotEmpty && selected.length < maxStops) {
      var bestIndex = -1;
      var bestScore = -double.infinity;
      var bestTravelMinutes = 0;
      var bestBufferMinutes = 0;
      String? bestMealLabel;
      var bestOptionalFood = false;
      final currentRouteMinute =
          routeStartMinute + (availableMinutes - remaining);
      final pendingMealLabel = _pendingMealLabel(
        currentRouteMinute,
        routeEndMinute,
        selectedMealLabels,
      );

      for (var index = 0; index < remainingCandidates.length; index++) {
        final candidate = remainingCandidates[index];
        final identity = _placeIdentity(candidate);
        final candidateKeys = _allPlaceKeys(candidate);
        if (selectedIdentities.contains(identity) ||
            (usedKeys != null &&
                candidateKeys.any((k) => usedKeys.contains(k)))) {
          continue;
        }
        final previousLocation = selected.isEmpty
            ? origin
            : _coordinateMap(selected.last['location']);
        final candidateLocation = _coordinateMap(candidate['location']);
        final distanceKm = previousLocation != null && candidateLocation != null
            ? _haversineKm(
                previousLocation['latitude']!,
                previousLocation['longitude']!,
                candidateLocation['latitude']!,
                candidateLocation['longitude']!,
              )
            : 0.0;
        if (selected.isNotEmpty && distanceKm > maxLegDistanceKm) {
          continue;
        }
        final travelMinutes = previousLocation == null
            ? 0
            : _estimatedTravelMinutes(
                previousLocation,
                candidateLocation,
                pace,
              );
        final visitMinutes =
            (candidate['durationMinutes'] as num?)?.round() ?? 60;
        final currentDayMinute = currentRouteMinute + travelMinutes;
        final candidateMealLabel = _mealLabelForMinute(currentDayMinute);
        final isFoodPlace = _isFoodPlace(candidate);
        final isMealCandidate =
            isFoodPlace &&
            candidateMealLabel != null &&
            !selectedMealLabels.contains(candidateMealLabel);
        final isPendingMealCandidate =
            isMealCandidate &&
            pendingMealLabel != null &&
            candidateMealLabel == pendingMealLabel;
        final isOptionalFoodCandidate =
            isFoodPlace &&
            candidateMealLabel == null &&
            foodExplorationEnabled &&
            optionalFoodCount < 2 &&
            selected.length >= 2;
        if (pendingMealLabel != null && !isPendingMealCandidate) {
          continue;
        }
        if (isFoodPlace && !isMealCandidate && !isOptionalFoodCandidate) {
          continue;
        }
        final bufferMinutes = _bufferMinutesFor(
          candidate,
          travelMinutes: travelMinutes,
          pace: pace,
        );
        if (travelMinutes + visitMinutes + bufferMinutes > remaining) continue;

        // Opening hours verification based on estimated visit time
        final window = ItinerarySchedulePlanner._openingWindow(
          '${candidate['openingHours'] ?? ''}',
        );
        double openingAdjustment = 0.0;
        if (window != null && !window.open24Hours) {
          if (currentDayMinute < window.opens) {
            openingAdjustment = -1.2; // Arrives before opening
          } else if (currentDayMinute >= window.closes) {
            openingAdjustment = -2.5; // Place already closed
          } else if (currentDayMinute + visitMinutes > window.closes) {
            openingAdjustment = -0.8; // Visit extends beyond closing
          } else {
            openingAdjustment = 0.50; // Perfectly fits open hours
          }
        }

        final category = '${candidate['category'] ?? ''}';
        final matchedInterests = _matchedSelectedInterests(
          candidate,
          selectedInterests,
        );
        final primaryInterest = matchedInterests.firstWhere(
          (interest) => (categoryCounts[interest] ?? 0) == 0,
          orElse: () => '${candidate['matchedInterest'] ?? category}',
        );
        final categoryAlreadySelected =
            (categoryCounts[primaryInterest] ?? 0) > 0;
        final coverageBonus =
            matchedInterests.isNotEmpty && !categoryAlreadySelected
            ? 1.25
            : 0.0;
        final duplicatePenalty = (categoryCounts[primaryInterest] ?? 0) * 0.62;
        final travelPenalty =
            min(travelMinutes / 45, 2.0) * 0.80 +
            max(0.0, distanceKm - 3.0) * 0.12;
        final mealAdjustment = _mealTimeScore(candidate, currentDayMinute);
        final optionalFoodPenalty = isOptionalFoodCandidate ? 0.55 : 0.0;
        final adjusted =
            _rank(
              candidate,
              userBudget: userBudget,
              preferredStartMinutes: preferredStartMinutes,
              isRainy: isRainy,
              weatherSeverity: weatherSeverity,
            ) +
            coverageBonus +
            mealAdjustment +
            openingAdjustment -
            duplicatePenalty -
            travelPenalty -
            optionalFoodPenalty;

        if (adjusted > bestScore) {
          bestScore = adjusted;
          bestIndex = index;
          bestTravelMinutes = travelMinutes;
          bestBufferMinutes = bufferMinutes;
          bestMealLabel = isMealCandidate ? candidateMealLabel : null;
          bestOptionalFood = isOptionalFoodCandidate;
        }
      }

      if (bestIndex < 0) {
        if (pendingMealLabel != null &&
            !selectedMealLabels.contains(pendingMealLabel)) {
          selectedMealLabels.add(pendingMealLabel);
          continue;
        }
        break;
      }
      final chosen = remainingCandidates.removeAt(bestIndex);
      chosen['travelMinutesBefore'] = bestTravelMinutes;
      chosen['bufferMinutesAfter'] = bestBufferMinutes;
      final chosenStartMinute =
          routeStartMinute + (availableMinutes - remaining) + bestTravelMinutes;
      final mealSuggestion = _mealSuggestionText(chosen, chosenStartMinute);
      if (bestOptionalFood) {
        optionalFoodCount++;
        chosen['durationMinutes'] = max(
          35,
          ((chosen['durationMinutes'] as num?)?.round() ?? 45),
        );
        chosen['optionalFoodExperience'] = true;
        chosen['scheduleType'] = 'optional_food';
        chosen['mealSuggestionLabel'] = 'Optional food exploration stop';
      } else if (mealSuggestion == null) {
        chosen.remove('mealSuggestionLabel');
        chosen.remove('optionalFoodExperience');
        chosen.remove('scheduleType');
      } else {
        chosen['durationMinutes'] = max(
          45,
          ((chosen['durationMinutes'] as num?)?.round() ?? 60),
        );
        chosen['mealRole'] = bestMealLabel;
        chosen['scheduleType'] = 'meal';
        chosen['mealSuggestionLabel'] = mealSuggestion;
      }
      selected.add(chosen);
      selectedIdentities.add(_placeIdentity(chosen));
      if (_isFoodPlace(chosen) && bestMealLabel != null) {
        selectedMealLabels.add(bestMealLabel);
      }
      remaining -=
          bestTravelMinutes +
          ((chosen['durationMinutes'] as num?)?.round() ?? 60) +
          bestBufferMinutes;
      final chosenInterests = _matchedSelectedInterests(
        chosen,
        selectedInterests,
      );
      final countKey = chosenInterests.firstWhere(
        (interest) => (categoryCounts[interest] ?? 0) == 0,
        orElse: () =>
            '${chosen['matchedInterest'] ?? chosen['category'] ?? ''}',
      );
      categoryCounts[countKey] = (categoryCounts[countKey] ?? 0) + 1;
    }

    _optimiseVisitOrder(
      selected,
      origin: origin,
      pace: pace,
      preferredStartMinutes: preferredStartMinutes,
    );

    if (GeoapifyConfig.useRoutingApi) {
      await _applyRoutingTimes(selected, pace: pace);
    }

    var totalEstimatedMinutes = selected.fold<int>(
      0,
      (total, place) =>
          total +
          ((place['durationMinutes'] as num?)?.round() ?? 60) +
          ((place['travelMinutesBefore'] as num?)?.round() ?? 0) +
          ((place['bufferMinutesAfter'] as num?)?.round() ?? 0),
    );

    while (selected.length > 1 && totalEstimatedMinutes > availableMinutes) {
      selected.removeLast();
      totalEstimatedMinutes = selected.fold<int>(
        0,
        (total, place) =>
            total +
            ((place['durationMinutes'] as num?)?.round() ?? 60) +
            ((place['travelMinutesBefore'] as num?)?.round() ?? 0) +
            ((place['bufferMinutesAfter'] as num?)?.round() ?? 0),
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
    required int? preferredStartMinutes,
  }) {
    if (selected.length < 2) {
      if (selected.isNotEmpty) {
        selected.first['travelMinutesBefore'] = 0;
      }
      return;
    }

    final unordered = List<Map<String, dynamic>>.from(selected);
    unordered.sort((a, b) {
      final winA = ItinerarySchedulePlanner._openingWindow(
        '${a['openingHours'] ?? ''}',
      );
      final winB = ItinerarySchedulePlanner._openingWindow(
        '${b['openingHours'] ?? ''}',
      );
      final openA = winA?.open24Hours == true
          ? 9 * 60
          : (winA?.opens ?? 9 * 60);
      final openB = winB?.open24Hours == true
          ? 9 * 60
          : (winB?.opens ?? 9 * 60);
      return openA.compareTo(openB);
    });

    final ordered = <Map<String, dynamic>>[];
    Map<String, double>? current = origin;
    var accumulatedTime = preferredStartMinutes ?? 9 * 60;

    while (unordered.isNotEmpty) {
      var bestIndex = 0;
      var bestScore = double.infinity;

      for (var index = 0; index < unordered.length; index++) {
        final candidate = unordered[index];
        final point = _coordinateMap(candidate['location']);
        final distanceKm = (point != null && current != null)
            ? _haversineKm(
                current['latitude']!,
                current['longitude']!,
                point['latitude']!,
                point['longitude']!,
              )
            : 2.0;

        final mealSlot = _mealSlotForLabel('${candidate['mealRole'] ?? ''}');
        final win = ItinerarySchedulePlanner._openingWindow(
          '${candidate['openingHours'] ?? ''}',
        );
        final opensAt = win?.open24Hours == true ? 0 : (win?.opens ?? 9 * 60);
        final closesAt = win?.open24Hours == true
            ? 24 * 60
            : (win?.closes ?? 22 * 60);

        double timePenalty = 0.0;
        if (mealSlot != null) {
          final estimatedArrival = accumulatedTime + (distanceKm * 10).round();
          if (estimatedArrival < mealSlot.start) {
            timePenalty += (mealSlot.start - estimatedArrival) * 0.02;
          } else if (estimatedArrival > mealSlot.end) {
            timePenalty += 80.0;
          } else {
            timePenalty -= 12.0;
          }
        }
        if (accumulatedTime < opensAt) {
          timePenalty += (opensAt - accumulatedTime) * 0.08;
        } else if (accumulatedTime >= closesAt) {
          timePenalty += 50.0;
        }

        final score = distanceKm * 1.5 + timePenalty;
        if (score < bestScore) {
          bestScore = score;
          bestIndex = index;
        }
      }

      final next = unordered.removeAt(bestIndex);
      final travel = ordered.isEmpty
          ? 0
          : _estimatedTravelMinutes(
              ordered.last['location'],
              next['location'],
              pace,
            );
      final buffer = _bufferMinutesFor(next, travelMinutes: travel, pace: pace);
      next['travelMinutesBefore'] = travel;
      next['bufferMinutesAfter'] = buffer;
      ordered.add(next);
      current = _coordinateMap(next['location']) ?? current;

      final win = ItinerarySchedulePlanner._openingWindow(
        '${next['openingHours'] ?? ''}',
      );
      final opensAt = win?.open24Hours == true ? 0 : (win?.opens ?? 9 * 60);
      final mealSlot = _mealSlotForLabel('${next['mealRole'] ?? ''}');
      var effectiveArrival = max(accumulatedTime + travel, opensAt);
      if (mealSlot != null && effectiveArrival < mealSlot.start) {
        effectiveArrival = mealSlot.start;
      }
      accumulatedTime =
          effectiveArrival +
          ((next['durationMinutes'] as num?)?.round() ?? 60) +
          buffer;
    }

    selected
      ..clear()
      ..addAll(ordered);
  }

  static Future<void> _applyRoutingTimes(
    List<Map<String, dynamic>> selected, {
    required String pace,
  }) async {
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
          final travelMinutes = max(1, (seconds / 60).ceil());
          selected[index + 1]['travelMinutesBefore'] = travelMinutes;
          selected[index + 1]['bufferMinutesAfter'] = _bufferMinutesFor(
            selected[index + 1],
            travelMinutes: travelMinutes,
            pace: pace,
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
    return max(5, min(180, ((distanceKm / walkingSpeed) * 60).round()));
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

  static bool _isFoodPlace(Map<String, dynamic> place) {
    final tags = List<String>.from(
      place['tags'] ?? const <String>[],
    ).map((t) => t.toLowerCase()).toList();
    final name =
        '${place['name'] ?? ''} ${place['businessName'] ?? ''} ${place['displayName'] ?? ''}'
            .toLowerCase();
    final category = '${place['category'] ?? ''}'.toLowerCase();
    final plannerCategories = List<String>.from(
      place['plannerCategories'] ?? const <String>[],
    ).map((t) => t.toLowerCase()).toList();

    return category == 'food' ||
        plannerCategories.contains('food') ||
        tags.any(
          (t) =>
              t.contains('food') ||
              t.contains('restaurant') ||
              t.contains('cafe') ||
              t.contains('hawker') ||
              t.contains('kopitiam') ||
              t.contains('bakery') ||
              t.contains('dessert') ||
              t.contains('tea') ||
              t.contains('market'),
        ) ||
        name.contains('restaurant') ||
        name.contains('cafe') ||
        name.contains('coffee') ||
        name.contains('kopitiam') ||
        name.contains('hawker') ||
        name.contains('food court') ||
        name.contains('bakery') ||
        name.contains('dessert') ||
        name.contains('tea') ||
        name.contains('nasi') ||
        name.contains('laksa') ||
        name.contains('roti') ||
        name.contains('char koay') ||
        name.contains('market');
  }

  static String? _mealLabelForMinute(int minutes) {
    final value = minutes % (24 * 60);
    if (value >= 7 * 60 && value <= 10 * 60 + 30) return 'Breakfast';
    if (value >= 11 * 60 + 30 && value <= 14 * 60) return 'Lunch';
    if (value >= 18 * 60 && value <= 21 * 60) return 'Dinner';
    return null;
  }

  static Set<String> _coveredMealLabels(
    int startMinutes,
    int availableMinutes,
  ) {
    final endMinutes = startMinutes + availableMinutes;
    final labels = <String>{};
    for (final slot in _mealSlots) {
      if (endMinutes >= slot.start && startMinutes <= slot.end) {
        labels.add(slot.label);
      }
    }
    return labels;
  }

  static ({String label, int start, int end})? _mealSlotForLabel(String label) {
    for (final slot in _mealSlots) {
      if (slot.label == label) return slot;
    }
    return null;
  }

  static String? _pendingMealLabel(
    int currentMinute,
    int endMinute,
    Set<String> selectedMealLabels,
  ) {
    for (final slot in _mealSlots) {
      if (selectedMealLabels.contains(slot.label)) continue;
      if (endMinute < slot.start + 30) continue;
      if (currentMinute >= slot.start - 20 && currentMinute <= slot.end) {
        return slot.label;
      }
    }
    return null;
  }

  static const List<({String label, int start, int end})> _mealSlots = [
    (label: 'Breakfast', start: 7 * 60, end: 10 * 60 + 30),
    (label: 'Lunch', start: 11 * 60 + 30, end: 14 * 60),
    (label: 'Dinner', start: 18 * 60, end: 21 * 60),
  ];

  static double _mealTimeScore(Map<String, dynamic> place, int startMinutes) {
    if (!_isFoodPlace(place)) return 0.0;
    final meal = _mealLabelForMinute(startMinutes);
    if (meal == null) return -0.22;
    return meal == 'Breakfast' ? 0.55 : 0.72;
  }

  static String? _mealSuggestionText(
    Map<String, dynamic> place,
    int startMinutes,
  ) {
    final meal = _mealLabelForMinute(startMinutes);
    if (meal == null || !_isFoodPlace(place)) return null;
    return '$meal stop around ${ItinerarySchedulePlanner.formatTime(startMinutes)}';
  }

  static int _bufferMinutesFor(
    Map<String, dynamic> place, {
    required int travelMinutes,
    required String pace,
  }) {
    final isMeal = _isFoodPlace(place);
    if (pace == 'Relaxed') {
      if (travelMinutes >= 30) return 15;
      return isMeal ? 10 : 8;
    }
    if (pace == 'Fast' || pace == 'Packed') {
      if (travelMinutes >= 35) return 8;
      return isMeal ? 5 : 0;
    }
    if (travelMinutes >= 30) return 10;
    if (travelMinutes >= 18) return 5;
    return isMeal ? 5 : 0;
  }

  static double _timeOfDayScore(Map<String, dynamic> place, int startMinutes) {
    final tags = List<String>.from(
      place['tags'] ?? const <String>[],
    ).map((t) => t.toLowerCase()).toList();
    final name = '${place['name'] ?? ''}'.toLowerCase();
    final category = '${place['category'] ?? ''}';
    final desc = '${place['description'] ?? ''}'.toLowerCase();
    final mealScore = _mealTimeScore(place, startMinutes);
    if (mealScore != 0) return mealScore;

    final isMorningCandidate =
        tags.any(
          (t) =>
              t.contains('kopitiam') ||
              t.contains('coffee') ||
              t.contains('breakfast') ||
              t.contains('bakery') ||
              t.contains('market') ||
              t.contains('nature') ||
              t.contains('trail'),
        ) ||
        category == 'Food' ||
        category == 'Nature' ||
        name.contains('kopitiam') ||
        name.contains('market') ||
        desc.contains('morning');

    final isAfternoonCandidate =
        tags.any(
          (t) =>
              t.contains('museum') ||
              t.contains('mansion') ||
              t.contains('heritage') ||
              t.contains('gallery') ||
              t.contains('indoor'),
        ) ||
        category == 'Heritage' ||
        category == 'Culture' ||
        category == 'Art';

    final isEveningCandidate =
        tags.any(
          (t) =>
              t.contains('night') ||
              t.contains('sunset') ||
              t.contains('dinner') ||
              t.contains('waterfront'),
        ) ||
        name.contains('night') ||
        desc.contains('evening') ||
        desc.contains('night');

    if (startMinutes < 660) {
      // Morning (before 11:00 AM)
      return isMorningCandidate ? 0.35 : (isAfternoonCandidate ? 0.15 : 0.0);
    } else if (startMinutes < 1020) {
      // Midday / Afternoon (11:00 AM - 5:00 PM)
      return isAfternoonCandidate ? 0.35 : 0.15;
    } else {
      // Evening / Night (5:00 PM+)
      return isEveningCandidate ? 0.45 : 0.10;
    }
  }

  static bool _isOutdoorPlace(Map<String, dynamic> place) {
    final category = '${place['category'] ?? ''}'.toLowerCase();
    final name = '${place['name'] ?? ''}'.toLowerCase();
    final desc = '${place['description'] ?? ''}'.toLowerCase();
    final tags = List<String>.from(
      place['tags'] ?? const <String>[],
    ).map((tag) => tag.toLowerCase()).toList();
    final terms = <String>[category, name, desc, ...tags];

    return terms.any(
      (term) =>
          term.contains('nature') ||
          term.contains('park') ||
          term.contains('garden') ||
          term.contains('beach') ||
          term.contains('viewpoint') ||
          term.contains('trail') ||
          term.contains('hill') ||
          term.contains('waterfront') ||
          term.contains('outdoor') ||
          term.contains('street art') ||
          term.contains('walking'),
    );
  }

  static bool _isIndoorFriendlyPlace(Map<String, dynamic> place) {
    final category = '${place['category'] ?? ''}'.toLowerCase();
    final name = '${place['name'] ?? ''}'.toLowerCase();
    final desc = '${place['description'] ?? ''}'.toLowerCase();
    final tags = List<String>.from(
      place['tags'] ?? const <String>[],
    ).map((tag) => tag.toLowerCase()).toList();
    final terms = <String>[category, name, desc, ...tags];

    return terms.any(
      (term) =>
          term.contains('museum') ||
          term.contains('gallery') ||
          term.contains('mansion') ||
          term.contains('cafe') ||
          term.contains('restaurant') ||
          term.contains('food court') ||
          term.contains('mall') ||
          term.contains('market') ||
          term.contains('covered') ||
          term.contains('indoor') ||
          term.contains('heritage house') ||
          term.contains('temple'),
    );
  }

  static double _weatherScore(
    Map<String, dynamic> place, {
    required String weatherSeverity,
    required bool isRainy,
  }) {
    final isOutdoor = _isOutdoorPlace(place);
    final indoorFriendly = _isIndoorFriendlyPlace(place);

    return switch (weatherSeverity) {
      'thunderstorm' ||
      'heavy_rain' => isOutdoor ? -0.75 : (indoorFriendly ? 0.40 : 0.12),
      'moderate_rain' => isOutdoor ? -0.30 : (indoorFriendly ? 0.20 : 0.06),
      'light_showers' => isOutdoor ? -0.08 : (indoorFriendly ? 0.10 : 0.03),
      'hot' => isOutdoor ? -0.10 : (indoorFriendly ? 0.08 : 0.02),
      'cloudy' => isOutdoor ? 0.24 : (indoorFriendly ? 0.04 : 0.0),
      'fair' => isOutdoor ? 0.28 : (indoorFriendly ? 0.02 : 0.0),
      _ =>
        isRainy
            ? (isOutdoor ? -0.18 : (indoorFriendly ? 0.14 : 0.04))
            : (isOutdoor ? 0.22 : 0.0),
    };
  }

  static double _rank(
    Map<String, dynamic> place, {
    String? userBudget,
    int? preferredStartMinutes,
    bool isRainy = false,
    String weatherSeverity = 'fair',
  }) {
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
        : source == 'real_map_place'
        ? 0.40
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
    final penangBonus = min(max(penangPriority, 0.0) / 100.0, 1.0) * 0.45;

    // Time-of-day alignment bonus
    final timeBonus = preferredStartMinutes != null
        ? _timeOfDayScore(place, preferredStartMinutes)
        : 0.0;

    // Budget alignment bonus
    final placeBudget = '${place['budgetLevel'] ?? 'Medium'}';
    final budgetBonus =
        userBudget != null &&
            userBudget.toLowerCase() == placeBudget.toLowerCase()
        ? 0.30
        : 0.0;

    final weatherBonus = _weatherScore(
      place,
      weatherSeverity: weatherSeverity,
      isRainy: isRainy,
    );

    return (score / 5) * 0.48 +
        min(reviewCount / 10, 1.0) * 0.18 +
        sourceBonus +
        taskBonus +
        voucherBonus +
        distanceBonus +
        min(max(areaRelevance, 0.0), 1.0) * 1.50 +
        (areaRelevance < 0.2 ? -1.0 : 0.0) +
        min(max(interestRelevance, 0.0), 1.0) * 0.85 +
        min(completeness, 1.0) * 0.20 +
        imageBonus +
        openingBonus +
        penangBonus +
        timeBonus +
        budgetBonus +
        weatherBonus;
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

  static Set<String> _allPlaceKeys(Map<String, dynamic> place) {
    final keys = <String>{};
    final placeId = '${place['placeId'] ?? ''}'.trim();
    if (placeId.isNotEmpty) keys.add('place:$placeId');
    final vendorId = '${place['vendorId'] ?? ''}'.trim();
    if (vendorId.isNotEmpty) keys.add('vendor:$vendorId');
    final geoapifyPlaceId = '${place['geoapifyPlaceId'] ?? ''}'.trim();
    if (geoapifyPlaceId.isNotEmpty) keys.add('geo:$geoapifyPlaceId');
    final name = _normalize('${place['name'] ?? ''}');
    if (name.isNotEmpty) keys.add('name:$name');
    final identity = _placeIdentity(place);
    if (identity.isNotEmpty) keys.add(identity);
    return keys;
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
    final mealSuggestion = '${place['mealSuggestionLabel'] ?? ''}'.trim();
    if (mealSuggestion.isNotEmpty) {
      reasons.add(mealSuggestion);
    }
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
  DateTime tripStartDate = DateTime.now().add(const Duration(days: 1));
  DateTime tripEndDate = DateTime.now().add(const Duration(days: 1));
  int get tripDays => max(
    1,
    tripEndDate
            .difference(
              DateTime(
                tripStartDate.year,
                tripStartDate.month,
                tripStartDate.day,
              ),
            )
            .inDays +
        1,
  );
  int selectedDayIndex = 0;
  List<PlannerDaySchedule> generatedDays = [];
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  double availableHours = 4;
  String budgetLevel = 'Medium';
  String pace = 'Balanced';
  bool foodExplorationEnabled = false;
  bool loading = false;
  int totalEstimatedMinutes = 0;
  int remainingMinutes = 0;
  List<Map<String, dynamic>> results = [];
  bool showSuggestions = false;
  List<MalaysianSubArea> suggestions = [];
  late MalaysianAreaHub activeHub;

  @override
  void initState() {
    super.initState();
    activeHub = MalaysianAreaSearchEngine.findHubForArea(area.text);
    _loadSavedPreferences();
  }

  void _onAreaChanged(String query) {
    final matches = MalaysianAreaSearchEngine.findSuggestions(query);
    final hub = MalaysianAreaSearchEngine.findHubForArea(query);
    setState(() {
      suggestions = matches;
      showSuggestions = matches.isNotEmpty && query.trim().isNotEmpty;
      activeHub = hub;
    });
  }

  void _selectSubArea(MalaysianSubArea sub) {
    setState(() {
      area.text = sub.fullQuery;
      showSuggestions = false;
      activeHub = MalaysianAreaSearchEngine.findHubForArea(sub.fullQuery);
    });
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
        final plannerPrefs = profile['lastPlannerPreferences'];
        if (plannerPrefs is Map) {
          foodExplorationEnabled =
              plannerPrefs['foodExplorationEnabled'] == true;
        }
      });
    } catch (_) {
      // Existing defaults remain available when the profile is unavailable.
    }
  }

  int get preferredStartMinutes => startTime.hour * 60 + startTime.minute;

  Future<void> generate() async {
    if (area.text.trim().isEmpty || selectedInterests.isEmpty) {
      showMessage(
        context,
        'Complete all required travel preferences.',
        error: true,
      );
      return;
    }

    setState(() {
      loading = true;
      showSuggestions = false;
    });

    try {
      final generated = await GeoapifyPlanner.generate(
        area: area.text.trim(),
        availableHours: availableHours,
        interests: selectedInterests.toList(),
        budgetLevel: budgetLevel,
        travelPace: pace,
        preferredStartMinutes: preferredStartMinutes,
        startDate: tripStartDate,
        dayCount: tripDays,
        foodExplorationEnabled: foodExplorationEnabled,
      );

      ItineraryImageResolver.clearCache();

      final plannedDays = <PlannerDaySchedule>[];
      for (final d in generated.days) {
        final resolvedPlaces = await Future.wait(
          d.places.map(
            (place) => ItineraryImageResolver.resolveStop(
              Map<String, dynamic>.from(place),
            ),
          ),
        );

        final daySchedule = ItinerarySchedulePlanner.plan(
          stops: resolvedPlaces,
          pace: pace,
          availableHours: availableHours,
          preferredStartMinutes: preferredStartMinutes,
        );

        plannedDays.add(
          PlannerDaySchedule(
            dayNumber: d.dayNumber,
            date: d.date,
            dateLabel: d.dateLabel,
            weather: d.weather,
            places: daySchedule.stops,
            totalEstimatedMinutes: daySchedule.totalEstimatedMinutes,
            remainingMinutes: daySchedule.remainingMinutes,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        generatedDays = plannedDays;
        selectedDayIndex = 0;
        if (plannedDays.isNotEmpty) {
          results = plannedDays.first.places;
          totalEstimatedMinutes = plannedDays.fold<int>(
            0,
            (sum, d) => sum + d.totalEstimatedMinutes,
          );
          remainingMinutes = plannedDays.first.remainingMinutes;
        } else {
          results = [];
          totalEstimatedMinutes = 0;
          remainingMinutes = (availableHours * 60).round();
        }
      });

      final uid = AppServices.auth.currentUser?.uid;
      if (uid != null) {
        await AppServices.travelerRef(uid).set({
          'lastPlannerPreferences': {
            'area': area.text.trim(),
            'availableHours': availableHours,
            'dayCount': tripDays,
            'interests': selectedInterests.toList(),
            'budgetLevel': budgetLevel,
            'travelPace': pace,
            'startMinutes': preferredStartMinutes,
            'foodExplorationEnabled': foodExplorationEnabled,
            'tripStartDate': Timestamp.fromDate(tripStartDate),
            'placeSource': 'Registered MyHeritage vendors and verified places',
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (generated.places.isEmpty && mounted) {
        showMessage(
          context,
          'No registered vendor matches the selected interests and budget. Try another area or interest.',
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

  ItineraryScheduleResult _currentSchedule() {
    final currentStops =
        generatedDays.isNotEmpty && selectedDayIndex < generatedDays.length
        ? generatedDays[selectedDayIndex].places
        : results;
    return ItinerarySchedulePlanner.plan(
      stops: currentStops,
      pace: pace,
      availableHours: availableHours,
      preferredStartMinutes: preferredStartMinutes,
    );
  }

  Future<void> save() async {
    if (results.isEmpty && generatedDays.isEmpty) return;
    final uid = AppServices.auth.currentUser?.uid;
    if (uid == null) {
      showMessage(
        context,
        'Please sign in to save your itinerary.',
        error: true,
      );
      return;
    }

    try {
      showMessage(context, 'Saving itinerary to your account...');

      final allDaysMap = <Map<String, dynamic>>[];
      final allStopsResolved = <Map<String, dynamic>>[];

      if (generatedDays.isNotEmpty) {
        for (final day in generatedDays) {
          final schedule = ItinerarySchedulePlanner.plan(
            stops: day.places,
            pace: pace,
            availableHours: availableHours,
            preferredStartMinutes: preferredStartMinutes,
          );

          final dayStops = await Future.wait(
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
                'dayNumber': day.dayNumber,
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
                'mealSuggestionLabel': data['mealSuggestionLabel'],
                'suggestionReason': data['suggestionReason'],
                'distanceMeters': data['distanceMeters'],
                'matchedInterest': data['matchedInterest'],
                'area': data['area'],
                'category': data['category'],
                'formattedAddress': data['formattedAddress'],
                'durationMinutes': data['durationMinutes'] ?? 60,
                'travelMinutesBefore': data['travelMinutesBefore'] ?? 0,
                'routeDistanceMetersBefore': data['routeDistanceMetersBefore'],
                'bufferMinutesAfter': data['bufferMinutesAfter'] ?? 0,
                'mealRole': data['mealRole'],
                'scheduleType': data['scheduleType'],
                'optionalFoodExperience':
                    data['optionalFoodExperience'] == true,
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

          final dayBudget = ItineraryBudgetEstimator.estimateDay(dayStops);
          allDaysMap.add({
            'dayNumber': day.dayNumber,
            'date': day.date.toIso8601String(),
            'dateLabel': day.dateLabel,
            'weather': day.weather,
            'stops': dayStops,
            'totalEstimatedMinutes': schedule.totalEstimatedMinutes,
            'remainingMinutes': schedule.remainingMinutes,
            'budget': dayBudget.dayBudget,
            'budgetLevel': dayBudget.budgetLevel,
          });

          allStopsResolved.addAll(dayStops);
        }
      } else {
        final schedule = _currentSchedule();
        final dayStops = await Future.wait(
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
              'dayNumber': 1,
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
              'mealSuggestionLabel': data['mealSuggestionLabel'],
              'suggestionReason': data['suggestionReason'],
              'distanceMeters': data['distanceMeters'],
              'matchedInterest': data['matchedInterest'],
              'area': data['area'],
              'category': data['category'],
              'formattedAddress': data['formattedAddress'],
              'durationMinutes': data['durationMinutes'] ?? 60,
              'travelMinutesBefore': data['travelMinutesBefore'] ?? 0,
              'routeDistanceMetersBefore': data['routeDistanceMetersBefore'],
              'bufferMinutesAfter': data['bufferMinutesAfter'] ?? 0,
              'mealRole': data['mealRole'],
              'scheduleType': data['scheduleType'],
              'optionalFoodExperience': data['optionalFoodExperience'] == true,
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
        allStopsResolved.addAll(dayStops);
        final dayBudget = ItineraryBudgetEstimator.estimateDay(dayStops);
        allDaysMap.add({
          'dayNumber': 1,
          'date': tripStartDate.toIso8601String(),
          'dateLabel': DateFormat('d MMM').format(tripStartDate),
          'weather': <String, dynamic>{},
          'stops': dayStops,
          'totalEstimatedMinutes': schedule.totalEstimatedMinutes,
          'remainingMinutes': schedule.remainingMinutes,
          'budget': dayBudget.dayBudget,
          'budgetLevel': dayBudget.budgetLevel,
        });
      }

      final tripArea = area.text.trim().isEmpty
          ? activeHub.name
          : area.text.trim();
      final tripTitle = tripDays > 1
          ? '$tripArea $tripDays-Day Tour'
          : '$tripArea Cultural Day';
      final tripEndDate = this.tripEndDate;
      final tripBudget = ItineraryBudgetEstimator.estimateTrip(
        allDaysMap,
        fallbackStops: allStopsResolved,
      );

      final docRef = await AppServices.db.collection('itineraries').add({
        'userId': uid,
        'title': tripTitle,
        'area': tripArea,
        'availableHours': availableHours,
        'dailyHours': availableHours,
        'dayCount': tripDays,
        'startDate': Timestamp.fromDate(tripStartDate),
        'endDate': Timestamp.fromDate(tripEndDate),
        'budget': tripBudget.tripBudget,
        'budgetLevel': tripBudget.budgetLevel,
        'budgetPreference': budgetLevel,
        'interests': selectedInterests.toList(),
        'travelPace': pace,
        'placeSource': 'Registered MyHeritage vendors & verified places',
        'suggestedStartMinutes': preferredStartMinutes,
        'totalEstimatedMinutes': totalEstimatedMinutes,
        'remainingMinutes': remainingMinutes,
        'stops': allStopsResolved,
        'days': allDaysMap,
        'status': 'saved',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await AppServices.scheduleTripNotification(
        userId: uid,
        itineraryId: docRef.id,
        title: tripTitle,
        area: tripArea,
        tripStartDate: tripStartDate,
        tripEndDate: tripEndDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Itinerary saved with trip notifications enabled!',
            ),
            backgroundColor: ExplorerColors.navy,
            action: SnackBarAction(
              label: 'View',
              textColor: ExplorerColors.gold,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ItineraryDetailPage(
                      itineraryId: docRef.id,
                      initialItinerary: {
                        'userId': uid,
                        'title': tripTitle,
                        'area': tripArea,
                        'availableHours': availableHours,
                        'dailyHours': availableHours,
                        'dayCount': tripDays,
                        'startDate': Timestamp.fromDate(tripStartDate),
                        'endDate': Timestamp.fromDate(tripEndDate),
                        'budget': tripBudget.tripBudget,
                        'budgetLevel': tripBudget.budgetLevel,
                        'budgetPreference': budgetLevel,
                        'interests': selectedInterests.toList(),
                        'travelPace': pace,
                        'suggestedStartMinutes': preferredStartMinutes,
                        'totalEstimatedMinutes': totalEstimatedMinutes,
                        'remainingMinutes': remainingMinutes,
                        'stops': allStopsResolved,
                        'days': allDaysMap,
                        'status': 'saved',
                      },
                    ),
                  ),
                );
              },
            ),
          ),
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
    }
  }

  @override
  void dispose() {
    area.dispose();
    super.dispose();
  }

  String _extractShortArea(String fullAddress) {
    if (fullAddress.isEmpty) return area.text.trim();
    final parts = fullAddress.split(',');
    if (parts.length >= 2) {
      final town = parts[parts.length - 2]
          .replaceAll(RegExp(r'\d+'), '')
          .trim();
      if (town.isNotEmpty && town.length < 24) return town;
    }
    return parts.first.trim();
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _currentSchedule();
    final scheduledResults = schedule.stops;
    final mainScheduleResults = scheduledResults
        .where((place) => place['optionalFoodExperience'] != true)
        .toList();
    final optionalFoodResults = scheduledResults
        .where((place) => place['optionalFoodExperience'] == true)
        .toList();
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
            'Curate your perfect cultural itinerary with authentic places & tasks.',
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
                  'Search Destination / Hub',
                  style: TextStyle(
                    color: ExplorerColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: area,
                  onChanged: _onAreaChanged,
                  decoration: InputDecoration(
                    hintText: 'e.g. png, kl, penang, bukit mertajam...',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    suffixIcon: area.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              area.clear();
                              _onAreaChanged('');
                            },
                          )
                        : null,
                  ),
                ),
                if (showSuggestions && suggestions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ExplorerColors.goldSoft),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: suggestions.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        color: ExplorerColors.goldSoft,
                      ),
                      itemBuilder: (context, index) {
                        final sub = suggestions[index];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: const Icon(
                            Icons.place,
                            size: 18,
                            color: ExplorerColors.navy,
                          ),
                          title: Text(
                            sub.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: ExplorerColors.navy,
                            ),
                          ),
                          subtitle: Text(
                            sub.highlight,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: ExplorerColors.muted,
                            ),
                          ),
                          onTap: () => _selectSubArea(sub),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Popular ${activeHub.name} Areas:',
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: activeHub.subAreas.map((sub) {
                      final isSelected = area.text.toLowerCase().contains(
                        sub.name.toLowerCase(),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(sub.name),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : ExplorerColors.navy,
                          ),
                          selected: isSelected,
                          selectedColor: ExplorerColors.navy,
                          backgroundColor: Colors.white,
                          onSelected: (_) => _selectSubArea(sub),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ExplorerColors.navySoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ExplorerColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: ExplorerColors.navy,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          activeHub.description,
                          style: const TextStyle(
                            fontSize: 10,
                            color: ExplorerColors.navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start Date',
                            style: TextStyle(
                              color: ExplorerColors.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tripStartDate,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 30),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setState(() {
                                  tripStartDate = picked;
                                  if (tripEndDate.isBefore(tripStartDate)) {
                                    tripEndDate = tripStartDate;
                                  } else if (tripEndDate
                                          .difference(tripStartDate)
                                          .inDays >
                                      4) {
                                    tripEndDate = tripStartDate.add(
                                      const Duration(days: 4),
                                    );
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: ExplorerColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month_outlined,
                                    size: 16,
                                    color: ExplorerColors.goldDark,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      DateFormat(
                                        'd MMM yyyy',
                                      ).format(tripStartDate),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: ExplorerColors.navy,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'End Date',
                            style: TextStyle(
                              color: ExplorerColors.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tripEndDate.isBefore(tripStartDate)
                                    ? tripStartDate
                                    : tripEndDate,
                                firstDate: tripStartDate,
                                lastDate: tripStartDate.add(
                                  const Duration(days: 4),
                                ),
                              );
                              if (picked != null) {
                                setState(() => tripEndDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: ExplorerColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.event_available_outlined,
                                    size: 16,
                                    color: Color(0xFF2E7D32),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      DateFormat(
                                        'd MMM yyyy',
                                      ).format(tripEndDate),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: ExplorerColors.navy,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ExplorerColors.navySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: ExplorerColors.navy,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Total Duration: $tripDays ${tripDays > 1 ? "Days" : "Day"} (${DateFormat("d MMM").format(tripStartDate)} - ${DateFormat("d MMM yyyy").format(tripEndDate)})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ExplorerColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Start Time',
                            style: TextStyle(
                              color: ExplorerColors.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: startTime,
                              );
                              if (picked != null) {
                                setState(() => startTime = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: ExplorerColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: ExplorerColors.goldDark,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      startTime.format(context),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: ExplorerColors.navy,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: ExplorerColors.muted,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hours (Per Day)',
                            style: TextStyle(
                              color: ExplorerColors.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<double>(
                            isExpanded: true,
                            isDense: true,
                            value: availableHours,
                            items: const [
                              DropdownMenuItem(
                                value: 2,
                                child: Text(
                                  '2 hours / day',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 4,
                                child: Text(
                                  '4 hrs / day',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 6,
                                child: Text(
                                  '6 hours / day',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 8,
                                child: Text(
                                  '8 hrs / day (Max)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => availableHours = value ?? 4),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              prefixIconConstraints: BoxConstraints(
                                minWidth: 26,
                                minHeight: 26,
                              ),
                              prefixIcon: Padding(
                                padding: EdgeInsets.only(left: 6, right: 4),
                                child: Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: ExplorerColors.goldDark,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                                if (item == 'Food') {
                                  foodExplorationEnabled = false;
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                ),
                if (selectedInterests.contains('Food')) ...[
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    value: foodExplorationEnabled,
                    onChanged: (value) =>
                        setState(() => foodExplorationEnabled = value),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    dense: true,
                    title: const Text(
                      'Explore local food',
                      style: TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: const Text(
                      'Add optional dessert, tea or snack stops outside main meals.',
                      style: TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
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
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: ExplorerColors.navySoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFB9CBE2)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        color: ExplorerColors.navy,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Budget range: Low RM0-50/day, Medium RM51-150/day, High RM151+/day. Saved trip budget is calculated from the selected places.',
                          style: TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 11,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                : IconButton(
                    tooltip: 'Save itinerary',
                    onPressed: save,
                    icon: const Icon(Icons.bookmark_add_outlined),
                  ),
          ),
          if (results.isNotEmpty && totalEstimatedMinutes > 0) ...[
            const SizedBox(height: 7),
            Text(
              tripDays > 1
                  ? '$tripDays-Day Tour • ${(totalEstimatedMinutes / 60).toStringAsFixed(1)} total hours planned'
                  : '${(displayTotalMinutes / 60).toStringAsFixed(1)} hours planned - $displayRemainingMinutes minutes remaining',
              style: const TextStyle(
                color: ExplorerColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (generatedDays.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: generatedDays.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final d = entry.value;
                  final isSel = selectedDayIndex == idx;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(d.dateLabel),
                      selected: isSel,
                      selectedColor: ExplorerColors.navy,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : ExplorerColors.navy,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                      backgroundColor: Colors.white,
                      onSelected: (_) => setState(() => selectedDayIndex = idx),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (scheduledResults.isNotEmpty) ...[
            if (generatedDays.isNotEmpty &&
                selectedDayIndex < generatedDays.length) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      (generatedDays[selectedDayIndex].weather['isRainy'] ==
                          true)
                      ? const Color(0xFFEBF3FC)
                      : const Color(0xFFFFF9EB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        (generatedDays[selectedDayIndex].weather['isRainy'] ==
                            true)
                        ? const Color(0xFFB9D7F6)
                        : const Color(0xFFFFE299),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      (generatedDays[selectedDayIndex].weather['isRainy'] ==
                              true)
                          ? Icons.beach_access_outlined
                          : Icons.wb_sunny_outlined,
                      color:
                          (generatedDays[selectedDayIndex].weather['isRainy'] ==
                              true)
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
                            '${generatedDays[selectedDayIndex].dateLabel} Weather: ${generatedDays[selectedDayIndex].weather['condition'] ?? 'Fair'} (${generatedDays[selectedDayIndex].weather['temperature'] ?? '30°C'})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color:
                                  (generatedDays[selectedDayIndex]
                                          .weather['isRainy'] ==
                                      true)
                                  ? const Color(0xFF0D47A1)
                                  : const Color(0xFFE65100),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${generatedDays[selectedDayIndex].weather['advice'] ?? ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  (generatedDays[selectedDayIndex]
                                          .weather['isRainy'] ==
                                      true)
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
              const SizedBox(height: 10),
            ] else ...[
              PlannerWeatherCard(
                area: activeHub.name,
                latitude: activeHub.subAreas.isNotEmpty
                    ? activeHub.subAreas.first.latitude
                    : 5.4164,
                longitude: activeHub.subAreas.isNotEmpty
                    ? activeHub.subAreas.first.longitude
                    : 100.3327,
              ),
              const SizedBox(height: 10),
            ],
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
                    'Select your preferences to generate an authentic cultural itinerary with real Google Maps places & tasks.',
                icon: Icons.route_outlined,
              ),
            )
          else ...[
            const ExplorerSectionTitle(
              'Main Schedule',
              subtitle:
                  'Meals, travel time, attraction visits and buffer time.',
            ),
            const SizedBox(height: 10),
            ...mainScheduleResults.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: _placeCard(context, entry.value, entry.key + 1),
              ),
            ),
            if (optionalFoodResults.isNotEmpty) ...[
              const SizedBox(height: 4),
              const ExplorerSectionTitle(
                'Optional Food Exploration',
                subtitle:
                    'Extra local food stops shown because food exploration is enabled.',
              ),
              const SizedBox(height: 10),
              ...optionalFoodResults.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: _placeCard(context, entry.value, entry.key + 1),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 14),
              child: Column(
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: ExplorerColors.navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: save,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text(
                      'Save Itinerary',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Save to your account to track cultural tasks and earn explorer points.',
                    style: TextStyle(color: ExplorerColors.muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
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
    final mealSuggestion = '${data['mealSuggestionLabel'] ?? ''}'.trim();
    final bufferMinutes = (data['bufferMinutesAfter'] as num?)?.round() ?? 0;
    final formattedAddress = '${data['formattedAddress'] ?? data['area'] ?? ''}'
        .trim();
    final shortArea = _extractShortArea(formattedAddress);

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
                if (mealSuggestion.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu_outlined,
                        size: 15,
                        color: ExplorerColors.navy,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          mealSuggestion,
                          style: const TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                ],
                Text(
                  '${data['description'] ?? formattedAddress}',
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
                    _meta(Icons.place_outlined, shortArea),
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
                    if (bufferMinutes > 0)
                      _meta(
                        Icons.more_time_outlined,
                        '$bufferMinutes min buffer',
                      ),
                    _meta(
                      Icons.payments_outlined,
                      '${data['budgetLevel'] ?? 'Low'} budget',
                    ),
                    _meta(Icons.star_rounded, () {
                      final raw =
                          ((data['score'] as num?) ??
                                  (data['rating'] as num?) ??
                                  0)
                              .toDouble();
                      final s = raw > 0 ? raw : 4.8;
                      final count = (data['inAppReviewCount'] as num? ?? 0);
                      return '${s.toStringAsFixed(1)} ★ (${count > 0 ? '$count reviews' : 'Verified'})';
                    }()),
                  ],
                ),
                if (formattedAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: ExplorerColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          formattedAddress,
                          style: const TextStyle(
                            color: ExplorerColors.muted,
                            fontSize: 10,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ExplorerColors.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
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
}

class PlannerWeatherCard extends StatefulWidget {
  const PlannerWeatherCard({
    super.key,
    required this.area,
    this.latitude,
    this.longitude,
  });

  final String area;
  final double? latitude;
  final double? longitude;

  @override
  State<PlannerWeatherCard> createState() => _PlannerWeatherCardState();
}

class _PlannerWeatherCardState extends State<PlannerWeatherCard> {
  bool loading = true;
  String? temperature;
  String? condition;
  String? tip;
  IconData icon = Icons.wb_sunny_outlined;
  Color iconColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  @override
  void didUpdateWidget(covariant PlannerWeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.area != widget.area ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _fetchWeather();
    }
  }

  Future<void> _fetchWeather() async {
    final lat = widget.latitude ?? 5.4164;
    final lng = widget.longitude ?? 100.3327;

    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': lat.toString(),
        'longitude': lng.toString(),
        'current':
            'temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m',
        'forecast_days': '1',
        'timezone': 'auto',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final current = Map<String, dynamic>.from(
          json['current'] as Map? ?? {},
        );
        final temp = (current['temperature_2m'] as num?)?.round() ?? 30;
        final code = (current['weather_code'] as num?)?.toInt() ?? 0;
        final rain = (current['precipitation'] as num?)?.toDouble() ?? 0.0;

        String cond;
        String advice;
        IconData ic;
        Color color;

        if (code >= 95 || rain > 5) {
          cond = 'Thunderstorms Forecast';
          advice =
              'Heavy rain possible. Prioritize indoor heritage museums, craft galleries & covered food courts.';
          ic = Icons.thunderstorm_outlined;
          color = Colors.deepPurple;
        } else if (code >= 51 || rain > 0) {
          cond = 'Scattered Showers';
          advice =
              'Rain showers expected. Carry an umbrella and schedule outdoor photo walks between showers.';
          ic = Icons.beach_access_outlined;
          color = Colors.blue;
        } else if (code >= 1 && code <= 3) {
          cond = 'Partly Cloudy';
          advice =
              'Pleasant weather for cultural walks, street art viewing & heritage trail exploration.';
          ic = Icons.cloud_outlined;
          color = ExplorerColors.navy;
        } else {
          cond = 'Sunny & Warm';
          advice =
              'Bright skies. Stay hydrated, use sun protection, and enjoy outdoor sights & beaches.';
          ic = Icons.wb_sunny_outlined;
          color = Colors.orange;
        }

        if (mounted) {
          setState(() {
            loading = false;
            temperature = '$temp°C';
            condition = cond;
            tip = advice;
            icon = ic;
            iconColor = color;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        loading = false;
        temperature = '30°C';
        condition = 'Tropical Fair';
        tip =
            'Warm tropical weather. Stay hydrated and carry an umbrella for sudden afternoon tropical rain.';
        icon = Icons.wb_sunny_outlined;
        iconColor = Colors.orange;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ExplorerColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              'Checking local weather & travel advice...',
              style: TextStyle(fontSize: 11, color: ExplorerColors.muted),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ExplorerColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.area}: $temperature • $condition',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: ExplorerColors.navy,
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WeatherReminderPage(),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Forecast',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ExplorerColors.goldDark,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: ExplorerColors.goldDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tip != null) ...[
            const SizedBox(height: 5),
            Text(
              tip!,
              style: const TextStyle(
                fontSize: 11,
                color: ExplorerColors.muted,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
