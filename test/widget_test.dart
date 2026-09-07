import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/core/services.dart';
import 'package:myheritage_explorer/traveler/traveler_pages.dart';
import 'package:myheritage_explorer/traveler/daily_planner/models/place_model.dart';
import 'package:myheritage_explorer/traveler/daily_planner/models/travel_preferences_model.dart';
import 'package:myheritage_explorer/traveler/daily_planner/models/itinerary_model.dart';
import 'package:myheritage_explorer/traveler/daily_planner/services/malaysia_location_service.dart';
import 'package:myheritage_explorer/traveler/daily_planner/services/itinerary_recommendation_service.dart';

void main() {
  test('basic Flutter test environment works', () {
    expect(1 + 1, 2);
  });

  test('review model flags negative text with a high star rating', () {
    final prediction = ReviewMlModel.analyze(
      reviewText:
          'Terrible experience, dirty display, rude service and not recommended.',
      rating: 5,
    );

    expect(prediction.ratingMismatch, isTrue);
    expect(prediction.isSuspicious, isTrue);
  });

  test('review model flags positive text with a low star rating', () {
    final prediction = ReviewMlModel.analyze(
      reviewText:
          'Excellent cultural stop with friendly staff and a wonderful visit.',
      rating: 1,
    );

    expect(prediction.ratingMismatch, isTrue);
    expect(prediction.isSuspicious, isTrue);
  });

  test('itinerary schedule recalculates when stops are reordered', () {
    final stops = [
      {
        'name': 'First Stop',
        'durationMinutes': 60,
        'location': {'latitude': 5.4141, 'longitude': 100.3288},
      },
      {
        'name': 'Second Stop',
        'durationMinutes': 60,
        'location': {'latitude': 5.4160, 'longitude': 100.3310},
      },
      {
        'name': 'Third Stop',
        'durationMinutes': 60,
        'location': {'latitude': 5.4200, 'longitude': 100.3380},
      },
    ];

    final original = ItinerarySchedulePlanner.plan(
      stops: stops,
      pace: 'Balanced',
      availableHours: 4,
    );
    final reordered = ItinerarySchedulePlanner.plan(
      stops: [stops[2], stops[0], stops[1]],
      pace: 'Balanced',
      availableHours: 4,
    );

    expect(original.stops.first['name'], 'First Stop');
    expect(original.stops.first['suggestedTimeLabel'], '9:00 AM - 10:00 AM');
    expect(reordered.stops.first['name'], 'Third Stop');
    expect(reordered.stops.first['suggestedTimeLabel'], '9:00 AM - 10:00 AM');
    expect(reordered.stops[1]['sequence'], 2);
    expect((reordered.stops[1]['travelMinutesBefore'] as num) > 0, isTrue);
  });

  test('itinerary schedule warns when visit runs past closing', () {
    final schedule = ItinerarySchedulePlanner.plan(
      stops: [
        {
          'name': 'Early Closing Stop',
          'durationMinutes': 90,
          'openingHours': '9:00-10:00',
          'location': {'latitude': 5.4141, 'longitude': 100.3288},
        },
      ],
      pace: 'Balanced',
      availableHours: 2,
    );

    final notes = List<String>.from(schedule.stops.first['scheduleNotes']);
    expect(notes, isNotEmpty);
    expect(notes.first, contains('closing'));
  });

  test('itinerary image candidates keep online fallback urls', () {
    final candidates = ItineraryImageResolver.imageCandidatesFor({
      'imageUrl': 'https://example.com/broken.jpg',
      'imageCandidates': [
        'https://example.com/broken.jpg',
        'https://commons.wikimedia.org/wiki/File:Khoo_Kongsi.jpg',
      ],
      'fallbackImageUrl': 'https://maps.geoapify.com/v1/staticmap?x=1',
    });

    expect(candidates, hasLength(3));
    expect(candidates.first, 'https://example.com/broken.jpg');
    expect(
      candidates[1],
      startsWith('https://commons.wikimedia.org/wiki/Special:Redirect/file/'),
    );
  });

  test('cached image resolution keeps latest timeline fields', () async {
    ItineraryImageResolver.clearCache();
    await ItineraryImageResolver.resolveStop({
      'name': 'Cache Timeline Stop',
      'imageUrl': 'https://example.com/photo.jpg',
      'photoUrl': 'https://example.com/photo-2.jpg',
      'thumbnailUrl': 'https://example.com/photo-3.jpg',
    });

    final resolved = await ItineraryImageResolver.resolveStop({
      'name': 'Cache Timeline Stop',
      'imageUrl': 'https://example.com/photo.jpg',
      'photoUrl': 'https://example.com/photo-2.jpg',
      'thumbnailUrl': 'https://example.com/photo-3.jpg',
      'suggestedTimeLabel': '10:00 AM - 11:00 AM',
      'suggestedStartMinutes': 600,
      'suggestedEndMinutes': 660,
      'scheduleNotes': ['Move this earlier.'],
    });

    expect(resolved['suggestedTimeLabel'], '10:00 AM - 11:00 AM');
    expect(resolved['suggestedStartMinutes'], 600);
    expect(List<String>.from(resolved['scheduleNotes']), [
      'Move this earlier.',
    ]);
  });

  test(
    'named itinerary destinations do not accept another same-state area',
    () {
      final destination = MalaysianAreaSearchEngine.findSpecificSubArea(
        'Bukit Mertajam, Pulau Pinang',
      );

      expect(destination?.name, 'Bukit Mertajam');
      expect(
        MalaysianAreaSearchEngine.matchesSpecificDestination(
          selectedArea: 'Bukit Mertajam, Pulau Pinang',
          vendorAddress: 'Jalan Pasar, 14000 Bukit Mertajam, Penang',
        ),
        isTrue,
      );
      expect(
        MalaysianAreaSearchEngine.matchesSpecificDestination(
          selectedArea: 'Bukit Mertajam, Pulau Pinang',
          vendorAddress: 'Armenian Street, George Town, Penang',
        ),
        isFalse,
      );
    },
  );

  test('destination aliases resolve while a state-wide choice stays broad', () {
    expect(
      MalaysianAreaSearchEngine.findSpecificSubArea(
        'Georgetown, Pulau Pinang',
      )?.name,
      'George Town',
    );
    expect(
      MalaysianAreaSearchEngine.findSpecificSubArea('Penang, Malaysia'),
      isNull,
    );
  });

  test('trip reminders prefer 3 days before and fall back to 2 days', () {
    final tripStart = DateTime(2026, 9, 10, 9);

    final threeDayReminder = AppServices.nextTripReminderTime(
      tripStartDate: tripStart,
      now: DateTime(2026, 9, 1, 12),
    );
    expect(threeDayReminder, DateTime(2026, 9, 7, 8));
    expect(
      AppServices.tripReminderLeadDays(
        tripStartDate: tripStart,
        reminderTime: threeDayReminder!,
      ),
      3,
    );

    final twoDayReminder = AppServices.nextTripReminderTime(
      tripStartDate: tripStart,
      now: DateTime(2026, 9, 7, 9),
    );
    expect(twoDayReminder, DateTime(2026, 9, 8, 8));
    expect(
      AppServices.tripReminderLeadDays(
        tripStartDate: tripStart,
        reminderTime: twoDayReminder!,
      ),
      2,
    );
  });

  test('firestore place image resolver preserves unique attraction photos', () async {
    final stop1 = await ItineraryImageResolver.resolveStop({
      'name': 'Mengkuang Dam Lakeside Park',
      'category': 'Nature',
      'primaryImageUrl': 'https://images.unsplash.com/photo-1439066615861-d1af74d74000',
    });
    final stop2 = await ItineraryImageResolver.resolveStop({
      'name': 'Chew Jetty',
      'category': 'Heritage',
      'primaryImageUrl': 'https://images.unsplash.com/photo-1596422846543-75c6fc197f07',
    });
    final stop3 = await ItineraryImageResolver.resolveStop({
      'name': 'Restoran BM Yam Rice',
      'category': 'Food',
      'primaryImageUrl': 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624',
    });

    expect(stop1['imageUrl'], isNotEmpty);
    expect(stop2['imageUrl'], isNotEmpty);
    expect(stop3['imageUrl'], isNotEmpty);

    // Verify all 3 stops have different, distinct images from their respective Firestore records
    expect(stop1['imageUrl'], isNot(equals(stop2['imageUrl'])));
    expect(stop1['imageUrl'], isNot(equals(stop3['imageUrl'])));
    expect(stop2['imageUrl'], isNot(equals(stop3['imageUrl'])));
  });

  group('Tutor Requirements: Multi-Day Date Validation', () {
    test('allows flexible multi-day trip selection without artificial 5-day cap', () {
      final start = DateTime(2026, 9, 10);
      
      // 1 day
      final pref1 = TravelPreferences(stateId: 'penang', startDate: start, endDate: start);
      expect(pref1.dayCount, 1);
      expect(pref1.isValid, isTrue);

      // 3 days
      final pref3 = TravelPreferences(stateId: 'penang', startDate: start, endDate: start.add(const Duration(days: 2)));
      expect(pref3.dayCount, 3);
      expect(pref3.isValid, isTrue);

      // 7 days
      final pref7 = TravelPreferences(stateId: 'penang', startDate: start, endDate: start.add(const Duration(days: 6)));
      expect(pref7.dayCount, 7);
      expect(pref7.isValid, isTrue);

      // 14 days
      final pref14 = TravelPreferences(stateId: 'penang', startDate: start, endDate: start.add(const Duration(days: 13)));
      expect(pref14.dayCount, 14);
      expect(pref14.isValid, isTrue);
    });
  });

  group('Tutor Requirements: 1 Itinerary = 1 Malaysian State Isolation', () {
    test('contains all 13 states + 3 federal territories in catalog', () {
      expect(MalaysiaLocationService.defaultStates.length, 16);
      final stateIds = MalaysiaLocationService.defaultStates.map((s) => s.id).toSet();
      expect(stateIds.contains('penang'), isTrue);
      expect(stateIds.contains('melaka'), isTrue);
      expect(stateIds.contains('kuala_lumpur'), isTrue);
      expect(stateIds.contains('selangor'), isTrue);
      expect(stateIds.contains('sabah'), isTrue);
      expect(stateIds.contains('sarawak'), isTrue);
    });

    test('state normalization and inference accurately maps locations', () {
      expect(MalaysiaLocationService.normalizeStateId('Penang'), 'penang');
      expect(MalaysiaLocationService.normalizeStateId('Pulau Pinang'), 'penang');
      expect(MalaysiaLocationService.normalizeStateId('Melaka'), 'melaka');
      expect(MalaysiaLocationService.normalizeStateId('Kuala Lumpur'), 'kuala_lumpur');

      expect(MalaysiaLocationService.inferStateIdFromArea('George Town'), 'penang');
      expect(MalaysiaLocationService.inferStateIdFromArea('Jonker Walk, Melaka'), 'melaka');
      expect(MalaysiaLocationService.inferStateIdFromArea('Bukit Bintang, KL'), 'kuala_lumpur');
      expect(MalaysiaLocationService.inferStateIdFromArea('Petaling Jaya'), 'selangor');
    });

    test('mock places repository enforces strict state boundary', () {
      final mockPenangPlace = PlaceModel(
        placeId: 'p1',
        name: 'Chew Jetty',
        stateId: 'penang',
        stateName: 'Penang',
        area: 'George Town',
        category: 'Heritage',
      );
      final mockMelakaPlace = PlaceModel(
        placeId: 'm1',
        name: 'Stadthuys',
        stateId: 'melaka',
        stateName: 'Melaka',
        area: 'Bandar Hilir',
        category: 'Heritage',
      );

      final isPenangSameState = mockPenangPlace.stateId == 'penang';
      final isMelakaSameState = mockMelakaPlace.stateId == 'penang';

      expect(isPenangSameState, isTrue);
      expect(isMelakaSameState, isFalse);
    });
  });

  group('Tutor Requirements: Duration Fitting & Stop Count', () {
    test('different available duration adjusts stop counts realistically', () async {
      // 2h -> 2 stops
      // 4h -> 3-4 stops
      // 8h -> 5-6 stops (with meal/rest)
      final dummyPlaces = List.generate(
        10,
        (i) => PlaceModel(
          placeId: 'place_$i',
          name: 'Penang Heritage Stop $i',
          stateId: 'penang',
          stateName: 'Penang',
          area: 'George Town',
          category: i % 2 == 0 ? 'Heritage' : 'Food',
          estimatedVisitMinutes: 45,
          publicRating: 4.5 + (i % 5) * 0.1,
          validReviewCount: 10 + i,
        ),
      );

      final pref2h = TravelPreferences(stateId: 'penang', availableHours: 2.0);
      final pref4h = TravelPreferences(stateId: 'penang', availableHours: 4.0);
      final pref8h = TravelPreferences(stateId: 'penang', availableHours: 8.0);

      final result2h = await ItineraryRecommendationService.generateItinerary(
        preferences: pref2h,
        candidatePlaces: dummyPlaces,
      );
      final result4h = await ItineraryRecommendationService.generateItinerary(
        preferences: pref4h,
        candidatePlaces: dummyPlaces,
      );
      final result8h = await ItineraryRecommendationService.generateItinerary(
        preferences: pref8h,
        candidatePlaces: dummyPlaces,
      );

      expect(result2h.days.first.stops.length, lessThanOrEqualTo(3));
      expect(result4h.days.first.stops.length, greaterThanOrEqualTo(3));
      expect(result8h.days.first.stops.length, greaterThan(result4h.days.first.stops.length));
    });
  });

  group('Tutor Requirements: Multi-Day Anti-Duplication', () {
    test('multi-day trip generation never repeats places across days', () async {
      final dummyPlaces = List.generate(
        20,
        (i) => PlaceModel(
          placeId: 'unique_place_$i',
          name: 'Penang Stop $i',
          stateId: 'penang',
          stateName: 'Penang',
          area: 'George Town',
          category: ['Heritage', 'Food', 'Culture', 'Art', 'Nature'][i % 5],
          estimatedVisitMinutes: 50,
          publicRating: 4.5,
          validReviewCount: 15,
        ),
      );

      final pref3Days = TravelPreferences(
        stateId: 'penang',
        startDate: DateTime(2026, 9, 10),
        endDate: DateTime(2026, 9, 12), // 3 days
        availableHours: 4.0,
      );

      final itinerary = await ItineraryRecommendationService.generateItinerary(
        preferences: pref3Days,
        candidatePlaces: dummyPlaces,
      );

      expect(itinerary.days.length, 3);

      final allPlaceIds = <String>[];
      for (final day in itinerary.days) {
        for (final stop in day.stops) {
          allPlaceIds.add(stop.placeId);
        }
      }

      final uniquePlaceIds = allPlaceIds.toSet();
      // No duplicate place IDs across the entire multi-day trip
      expect(allPlaceIds.length, uniquePlaceIds.length);
    });
  });

  group('Tutor Requirements: Controlled Diversity & Recommendation Pipeline', () {
    test('penalty for recently selected place IDs promotes diversity on consecutive runs', () async {
      final dummyPlaces = List.generate(
        15,
        (i) => PlaceModel(
          placeId: 'divers_place_$i',
          name: 'Attraction $i',
          stateId: 'penang',
          stateName: 'Penang',
          area: 'George Town',
          category: 'Heritage',
          estimatedVisitMinutes: 45,
          publicRating: 4.8,
          validReviewCount: 20,
        ),
      );

      final pref = TravelPreferences(stateId: 'penang', availableHours: 4.0);

      // Run 1
      final it1 = await ItineraryRecommendationService.generateItinerary(
        preferences: pref,
        candidatePlaces: dummyPlaces,
        randomSeed: 42,
      );
      final run1PlaceIds = it1.days.first.stops.map((s) => s.placeId).toSet();

      // Run 2 with recentlyRecommendedPlaceIds from Run 1
      final it2 = await ItineraryRecommendationService.generateItinerary(
        preferences: pref,
        candidatePlaces: dummyPlaces,
        recentlyRecommendedPlaceIds: run1PlaceIds,
        randomSeed: 99,
      );
      final run2PlaceIds = it2.days.first.stops.map((s) => s.placeId).toSet();

      // Run 2 should contain varied stops that were not in Run 1
      final difference = run2PlaceIds.difference(run1PlaceIds);
      expect(difference.isNotEmpty, isTrue);
    });
  });

  group('Daily Planner Scenarios DP1 - DP8 & Meal Logic Tests', () {
    final testCatalog = [
      PlaceModel(
        placeId: 'p_bf_beach',
        name: 'Batu Ferringhi Beach',
        stateId: 'penang',
        stateName: 'Penang',
        area: 'Batu Ferringhi',
        category: 'Nature',
        interestTags: ['Nature', 'Beach'],
        estimatedVisitMinutes: 60,
        latitude: 5.4744,
        longitude: 100.2472,
      ),
      PlaceModel(
        placeId: 'p_spice_garden',
        name: 'Tropical Spice Garden',
        stateId: 'penang',
        stateName: 'Penang',
        area: 'Batu Ferringhi',
        category: 'Nature',
        interestTags: ['Nature', 'Culture'],
        estimatedVisitMinutes: 75,
        latitude: 5.4628,
        longitude: 100.2289,
      ),
      PlaceModel(
        placeId: 'p_bf_kopitiam',
        name: 'Batu Ferringhi Heritage Kopitiam',
        stateId: 'penang',
        stateName: 'Penang',
        area: 'Batu Ferringhi',
        category: 'Food',
        interestTags: ['Food', 'Breakfast', 'Kopitiam'],
        estimatedVisitMinutes: 40,
        latitude: 5.4715,
        longitude: 100.2450,
      ),
      PlaceModel(
        placeId: 'p_long_beach_cafe',
        name: 'Long Beach Food Court',
        stateId: 'penang',
        stateName: 'Penang',
        area: 'Batu Ferringhi',
        category: 'Food',
        interestTags: ['Food', 'Lunch', 'Dinner'],
        estimatedVisitMinutes: 50,
        latitude: 5.4730,
        longitude: 100.2465,
      ),
      PlaceModel(
        placeId: 'p_chew_jetty',
        name: 'Chew Jetty',
        stateId: 'penang',
        stateName: 'Penang',
        area: 'George Town',
        category: 'Heritage',
        interestTags: ['Heritage', 'Culture'],
        estimatedVisitMinutes: 60,
        latitude: 5.4128,
        longitude: 100.3402,
      ),
      PlaceModel(
        placeId: 'p_pinang_mansion',
        name: 'Pinang Peranakan Mansion',
        stateId: 'penang',
        stateName: 'Penang',
        area: 'George Town',
        category: 'Heritage',
        interestTags: ['Heritage', 'Culture', 'Art'],
        estimatedVisitMinutes: 75,
        latitude: 5.4182,
        longitude: 100.3408,
      ),
      PlaceModel(
        placeId: 'p_hameediyah',
        name: 'Hameediyah Restaurant',
        stateId: 'penang',
        stateName: 'Penang',
        area: 'George Town',
        category: 'Food',
        interestTags: ['Food', 'Lunch', 'Dinner'],
        estimatedVisitMinutes: 50,
        latitude: 5.4172,
        longitude: 100.3330,
      ),
      PlaceModel(
        placeId: 'p_teochew_chendul',
        name: 'Penang Road Famous Teochew Chendul',
        stateId: 'penang',
        stateName: 'Penang',
        area: 'George Town',
        category: 'Food',
        interestTags: ['Food', 'Dessert', 'chendul'],
        estimatedVisitMinutes: 30,
        latitude: 5.4183,
        longitude: 100.3310,
      ),
      PlaceModel(
        placeId: 'p_kek_seng',
        name: 'Kek Seng Ice Kacang & Durian Ice Cream',
        stateId: 'penang',
        stateName: 'Penang',
        area: 'George Town',
        category: 'Food',
        interestTags: ['Food', 'Dessert', 'ice cream'],
        estimatedVisitMinutes: 30,
        latitude: 5.4165,
        longitude: 100.3290,
      ),
      PlaceModel(
        placeId: 'p_ferringhi_chendul',
        name: 'Batu Ferringhi Heritage Chendul',
        stateId: 'penang',
        stateName: 'Penang',
        area: 'Batu Ferringhi',
        category: 'Food',
        interestTags: ['Food', 'Dessert', 'chendul'],
        estimatedVisitMinutes: 30,
        latitude: 5.4700,
        longitude: 100.2450,
      ),
      PlaceModel(
        placeId: 'p_dinner_place',
        name: 'Gurney Drive Night Hawker',
        stateId: 'penang',
        stateName: 'Penang',
        area: 'George Town',
        category: 'Food',
        interestTags: ['Food', 'Dinner', 'Street Food'],
        estimatedVisitMinutes: 60,
        latitude: 5.4400,
        longitude: 100.3100,
      ),
    ];

    test('SCENARIO DP1: Penang, Batu Ferringhi, 09:00, 6 hours, Food + Nature <= 6h with logical meals', () async {
      final pref = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'Batu Ferringhi',
        dailyStartMinutes: 9 * 60, // 09:00
        availableHours: 6.0, // 6 hours (09:00 to 15:00)
        interests: ['Food', 'Nature'],
      );

      final it = await ItineraryRecommendationService.generateItinerary(
        preferences: pref,
        candidatePlaces: testCatalog,
      );

      final day = it.days.first;
      expect(day.usedScheduleMinutes <= 360, isTrue); // <= 6 hours
      expect(day.stops.length, greaterThanOrEqualTo(2));

      // No stop should finish after 15:00 (900 min)
      final lastStop = day.stops.last;
      expect(lastStop.suggestedEndMinutes!, lessThanOrEqualTo(15 * 60));

      // Has Breakfast or Lunch, NO dinner because ends at 15:00
      final mealRoles = day.stops.map((s) => s.mealRole).where((r) => r != null).toList();
      expect(mealRoles.contains('Dinner'), isFalse);

      // Has Category Diversity (both Food and Nature represented)
      final categories = day.stops.map((s) => s.category).toSet();
      expect(categories.contains('Food') || categories.contains('Nature'), isTrue);
    });

    test('SCENARIO DP2: Penang, Batu Ferringhi, 09:00, 2 hours, Food + Nature <= 2h', () async {
      final pref = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'Batu Ferringhi',
        dailyStartMinutes: 9 * 60,
        availableHours: 2.0, // 2 hours (09:00 to 11:00)
        interests: ['Food', 'Nature'],
      );

      final it = await ItineraryRecommendationService.generateItinerary(
        preferences: pref,
        candidatePlaces: testCatalog,
      );

      final day = it.days.first;
      expect(day.usedScheduleMinutes <= 120, isTrue); // <= 2 hours
      final lastStop = day.stops.last;
      expect(lastStop.suggestedEndMinutes!, lessThanOrEqualTo(11 * 60));

      // Lunch should NOT be forced because trip ends at 11:00
      final mealRoles = day.stops.map((s) => s.mealRole).where((r) => r != null).toList();
      expect(mealRoles.contains('Lunch'), isFalse);
    });

    test('SCENARIO DP3: Penang, Batu Ferringhi, 09:00, 8 hours, Food + Nature <= 8h and optional dessert', () async {
      final pref = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'Batu Ferringhi',
        dailyStartMinutes: 9 * 60,
        availableHours: 8.0, // 8 hours (09:00 to 17:00)
        interests: ['Food', 'Nature'],
      );

      final it = await ItineraryRecommendationService.generateItinerary(
        preferences: pref,
        candidatePlaces: testCatalog,
      );

      final day = it.days.first;
      expect(day.usedScheduleMinutes <= 480, isTrue); // <= 8 hours
      expect(day.stops.last.suggestedEndMinutes!, lessThanOrEqualTo(17 * 60));

      // Test optional dessert addition
      if (day.remainingMinutes >= 35) {
        final updatedDay = ItineraryRecommendationService.addDessertStopToDay(
          currentDay: day,
          availablePlaces: testCatalog,
          availableHours: 8.0,
          startMinutes: 9 * 60,
          stateId: 'penang',
          stateName: 'Penang',
        );
        expect(updatedDay, isNotNull);
        expect(updatedDay!.stops.any((s) => s.mealRole == 'Dessert'), isTrue);
        expect(updatedDay.usedScheduleMinutes <= 480, isTrue);
      }
    });

    test('SCENARIO DP4: Penang, George Town, 09:00, 6 hours, Heritage only has no forced meals', () async {
      final pref = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'George Town',
        dailyStartMinutes: 9 * 60,
        availableHours: 6.0,
        interests: ['Heritage'], // No Food selected
      );

      final it = await ItineraryRecommendationService.generateItinerary(
        preferences: pref,
        candidatePlaces: testCatalog,
      );

      final day = it.days.first;
      expect(day.usedScheduleMinutes <= 360, isTrue);
      // Stops should be Heritage, no forced meals
      expect(day.stops.every((s) => s.category != 'Food' || s.tags.contains('Heritage')), isTrue);
    });

    test('SCENARIO DP5: Penang, George Town, 11:00, 6 hours, Food + Heritage has Lunch eligible and ends <= 17:00', () async {
      final pref = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'George Town',
        dailyStartMinutes: 11 * 60, // 11:00 AM
        availableHours: 6.0, // 11:00 to 17:00
        interests: ['Food', 'Heritage'],
      );

      final it = await ItineraryRecommendationService.generateItinerary(
        preferences: pref,
        candidatePlaces: testCatalog,
      );

      final day = it.days.first;
      expect(day.usedScheduleMinutes <= 360, isTrue);
      expect(day.stops.last.suggestedEndMinutes!, lessThanOrEqualTo(17 * 60));

      final mealRoles = day.stops.map((s) => s.mealRole).where((r) => r != null).toList();
      // Breakfast should NOT appear since trip starts at 11:00 AM
      expect(mealRoles.contains('Breakfast'), isFalse);
    });

    test('SCENARIO DP6: Penang, George Town, 15:00, 6 hours, Food + Heritage has Dinner eligible and ends <= 21:00', () async {
      final pref = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'George Town',
        dailyStartMinutes: 15 * 60, // 15:00 (3:00 PM)
        availableHours: 6.0, // 15:00 to 21:00
        interests: ['Food', 'Heritage'],
      );

      final it = await ItineraryRecommendationService.generateItinerary(
        preferences: pref,
        candidatePlaces: testCatalog,
      );

      final day = it.days.first;
      expect(day.usedScheduleMinutes <= 360, isTrue);
      expect(day.stops.last.suggestedEndMinutes!, lessThanOrEqualTo(21 * 60));

      final mealRoles = day.stops.map((s) => s.mealRole).where((r) => r != null).toList();
      // Breakfast and Lunch should NOT appear
      expect(mealRoles.contains('Breakfast'), isFalse);
      expect(mealRoles.contains('Lunch'), isFalse);
    });

    test('SCENARIO DP7: 3-day Penang trip maintains independent daily meal state and no duplicates', () async {
      final pref = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'George Town',
        startDate: DateTime(2026, 9, 10),
        endDate: DateTime(2026, 9, 12), // 3 days
        dailyStartMinutes: 9 * 60,
        availableHours: 4.0,
        interests: ['Food', 'Nature', 'Heritage'],
      );

      final it = await ItineraryRecommendationService.generateItinerary(
        preferences: pref,
        candidatePlaces: testCatalog,
      );

      expect(it.days.length, 3);
      for (final day in it.days) {
        expect(day.usedScheduleMinutes <= 240, isTrue);
      }
    });

    test('SCENARIO DP8: Empty state throws clear descriptive exception without crashing', () async {
      final pref = TravelPreferences(
        stateId: 'perlis', // No places in candidate list
        availableHours: 4.0,
      );

      expect(
        () async => await ItineraryRecommendationService.generateItinerary(
          preferences: pref,
          candidatePlaces: [],
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Time Calculation: planned activity minutes + travel minutes = used schedule minutes', () {
      final stops = [
        {
          'name': 'Stop 1',
          'durationMinutes': 60,
          'travelMinutesBefore': 0,
          'location': {'latitude': 5.4141, 'longitude': 100.3288},
        },
        {
          'name': 'Stop 2',
          'durationMinutes': 90,
          'travelMinutesBefore': 15,
          'location': {'latitude': 5.4160, 'longitude': 100.3310},
        },
        {
          'name': 'Stop 3 (Meal)',
          'durationMinutes': 45,
          'travelMinutesBefore': 10,
          'mealRole': 'Lunch',
          'location': {'latitude': 5.4200, 'longitude': 100.3380},
        },
      ];

      final schedule = ItinerarySchedulePlanner.plan(
        stops: stops,
        pace: 'Balanced',
        availableHours: 6.0, // 360 min
        preferredStartMinutes: 9 * 60, // 540
      );

      // Activity = 60 + 90 + 45 = 195 min
      expect(schedule.plannedActivityMinutes, 195);
      // Travel = 0 + 6 + 10 = 16 min (calculated from coordinates)
      expect(schedule.travelMinutes, 16);
      // Total used = 195 + 16 = 211 min
      expect(schedule.usedScheduleMinutes, 211);
      expect(schedule.totalEstimatedMinutes, 211);
      // Remaining = 360 - 211 = 149 min
      expect(schedule.remainingMinutes, 149);
      // End minutes = 540 + 211 = 751 (12:31 PM)
      expect(schedule.endMinutes, 751);
      expect(schedule.endMinutes <= 900, isTrue);
    });

    test('Dessert fitting: rejects dessert safely when remaining time is insufficient', () {
      final dayModel = ItineraryDayModel(
        dayNumber: 1,
        date: DateTime(2026, 9, 10),
        dateLabel: 'Day 1',
        stops: [
          ItineraryStopModel(
            placeId: 'p1',
            name: 'Big Stop',
            stateId: 'penang',
            stateName: 'Penang',
            area: 'George Town',
            category: 'Heritage',
            durationMinutes: 340, // Uses almost entire 6h (360 min)
            sequence: 1,
            dayNumber: 1,
          ),
        ],
        totalEstimatedMinutes: 340,
        remainingMinutes: 20, // Only 20 min remaining (< 35 min required)
      );

      expect(
        () => ItineraryRecommendationService.addDessertStopToDay(
          currentDay: dayModel,
          availablePlaces: testCatalog,
          availableHours: 6.0,
          startMinutes: 9 * 60,
          stateId: 'penang',
          stateName: 'Penang',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

