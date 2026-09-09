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
      // 1. Single area from different state
      final crossStatePref = TravelPreferences(
        stateId: 'penang',
        selectedArea: 'Jonker Walk & Heritage Core', // Melaka
      );
      expect(crossStatePref.isValid, isFalse);
      expect(crossStatePref.validate(), contains('does not belong to Penang'));

      // 2. Multi-area containing an area from different state
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
}
