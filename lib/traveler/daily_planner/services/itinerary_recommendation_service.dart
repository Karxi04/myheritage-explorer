import 'dart:math';
import 'package:intl/intl.dart';
import '../models/itinerary_model.dart';
import '../models/place_model.dart';
import '../models/travel_preferences_model.dart';
import 'cultural_task_service.dart';
import 'meal_planning_service.dart';
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

  /// Generate stops for a single day fitting the available hours and meal rules
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
    final candidates = availablePlaces.where((p) => p.isActive).toList();
    if (candidates.isEmpty) return [];

    final hasFoodInterest = preferences.interests.contains('Food');
    final dailyAvailableMinutes = (preferences.availableHours * 60).round();
    final startMinutes = preferences.dailyStartMinutes;

    // Check eligible meal types for this specific day window
    final eligibleMeals = MealPlanningService.getEligibleMealTypes(
      startMinutes: startMinutes,
      availableMinutes: dailyAvailableMinutes,
      foodInterestSelected: hasFoodInterest,
    );

    final mealTracker = DayMealTracker();
    final daySelectedPlaces = <PlaceModel>[];
    final dayPlaceMealRoles = <String, String>{};
    final dayUsedPlaceIds = <String>{};

    int currentMinute = startMinutes;
    int remainingMinutes = dailyAvailableMinutes;
    PlaceModel? lastSelectedPlace;

    // Seeded Random for controlled variety
    final rand = randomSeed != null
        ? Random(randomSeed + dayIndex * 31)
        : Random(DateTime.now().minute + dayIndex * 31);

    // Score all candidates
    final scoredAll = <_ScoredPlace>[];
    for (final place in candidates) {
      final task = CulturalTaskService.matchTaskForPlace(place.toMap(), activeTasks);
      final baseScore = _calculateSuitabilityScore(
        place: place,
        preferences: preferences,
        dayInterests: dayInterests,
        hasCulturalTask: task != null,
        isUsedGlobally: globallyUsedIds.contains(place.placeId),
      );
      final score = baseScore + (rand.nextDouble() * 0.05);
      scoredAll.add(_ScoredPlace(place: place, score: score, task: task));
    }
    scoredAll.sort((a, b) => b.score.compareTo(a.score));

    // A. Check if Breakfast should be scheduled first
    if (eligibleMeals.contains('Breakfast') &&
        mealTracker.canServe('Breakfast') &&
        currentMinute <= MealPlanningService.breakfastEnd - 20) {
      final breakfastCandidates = scoredAll.where((sp) {
        if (globallyUsedIds.contains(sp.place.placeId) && scoredAll.length > 5) return false;
        return MealPlanningService.isFoodPlace(sp.place);
      }).toList();

      if (breakfastCandidates.isNotEmpty) {
        final bPlace = breakfastCandidates.first.place;
        final visitMin = min(bPlace.estimatedVisitMinutes, MealPlanningService.breakfastDefaultDuration);
        if (visitMin <= remainingMinutes) {
          daySelectedPlaces.add(bPlace.copyWith(estimatedVisitMinutes: visitMin));
          dayPlaceMealRoles[bPlace.placeId] = 'Breakfast';
          dayUsedPlaceIds.add(bPlace.placeId);
          mealTracker.markServed('Breakfast');
          lastSelectedPlace = bPlace;
          currentMinute += visitMin;
          remainingMinutes -= visitMin;
          _recordHistory(bPlace.placeId);
        }
      }
    }

    // B. Main scheduling loop for attractions and meals
    final seenCategories = <String>{};
    for (final p in daySelectedPlaces) {
      seenCategories.add(p.category);
    }

    while (remainingMinutes >= 30) {
      // 1. Check if we reached Lunch window
      if (eligibleMeals.contains('Lunch') &&
          mealTracker.canServe('Lunch') &&
          currentMinute >= MealPlanningService.lunchStart - 15 &&
          currentMinute <= MealPlanningService.lunchEnd) {
        final lunchCandidates = scoredAll.where((sp) {
          if (dayUsedPlaceIds.contains(sp.place.placeId)) return false;
          if (globallyUsedIds.contains(sp.place.placeId) && scoredAll.length > 6) return false;
          return MealPlanningService.isFoodPlace(sp.place);
        }).toList();

        if (lunchCandidates.isNotEmpty) {
          final lPlace = lunchCandidates.first.place;
          final travel = lastSelectedPlace != null
              ? MealPlanningService.estimateTravelMinutes(lastSelectedPlace, lPlace)
              : 0;
          final visitMin = min(lPlace.estimatedVisitMinutes, MealPlanningService.lunchDefaultDuration);
          final totalCost = visitMin + travel;

          if (totalCost <= remainingMinutes) {
            daySelectedPlaces.add(lPlace.copyWith(estimatedVisitMinutes: visitMin));
            dayPlaceMealRoles[lPlace.placeId] = 'Lunch';
            dayUsedPlaceIds.add(lPlace.placeId);
            mealTracker.markServed('Lunch');
            lastSelectedPlace = lPlace;
            currentMinute += totalCost;
            remainingMinutes -= totalCost;
            _recordHistory(lPlace.placeId);
            continue;
          }
        }
      }

      // 2. Check if we reached Dinner window
      if (eligibleMeals.contains('Dinner') &&
          mealTracker.canServe('Dinner') &&
          currentMinute >= MealPlanningService.dinnerStart - 15 &&
          currentMinute <= MealPlanningService.dinnerEnd) {
        final dinnerCandidates = scoredAll.where((sp) {
          if (dayUsedPlaceIds.contains(sp.place.placeId)) return false;
          if (globallyUsedIds.contains(sp.place.placeId) && scoredAll.length > 6) return false;
          return MealPlanningService.isFoodPlace(sp.place);
        }).toList();

        if (dinnerCandidates.isNotEmpty) {
          final dPlace = dinnerCandidates.first.place;
          final travel = lastSelectedPlace != null
              ? MealPlanningService.estimateTravelMinutes(lastSelectedPlace, dPlace)
              : 0;
          final visitMin = min(dPlace.estimatedVisitMinutes, MealPlanningService.dinnerDefaultDuration);
          final totalCost = visitMin + travel;

          if (totalCost <= remainingMinutes) {
            daySelectedPlaces.add(dPlace.copyWith(estimatedVisitMinutes: visitMin));
            dayPlaceMealRoles[dPlace.placeId] = 'Dinner';
            dayUsedPlaceIds.add(dPlace.placeId);
            mealTracker.markServed('Dinner');
            lastSelectedPlace = dPlace;
            currentMinute += totalCost;
            remainingMinutes -= totalCost;
            _recordHistory(dPlace.placeId);
            continue;
          }
        }
      }

      // 3. Find top attraction (non-food or general interest)
      final availableAttractions = scoredAll.where((sp) {
        if (dayUsedPlaceIds.contains(sp.place.placeId)) return false;
        if (globallyUsedIds.contains(sp.place.placeId) && scoredAll.length > daySelectedPlaces.length + 3) {
          return false;
        }
        // If food interest is not selected, skip food places
        if (!hasFoodInterest && MealPlanningService.isFoodPlace(sp.place)) return false;
        return true;
      }).toList();

      if (availableAttractions.isEmpty) break;

      // Select diverse attraction
      PlaceModel? bestFitPlace;
      int bestFitTravel = 0;
      int bestFitDuration = 0;

      for (final sp in availableAttractions) {
        final cand = sp.place;
        final travel = lastSelectedPlace != null
            ? MealPlanningService.estimateTravelMinutes(lastSelectedPlace, cand)
            : 0;
        final visitMin = cand.estimatedVisitMinutes;
        final totalCost = visitMin + travel;

        // Strict duration fitting check
        if (totalCost <= remainingMinutes) {
          // Diversity preference
          if (seenCategories.contains(cand.category) && availableAttractions.length > 2) {
            final unrepresented = availableAttractions.firstWhere(
              (alt) => !seenCategories.contains(alt.place.category) &&
                  (alt.place.estimatedVisitMinutes +
                          (lastSelectedPlace != null
                              ? MealPlanningService.estimateTravelMinutes(lastSelectedPlace, alt.place)
                              : 0)) <=
                      remainingMinutes,
              orElse: () => sp,
            );
            bestFitPlace = unrepresented.place;
            bestFitTravel = lastSelectedPlace != null
                ? MealPlanningService.estimateTravelMinutes(lastSelectedPlace, bestFitPlace)
                : 0;
            bestFitDuration = bestFitPlace.estimatedVisitMinutes;
            break;
          }

          bestFitPlace = cand;
          bestFitTravel = travel;
          bestFitDuration = visitMin;
          break;
        }
      }

      if (bestFitPlace == null) {
        // No more candidates fit within the remaining minutes
        break;
      }

      daySelectedPlaces.add(bestFitPlace);
      dayUsedPlaceIds.add(bestFitPlace.placeId);
      seenCategories.add(bestFitPlace.category);
      lastSelectedPlace = bestFitPlace;
      currentMinute += bestFitDuration + bestFitTravel;
      remainingMinutes -= (bestFitDuration + bestFitTravel);
      _recordHistory(bestFitPlace.placeId);
    }

    // 4. Arrange visiting sequence and schedule timeline
    return _buildScheduledStops(
      places: daySelectedPlaces,
      startMinutes: preferences.dailyStartMinutes,
      dayNumber: dayNumber,
      stateId: preferences.stateId,
      stateName: preferences.stateName,
      mealRoles: dayPlaceMealRoles,
      activeTasks: activeTasks,
    );
  }

  /// Add optional dessert stop to a generated day if remaining time permits
  static ItineraryDayModel? addDessertStopToDay({
    required ItineraryDayModel currentDay,
    required List<PlaceModel> availablePlaces,
    required double availableHours,
    required int startMinutes,
    required String stateId,
    required String stateName,
  }) {
    final dailyAvailableMin = (availableHours * 60).round();
    final usedMinutes = currentDay.usedScheduleMinutes;
    final remainingMin = dailyAvailableMin - usedMinutes;

    if (remainingMin < 35) {
      throw Exception('Not enough remaining time to add a dessert stop (requires at least 35 min).');
    }

    final alreadyUsedIds = currentDay.stops.map((s) => s.placeId).toSet();
    PlaceModel? lastStopPlace;
    if (currentDay.stops.isNotEmpty) {
      final lastStop = currentDay.stops.last;
      lastStopPlace = availablePlaces.firstWhere(
        (p) => p.placeId == lastStop.placeId,
        orElse: () => PlaceModel(
          placeId: lastStop.placeId,
          name: lastStop.name,
          stateId: stateId,
          stateName: stateName,
          area: lastStop.area,
          category: lastStop.category,
          latitude: lastStop.latitude,
          longitude: lastStop.longitude,
        ),
      );
    }

    final dessertCandidate = MealPlanningService.selectDessertCandidate(
      availablePlaces: availablePlaces,
      alreadyUsedIds: alreadyUsedIds,
      remainingMinutes: remainingMin,
      referenceLocation: lastStopPlace,
    );

    if (dessertCandidate == null) {
      throw Exception('Not enough remaining time to add a dessert stop.');
    }

    final updatedPlaces = currentDay.stops.map((s) {
      final base = availablePlaces.firstWhere(
        (p) => p.placeId == s.placeId,
        orElse: () => PlaceModel(
          placeId: s.placeId,
          name: s.name,
          stateId: stateId,
          stateName: stateName,
          area: s.area,
          category: s.category,
          estimatedVisitMinutes: s.durationMinutes,
          latitude: s.latitude,
          longitude: s.longitude,
          primaryImageUrl: s.imageUrl,
          publicRating: s.publicRating,
          trustLabel: s.trustLabel,
        ),
      );
      return base.copyWith(estimatedVisitMinutes: s.durationMinutes);
    }).toList();

    updatedPlaces.add(dessertCandidate);

    final mealRoles = <String, String>{};
    for (final s in currentDay.stops) {
      if (s.mealRole != null) mealRoles[s.placeId] = s.mealRole!;
    }
    mealRoles[dessertCandidate.placeId] = 'Dessert';

    final updatedStops = _buildScheduledStops(
      places: updatedPlaces,
      startMinutes: startMinutes,
      dayNumber: currentDay.dayNumber,
      stateId: stateId,
      stateName: stateName,
      mealRoles: mealRoles,
      activeTasks: const [],
    );

    int totalMinutes = 0;
    for (final s in updatedStops) {
      totalMinutes += s.durationMinutes + s.travelMinutesBefore;
    }

    return ItineraryDayModel(
      dayNumber: currentDay.dayNumber,
      date: currentDay.date,
      dateLabel: currentDay.dateLabel,
      stops: updatedStops,
      weather: currentDay.weather,
      totalEstimatedMinutes: totalMinutes,
      remainingMinutes: max(0, dailyAvailableMin - totalMinutes),
      budget: _calculateDayBudget(updatedStops, currentDay.budgetLevel),
      budgetLevel: currentDay.budgetLevel,
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

  /// Construct scheduled stop models with sequential times and exact travel legs
  static List<ItineraryStopModel> _buildScheduledStops({
    required List<PlaceModel> places,
    required int startMinutes,
    required int dayNumber,
    required String stateId,
    required String stateName,
    Map<String, String> mealRoles = const {},
    List<Map<String, dynamic>> activeTasks = const [],
  }) {
    final result = <ItineraryStopModel>[];
    int currentMinutes = startMinutes;

    for (var i = 0; i < places.length; i++) {
      final place = places[i];
      final task = CulturalTaskService.matchTaskForPlace(place.toMap(), activeTasks);

      // Travel time from previous stop
      int travelTime = 0;
      if (i > 0) {
        final prevPlace = places[i - 1];
        travelTime = MealPlanningService.estimateTravelMinutes(prevPlace, place);
      }
      currentMinutes += travelTime;

      final stopStart = currentMinutes;
      final stopEnd = stopStart + place.estimatedVisitMinutes;
      currentMinutes = stopEnd; // Sequential exact scheduling (no phantom gap jumps)

      final timeLabel = '${_formatMinutes(stopStart)} - ${_formatMinutes(stopEnd)}';

      final notes = <String>[];
      if (task != null) {
        notes.add('Cultural task available: ${task['title']} (+${task['rewardPoints']} pts)');
      }

      final mealRole = mealRoles[place.placeId] ??
          (place.category == 'Food' ? MealPlanningService.getMealRoleForMinute(stopStart) : null);

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
        mealRole: mealRole,
        phone: place.phone,
        website: place.website,
      ));
    }

    return result;
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
