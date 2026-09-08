import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:myheritage_explorer/models/navigation_stop.dart';
import 'package:myheritage_explorer/services/place_geocoding_service.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/destination_search_page.dart';

void main() {
  const georgetown = LatLng(5.4141, 100.3288);
  const distantJohor = LatLng(1.4927, 103.7414);

  setUp(() {
    DestinationSearchPage.clearSessionCache();
  });

  group('matchTier unit tests', () {
    final sampleStop = NavigationStop(
      id: 'stop-tier',
      location: const LatLng(5.4345, 100.3090),
      displayName: 'Gurney Paragon Mall',
      address: 'Persiaran Gurney, Pulau Tikus, 10250 Penang',
      isDestination: true,
    );

    test('Tier 1: full display name starts with query', () {
      expect(matchTier(sampleStop, 'g'), 1);
      expect(matchTier(sampleStop, 'gur'), 1);
      expect(matchTier(sampleStop, 'Gurney'), 1);
    });

    test('Tier 2: display name token/word starts with query', () {
      expect(matchTier(sampleStop, 'par'), 2);
      expect(matchTier(sampleStop, 'mall'), 2);
    });

    test('Tier 3: address token/word starts with query', () {
      expect(matchTier(sampleStop, 'pul'), 3);
      expect(matchTier(sampleStop, 'tikus'), 3);
      expect(matchTier(sampleStop, 'persiaran'), 3);
    });

    test('Tier 4: display name contains query anywhere', () {
      expect(matchTier(sampleStop, 'agon'), 4);
      expect(matchTier(sampleStop, 'all'), 4);
    });

    test('Tier 5: address contains query anywhere', () {
      expect(matchTier(sampleStop, 'siaran'), 5);
      expect(matchTier(sampleStop, 'ikus'), 5);
    });

    test('Tier 6: query does not match stop at all', () {
      expect(matchTier(sampleStop, 'kuala lumpur'), 6);
      expect(matchTier(sampleStop, 'alor setar'), 6);
    });

    test('empty query returns Tier 1', () {
      expect(matchTier(sampleStop, ''), 1);
      expect(matchTier(sampleStop, '   '), 1);
    });
  });

  group('areStopsDuplicate & deduplicateStops unit tests', () {
    final stop1 = NavigationStop(
      id: 'poi-1',
      location: const LatLng(5.4345, 100.3090),
      displayName: 'Gurney Paragon',
      address: 'Persiaran Gurney, Penang',
    );

    final stop1DuplicateId = NavigationStop(
      id: 'poi-1',
      location: const LatLng(5.4350, 100.3100),
      displayName: 'Different Name Same ID',
      address: 'Persiaran Gurney, Penang',
    );

    final stop1SimilarNameNearby = NavigationStop(
      id: 'poi-other-id',
      location: const LatLng(5.4350, 100.3095), // ~80m away
      displayName: 'Gurney Paragon Mall',
      address: 'Persiaran Gurney, Penang',
    );

    final stop1SameNameFar = NavigationStop(
      id: 'poi-far-id',
      location: distantJohor, // hundreds of km away
      displayName: 'Gurney Paragon',
      address: 'Johor Bahru',
    );

    final differentPlaceNearby = NavigationStop(
      id: 'poi-diff-near',
      location: const LatLng(5.4348, 100.3092), // ~40m away
      displayName: 'Starbucks Coffee',
      address: 'Persiaran Gurney, Penang',
    );

    test('stops with identical id are duplicate', () {
      expect(areStopsDuplicate(stop1, stop1DuplicateId), isTrue);
    });

    test('stops with matching/prefix name within 250m are duplicate', () {
      expect(areStopsDuplicate(stop1, stop1SimilarNameNearby), isTrue);
    });

    test('stops with matching name but > 250m apart are not duplicate', () {
      expect(areStopsDuplicate(stop1, stop1SameNameFar), isFalse);
    });

    test('stops with distinct names within 250m are not duplicate', () {
      expect(areStopsDuplicate(stop1, differentPlaceNearby), isFalse);
    });

    test(
      'deduplicateStops preserves first encountered stop and drops duplicate',
      () {
        final input = [stop1, stop1SimilarNameNearby, differentPlaceNearby];
        final deduped = deduplicateStops(input);

        expect(deduped, hasLength(2));
        expect(deduped[0].id, 'poi-1');
        expect(deduped[1].id, 'poi-diff-near');
      },
    );
  });

  group('rankSearchResults unit tests', () {
    final gurneyClose = NavigationStop(
      id: 'g-close',
      location: const LatLng(5.4345, 100.3090),
      displayName: 'Gurney Paragon',
      address: 'George Town, Penang',
      isDestination: true,
    );

    final gurneyFar = NavigationStop(
      id: 'g-far',
      location: distantJohor,
      displayName: 'Gurney South Plaza',
      address: 'Johor Bahru',
      isDestination: true,
    );

    final otherWithG = NavigationStop(
      id: 'other-g',
      location: const LatLng(5.4200, 100.3100),
      displayName: 'Tanjung Bungah',
      address: 'Penang',
      isDestination: true,
    );

    final tokenMatchClose = NavigationStop(
      id: 'token-match',
      location: const LatLng(5.4340, 100.3085),
      displayName: 'Grand Gurney Suites',
      address: 'Penang',
      isDestination: true,
    );

    final addressTokenMatch = NavigationStop(
      id: 'addr-match',
      location: const LatLng(5.4330, 100.3075),
      displayName: 'Seaside Hotel',
      address: 'Gurney Drive, Penang',
      isDestination: true,
    );

    test('prefix match ranks before non-prefix match', () {
      final input = [otherWithG, gurneyClose];
      final ranked = rankSearchResults(
        input,
        query: 'g',
        proximity: georgetown,
      );

      expect(ranked.first.displayName, 'Gurney Paragon');
      expect(ranked.last.displayName, 'Tanjung Bungah');
    });

    test('tier order is strictly respected: Tier 1 > Tier 2 > Tier 3', () {
      final input = [
        otherWithG,
        addressTokenMatch,
        tokenMatchClose,
        gurneyClose,
      ];
      final ranked = rankSearchResults(
        input,
        query: 'gurn',
        proximity: georgetown,
      );

      expect(ranked[0].displayName, 'Gurney Paragon'); // Tier 1
      expect(ranked[1].displayName, 'Grand Gurney Suites'); // Tier 2
      expect(ranked[2].displayName, 'Seaside Hotel'); // Tier 3
      expect(ranked, hasLength(3)); // otherWithG does not have 'gurn'
    });

    test('nearby prefix result ranks before distant prefix result', () {
      final input = [gurneyFar, gurneyClose];
      final ranked = rankSearchResults(
        input,
        query: 'g',
        proximity: georgetown,
      );

      expect(ranked.first.displayName, 'Gurney Paragon');
      expect(ranked.last.displayName, 'Gurney South Plaza');
    });

    test('case-insensitive prefix ranking', () {
      final substringMatch = NavigationStop(
        id: 'sub-match',
        location: const LatLng(5.4200, 100.3100),
        displayName: 'Old Gurney Corner',
        address: 'Penang',
        isDestination: true,
      );
      final input = [substringMatch, gurneyClose];
      final ranked = rankSearchResults(
        input,
        query: 'GUR',
        proximity: georgetown,
      );

      expect(ranked.first.displayName, 'Gurney Paragon');
      expect(ranked.last.displayName, 'Old Gurney Corner');
    });

    test('preserves provider order when prefix and proximity tie', () {
      final placeA = NavigationStop(
        id: 'a',
        location: const LatLng(5.4345, 100.3090),
        displayName: 'G Hotel Gurney',
        isDestination: true,
      );
      final placeB = NavigationStop(
        id: 'b',
        location: const LatLng(5.4345, 100.3090),
        displayName: 'G Hotel Kelawai',
        isDestination: true,
      );

      final ranked = rankSearchResults(
        [placeA, placeB],
        query: 'g',
        proximity: georgetown,
      );

      expect(ranked[0].displayName, 'G Hotel Gurney');
      expect(ranked[1].displayName, 'G Hotel Kelawai');
    });

    test('works gracefully when proximity is null', () {
      final input = [otherWithG, gurneyFar, gurneyClose];
      final ranked = rankSearchResults(input, query: 'g', proximity: null);

      expect(ranked[0].displayName, 'Gurney South Plaza');
      expect(ranked[1].displayName, 'Gurney Paragon');
      expect(ranked[2].displayName, 'Tanjung Bungah');
    });

    test(
      'empty query with null proximity returns original list unmodified',
      () {
        final input = [otherWithG, gurneyClose];
        final ranked = rankSearchResults(input, query: '', proximity: null);

        expect(ranked, equals(input));
      },
    );

    test('empty query with proximity sorts nearby places by distance', () {
      final input = [gurneyFar, gurneyClose];
      final ranked = rankSearchResults(input, query: '', proximity: georgetown);

      expect(ranked[0].displayName, 'Gurney Paragon');
      expect(ranked[1].displayName, 'Gurney South Plaza');
    });
  });

  group('DestinationSearchPage widget tests', () {
    testWidgets(
      'initial state with GPS proximity displays "Nearby Places" and cached items immediately',
      (tester) async {
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/v2/places')) {
            return http.Response(
              jsonEncode({
                'type': 'FeatureCollection',
                'features': [
                  {
                    'type': 'Feature',
                    'properties': {
                      'place_id': 'poi-1',
                      'name': 'Gurney Paragon',
                      'formatted': 'Persiaran Gurney, Penang',
                      'lat': 5.4345,
                      'lon': 100.3090,
                    },
                  },
                  {
                    'type': 'Feature',
                    'properties': {
                      'place_id': 'poi-2',
                      'name': 'G Hotel Kelawai',
                      'formatted': 'Jalan Kelawai, Penang',
                      'lat': 5.4355,
                      'lon': 100.3105,
                    },
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            '{"type":"FeatureCollection","features":[]}',
            200,
          );
        });

        final service = PlaceGeocodingService(
          client: mockClient,
          apiKey: 'test-key',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DestinationSearchPage(
              geocodingService: service,
              proximity: georgetown,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Nearby Places'), findsOneWidget);
        expect(find.text('Gurney Paragon'), findsOneWidget);
        expect(find.text('G Hotel Kelawai'), findsOneWidget);
      },
    );

    testWidgets(
      'initial state without GPS proximity displays search prompt illustration',
      (tester) async {
        var placesCalled = false;
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/v2/places')) {
            placesCalled = true;
          }
          return http.Response('{}', 200);
        });

        final service = PlaceGeocodingService(
          client: mockClient,
          apiKey: 'test-key',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DestinationSearchPage(
              geocodingService: service,
              proximity: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(placesCalled, isFalse);
        expect(find.text('Search Destinations'), findsOneWidget);
      },
    );

    testWidgets(
      'one-character query filters cached nearby places immediately before debounce',
      (tester) async {
        int textSearchCallCount = 0;
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/v2/places')) {
            return http.Response(
              jsonEncode({
                'type': 'FeatureCollection',
                'features': [
                  {
                    'type': 'Feature',
                    'properties': {
                      'place_id': 'poi-1',
                      'name': 'Gurney Paragon',
                      'formatted': 'Persiaran Gurney, Penang',
                      'lat': 5.4345,
                      'lon': 100.3090,
                    },
                  },
                  {
                    'type': 'Feature',
                    'properties': {
                      'place_id': 'poi-2',
                      'name': 'Alor Setar Mall',
                      'formatted': 'Bandar Barat, Kedah',
                      'lat': 6.1200,
                      'lon': 100.3600,
                    },
                  },
                ],
              }),
              200,
            );
          }
          textSearchCallCount++;
          return http.Response(
            jsonEncode({
              'type': 'FeatureCollection',
              'features': [
                {
                  'type': 'Feature',
                  'properties': {
                    'place_id': 'search-1',
                    'name': 'Gurney Plaza',
                    'formatted': 'Persiaran Gurney, Penang',
                    'lat': 5.4377,
                    'lon': 100.3097,
                  },
                },
              ],
            }),
            200,
          );
        });

        final service = PlaceGeocodingService(
          client: mockClient,
          apiKey: 'test-key',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DestinationSearchPage(
              geocodingService: service,
              proximity: georgetown,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final searchInput = find.byKey(
          const ValueKey('safe-navigation-search-input'),
        );

        // Type 1 single character
        await tester.enterText(searchInput, 'g');
        await tester.pump(const Duration(milliseconds: 50));

        // Before 350ms debounce: NO remote API call yet
        expect(textSearchCallCount, 0);
        // BUT cached nearby match "Gurney Paragon" is ALREADY visible immediately!
        expect(find.text('Gurney Paragon'), findsOneWidget);
        // Non-matching "Alor Setar Mall" is filtered out
        expect(find.text('Alor Setar Mall'), findsNothing);

        // Now advance past 350ms debounce
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        // Remote search was executed and combined
        expect(textSearchCallCount, 1);
        expect(find.text('Gurney Paragon'), findsOneWidget);
        expect(find.text('Gurney Plaza'), findsOneWidget);
      },
    );

    testWidgets('empty query does not make remote search API request', (
      tester,
    ) async {
      int textSearchCallCount = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/v2/places')) {
          return http.Response(
            '{"type":"FeatureCollection","features":[]}',
            200,
          );
        }
        textSearchCallCount++;
        return http.Response('{}', 200);
      });

      final service = PlaceGeocodingService(
        client: mockClient,
        apiKey: 'test-key',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DestinationSearchPage(
            geocodingService: service,
            proximity: georgetown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.byKey(
        const ValueKey('safe-navigation-search-input'),
      );
      await tester.enterText(searchInput, '   ');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(textSearchCallCount, 0);
    });

    testWidgets('rapid g -> gu -> gur produces only final intended request', (
      tester,
    ) async {
      int textSearchCallCount = 0;
      final requestedTexts = <String>[];
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/v2/places')) {
          return http.Response(
            '{"type":"FeatureCollection","features":[]}',
            200,
          );
        }
        textSearchCallCount++;
        requestedTexts.add(request.url.queryParameters['text'] ?? '');
        return http.Response(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'properties': {
                  'name': 'Gurney Paragon',
                  'formatted': 'Persiaran Gurney, George Town, Penang',
                  'lat': 5.4350,
                  'lon': 100.3100,
                },
              },
            ],
          }),
          200,
        );
      });

      final service = PlaceGeocodingService(
        client: mockClient,
        apiKey: 'test-key',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DestinationSearchPage(
            geocodingService: service,
            proximity: georgetown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.byKey(
        const ValueKey('safe-navigation-search-input'),
      );
      await tester.enterText(searchInput, 'g');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(searchInput, 'gu');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(searchInput, 'gur');
      await tester.pump(const Duration(milliseconds: 100));

      expect(textSearchCallCount, 0);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(textSearchCallCount, 1);
      expect(requestedTexts, ['gur']);
      expect(find.text('Gurney Paragon'), findsOneWidget);
    });

    testWidgets('stale one-character result cannot overwrite newer query', (
      tester,
    ) async {
      Completer<http.Response>? slowCompleter;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/v2/places')) {
          return http.Response(
            '{"type":"FeatureCollection","features":[]}',
            200,
          );
        }
        final text = request.url.queryParameters['text'] ?? '';
        if (text == 'g') {
          slowCompleter = Completer<http.Response>();
          return slowCompleter!.future;
        }
        return http.Response(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'properties': {
                  'name': 'Gurney Plaza',
                  'formatted': 'Persiaran Gurney, Penang',
                  'lat': 5.4377,
                  'lon': 100.3097,
                },
              },
            ],
          }),
          200,
        );
      });

      final service = PlaceGeocodingService(
        client: mockClient,
        apiKey: 'test-key',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DestinationSearchPage(
            geocodingService: service,
            proximity: georgetown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.byKey(
        const ValueKey('safe-navigation-search-input'),
      );
      await tester.enterText(searchInput, 'g');
      await tester.pump(const Duration(milliseconds: 400));
      expect(slowCompleter, isNotNull);

      // Now enter 'gu' which completes immediately
      await tester.enterText(searchInput, 'gu');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Gurney Plaza'), findsOneWidget);

      // Now slow 'g' completes
      slowCompleter!.complete(
        http.Response(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'properties': {
                  'name': 'George Town Heritage',
                  'formatted': 'George Town, Penang',
                  'lat': 5.4141,
                  'lon': 100.3288,
                },
              },
            ],
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();

      // 'George Town Heritage' from stale 'g' call did NOT overwrite 'Gurney Plaza'
      expect(find.text('Gurney Plaza'), findsOneWidget);
      expect(find.text('George Town Heritage'), findsNothing);
    });

    testWidgets('current GPS proximity is passed to search service', (
      tester,
    ) async {
      String? biasParam;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/v2/places')) {
          return http.Response(
            '{"type":"FeatureCollection","features":[]}',
            200,
          );
        }
        biasParam = request.url.queryParameters['bias'];
        return http.Response(
          jsonEncode({'type': 'FeatureCollection', 'features': []}),
          200,
        );
      });

      final service = PlaceGeocodingService(
        client: mockClient,
        apiKey: 'test-key',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DestinationSearchPage(
            geocodingService: service,
            proximity: georgetown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.byKey(
        const ValueKey('safe-navigation-search-input'),
      );
      await tester.enterText(searchInput, 'g');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(biasParam, contains('proximity:100.3288,5.4141'));
    });

    testWidgets('GPS unavailable allows normal search without proximity bias', (
      tester,
    ) async {
      String? biasParam;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/v2/places')) {
          return http.Response(
            '{"type":"FeatureCollection","features":[]}',
            200,
          );
        }
        biasParam = request.url.queryParameters['bias'];
        return http.Response(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'properties': {
                  'name': 'Kuala Lumpur Tower',
                  'formatted': 'Kuala Lumpur',
                  'lat': 3.1528,
                  'lon': 101.7037,
                },
              },
            ],
          }),
          200,
        );
      });

      final service = PlaceGeocodingService(
        client: mockClient,
        apiKey: 'test-key',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DestinationSearchPage(
            geocodingService: service,
            proximity: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.byKey(
        const ValueKey('safe-navigation-search-input'),
      );
      await tester.enterText(searchInput, 'k');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(biasParam, isNull);
      expect(find.text('Kuala Lumpur Tower'), findsOneWidget);
      expect(find.text('Search Results'), findsOneWidget);
    });

    testWidgets(
      'full-screen search layout renders correctly with back button, input, and distance',
      (tester) async {
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/v2/places')) {
            return http.Response(
              '{"type":"FeatureCollection","features":[]}',
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'type': 'FeatureCollection',
              'features': [
                {
                  'type': 'Feature',
                  'properties': {
                    'name': 'Gurney Paragon',
                    'formatted': '163D Persiaran Gurney, George Town, Penang',
                    'lat': 5.4345,
                    'lon': 100.3090,
                  },
                },
              ],
            }),
            200,
          );
        });

        final service = PlaceGeocodingService(
          client: mockClient,
          apiKey: 'test-key',
        );

        NavigationStop? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selected = await Navigator.of(context).push<NavigationStop>(
                    MaterialPageRoute(
                      builder: (_) => DestinationSearchPage(
                        geocodingService: service,
                        proximity: georgetown,
                      ),
                    ),
                  );
                },
                child: const Text('Open Search'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Search'));
        await tester.pumpAndSettle();

        expect(find.text('Search destination'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('safe-navigation-search-back')),
          findsOneWidget,
        );

        final input = find.byKey(
          const ValueKey('safe-navigation-search-input'),
        );
        await tester.enterText(input, 'g');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Gurney Paragon'), findsOneWidget);
        expect(
          find.text('163D Persiaran Gurney, George Town, Penang'),
          findsOneWidget,
        );
        expect(find.textContaining('away'), findsOneWidget);

        // Tap result
        await tester.tap(
          find.byKey(const ValueKey('safe-navigation-search-result-0')),
        );
        await tester.pumpAndSettle();

        expect(selected, isNotNull);
        expect(selected!.displayName, 'Gurney Paragon');
      },
    );

    testWidgets('390 px mobile viewport and 200% text scale have no overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/v2/places')) {
          return http.Response(
            '{"type":"FeatureCollection","features":[]}',
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'properties': {
                  'name': 'Gurney Paragon Shopping Mall and Residence Tower',
                  'formatted':
                      '163D Persiaran Gurney, Pulau Pinang, 10250 George Town',
                  'lat': 5.4345,
                  'lon': 100.3090,
                },
              },
            ],
          }),
          200,
        );
      });

      final service = PlaceGeocodingService(
        client: mockClient,
        apiKey: 'test-key',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DestinationSearchPage(
            geocodingService: service,
            proximity: georgetown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byKey(const ValueKey('safe-navigation-search-input'));
      await tester.enterText(input, 'g');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Gurney Paragon'), findsOneWidget);
    });

    testWidgets('remote search failure retains local nearby results', (
      tester,
    ) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/v2/places')) {
          return http.Response(
            jsonEncode({
              'type': 'FeatureCollection',
              'features': [
                {
                  'type': 'Feature',
                  'properties': {
                    'place_id': 'poi-gurney',
                    'name': 'Gurney Paragon',
                    'formatted': 'Persiaran Gurney, George Town, Penang',
                    'lat': 5.4345,
                    'lon': 100.3090,
                  },
                },
              ],
            }),
            200,
          );
        }
        // Remote search fails with 500
        return http.Response('Server error', 500);
      });

      final service = PlaceGeocodingService(
        client: mockClient,
        apiKey: 'test-key',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DestinationSearchPage(
            geocodingService: service,
            proximity: georgetown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byKey(const ValueKey('safe-navigation-search-input'));
      await tester.enterText(input, 'g');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Local match "Gurney Paragon" is preserved!
      expect(find.text('Gurney Paragon'), findsOneWidget);
      // No error message displayed because local results exist
      expect(
        find.byKey(const ValueKey('safe-navigation-search-error')),
        findsNothing,
      );
    });

    testWidgets('remote search empty features retains local nearby results', (
      tester,
    ) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/v2/places')) {
          return http.Response(
            jsonEncode({
              'type': 'FeatureCollection',
              'features': [
                {
                  'type': 'Feature',
                  'properties': {
                    'place_id': 'poi-gurney',
                    'name': 'Gurney Paragon',
                    'formatted': 'Persiaran Gurney, George Town, Penang',
                    'lat': 5.4345,
                    'lon': 100.3090,
                  },
                },
              ],
            }),
            200,
          );
        }
        // Remote search returns empty list
        return http.Response('{"type":"FeatureCollection","features":[]}', 200);
      });

      final service = PlaceGeocodingService(
        client: mockClient,
        apiKey: 'test-key',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DestinationSearchPage(
            geocodingService: service,
            proximity: georgetown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byKey(const ValueKey('safe-navigation-search-input'));
      await tester.enterText(input, 'g');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Local match "Gurney Paragon" is preserved!
      expect(find.text('Gurney Paragon'), findsOneWidget);
      expect(find.text('No matching places found.'), findsNothing);
    });

    testWidgets(
      'both local and remote returning empty displays "No matching places found."',
      (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '{"type":"FeatureCollection","features":[]}',
            200,
          );
        });

        final service = PlaceGeocodingService(
          client: mockClient,
          apiKey: 'test-key',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DestinationSearchPage(
              geocodingService: service,
              proximity: georgetown,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final input = find.byKey(
          const ValueKey('safe-navigation-search-input'),
        );
        await tester.enterText(input, 'zzz');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('No matching places found.'), findsOneWidget);
      },
    );

    testWidgets('API failure with zero local results remains user-friendly', (
      tester,
    ) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/v2/places')) {
          return http.Response(
            '{"type":"FeatureCollection","features":[]}',
            200,
          );
        }
        return http.Response('Internal Server Error', 500);
      });

      final service = PlaceGeocodingService(
        client: mockClient,
        apiKey: 'test-key',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DestinationSearchPage(
            geocodingService: service,
            proximity: georgetown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byKey(const ValueKey('safe-navigation-search-input'));
      await tester.enterText(input, 'error');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(
        find.text('Unable to search places right now. Try again.'),
        findsWidgets,
      );
    });

    testWidgets(
      'nearby POIs are only fetched once per proximity session and not on keystrokes',
      (tester) async {
        int nearbyFetchCount = 0;
        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/v2/places')) {
            nearbyFetchCount++;
            return http.Response(
              jsonEncode({
                'type': 'FeatureCollection',
                'features': [
                  {
                    'type': 'Feature',
                    'properties': {
                      'place_id': 'poi-gurney',
                      'name': 'Gurney Paragon',
                      'formatted': 'Persiaran Gurney, Penang',
                      'lat': 5.4345,
                      'lon': 100.3090,
                    },
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(
            '{"type":"FeatureCollection","features":[]}',
            200,
          );
        });

        final service = PlaceGeocodingService(
          client: mockClient,
          apiKey: 'test-key',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: DestinationSearchPage(
              geocodingService: service,
              proximity: georgetown,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(nearbyFetchCount, 1);

        final input = find.byKey(
          const ValueKey('safe-navigation-search-input'),
        );
        await tester.enterText(input, 'g');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(input, 'gu');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.enterText(input, 'gur');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        // Still exactly 1 fetch of nearby POIs!
        expect(nearbyFetchCount, 1);
      },
    );
  });
}
