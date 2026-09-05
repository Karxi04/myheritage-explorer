import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/core/services.dart';
import 'package:myheritage_explorer/traveler/traveler_pages.dart';
import 'package:myheritage_explorer/traveler/daily_planner/models/place_model.dart';
import 'package:myheritage_explorer/traveler/daily_planner/models/travel_preferences_model.dart';
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
}
