import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/traveler/daily_planner/models/place_model.dart';
import 'package:myheritage_explorer/traveler/daily_planner/models/travel_preferences_model.dart';
import 'package:myheritage_explorer/traveler/daily_planner/services/itinerary_recommendation_service.dart';
import 'package:myheritage_explorer/traveler/daily_planner/services/place_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<PlaceModel> allCatalogPlaces;

  setUpAll(() {
    allCatalogPlaces = PlaceRepository.getHeritageCatalogue();
  });

  group('Requirement 1: Place / Vendor Coverage Across Penang Areas', () {
    test('Penang catalogue covers all required areas with authentic places', () {
      final penangPlaces = allCatalogPlaces.where((p) => p.stateId == 'penang').toList();
      expect(penangPlaces.length, greaterThanOrEqualTo(60));

      final areas = penangPlaces.map((p) => p.area).toSet();
      expect(areas, contains('George Town'));
      expect(areas, contains('Bukit Mertajam'));
      expect(areas, contains('Butterworth'));
      expect(areas, contains('Batu Ferringhi'));
      expect(areas, contains('Tanjung Bungah'));
      expect(areas, contains('Balik Pulau'));
      expect(areas, contains('Air Itam'));
      expect(areas, contains('Teluk Bahang'));
      expect(areas, contains('Bayan Lepas'));
      expect(areas, contains('Nibong Tebal'));
    });

    test('All Penang places have unique names and unique primary image URLs', () {
      final penangPlaces = allCatalogPlaces.where((p) => p.stateId == 'penang').toList();
      final names = <String>{};
      final images = <String>{};

      for (final p in penangPlaces) {
        expect(names.contains(p.name), isFalse, reason: 'Duplicate place name found: ${p.name}');
        names.add(p.name);

        expect(p.primaryImageUrl.isNotEmpty, isTrue);
        expect(images.contains(p.primaryImageUrl), isFalse, reason: 'Duplicate image URL found: ${p.primaryImageUrl} in ${p.name}');
        images.add(p.primaryImageUrl);
      }
    });

    test('All Penang places have valid coordinates and reasonable durations', () {
      final penangPlaces = allCatalogPlaces.where((p) => p.stateId == 'penang').toList();
      for (final p in penangPlaces) {
        expect(p.latitude, greaterThan(5.0));
        expect(p.latitude, lessThan(6.0));
        expect(p.longitude, greaterThan(100.0));
        expect(p.longitude, lessThan(101.0));
        expect(p.estimatedVisitMinutes, greaterThanOrEqualTo(20));
        expect(p.estimatedVisitMinutes, lessThanOrEqualTo(180));
      }
    });
  });

  group('Requirement 2: Single Area Itinerary Generation (Non-George Town Areas)', () {
    test('Scenario 1: Single Area - Bukit Mertajam returns only BM places and local vendors', () async {
      final prefs = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'Bukit Mertajam',
        availableHours: 6.0,
        dailyStartMinutes: 9 * 60,
        interests: ['Heritage', 'Culture', 'Food'],
      );

      final itinerary = await ItineraryRecommendationService.generateItinerary(
        preferences: prefs,
        candidatePlaces: allCatalogPlaces,
      );

      expect(itinerary.stops.isNotEmpty, isTrue);
      for (final stop in itinerary.stops) {
        expect(stop.area.toLowerCase(), contains('bukit mertajam'),
            reason: 'Stop ${stop.name} (${stop.area}) should be in Bukit Mertajam');
      }

      // Check meal vendor is local to BM
      final foodStops = itinerary.stops.where((s) => s.category == 'Food' || s.mealRole != null).toList();
      expect(foodStops.isNotEmpty, isTrue);
      for (final meal in foodStops) {
        expect(meal.area.toLowerCase(), contains('bukit mertajam'));
      }
    });

    test('Scenario 2: Single Area - Butterworth returns only Butterworth places', () async {
      final prefs = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'Butterworth',
        availableHours: 6.0,
        dailyStartMinutes: 9 * 60,
        interests: ['Heritage', 'Nature', 'Art', 'Food'],
      );

      final itinerary = await ItineraryRecommendationService.generateItinerary(
        preferences: prefs,
        candidatePlaces: allCatalogPlaces,
      );

      expect(itinerary.stops.isNotEmpty, isTrue);
      for (final stop in itinerary.stops) {
        expect(stop.area.toLowerCase(), contains('butterworth'),
            reason: 'Stop ${stop.name} (${stop.area}) should be in Butterworth');
      }
    });

    test('Scenario 3: Single Area - Tanjung Bungah returns only Tanjung Bungah places', () async {
      final prefs = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'Tanjung Bungah',
        availableHours: 4.0,
        dailyStartMinutes: 9 * 60,
        interests: ['Culture', 'Nature', 'Food'],
      );

      final itinerary = await ItineraryRecommendationService.generateItinerary(
        preferences: prefs,
        candidatePlaces: allCatalogPlaces,
      );

      expect(itinerary.stops.isNotEmpty, isTrue);
      for (final stop in itinerary.stops) {
        expect(stop.area.toLowerCase(), contains('tanjung bunga'),
            reason: 'Stop ${stop.name} (${stop.area}) should be in Tanjung Bungah');
      }
    });

    test('Scenario 4: Single Area - Balik Pulau returns countryside places and local laksa/farms', () async {
      final prefs = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'Balik Pulau',
        availableHours: 5.0,
        dailyStartMinutes: 9 * 60,
        interests: ['Nature', 'Culture', 'Food'],
      );

      final itinerary = await ItineraryRecommendationService.generateItinerary(
        preferences: prefs,
        candidatePlaces: allCatalogPlaces,
      );

      expect(itinerary.stops.isNotEmpty, isTrue);
      for (final stop in itinerary.stops) {
        expect(stop.area.toLowerCase(), contains('balik pulau'),
            reason: 'Stop ${stop.name} (${stop.area}) should be in Balik Pulau');
      }
    });
  });

  group('Requirement 3: Multi-Destination / Multi-Area Itinerary Generation', () {
    test('Scenario 5: Multi-Area - George Town + Batu Ferringhi corridor', () async {
      final prefs = TravelPreferences(
        stateId: 'penang',
        travelAreaMode: 'multiple',
        selectedAreas: ['George Town', 'Batu Ferringhi'],
        availableHours: 6.0,
        dailyStartMinutes: 9 * 60,
        interests: ['Heritage', 'Nature', 'Food'],
      );

      final itinerary = await ItineraryRecommendationService.generateItinerary(
        preferences: prefs,
        candidatePlaces: allCatalogPlaces,
      );

      expect(itinerary.stops.isNotEmpty, isTrue);
      final allowedAreas = {'george town', 'batu ferringhi', 'batu feringghi'};
      for (final stop in itinerary.stops) {
        final match = allowedAreas.any((a) => stop.area.toLowerCase().contains(a));
        expect(match, isTrue, reason: 'Stop ${stop.name} in area ${stop.area} must be in selected areas');
      }

      // Check total time feasibility <= 6 hours (360 min)
      final totalMinutes = itinerary.days.first.totalEstimatedMinutes;
      expect(totalMinutes, lessThanOrEqualTo(360));
    });

    test('Scenario 6: Multi-Area - Bukit Mertajam + Butterworth (Mainland cluster)', () async {
      final prefs = TravelPreferences(
        stateId: 'penang',
        travelAreaMode: 'multiple',
        selectedAreas: ['Bukit Mertajam', 'Butterworth'],
        availableHours: 6.0,
        dailyStartMinutes: 9 * 60,
        interests: ['Heritage', 'Nature', 'Food'],
      );

      final itinerary = await ItineraryRecommendationService.generateItinerary(
        preferences: prefs,
        candidatePlaces: allCatalogPlaces,
      );

      expect(itinerary.stops.isNotEmpty, isTrue);
      final allowedAreas = {'bukit mertajam', 'butterworth'};
      for (final stop in itinerary.stops) {
        final match = allowedAreas.any((a) => stop.area.toLowerCase().contains(a));
        expect(match, isTrue, reason: 'Stop ${stop.name} in area ${stop.area} must be in BM or Butterworth');
      }
      expect(itinerary.days.first.totalEstimatedMinutes, lessThanOrEqualTo(360));
    });

    test('Scenario 7: Multi-Day Multi-Area allocates days to selected area clusters', () async {
      final start = DateTime(2026, 9, 10);
      final prefs = TravelPreferences(
        stateId: 'penang',
        travelAreaMode: 'multiple',
        selectedAreas: ['George Town', 'Bukit Mertajam'],
        startDate: start,
        endDate: start.add(const Duration(days: 1)), // 2 days
        availableHours: 5.0,
        dailyStartMinutes: 9 * 60,
        interests: ['Heritage', 'Food'],
      );

      final itinerary = await ItineraryRecommendationService.generateItinerary(
        preferences: prefs,
        candidatePlaces: allCatalogPlaces,
      );

      expect(itinerary.days.length, 2);
      expect(itinerary.days[0].stops.isNotEmpty, isTrue);
      expect(itinerary.days[1].stops.isNotEmpty, isTrue);

      // Day 1 should have George Town focus, Day 2 should have BM focus
      final day1Stops = itinerary.days[0].stops;
      final day2Stops = itinerary.days[1].stops;

      expect(day1Stops.any((s) => s.area.toLowerCase().contains('george town')), isTrue);
      expect(day2Stops.any((s) => s.area.toLowerCase().contains('bukit mertajam')), isTrue);

      // No cross-day duplicate stops
      final day1Ids = day1Stops.map((s) => s.placeId).toSet();
      for (final s in day2Stops) {
        expect(day1Ids.contains(s.placeId), isFalse, reason: 'Duplicate stop across days: ${s.name}');
      }
    });
  });

  group('Requirement 4: Strict Same-State Isolation & Validation', () {
    test('Same-state rule strictly prohibits cross-state areas', () {
      final crossStatePref = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'Jonker Walk & Heritage Core', // Melaka
      );
      expect(crossStatePref.isValid, isFalse);
      expect(crossStatePref.validate(), contains('does not belong to Penang'));

      final crossMultiPref = TravelPreferences(
        stateId: 'penang',
        travelAreaMode: 'multiple',
        selectedAreas: ['George Town', 'KLCC & City Centre'], // KL
      );
      expect(crossMultiPref.isValid, isFalse);
      expect(crossMultiPref.validate(), contains('Cross-state itineraries are not permitted'));
    });

    test('Validation requires at least one selected area in multi-area mode', () {
      final emptyAreasPref = TravelPreferences(
        stateId: 'penang',
        travelAreaMode: 'multiple',
        selectedAreas: [],
      );
      expect(emptyAreasPref.isValid, isFalse);
      expect(emptyAreasPref.validate(), contains('Please select at least one area'));
    });
  });

  group('Requirement 5: Time Duration Feasibility', () {
    test('Short 2-hour duration strictly limits stops and excludes distant stops', () async {
      final prefs = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'George Town',
        availableHours: 2.0,
        dailyStartMinutes: 9 * 60,
        interests: ['Heritage'],
      );

      final itinerary = await ItineraryRecommendationService.generateItinerary(
        preferences: prefs,
        candidatePlaces: allCatalogPlaces,
      );

      expect(itinerary.days.first.totalEstimatedMinutes, lessThanOrEqualTo(120));
      expect(itinerary.stops.length, inInclusiveRange(1, 3));
    });
  });

  group('New Requirements A - G: Cross-Midnight, Area Limits & Smart Clustering', () {
    test('Test A: 12:00 AM -> 5:00 AM calculates 5.0 available hours correctly', () {
      final hours = TravelPreferences.calculateAvailableHoursFromTimes(
        startHour: 0,
        startMinute: 0,
        endHour: 5,
        endMinute: 0,
      );
      expect(hours, 5.0);

      final pref = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'George Town',
        dailyStartMinutes: 0, // 12:00 AM
        availableHours: 5.0,
      );
      expect(pref.dailyStartTimeLabel, '12:00 AM');
      expect(pref.dailyEndTimeLabel, '5:00 AM');
    });

    test('Test B: 10:00 PM -> 2:00 AM calculates 4.0 hours across midnight', () {
      final hours = TravelPreferences.calculateAvailableHoursFromTimes(
        startHour: 22,
        startMinute: 0,
        endHour: 2,
        endMinute: 0,
      );
      expect(hours, 4.0);

      final pref = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'George Town',
        dailyStartMinutes: 22 * 60, // 10:00 PM
        availableHours: 4.0,
      );
      expect(pref.dailyStartTimeLabel, '10:00 PM');
      expect(pref.dailyEndTimeLabel, '2:00 AM');
    });

    test('Test C: 12 AM - 5 AM excludes closed daytime attractions and excludes forced standard meals', () async {
      final pref = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'George Town',
        dailyStartMinutes: 0, // 12:00 AM
        availableHours: 5.0,
        interests: ['Heritage', 'Food'],
      );

      final itinerary = await ItineraryRecommendationService.generateItinerary(
        preferences: pref,
        candidatePlaces: allCatalogPlaces,
      );

      // Normal closed daytime museums (09:30 - 17:00) must be excluded
      final stopNames = itinerary.stops.map((s) => s.name).toList();
      expect(stopNames.contains('Pinang Peranakan Mansion'), isFalse);
      expect(stopNames.contains('Cheong Fatt Tze - The Blue Mansion'), isFalse);

      // Must not create standard breakfast or lunch during 12 AM - 5 AM
      for (final stop in itinerary.stops) {
        expect(stop.mealRole, isNot('Breakfast'));
        expect(stop.mealRole, isNot('Lunch'));
        expect(stop.mealRole, isNot('Dinner'));
      }
    });

    test('Test D: 1-day trip selecting more than 5 areas is blocked by validation', () {
      final start = DateTime(2026, 9, 10);
      final pref = TravelPreferences(
        stateId: 'penang',
        travelAreaMode: 'multiple',
        startDate: start,
        endDate: start, // 1 day
        selectedAreas: [
          'George Town',
          'Tanjung Bungah',
          'Batu Ferringhi',
          'Butterworth',
          'Bukit Mertajam',
          'Balik Pulau', // 6 areas > max 5
        ],
      );

      expect(pref.isValid, isFalse);
      expect(pref.validate(), contains('You can select up to 5 areas for this 1-day trip.'));
    });

    test('Test E: 2-day trip dynamically allows up to 10 areas and blocks 11', () {
      final start = DateTime(2026, 9, 10);
      final valid2DayPref = TravelPreferences(
        stateId: 'penang',
        travelAreaMode: 'multiple',
        startDate: start,
        endDate: start.add(const Duration(days: 1)), // 2 days -> max 10
        selectedAreas: [
          'George Town',
          'Tanjung Bungah',
          'Batu Ferringhi',
          'Butterworth',
          'Bukit Mertajam',
          'Balik Pulau',
          'Air Itam',
          'Bayan Lepas',
        ],
      );
      expect(valid2DayPref.isValid, isTrue);

      final invalid2DayPref = TravelPreferences(
        stateId: 'penang',
        travelAreaMode: 'multiple',
        startDate: start,
        endDate: start.add(const Duration(days: 1)), // 2 days -> max 10
        selectedAreas: [
          'George Town',
          'Tanjung Bungah',
          'Batu Ferringhi',
          'Butterworth',
          'Bukit Mertajam',
          'Balik Pulau',
          'Air Itam',
          'Bayan Lepas',
          'Teluk Bahang',
          'Nibong Tebal',
          'Extra Area', // 11 areas > max 10
        ],
      );
      expect(invalid2DayPref.isValid, isFalse);
      expect(invalid2DayPref.validate(), contains('You can select up to 10 areas for this 2-day trip.'));
    });

    test('Test F: 5 selected areas but only realistic ones fit within 6 hours generates route and area note', () async {
      final start = DateTime(2026, 9, 10);
      final pref = TravelPreferences(
        stateId: 'penang',
        travelAreaMode: 'multiple',
        startDate: start,
        endDate: start, // 1 day
        availableHours: 6.0,
        dailyStartMinutes: 9 * 60,
        selectedAreas: [
          'George Town',
          'Tanjung Bungah',
          'Batu Ferringhi',
          'Butterworth',
          'Bukit Mertajam',
        ],
        interests: ['Heritage', 'Nature'],
      );

      final itinerary = await ItineraryRecommendationService.generateItinerary(
        preferences: pref,
        candidatePlaces: allCatalogPlaces,
      );

      expect(itinerary.stops.isNotEmpty, isTrue);
      expect(itinerary.days.first.totalEstimatedMinutes, lessThanOrEqualTo(360));

      final visitedAreas = itinerary.stops.map((s) => s.area).toSet();
      if (visitedAreas.length < 5) {
        expect(itinerary.areaInclusionNote, isNotNull);
        expect(itinerary.areaInclusionNote, contains('of your 5 selected areas were included'));
      }
    });

    test('Test G: Multi-day selected areas distribute geographically across different days based on proximity', () async {
      final start = DateTime(2026, 9, 10);
      final pref = TravelPreferences(
        stateId: 'penang',
        travelAreaMode: 'multiple',
        startDate: start,
        endDate: start.add(const Duration(days: 2)), // 3 days
        availableHours: 5.0,
        dailyStartMinutes: 9 * 60,
        selectedAreas: [
          'George Town',
          'Tanjung Bungah',
          'Batu Ferringhi',
          'Butterworth',
          'Bukit Mertajam',
          'Balik Pulau',
        ],
        interests: ['Heritage', 'Nature', 'Food'],
      );

      final itinerary = await ItineraryRecommendationService.generateItinerary(
        preferences: pref,
        candidatePlaces: allCatalogPlaces,
      );

      expect(itinerary.days.length, 3);
      expect(itinerary.days[0].stops.isNotEmpty, isTrue);
      expect(itinerary.days[1].stops.isNotEmpty, isTrue);
      expect(itinerary.days[2].stops.isNotEmpty, isTrue);

      final day1Areas = itinerary.days[0].stops.map((s) => s.area.toLowerCase()).toSet();
      final day2Areas = itinerary.days[1].stops.map((s) => s.area.toLowerCase()).toSet();
      final day3Areas = itinerary.days[2].stops.map((s) => s.area.toLowerCase()).toSet();

      final allDayAreas = [day1Areas, day2Areas, day3Areas];
      final mainlandDay = allDayAreas.indexWhere((areas) =>
          areas.any((a) => a.contains('butterworth') || a.contains('bukit mertajam')));
      expect(mainlandDay, isNot(-1), reason: 'At least one day should focus on the mainland cluster');
    });
  });
}
