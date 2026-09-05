import 'dart:math';
import 'package:intl/intl.dart';
import '../models/itinerary_model.dart';
import '../models/place_model.dart';
import '../models/travel_preferences_model.dart';
import 'cultural_task_service.dart';
import 'place_repository.dart';

class ItineraryRecommendationService {
  static final List<String> _recentRecommendationHistory = [];

  /// Generate a complete multi-day or single-day itinerary based on user preferences
  static Future<ItineraryModel> generateItinerary({
    required TravelPreferences preferences,
    String userId = '',
    List<String> previouslyVisitedPlaceIds = const [],
    List<PlaceModel>? candidatePlaces,
    Set<String>? recentlyRecommendedPlaceIds,
    int? randomSeed,
  }) async {
    final validationError = preferences.validate();
    if (validationError != null) {
      throw Exception(validationError);
    }

    if (recentlyRecommendedPlaceIds != null) {
      _recentRecommendationHistory.addAll(recentlyRecommendedPlaceIds);
    }

    // 1. Retrieve all active places for the selected Malaysian state
    List<PlaceModel> allStatePlaces = candidatePlaces ?? [];
    if (allStatePlaces.isEmpty) {
      allStatePlaces = await PlaceRepository.getPlacesForState(preferences.stateId);
      if (allStatePlaces.isEmpty) {
        // If Firestore is empty, attempt initial seed
        await PlaceRepository.seedInitialPlacesIfEmpty();
        allStatePlaces = await PlaceRepository.getPlacesForState(preferences.stateId);
        if (allStatePlaces.isEmpty) {
          throw Exception(
            'No attractions found for ${preferences.stateName}. Please select another Malaysian state.',
          );
        }
      }
    }

    List<Map<String, dynamic>> activeTasks = const [];
    try {
      activeTasks = await CulturalTaskService.loadActiveTasks();
    } catch (_) {}

    final totalDays = preferences.numberOfDays;
    final globalSelectedIds = <String>{...previouslyVisitedPlaceIds};

    final generatedDays = <ItineraryDayModel>[];
    final allStops = <ItineraryStopModel>[];

    for (var dayIdx = 0; dayIdx < totalDays; dayIdx++) {
      final dayNumber = dayIdx + 1;
      final dayDate = preferences.startDate.add(Duration(days: dayIdx));
      final dateLabel = 'Day $dayNumber (${DateFormat("d MMM").format(dayDate)})';

      // Day focus rotation for rich variety across multi-day trips
      final dayInterests = _resolveDayInterests(
        allInterests: preferences.interests,
        dayIndex: dayIdx,
      );

      final dayStops = _generateSingleDay(
        dayNumber: dayNumber,
        preferences: preferences,
        availablePlaces: allStatePlaces,
        activeTasks: activeTasks,
        dayInterests: dayInterests,
        globallyUsedIds: globalSelectedIds,
        dayIndex: dayIdx,
        randomSeed: randomSeed,
      );

      for (final stop in dayStops) {
        globalSelectedIds.add(stop.placeId);
        allStops.add(stop);
      }

      int totalDayMinutes = 0;
      for (final stop in dayStops) {
        totalDayMinutes += stop.durationMinutes + stop.travelMinutesBefore;
      }
      final availableTotalMinutes = (preferences.availableHours * 60).round();
      final remainingMin = max(0, availableTotalMinutes - totalDayMinutes);

      generatedDays.add(ItineraryDayModel(
        dayNumber: dayNumber,
        date: dayDate,
        dateLabel: dateLabel,
        stops: dayStops,
        totalEstimatedMinutes: totalDayMinutes,
        remainingMinutes: remainingMin,
        budget: _calculateDayBudget(dayStops, preferences.budget),
        budgetLevel: preferences.budget,
      ));
    }

    final tripTitle = totalDays > 1
        ? '${preferences.stateName} ($totalDays-Day Tour)'
        : '${preferences.selectedArea} Cultural Day';

    return ItineraryModel(
      id: '',
      userId: userId,
      title: tripTitle,
      stateId: preferences.stateId,
      stateName: preferences.stateName,
      selectedArea: preferences.selectedArea,
      startDate: preferences.startDate,
      endDate: preferences.endDate,
      numberOfDays: totalDays,
      dailyStartTime: preferences.dailyStartTimeLabel,
      dailyEndTime: preferences.dailyEndTimeLabel,
      availableHours: preferences.availableHours,
      interests: preferences.interests,
      budget: preferences.budget,
      pace: preferences.pace,
      days: generatedDays,
      stops: allStops,
      status: 'generated',
    );
  }

