import 'dart:math';
import 'package:intl/intl.dart';
import '../models/itinerary_model.dart';
import '../models/place_model.dart';
import '../models/travel_preferences_model.dart';
import 'cultural_task_service.dart';
import 'malaysia_location_service.dart';
import 'meal_planning_service.dart';
import 'place_repository.dart';

/// Central recommendation engine for Malaysian Daily Planner itineraries
class ItineraryRecommendationService {
  const ItineraryRecommendationService._();

  static final List<String> _recentRecommendationHistory = [];

  static const Set<String> _mainlandAreas = {
    'butterworth',
    'bukit mertajam',
    'nibong tebal',
    'seberang perai',
    'perai',
    'seberang jaya',
    'raja uda',
    'chai leng park',
  };

  /// Geographically cluster selected areas into day-groups using average linkage distance
  static List<List<String>> _clusterAreasForDays({
    required List<String> selectedAreas,
    required int numberOfDays,
    required List<PlaceModel> places,
  }) {
    if (selectedAreas.isEmpty) {
      return List.generate(numberOfDays, (_) => <String>[]);
    }
    if (numberOfDays <= 1) {
      return [List<String>.from(selectedAreas)];
    }

    // Compute centroid coordinates for each area from places
    final centroids = <String, (double, double)>{};
    for (final area in selectedAreas) {
      final areaKey = area.toLowerCase();
      final matchingPlaces = places.where((p) =>
          p.area.toLowerCase().contains(areaKey) ||
          areaKey.contains(p.area.toLowerCase())).toList();
      if (matchingPlaces.isNotEmpty) {
        final avgLat = matchingPlaces.fold<double>(0, (s, p) => s + p.latitude) / matchingPlaces.length;
        final avgLng = matchingPlaces.fold<double>(0, (s, p) => s + p.longitude) / matchingPlaces.length;
        centroids[area] = (avgLat, avgLng);
      } else {
        centroids[area] = (5.4164, 100.3327); // Default
      }
    }

    double geoDist(String a1, String a2) {
      final c1 = centroids[a1] ?? (5.4164, 100.3327);
      final c2 = centroids[a2] ?? (5.4164, 100.3327);
      final dLat = (c1.$1 - c2.$1) * 111.0;
      final dLng = (c1.$2 - c2.$2) * 111.0 * cos(c1.$1 * pi / 180);
      var dist = sqrt(dLat * dLat + dLng * dLng);

      // Mainland vs Island bridge crossing penalty
      final isM1 = _mainlandAreas.any((m) => a1.toLowerCase().contains(m));
      final isM2 = _mainlandAreas.any((m) => a2.toLowerCase().contains(m));
      if (isM1 != isM2) {
        dist += 20.0;
      }
      return dist;
    }

    // Agglomerative clustering with average linkage
    final clusters = selectedAreas.map((a) => [a]).toList();

    while (clusters.length > numberOfDays) {
      int? bestI, bestJ;
      double minDist = double.infinity;

      for (var i = 0; i < clusters.length; i++) {
        for (var j = i + 1; j < clusters.length; j++) {
          double totalDist = 0.0;
          for (final a1 in clusters[i]) {
            for (final a2 in clusters[j]) {
              totalDist += geoDist(a1, a2);
            }
          }
          final avgDist = totalDist / (clusters[i].length * clusters[j].length);
          if (avgDist < minDist) {
            minDist = avgDist;
            bestI = i;
            bestJ = j;
          }
        }
      }

      if (bestI != null && bestJ != null) {
        clusters[bestI].addAll(clusters[bestJ]);
        clusters.removeAt(bestJ);
      } else {
        break;
      }
    }

    while (clusters.length < numberOfDays) {
      clusters.add(<String>[]);
    }

    return clusters;
  }

