import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:myheritage_explorer/models/navigation_stop.dart';
import 'package:myheritage_explorer/services/place_geocoding_service.dart';

void main() {
  const alorSetar = LatLng(6.1248, 100.3678);

  group('PlaceGeocodingService - searchPlaces', () {
    test('returns parsed NavigationStop list on successful response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'api.geoapify.com');
        expect(request.url.path, '/v1/geocode/search');
        expect(request.url.queryParameters['text'], 'Aman Central');
        expect(request.url.queryParameters['filter'], 'countrycode:my');
        expect(request.url.queryParameters['apiKey'], 'test-geo-key');

        return http.Response(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'properties': {
                  'place_id': 'place-123',
                  'name': 'Aman Central',
                  'formatted':
                      'Aman Central, Darul Aman Hwy, 05100 Alor Setar, Kedah',
                  'lat': 6.1234,
                  'lon': 100.3678,
                },
                'geometry': {
                  'type': 'Point',
                  'coordinates': [100.3678, 6.1234],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = PlaceGeocodingService(
        client: mockClient,
        apiKey: 'test-geo-key',
      );

      final results = await service.searchPlaces('Aman Central');

      expect(results, hasLength(1));
      final stop = results.first;
      expect(stop.id, 'place-123');
      expect(stop.displayName, 'Aman Central');
      expect(
        stop.address,
        'Aman Central, Darul Aman Hwy, 05100 Alor Setar, Kedah',
      );
      expect(stop.location.latitude, 6.1234);
      expect(stop.location.longitude, 100.3678);
    });

    test('includes proximity bias when provided', () async {
      late Uri capturedUri;
      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({'type': 'FeatureCollection', 'features': []}),
          200,
        );
      });

      final service = PlaceGeocodingService(
        client: mockClient,
        apiKey: 'test-geo-key',
      );

      await service.searchPlaces('Balai Besar', proximity: alorSetar);

      expect(capturedUri.queryParameters['bias'], 'proximity:100.3678,6.1248');
    });

    test(
      'returns empty list without network call when query is blank',
      () async {
        var callCount = 0;
        final mockClient = MockClient((_) async {
          callCount++;
          return http.Response('{}', 200);
        });

        final service = PlaceGeocodingService(
          client: mockClient,
          apiKey: 'test-geo-key',
        );

        final results = await service.searchPlaces('   ');

        expect(results, isEmpty);
        expect(callCount, 0);
      },
    );

    test('returns empty list gracefully on HTTP error', () async {
      final mockClient = MockClient((_) async => http.Response('Error', 500));
      final service = PlaceGeocodingService(
        client: mockClient,
        apiKey: 'test-geo-key',
      );

      final results = await service.searchPlaces('Menara Alor Setar');

      expect(results, isEmpty);
    });

    test('returns empty list gracefully on client exception', () async {
      final mockClient = MockClient(
        (_) async => throw http.ClientException('Network down'),
      );
      final service = PlaceGeocodingService(
        client: mockClient,
        apiKey: 'test-geo-key',
      );

      final results = await service.searchPlaces('Menara Alor Setar');

      expect(results, isEmpty);
    });
  });

  group('PlaceGeocodingService - reverseGeocode', () {
    test('resolves place name and address on successful response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/v1/geocode/reverse');
        expect(request.url.queryParameters['lat'], '6.1248');
        expect(request.url.queryParameters['lon'], '100.3678');

        return http.Response(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'properties': {
                  'place_id': 'rev-place-999',
                  'name': 'Masjid Zahir',
                  'formatted': 'Masjid Zahir, Jalan Bakar Bata, Alor Setar',
                  'lat': 6.1248,
                  'lon': 100.3678,
                },
              },
            ],
          }),
          200,
        );
      });

      final service = PlaceGeocodingService(
        client: mockClient,
        apiKey: 'test-geo-key',
      );

      final stop = await service.reverseGeocode(alorSetar);

      expect(stop.id, 'rev-place-999');
      expect(stop.displayName, 'Masjid Zahir');
      expect(stop.address, 'Masjid Zahir, Jalan Bakar Bata, Alor Setar');
      expect(stop.location.latitude, alorSetar.latitude);
      expect(stop.location.longitude, alorSetar.longitude);
    });

    test(
      'gracefully falls back to formatted coordinates on HTTP error',
      () async {
        final mockClient = MockClient(
          (_) async => http.Response('Forbidden', 403),
        );
        final service = PlaceGeocodingService(
          client: mockClient,
          apiKey: 'test-geo-key',
        );

        final stop = await service.reverseGeocode(alorSetar);

        expect(stop.displayName, 'Location (6.1248, 100.3678)');
        expect(stop.location, alorSetar);
        expect(stop.address, contains('6.12480'));
      },
    );

    test(
      'gracefully falls back to formatted coordinates when API key is empty',
      () async {
        var callCount = 0;
        final mockClient = MockClient((_) async {
          callCount++;
          return http.Response('{}', 200);
        });

        final service = PlaceGeocodingService(client: mockClient, apiKey: '');

        final stop = await service.reverseGeocode(alorSetar);

        expect(stop.displayName, 'Location (6.1248, 100.3678)');
        expect(callCount, 0);
      },
    );
  });

  group('NavigationStop model', () {
    test('JSON serialization and copyWith work as expected', () {
      final original = NavigationStop(
        id: 'stop-1',
        location: alorSetar,
        displayName: 'Test Stop',
        address: '123 Test St',
        isDestination: false,
      );

      final json = original.toJson();
      final restored = NavigationStop.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.displayName, original.displayName);
      expect(restored.address, original.address);
      expect(restored.location.latitude, original.location.latitude);
      expect(restored.location.longitude, original.location.longitude);
      expect(restored.isDestination, isFalse);

      final copy = original.copyWith(isDestination: true);
      expect(copy.isDestination, isTrue);
      expect(copy.id, original.id);
      expect(original == restored, isTrue);
    });
  });
}
