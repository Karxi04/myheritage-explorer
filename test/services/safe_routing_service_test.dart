import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:myheritage_explorer/core/safety_config.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/services/safe_routing_service.dart';

void main() {
  const start = LatLng(5.4141, 100.3288);
  const destination = LatLng(5.45, 100.36);

  HazardReport hazard({
    String id = 'hazard-1',
    String severity = 'High',
    String status = HazardReportStatus.verified,
    double latitude = 5.43,
    double longitude = 100.34,
  }) {
    return HazardReport(
      id: id,
      userId: 'reporter',
      category: 'Road damage',
      severity: severity,
      description: 'Test hazard',
      latitude: latitude,
      longitude: longitude,
      status: status,
    );
  }

  String successfulResponse() => jsonEncode({
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [100.3288, 5.4141],
            [100.34, 5.43],
            [100.36, 5.45],
          ],
        },
        'properties': {
          'summary': {'distance': 6123.4, 'duration': 734.5},
          'segments': [
            {
              'steps': [
                {
                  'distance': 1200.5,
                  'duration': 145.2,
                  'type': 11,
                  'instruction': 'Head northeast on Lebuh Test',
                  'name': 'Lebuh Test',
                  'way_points': [0, 1],
                },
                {
                  'distance': 4922.9,
                  'duration': 589.3,
                  'type': 10,
                  'instruction': 'Arrive at the destination',
                  'name': '-',
                  'way_points': [1, 2],
                },
              ],
            },
          ],
        },
      },
    ],
  });

  late http.Request capturedRequest;
  late int requestCount;

  SafeRoutingService serviceReturning({
    int statusCode = 200,
    String? body,
    String apiKey = 'test-key',
  }) {
    requestCount = 0;
    return SafeRoutingService(
      apiKey: apiKey,
      client: MockClient((request) async {
        requestCount++;
        capturedRequest = request;
        return http.Response(body ?? successfulResponse(), statusCode);
      }),
    );
  }

  Map<String, dynamic> capturedBody() =>
      jsonDecode(capturedRequest.body) as Map<String, dynamic>;

  dynamic avoidanceGeometry() {
    final options = capturedBody()['options'] as Map<String, dynamic>;
    return options['avoid_polygons'];
  }

  group('hazard polygon generation', () {
    test('Verified High hazard uses the SafetyConfig radius', () {
      final report = hazard(severity: 'High');
      final ring = SafeRoutingService.buildHazardPolygon(report);
      final firstPoint = SafeRoutingService.fromOrsCoordinate(ring.first);

      expect(
        SafeRoutingService.distanceMeters(
          LatLng(report.latitude, report.longitude),
          firstPoint,
        ),
        closeTo(SafetyConfig.dangerRadiusForSeverity('High'), .001),
      );
    });

    test('Verified Medium hazard uses the SafetyConfig radius', () {
      final report = hazard(severity: 'Medium');
      final ring = SafeRoutingService.buildHazardPolygon(report);
      final firstPoint = SafeRoutingService.fromOrsCoordinate(ring.first);

      expect(
        SafeRoutingService.distanceMeters(
          LatLng(report.latitude, report.longitude),
          firstPoint,
        ),
        closeTo(SafetyConfig.dangerRadiusForSeverity('Medium'), .001),
      );
    });

    test('Verified Low hazard uses the SafetyConfig radius', () {
      final report = hazard(severity: 'Low');
      final ring = SafeRoutingService.buildHazardPolygon(report);
      final firstPoint = SafeRoutingService.fromOrsCoordinate(ring.first);

      expect(
        SafeRoutingService.distanceMeters(
          LatLng(report.latitude, report.longitude),
          firstPoint,
        ),
        closeTo(SafetyConfig.dangerRadiusForSeverity('Low'), .001),
      );
    });

    test('polygon is closed', () {
      final ring = SafeRoutingService.buildHazardPolygon(hazard());

      expect(ring.last, orderedEquals(ring.first));
    });

    test('16 segments produce 17 points including closure', () {
      final ring = SafeRoutingService.buildHazardPolygon(hazard());

      expect(ring, hasLength(17));
    });
  });

  group('coordinate conversion', () {
    test('LatLng converts to ORS longitude-latitude order', () {
      expect(
        SafeRoutingService.toOrsCoordinate(start),
        orderedEquals([100.3288, 5.4141]),
      );
    });

    test('ORS longitude-latitude converts to LatLng', () {
      final point = SafeRoutingService.fromOrsCoordinate([100.3288, 5.4141]);

      expect(point.latitude, 5.4141);
      expect(point.longitude, 100.3288);
    });
  });

  group('request construction and filtering', () {
    Future<Map<String, dynamic>> requestFor(List<HazardReport> hazards) async {
      final service = serviceReturning();
      await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: hazards,
      );
      return capturedBody();
    }

    test('Pending Review hazard is excluded', () async {
      final body = await requestFor([
        hazard(status: HazardReportStatus.pendingReview),
      ]);

      expect(body, isNot(contains('options')));
    });

    test('Rejected hazard is excluded', () async {
      final body = await requestFor([
        hazard(status: HazardReportStatus.rejected),
      ]);

      expect(body, isNot(contains('options')));
    });

    test('Resolved hazard is excluded', () async {
      final body = await requestFor([
        hazard(status: HazardReportStatus.resolved),
      ]);

      expect(body, isNot(contains('options')));
    });

    test('invalid-coordinate hazard is excluded safely', () async {
      final body = await requestFor([hazard(latitude: double.nan)]);

      expect(body, isNot(contains('options')));
    });

    test('multiple Verified hazards produce a MultiPolygon', () async {
      await requestFor([
        hazard(id: 'high', severity: 'High'),
        hazard(id: 'low', severity: 'Low', latitude: 5.44, longitude: 100.35),
      ]);
      final geometry = avoidanceGeometry() as Map<String, dynamic>;

      expect(geometry['type'], 'MultiPolygon');
      expect(geometry['coordinates'], hasLength(2));
    });

    test('request contains options.avoid_polygons', () async {
      await requestFor([hazard()]);

      expect(avoidanceGeometry(), isA<Map<String, dynamic>>());
    });

    test('request uses the driving-car GeoJSON endpoint and headers', () async {
      await requestFor([hazard()]);

      expect(capturedRequest.url, SafeRoutingService.endpoint);
      expect(capturedRequest.url.path, contains('/driving-car/geojson'));
      expect(capturedRequest.headers['Authorization'], 'test-key');
      expect(capturedRequest.headers['Content-Type'], 'application/json');
      expect(
        capturedRequest.headers['Accept'],
        'application/json, application/geo+json',
      );
    });

    test('route coordinates use ORS coordinate order in request', () async {
      final body = await requestFor([]);

      expect(
        (body['coordinates'] as List).first,
        orderedEquals([100.3288, 5.4141]),
      );
    });

    test(
      'no valid hazards sends a normal request without avoid_polygons',
      () async {
        final body = await requestFor([
          hazard(status: HazardReportStatus.rejected),
          hazard(id: 'invalid', longitude: double.infinity),
        ]);

        expect(body['coordinates'], hasLength(2));
        expect(body, isNot(contains('options')));
        expect(requestCount, 1);
      },
    );
  });

  group('response parsing', () {
    late SafeRoutingService service;

    setUp(() => service = serviceReturning());

    Future<dynamic> route() => service.calculateSafeRoute(
      start: start,
      destination: destination,
      hazards: [hazard()],
    );

    test('successful GeoJSON route parses geometry in LatLng order', () async {
      final result = await route();

      expect(result.geometry, hasLength(3));
      expect(result.geometry.first.latitude, 5.4141);
      expect(result.geometry.first.longitude, 100.3288);
      expect(result.avoidedHazardIds, ['hazard-1']);
    });

    test('distance parses correctly', () async {
      expect((await route()).distanceMeters, 6123.4);
    });

    test('duration parses correctly', () async {
      expect((await route()).durationSeconds, 734.5);
    });

    test('turn instruction parses correctly', () async {
      expect(
        (await route()).steps.first.instruction,
        'Head northeast on Lebuh Test',
      );
    });

    test('road name parses correctly', () async {
      expect((await route()).steps.first.roadName, 'Lebuh Test');
    });

    test('ORS maneuver type parses correctly', () async {
      expect((await route()).steps.first.maneuverType, 11);
    });

    test('way_points geometry indexes parse correctly', () async {
      final step = (await route()).steps.first;

      expect(step.startGeometryIndex, 0);
      expect(step.endGeometryIndex, 1);
    });
  });

  group('controlled failures', () {
    test('missing API key fails before a network request', () async {
      final service = serviceReturning(apiKey: '');

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [],
        ),
        throwsA(
          isA<SafeRoutingException>().having(
            (error) => error.code,
            'code',
            SafeRoutingFailureCode.missingApiKey,
          ),
        ),
      );
      expect(requestCount, 0);
    });

    test('HTTP 429 returns a rate-limit failure', () async {
      final service = serviceReturning(statusCode: 429, body: '{}');

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [],
        ),
        throwsA(
          isA<SafeRoutingException>()
              .having(
                (error) => error.code,
                'code',
                SafeRoutingFailureCode.rateLimited,
              )
              .having((error) => error.statusCode, 'statusCode', 429),
        ),
      );
    });

    test('malformed response returns a provider parsing failure', () async {
      final service = serviceReturning(body: '{not valid json');

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [],
        ),
        throwsA(
          isA<SafeRoutingException>().having(
            (error) => error.code,
            'code',
            SafeRoutingFailureCode.malformedResponse,
          ),
        ),
      );
    });

    test('missing route feature returns no-route failure', () async {
      final service = serviceReturning(body: '{"features":[]}');

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [],
        ),
        throwsA(
          isA<SafeRoutingException>().having(
            (error) => error.code,
            'code',
            SafeRoutingFailureCode.noRoute,
          ),
        ),
      );
    });

    test('HTTP 404 returns no-route failure', () async {
      final service = serviceReturning(statusCode: 404, body: '{}');

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [],
        ),
        throwsA(
          isA<SafeRoutingException>().having(
            (error) => error.code,
            'code',
            SafeRoutingFailureCode.noRoute,
          ),
        ),
      );
    });

    test('start inside a hazard fails before the network call', () async {
      final service = serviceReturning();

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [
            hazard(latitude: start.latitude, longitude: start.longitude),
          ],
        ),
        throwsA(
          isA<SafeRoutingException>()
              .having(
                (error) => error.code,
                'code',
                SafeRoutingFailureCode.startInsideHazard,
              )
              .having((error) => error.hazardId, 'hazardId', 'hazard-1'),
        ),
      );
      expect(requestCount, 0);
    });

    test('destination inside a hazard fails before the network call', () async {
      final service = serviceReturning();

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [
            hazard(
              latitude: destination.latitude,
              longitude: destination.longitude,
            ),
          ],
        ),
        throwsA(
          isA<SafeRoutingException>()
              .having(
                (error) => error.code,
                'code',
                SafeRoutingFailureCode.destinationInsideHazard,
              )
              .having((error) => error.hazardId, 'hazardId', 'hazard-1'),
        ),
      );
      expect(requestCount, 0);
    });
  });
}

// Optional live smoke-test procedure (never part of automated tests):
// 1. Supply a restricted ORS key with --dart-define=ORS_API_KEY=... .
// 2. Choose road-connected A/B points and place a Verified hazard on the
//    ordinary shortest road, with neither endpoint inside its danger radius.
// 3. Call calculateSafeRoute and plot the returned geometry plus the exact
//    buildHazardPolygon ring.
// 4. Confirm every route segment stays outside the polygon and compare against
//    a request with no hazards; the safe route should visibly detour.