  /// Generate a complete multi-day or single-day itinerary based on preferences
  static Future<ItineraryModel> generateItinerary({
    required TravelPreferences preferences,
    String userId = '',
    List<PlaceModel>? candidatePlaces,
    List<Map<String, dynamic>>? culturalTasks,
    Set<String>? previouslyVisitedPlaceIds,
    Set<String>? recentlyRecommendedPlaceIds,
    int? randomSeed,
  }) async {
    // 1. Strict validation
    final validationError = preferences.validate(allowPastDates: true);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    // 2. Fetch or use provided places strictly scoped to state
    List<PlaceModel> places;
    if (candidatePlaces != null && candidatePlaces.isNotEmpty) {
      places = candidatePlaces.where((p) => p.stateId == preferences.stateId).toList();
    } else {
      places = await PlaceRepository.getPlacesForState(preferences.stateId);
      if (places.isEmpty) {
        places = PlaceRepository.getHeritageCatalogue()
            .where((p) => p.stateId == preferences.stateId)
            .toList();
      }
    }

    if (places.isEmpty) {
      throw Exception(
        'No places available for ${preferences.stateName}. Please ensure places data is seeded.',
      );
    }

    // Filter places by area selection
    final scopedPlaces = _filterPlacesForSelectedArea(places, preferences);
    if (scopedPlaces.isEmpty) {
      throw Exception(
        'No places found matching "${preferences.selectedArea}" in ${preferences.stateName}.',
      );
    }

    // Fetch active cultural tasks
    List<Map<String, dynamic>> activeTasks = culturalTasks ?? const [];
    if (culturalTasks == null) {
      try {
        activeTasks = await CulturalTaskService.fetchActiveTasks(stateId: preferences.stateId);
      } catch (_) {
        activeTasks = const [];
      }
    }

    final totalDays = preferences.numberOfDays;
    final globalSelectedIds = <String>{
      ...?previouslyVisitedPlaceIds,
      ...?recentlyRecommendedPlaceIds,
    };

    final generatedDays = <ItineraryDayModel>[];
    final allStops = <ItineraryStopModel>[];

    // Compute area clusters per day for multi-day / multi-area itineraries
    final dayAreaClusters = preferences.isMultiAreaMode
        ? _clusterAreasForDays(
            selectedAreas: preferences.selectedAreas,
            numberOfDays: totalDays,
            places: scopedPlaces,
          )
        : List.generate(totalDays, (_) => [preferences.selectedArea]);

    final daySchedules = preferences.getEffectiveDaySchedules();

    for (var dayIdx = 0; dayIdx < totalDays; dayIdx++) {
      final dayNumber = dayIdx + 1;
      final daySchedule = daySchedules[dayIdx];
      final dayDate = daySchedule.date;
      final dateLabel = 'Day $dayNumber (${DateFormat("d MMM").format(dayDate)})';

      // Day focus rotation for rich variety across multi-day trips
      final dayInterests = _resolveDayInterests(
        allInterests: preferences.interests,
        dayIndex: dayIdx,
      );

      final assignedAreas = dayAreaClusters[dayIdx];
      final dayPrimaryArea = assignedAreas.isNotEmpty ? assignedAreas.first : null;

      final dayStops = _generateSingleDay(
        dayNumber: dayNumber,
        preferences: preferences,
        availablePlaces: scopedPlaces,
        activeTasks: activeTasks,
        dayInterests: dayInterests,
        globallyUsedIds: globalSelectedIds,
        dayIndex: dayIdx,
        dayStartMinutes: daySchedule.startMinutes,
        dayAvailableHours: daySchedule.availableHours,
        dayAssignedAreas: assignedAreas,
        dayPrimaryArea: dayPrimaryArea,
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
      final availableTotalMinutes = (daySchedule.availableHours * 60).round();
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
        startTime: daySchedule.startTimeLabel,
        startMinutes: daySchedule.startMinutes,
        availableHours: daySchedule.availableHours,
        availableMinutes: daySchedule.availableMinutes,
        endTime: daySchedule.endTimeLabel,
      ));
    }

    final tripTitle = totalDays > 1
        ? '${preferences.stateName} ($totalDays-Day Tour)'
        : (preferences.isMultiAreaMode
            ? '${preferences.stateName} Multi-Area Tour'
            : '${preferences.selectedArea} Cultural Day');

    // Warning message for limited hours / closed places
    String? warningMessage;
    if (allStops.isEmpty) {
      warningMessage = 'Limited places are available during your selected travel hours. Try changing your start time or duration.';
    }