  /// Generate stops for a single day fitting the available hours
  static List<ItineraryStopModel> _generateSingleDay({
    required int dayNumber,
    required TravelPreferences preferences,
    required List<PlaceModel> availablePlaces,
    required List<Map<String, dynamic>> activeTasks,
    required List<String> dayInterests,
    required Set<String> globallyUsedIds,
    required int dayIndex,
    int? randomSeed,
  }) {
    // 1. Filter places strictly belonging to state & active
    final candidates = availablePlaces.where((p) {
      if (!p.isActive) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) return [];

    // 2. Score candidate places with weighted factors & diversity
    final scored = <_ScoredPlace>[];
    for (final place in candidates) {
      final task = CulturalTaskService.matchTaskForPlace(place.toMap(), activeTasks);
      final score = _calculateSuitabilityScore(
        place: place,
        preferences: preferences,
        dayInterests: dayInterests,
        hasCulturalTask: task != null,
        isUsedGlobally: globallyUsedIds.contains(place.placeId),
      );
      scored.add(_ScoredPlace(place: place, score: score, task: task));
    }

    // Sort descending by score
    scored.sort((a, b) => b.score.compareTo(a.score));

    // 3. Controlled diversity pool selection
    // Rather than taking strictly [0, 1, 2], create a top-quality candidate pool and pick
    final selectedPlaces = _selectDiverseStops(
      scoredPlaces: scored,
      availableHours: preferences.availableHours,
      pace: preferences.pace,
      globallyUsedIds: globallyUsedIds,
      dayIndex: dayIndex,
      randomSeed: randomSeed,
    );

    // 4. Arrange visiting sequence and schedule timeline
    return _buildScheduledStops(
      places: selectedPlaces,
      startMinutes: preferences.dailyStartMinutes,
      dayNumber: dayNumber,
      stateId: preferences.stateId,
      stateName: preferences.stateName,
    );
  }

  /// Compute suitability score based on weighted factors
  static double _calculateSuitabilityScore({
    required PlaceModel place,
    required TravelPreferences preferences,
    required List<String> dayInterests,
    required bool hasCulturalTask,
    required bool isUsedGlobally,
  }) {
    double score = 0.0;

    // 1. Interest match (Weight: 35)
    final placeInterests = place.interestTags.map((t) => t.toLowerCase()).toSet();
    placeInterests.add(place.category.toLowerCase());
    int matchCount = 0;
    for (final interest in dayInterests) {
      if (placeInterests.contains(interest.toLowerCase())) {
        matchCount++;
      }
    }
    if (dayInterests.isNotEmpty) {
      score += (matchCount / dayInterests.length) * 35.0;
    }

    // 2. Public Rating & Quality (Weight: 25)
    final ratingNorm = (place.publicRating.clamp(1.0, 5.0) - 1.0) / 4.0;
    score += ratingNorm * 25.0;

    // 3. Cultural Task Active (Weight: 15)
    if (hasCulturalTask) {
      score += 15.0;
    }

    // 4. Verification & Trust (Weight: 10)
    if (place.isVerified || place.trustLabel == 'Verified Place' || place.trustLabel == 'High Trust') {
      score += 10.0;
    }

    // 5. Area proximity to selected area (Weight: 15)
    if (preferences.selectedArea != 'All Areas' &&
        place.area.toLowerCase().contains(preferences.selectedArea.toLowerCase())) {
      score += 15.0;
    }

    // 6. Multi-day penalty: if already used in a previous day of the trip, heavy penalty (-80)
    if (isUsedGlobally) {
      score -= 80.0;
    }

    // 7. Recent recommendation history penalty (Weight: -15)
    if (_recentRecommendationHistory.contains(place.placeId)) {
      score -= 15.0;
    }

    return score;
  }

  /// Select a diverse subset of stops fitting the daily time budget
  static List<_ScoredPlace> _selectDiverseStops({
    required List<_ScoredPlace> scoredPlaces,
    required double availableHours,
    required String pace,
    required Set<String> globallyUsedIds,
    required int dayIndex,
    int? randomSeed,
  }) {
    // Determine target stop count based on duration and pace
    final int targetStopCount = switch (availableHours) {
      <= 2.5 => 2,
      <= 4.5 => pace == 'Relaxed' ? 2 : (pace == 'Fast' ? 4 : 3),
      <= 6.5 => pace == 'Relaxed' ? 3 : (pace == 'Fast' ? 5 : 4),
      _ => pace == 'Relaxed' ? 4 : (pace == 'Fast' ? 6 : 5),
    };

    final maxMinutes = (availableHours * 60).round();
    final chosen = <_ScoredPlace>[];
    int accumulatedMinutes = 0;

    // Filter available pool (prefer unused globally)
    var candidatePool = scoredPlaces.where((sp) => !globallyUsedIds.contains(sp.place.placeId)).toList();
    if (candidatePool.length < targetStopCount) {
      candidatePool = List.from(scoredPlaces);
    }

    // Controlled stochastic rotation: take top candidates and pick diverse subset
    final poolSize = min(candidatePool.length, targetStopCount * 2 + 2);
    final topPool = candidatePool.take(poolSize).toList();

    // Deterministic yet diverse seed based on dayIndex and current timestamp minute or explicit seed
    final rand = randomSeed != null ? Random(randomSeed + dayIndex * 17) : Random(DateTime.now().minute + dayIndex * 17);

    // Shuffle top pool slightly to guarantee variety for identical inputs
    final shuffledPool = List<_ScoredPlace>.from(topPool);
    if (shuffledPool.length > 2) {
      shuffledPool.shuffle(rand);
      // Re-sort with small jitter to maintain quality
      shuffledPool.sort((a, b) {
        final jitterA = a.score + (rand.nextDouble() * 4.0 - 2.0);
        final jitterB = b.score + (rand.nextDouble() * 4.0 - 2.0);
        return jitterB.compareTo(jitterA);
      });
    }

    final seenCategories = <String>{};

    for (final candidate in shuffledPool) {
      if (chosen.length >= targetStopCount) break;

      final estTravel = chosen.isEmpty ? 0 : 15;
      final stopDuration = candidate.place.estimatedVisitMinutes;
      final projectedTotal = accumulatedMinutes + stopDuration + estTravel;

      // Allow slight flexibility (up to 10% over) if need at least 2 stops
      if (projectedTotal <= maxMinutes || chosen.length < 2) {
        // Encourage category variety
        if (chosen.length > 1 && seenCategories.contains(candidate.place.category) && candidatePool.length > targetStopCount) {
          // Check if there is another unrepresented category
          final alternate = shuffledPool.firstWhere(
            (alt) => !chosen.contains(alt) && !seenCategories.contains(alt.place.category),
            orElse: () => candidate,
          );
          if (alternate != candidate) {
            chosen.add(alternate);
            seenCategories.add(alternate.place.category);
            accumulatedMinutes += alternate.place.estimatedVisitMinutes + estTravel;
            _recordHistory(alternate.place.placeId);
            continue;
          }
        }

        chosen.add(candidate);
        seenCategories.add(candidate.place.category);
        accumulatedMinutes = projectedTotal;
        _recordHistory(candidate.place.placeId);
      }
    }

    return chosen;
  }

  /// Construct scheduled stop models with sequential times and travel buffers
  static List<ItineraryStopModel> _buildScheduledStops({
    required List<_ScoredPlace> places,
    required int startMinutes,
    required int dayNumber,
    required String stateId,
    required String stateName,
  }) {
    final result = <ItineraryStopModel>[];
    int currentMinutes = startMinutes;

    for (var i = 0; i < places.length; i++) {
      final sp = places[i];
      final place = sp.place;
      final task = sp.task;

      // Calculate travel time from previous stop
      int travelTime = 0;
      if (i > 0) {
        final prevPlace = places[i - 1].place;
        travelTime = _estimateTravelMinutes(prevPlace, place);
      }
      currentMinutes += travelTime;

      final stopStart = currentMinutes;
      final stopEnd = stopStart + place.estimatedVisitMinutes;
      currentMinutes = stopEnd + 10; // 10 min rest/buffer

      final timeLabel = '${_formatMinutes(stopStart)} - ${_formatMinutes(stopEnd)}';

      final notes = <String>[];
      if (task != null) {
        notes.add('Cultural task available: ${task['title']} (+${task['rewardPoints']} pts)');
      }

      result.add(ItineraryStopModel(
        placeId: place.placeId,
        name: place.name,
        stateId: stateId,
        stateName: stateName,
        area: place.area,
        category: place.category,
        durationMinutes: place.estimatedVisitMinutes,
        sequence: i + 1,
        dayNumber: dayNumber,
        tags: place.interestTags,
        description: place.description,
        formattedAddress: place.formattedAddress,
        latitude: place.latitude,
        longitude: place.longitude,
        budgetLevel: place.estimatedBudget,
        openingHours: place.openingHours,
        publicRating: place.publicRating,
        imageUrl: place.primaryImageUrl,
        imageUrls: place.imageUrls,
        trustLabel: place.trustLabel,
        vendorId: place.vendorId,
        culturalTask: task,
        culturalTaskId: task?['id']?.toString() ?? place.culturalTaskId,
        culturalTaskTitle: task?['title']?.toString(),
        culturalTaskRewardPoints: (task?['rewardPoints'] as num?)?.toInt(),
        suggestedTimeLabel: timeLabel,
        suggestedStartMinutes: stopStart,
        suggestedEndMinutes: stopEnd,
        travelMinutesBefore: travelTime,
        scheduleNotes: notes,
        mealRole: place.category == 'Food' ? (stopStart >= 720 ? 'Lunch / Dinner' : 'Breakfast / Tea') : null,
        phone: place.phone,
        website: place.website,
      ));
    }

    return result;
  }

  static int _estimateTravelMinutes(PlaceModel from, PlaceModel to) {
    if (from.latitude == 0 || to.latitude == 0) return 15;
    // Haversine approximate distance
    final dLat = (to.latitude - from.latitude) * 111.0;
    final dLng = (to.longitude - from.longitude) * 111.0 * cos(from.latitude * pi / 180);
    final distanceKm = sqrt(dLat * dLat + dLng * dLng);

    if (distanceKm <= 1.5) return 8;
    if (distanceKm <= 5.0) return 15;
    if (distanceKm <= 15.0) return 25;
    return 35;
  }

  static String _formatMinutes(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final displayM = m.toString().padLeft(2, '0');
    return '$displayH:$displayM $period';
  }

  static List<String> _resolveDayInterests({
    required List<String> allInterests,
    required int dayIndex,
  }) {
    if (allInterests.length <= 1) return allInterests;
    // Rotate primary interest for variety across multi-day tours
    final rotated = <String>[];
    for (var i = 0; i < allInterests.length; i++) {
      rotated.add(allInterests[(i + dayIndex) % allInterests.length]);
    }
    return rotated;
  }

  static String _calculateDayBudget(List<ItineraryStopModel> stops, String preference) {
    int totalRM = 0;
    for (final s in stops) {
      if (s.category == 'Food') {
        totalRM += s.budgetLevel == 'High' ? 45 : (s.budgetLevel == 'Medium' ? 25 : 15);
      } else {
        totalRM += s.budgetLevel == 'High' ? 30 : (s.budgetLevel == 'Medium' ? 15 : 5);
      }
    }
    final minRM = max(20, totalRM - 15);
    final maxRM = totalRM + 25;
    return 'RM $minRM - $maxRM';
  }

  static void _recordHistory(String placeId) {
    _recentRecommendationHistory.add(placeId);
    if (_recentRecommendationHistory.length > 30) {
      _recentRecommendationHistory.removeAt(0);
    }
  }

  static void clearHistory() {
    _recentRecommendationHistory.clear();
  }
}

class _ScoredPlace {
  const _ScoredPlace({
    required this.place,
    required this.score,
    this.task,
  });

  final PlaceModel place;
  final double score;
  final Map<String, dynamic>? task;
}