    // Area inclusion note when not all selected areas fit due to time constraints
    String? areaInclusionNote;
    if (preferences.isMultiAreaMode && preferences.selectedAreas.isNotEmpty && allStops.isNotEmpty) {
      final visitedAreaKeys = allStops.map((s) => _areaKey(s.area)).toSet();
      final includedAreas = preferences.selectedAreas.where((a) {
        final aKey = _areaKey(a);
        return visitedAreaKeys.any((v) => v.contains(aKey) || aKey.contains(v));
      }).toList();

      if (includedAreas.length < preferences.selectedAreas.length) {
        areaInclusionNote = '${includedAreas.length} of your ${preferences.selectedAreas.length} selected areas were included based on your available travel time.';
      }
    }

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
      warningMessage: warningMessage,
      areaInclusionNote: areaInclusionNote,
      status: 'generated',
    );
  }

  /// Generate stops for a single day fitting the available hours, opening times, and meal rules
  static List<ItineraryStopModel> _generateSingleDay({
    required int dayNumber,
    required TravelPreferences preferences,
    required List<PlaceModel> availablePlaces,
    required List<Map<String, dynamic>> activeTasks,
    required List<String> dayInterests,
    required Set<String> globallyUsedIds,
    required int dayIndex,
    int? dayStartMinutes,
    double? dayAvailableHours,
    List<String> dayAssignedAreas = const [],
    String? dayPrimaryArea,
    int? randomSeed,
  }) {
    final startMinutes = dayStartMinutes ?? preferences.dailyStartMinutes;
    final dailyAvailableMinutes = ((dayAvailableHours ?? preferences.availableHours) * 60).round();
    final endMinutes = startMinutes + dailyAvailableMinutes;

    // Filter places strictly belonging to state, active, and open during travel window
    final candidates = availablePlaces.where((p) {
      if (!p.isActive) return false;
      return p.isOpenDuring(startMinutes, endMinutes);
    }).toList();

    if (candidates.isEmpty) return [];

    final hasFoodInterest = preferences.interests.contains('Food');

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
        dayAssignedAreas: dayAssignedAreas,
        dayPrimaryArea: dayPrimaryArea,
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
        if (!sp.place.isOpenAtMinute(currentMinute)) return false;
        return MealPlanningService.isFoodPlace(sp.place);
      }).toList();

      // Sort by assigned areas or primary area
      if (dayAssignedAreas.isNotEmpty) {
        breakfastCandidates.sort((a, b) {
          final aMatch = dayAssignedAreas.any((area) => a.place.area.toLowerCase().contains(area.toLowerCase())) ? 0 : 1;
          final bMatch = dayAssignedAreas.any((area) => b.place.area.toLowerCase().contains(area.toLowerCase())) ? 0 : 1;
          if (aMatch != bMatch) return aMatch.compareTo(bMatch);
          return b.score.compareTo(a.score);
        });
      }

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

    while (remainingMinutes >= 20) {
      // 1. Check if we reached Lunch window
      if (eligibleMeals.contains('Lunch') &&
          mealTracker.canServe('Lunch') &&
          currentMinute >= MealPlanningService.lunchStart - 15 &&
          currentMinute <= MealPlanningService.lunchEnd) {
        final lunchCandidates = scoredAll.where((sp) {
          if (dayUsedPlaceIds.contains(sp.place.placeId)) return false;
          if (globallyUsedIds.contains(sp.place.placeId) && scoredAll.length > 6) return false;
          if (!sp.place.isOpenAtMinute(currentMinute)) return false;
          return MealPlanningService.isFoodPlace(sp.place);
        }).toList();

        if (lunchCandidates.isNotEmpty) {
          // Sort lunch candidates prioritizing local vendors in the active area
          if (lastSelectedPlace != null) {
            final lsp = lastSelectedPlace;
            lunchCandidates.sort((a, b) {
              final aSame = a.place.area.toLowerCase() == lsp.area.toLowerCase() ? 0 : 1;
              final bSame = b.place.area.toLowerCase() == lsp.area.toLowerCase() ? 0 : 1;
              if (aSame != bSame) return aSame.compareTo(bSame);
              final tA = MealPlanningService.estimateTravelMinutes(lsp, a.place);
              final tB = MealPlanningService.estimateTravelMinutes(lsp, b.place);
              return tA.compareTo(tB);
            });
          }

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
          if (!sp.place.isOpenAtMinute(currentMinute)) return false;
          return MealPlanningService.isFoodPlace(sp.place);
        }).toList();

        if (dinnerCandidates.isNotEmpty) {
          // Sort dinner candidates prioritizing local vendors in the active area
          if (lastSelectedPlace != null) {
            final lsp = lastSelectedPlace;
            dinnerCandidates.sort((a, b) {
              final aSame = a.place.area.toLowerCase() == lsp.area.toLowerCase() ? 0 : 1;
              final bSame = b.place.area.toLowerCase() == lsp.area.toLowerCase() ? 0 : 1;
              if (aSame != bSame) return aSame.compareTo(bSame);
              final tA = MealPlanningService.estimateTravelMinutes(lsp, a.place);
              final tB = MealPlanningService.estimateTravelMinutes(lsp, b.place);
              return tA.compareTo(tB);
            });
          }

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
        if (!hasFoodInterest && MealPlanningService.isFoodPlace(sp.place)) return false;
        if (!sp.place.isOpenAtMinute(currentMinute)) return false;
        return true;
      }).toList();

      if (availableAttractions.isEmpty) break;

      // Select diverse attraction along continuous geographic corridor
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
      startMinutes: startMinutes,
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
    String selectedArea = '',
  }) {
    final localPlaces = selectedArea.trim().isEmpty
        ? availablePlaces
        : availablePlaces
            .where((place) => _placeMatchesSelectedArea(
                  place,
                  selectedArea: selectedArea,
                  stateId: stateId,
                ))
            .toList();
    final effectiveAvailHours = currentDay.availableHours > 0 ? currentDay.availableHours : availableHours;
    final dailyAvailableMin = (effectiveAvailHours * 60).round();
    final usedMinutes = currentDay.usedScheduleMinutes;
    final remainingMin = dailyAvailableMin - usedMinutes;

    if (remainingMin < 35) {
      throw Exception('Not enough remaining time to add a dessert stop (requires at least 35 min).');
    }

    final alreadyUsedIds = currentDay.stops.map((s) => s.placeId).toSet();
    PlaceModel? lastStopPlace;
    if (currentDay.stops.isNotEmpty) {
      final lastStop = currentDay.stops.last;
      lastStopPlace = PlaceModel(
        placeId: lastStop.placeId,
        name: lastStop.name,
        stateId: lastStop.stateId,
        stateName: lastStop.stateName,
        area: lastStop.area,
        category: lastStop.category,
        latitude: lastStop.latitude,
        longitude: lastStop.longitude,
      );
    }

    final dessertCandidate = MealPlanningService.selectDessertCandidate(
      availablePlaces: localPlaces,
      alreadyUsedIds: alreadyUsedIds,
      remainingMinutes: remainingMin,
      referenceLocation: lastStopPlace,
    );

    if (dessertCandidate == null) {
      throw Exception('No suitable dessert or tea vendor available that fits the schedule.');
    }

    final updatedPlaces = currentDay.stops.map<PlaceModel>((s) => PlaceModel(
      placeId: s.placeId,
      name: s.name,
      stateId: s.stateId,
      stateName: s.stateName,
      area: s.area,
      category: s.category,
      interestTags: s.tags,
      description: s.description,
      formattedAddress: s.formattedAddress,
      latitude: s.latitude,
      longitude: s.longitude,
      estimatedVisitMinutes: s.durationMinutes,
      estimatedBudget: s.budgetLevel,
      openingHours: s.openingHours,
      publicRating: s.publicRating,
      primaryImageUrl: s.imageUrl,
      imageUrls: s.imageUrls,
      trustLabel: s.trustLabel,
      vendorId: s.vendorId,
      culturalTaskId: s.culturalTaskId,
      culturalTask: s.culturalTask,
      phone: s.phone,
      website: s.website,
      mealRole: s.mealRole,
    )).toList();

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

  /// Alias for backward compatibility
  static ItineraryDayModel? attachDessertToDay({
    required ItineraryDayModel currentDay,
    required List<PlaceModel> availablePlaces,
    required String stateId,
    required String stateName,
    required double dailyAvailableHours,
    required int startMinutes,
  }) => addDessertStopToDay(
    currentDay: currentDay,
    availablePlaces: availablePlaces,
    availableHours: dailyAvailableHours,
    startMinutes: startMinutes,
    stateId: stateId,
    stateName: stateName,
  );

  /// Compute suitability score based on weighted factors
  static double _calculateSuitabilityScore({
    required PlaceModel place,
    required TravelPreferences preferences,
    required List<String> dayInterests,
    required bool hasCulturalTask,
    required bool isUsedGlobally,
    List<String> dayAssignedAreas = const [],
    String? dayPrimaryArea,
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

    // 4. Budget match (Weight: 10)
    if (preferences.budget.toLowerCase() == place.estimatedBudget.toLowerCase()) {
      score += 10.0;
    }

    // 5. Area proximity & Day cluster focus (Weight: 25)
    final pAreaKey = _areaKey(place.area);
    if (dayAssignedAreas.isNotEmpty) {
      final isAssigned = dayAssignedAreas.any((a) {
        final aKey = _areaKey(a);
        return pAreaKey.contains(aKey) || aKey.contains(pAreaKey);
      });
      if (isAssigned) {
        score += 25.0;
      } else {
        score -= 25.0;
      }
    } else if (dayPrimaryArea != null && dayPrimaryArea.isNotEmpty) {
      final targetKey = _areaKey(dayPrimaryArea);
      if (pAreaKey.contains(targetKey) || targetKey.contains(pAreaKey)) {
        score += 20.0;
      }
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
      currentMinutes = stopEnd; // Sequential exact scheduling

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

  static List<PlaceModel> _filterPlacesForSelectedArea(
    List<PlaceModel> places,
    TravelPreferences preferences,
  ) {
    if (preferences.isMultiAreaMode) {
      final selectedAreas = preferences.selectedAreas;
      if (selectedAreas.isEmpty || selectedAreas.any(_isBroadAreaChoice)) {
        return places;
      }
      return places.where((place) {
        return selectedAreas.any((area) => _placeMatchesSelectedArea(
          place,
          selectedArea: area,
          stateId: preferences.stateId,
          allowedAreas: selectedAreas,
        ));
      }).toList();
    }

    final selectedArea = preferences.selectedArea.trim();
    if (_isBroadAreaChoice(selectedArea)) return places;

    return places
        .where(
          (place) => _placeMatchesSelectedArea(
            place,
            selectedArea: selectedArea,
            stateId: preferences.stateId,
          ),
        )
        .toList();
  }

  static bool _placeMatchesSelectedArea(
    PlaceModel place, {
    required String selectedArea,
    required String stateId,
    List<String> allowedAreas = const [],
  }) {
    final selectedAliases = _areaAliases(selectedArea);
    if (selectedAliases.isEmpty) return true;

    final placeAreaKey = _areaKey(place.area);
    final addressKey = _areaKey(place.formattedAddress);
    final nameKey = _areaKey(place.name);

    final allAllowedAliases = <String>{...selectedAliases};
    for (final a in allowedAreas) {
      allAllowedAliases.addAll(_areaAliases(a));
    }

    if (_mentionsOtherKnownArea(
      addressKey,
      selectedAliases: allAllowedAliases,
      stateId: stateId,
    )) {
      return false;
    }

    final combinedKey = '$placeAreaKey $addressKey $nameKey';
    return selectedAliases.any(
      (alias) => _containsAreaTerm(combinedKey, alias),
    );
  }

  static bool _mentionsOtherKnownArea(
    String valueKey, {
    required Set<String> selectedAliases,
    required String stateId,
  }) {
    if (valueKey.isEmpty) return false;

    final knownAreas = _knownAreaNamesForState(stateId);
    for (final area in knownAreas) {
      final aliases = _areaAliases(area);
      if (aliases.any(selectedAliases.contains)) continue;
      if (aliases.any((alias) => _containsAreaTerm(valueKey, alias))) {
        return true;
      }
    }
    return false;
  }

  static List<String> _knownAreaNamesForState(String stateId) {
    final normalizedStateId = MalaysiaLocationService.normalizeStateId(stateId);
    final state = MalaysiaLocationService.defaultStates.firstWhere(
      (item) => item.id == normalizedStateId,
      orElse: () => const MalaysianStateItem(id: '', name: '', areas: []),
    );
    final areas = <String>{...state.areas};
    if (normalizedStateId == 'penang') {
      areas.addAll(const ['Air Itam', 'Ayer Itam', 'Penang Hill']);
    }
    return areas.toList();
  }

  static bool _isBroadAreaChoice(String value) {
    final key = _areaKey(value);
    return key.isEmpty ||
        key == 'all' ||
        key == 'all areas' ||
        key == 'all places' ||
        key == 'statewide' ||
        key == 'malaysia';
  }

  static Set<String> _areaAliases(String value) {
    final key = _areaKey(value);
    if (key.isEmpty) return const {};

    final aliases = <String>{key};
    final withoutParentheses = _areaKey(
      value.replaceAll(RegExp(r'\([^)]*\)'), ' '),
    );
    if (withoutParentheses.isNotEmpty) aliases.add(withoutParentheses);

    for (final part in value.split(RegExp(r'[/&,]'))) {
      final partKey = _areaKey(part);
      if (partKey.length > 2) aliases.add(partKey);
    }

    switch (key) {
      case 'george town':
        aliases.addAll(const [
          'georgetown',
          'unesco core',
          'armenian street',
          'lebuh armenian',
          'love lane',
          'chulia street',
          'little india',
          'carnarvon',
          'campbell street',
          'church street',
          'lebuh pantai',
          'beach street',
          'weld quay',
          'jalan penang',
        ]);
        break;
      case 'air itam':
      case 'ayer itam':
      case 'penang hill':
        aliases.addAll(const [
          'air itam',
          'ayer itam',
          'penang hill',
          'bukit bendera',
          'kek lok si',
        ]);
        break;
      case 'batu ferringhi':
      case 'batu feringghi':
        aliases.addAll(const [
          'batu ferringhi',
          'batu feringghi',
          'ferringhi',
          'feringghi',
          'moonlight bay',
          'miami beach',
        ]);
        break;
      case 'tanjung bungah':
      case 'tanjung bunga':
        aliases.addAll(const [
          'tanjung bungah',
          'tanjung bunga',
          'floating mosque',
          'masjid terapung',
          'avatar secret garden',
        ]);
        break;
      case 'tanjung tokong':
        aliases.addAll(const [
          'tanjung tokong',
          'straits quay',
          'tesco tg tokong',
        ]);
        break;
      case 'pulau tikus':
        aliases.addAll(const [
          'pulau tikus',
          'wat chayamangkalaram',
          'dhammikarama',
        ]);
        break;
      case 'bukit mertajam':
        aliases.addAll(const [
          'bukit mertajam',
          'bm',
          'mertajam',
          'cherok tokun',
          'st anne',
          'mengkuang',
        ]);
        break;
      case 'butterworth':
        aliases.addAll(const [
          'butterworth',
          'seberang jaya',
          'chai leng park',
          'raja uda',
          'tow boo kong',
          'frog hill',
          'robina',
        ]);
        break;
      case 'balik pulau':
        aliases.addAll(const [
          'balik pulau',
          'sungai pinang',
          'sungai rusa',
          'audi dream farm',
          'bao sheng',
        ]);
        break;
      case 'bayan lepas':
        aliases.addAll(const [
          'bayan lepas',
          'batu maung',
          'snake temple',
          'war museum',
          'teluk tempoyak',
        ]);
        break;
      case 'teluk bahang':
        aliases.addAll(const [
          'teluk bahang',
          'taman negara pulau pinang',
          'tropical spice garden',
          'entopia',
          'escape',
        ]);
        break;
      case 'nibong tebal':
        aliases.addAll(const [
          'nibong tebal',
          'sungai kerian',
          'bukit panchor',
        ]);
        break;
      case 'melaka city bandar hilir':
        aliases.addAll(const ['melaka city', 'bandar hilir']);
        break;
      case 'jonker walk heritage core':
        aliases.addAll(const ['jonker walk', 'jonker']);
        break;
      case 'klcc city centre':
        aliases.addAll(const ['klcc', 'city centre', 'kuala lumpur city centre']);
        break;
      case 'chinatown petaling street':
        aliases.addAll(const ['chinatown', 'petaling street']);
        break;
      case 'brickfields little india':
        aliases.addAll(const ['brickfields', 'little india']);
        break;
      case 'kundasang ranau':
        aliases.addAll(const ['kundasang', 'ranau']);
        break;
      case 'langkawi kuah cenang':
        aliases.addAll(const ['langkawi', 'kuah', 'cenang']);
        break;
      case 'kuching waterfront old town':
        aliases.addAll(const ['kuching', 'kuching waterfront', 'old town']);
        break;
      case 'bau wind caves':
        aliases.addAll(const ['bau', 'wind caves']);
        break;
    }

    return aliases;
  }

  static bool _containsAreaTerm(String valueKey, String term) {
    final termKey = _areaKey(term);
    if (valueKey.isEmpty || termKey.isEmpty) return false;
    if (termKey.length <= 2) {
      return valueKey.split(' ').contains(termKey);
    }
    return valueKey == termKey || valueKey.contains(termKey);
  }

  static String _areaKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
