import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:myheritage_explorer/core/safety_config.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/models/navigation_stop.dart';
import 'package:myheritage_explorer/models/safe_route.dart';
import 'package:myheritage_explorer/services/safe_routing_service.dart';

void main() {
  setUp(() {
    SafeRoutingService.clearRateLimitCooldown();
    SafeRoutingService.clearCache();
  });

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

  late http.Request capturedRequest;
  final capturedRequests = <http.Request>[];
  late int requestCount;

  String routeResponse({
    required List<List<double>> coordinates,
    double distance = 1000.0,
    double duration = 120.0,
    List<Map<String, dynamic>>? steps,
  }) {
    final stepList =
        steps ??
        [
          {
            'distance': distance,
            'duration': duration,
            'type': 11,
            'instruction': 'Continue',
            'name': 'Road',
            'way_points': [0, coordinates.length - 1],
          },
        ];
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {'type': 'LineString', 'coordinates': coordinates},
          'properties': {
            'summary': {'distance': distance, 'duration': duration},
            'segments': [
              {'steps': stepList},
            ],
          },
        },
      ],
    });
  }

  SafeRoutingService serviceReturning({
    int statusCode = 200,
    String? body,
    String apiKey = 'test-key',
    Future<http.Response> Function(http.Request request, int count)? handler,
  }) {
    requestCount = 0;
    capturedRequests.clear();
    return SafeRoutingService(
      apiKey: apiKey,
      client: MockClient((request) async {
        requestCount++;
        capturedRequest = request;
        capturedRequests.add(request);
        if (handler != null) return handler(request, requestCount);
        if (body != null) return http.Response(body, statusCode);
        if (statusCode != 200) return http.Response('{}', statusCode);

        final reqBody = jsonDecode(request.body) as Map<String, dynamic>;
        final reqCoords = (reqBody['coordinates'] as List)
            .map((c) => (c as List).map((n) => (n as num).toDouble()).toList())
            .toList();
        final c1 = reqCoords[0];
        final c2 = reqCoords[1];
        final mid = [(c1[0] + c2[0]) / 2, (c1[1] + c2[1]) / 2];

        return http.Response(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'geometry': {
                  'type': 'LineString',
                  'coordinates': [c1, mid, c2],
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
          }),
          statusCode,
        );
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

      expect(
        SafeRoutingService.endpointUrl,
        'https://api.heigit.org/openrouteservice/v2/directions/driving-car/geojson',
      );
      expect(capturedRequest.url, SafeRoutingService.endpoint);
      expect(capturedRequest.url.toString(), SafeRoutingService.endpointUrl);
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

    test('HTTP 401 maps to unauthorized', () async {
      final service = serviceReturning(statusCode: 401, body: '{}');

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
                SafeRoutingFailureCode.unauthorized,
              )
              .having((error) => error.statusCode, 'statusCode', 401)
              .having((error) => error.message, 'message', contains('401')),
        ),
      );
    });

    test('HTTP 403 maps to unauthorized/forbidden appropriately', () async {
      final service = serviceReturning(statusCode: 403, body: '{}');

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
                SafeRoutingFailureCode.unauthorized,
              )
              .having((error) => error.statusCode, 'statusCode', 403)
              .having(
                (error) => error.message,
                'message',
                contains('403 Forbidden'),
              ),
        ),
      );
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

    test(
      'generic HTTP 404 without ORS error code returns provider failure',
      () async {
        final service = serviceReturning(
          statusCode: 404,
          body: '{"error":{"message":"Endpoint not found"}}',
        );

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
                  SafeRoutingFailureCode.providerFailure,
                )
                .having((error) => error.statusCode, 'statusCode', 404),
          ),
        );
      },
    );

    test('HTTP 404 with ORS error code 2009 maps to noRoute', () async {
      final service = serviceReturning(
        statusCode: 404,
        body:
            '{"error":{"code":2009,"message":"Route could not be found - Unable to find a route between points"}}',
      );

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
                SafeRoutingFailureCode.noRoute,
              )
              .having((error) => error.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('HTTP 404 with ORS error code 2016 maps to noRoute', () async {
      final service = serviceReturning(
        statusCode: 404,
        body:
            '{"error":{"code":2016,"message":"Could not find point 0 within a radius of 350.0 meters"}}',
      );

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
                SafeRoutingFailureCode.noRoute,
              )
              .having((error) => error.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('HTTP 404 with ORS error code 2010 remains providerFailure', () async {
      final service = serviceReturning(
        statusCode: 404,
        body:
            '{"error":{"code":2010,"message":"Could not find routable point within a radius of 350.0 meters"}}',
      );

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [
            hazard(id: '2010-high', severity: 'High'),
            hazard(
              id: '2010-medium',
              severity: 'Medium',
              latitude: 5.435,
              longitude: 100.345,
            ),
            hazard(
              id: '2010-low',
              severity: 'Low',
              latitude: 5.44,
              longitude: 100.35,
            ),
          ],
        ),
        throwsA(
          isA<SafeRoutingException>()
              .having(
                (error) => error.code,
                'code',
                SafeRoutingFailureCode.providerFailure,
              )
              .having((error) => error.orsErrorCode, 'orsErrorCode', 2010),
        ),
      );
      expect(requestCount, 1);
      final polygons =
          ((capturedBody()['options'] as Map<String, dynamic>)['avoid_polygons']
                  as Map<String, dynamic>)['coordinates']
              as List;
      expect(polygons, hasLength(3));
    });

    test('a genuine ORS no-route code maps to no-route', () async {
      final service = serviceReturning(
        statusCode: 400,
        body: '{"error":{"code":2009,"message":"Route could not be found"}}',
      );

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

  group('API key resolution and environment handling', () {
    test(
      'production SafeRoutingService resolves ORS_API_KEY correctly when supplied through dart-define',
      () {
        expect(
          SafeRoutingService.defaultEnvironmentApiKey,
          const String.fromEnvironment('ORS_API_KEY', defaultValue: ''),
        );
      },
    );

    test('an explicitly injected API key still works for tests', () {
      final service = SafeRoutingService(apiKey: 'custom-injected-key');
      expect(service.apiKey, 'custom-injected-key');
    });

    test(
      'empty injected values do not accidentally override a configured environment key',
      () {
        final resolved = SafeRoutingService.resolveApiKey('   ');
        expect(
          resolved,
          SafeRoutingService.sanitizeApiKey(
            SafeRoutingService.defaultEnvironmentApiKey,
          ),
        );
      },
    );

    test('sanitizeApiKey trims whitespace and strips quotes safely', () {
      expect(SafeRoutingService.sanitizeApiKey('  abc123  '), 'abc123');
      expect(SafeRoutingService.sanitizeApiKey('"quoted-key"'), 'quoted-key');
      expect(
        SafeRoutingService.sanitizeApiKey("'single-quoted'"),
        'single-quoted',
      );
      expect(SafeRoutingService.sanitizeApiKey(''), '');
      expect(SafeRoutingService.sanitizeApiKey(null), '');
    });
  });

  group('escape mode (start inside hazard)', () {
    test(
      'start outside hazards uses existing single-request behavior',
      () async {
        final service = serviceReturning();
        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [hazard(latitude: 5.43, longitude: 100.34)],
        );

        expect(requestCount, 1);
        expect(result.startedInsideHazard, isFalse);
        expect(result.escapeHazardIds, isEmpty);
      },
    );

    test(
      'start inside High hazard allows route calculation via escape mode',
      () async {
        final highHazard = hazard(
          id: 'high-hazard',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            return http.Response(
              routeResponse(
                coordinates: count == 1
                    ? [
                        [100.3288, 5.4141],
                        [100.334, 5.419],
                      ]
                    : [
                        [100.334, 5.419],
                        [100.345, 5.43],
                        [100.36, 5.45],
                      ],
                distance: count == 1 ? 800.0 : 4000.0,
                duration: count == 1 ? 120.0 : 500.0,
              ),
              200,
            );
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [highHazard],
        );

        expect(requestCount, 2);
        expect(result.startedInsideHazard, isTrue);
        expect(result.escapeHazardIds, ['high-hazard']);
        expect(result.distanceMeters, 4800.0);
        expect(result.durationSeconds, 620.0);
      },
    );

    test('start inside Medium hazard allows route calculation', () async {
      final medHazard = hazard(
        id: 'med-hazard',
        severity: 'Medium',
        latitude: start.latitude,
        longitude: start.longitude,
      );

      final service = serviceReturning();
      final result = await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [medHazard],
      );

      expect(requestCount, 2);
      expect(result.startedInsideHazard, isTrue);
      expect(result.escapeHazardIds, ['med-hazard']);
    });

    test('start inside Low hazard allows route calculation', () async {
      final lowHazard = hazard(
        id: 'low-hazard',
        severity: 'Low',
        latitude: start.latitude,
        longitude: start.longitude,
      );

      final service = serviceReturning();
      final result = await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [lowHazard],
      );

      expect(requestCount, 2);
      expect(result.startedInsideHazard, isTrue);
      expect(result.escapeHazardIds, ['low-hazard']);
    });

    test(
      'escape candidate point is outside starting hazard radius plus safety margin',
      () {
        final h = hazard(
          id: 'hazard-1',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );
        final candidate = SafeRoutingService.findCandidateEscapePoint(
          start: start,
          destination: destination,
          containingHazards: [h],
          unrelatedHazards: [],
          bearingOffset: 0,
        );

        expect(candidate, isNotNull);
        final dist = SafeRoutingService.distanceMeters(
          LatLng(h.latitude, h.longitude),
          candidate!,
        );
        final expectedRadius = SafetyConfig.dangerRadiusForSeverity('High');
        expect(
          dist,
          greaterThanOrEqualTo(
            expectedRadius + SafetyConfig.escapeSafetyMarginMeters - 0.5,
          ),
        );
      },
    );

    test(
      'tourist inside overlapping hazards produces escape point outside ALL containing hazards',
      () {
        final h1 = hazard(
          id: 'hazard-1',
          severity: 'Medium',
          latitude: start.latitude,
          longitude: start.longitude,
        );
        final h2 = hazard(
          id: 'hazard-2',
          severity: 'High',
          latitude: start.latitude + 0.001,
          longitude: start.longitude + 0.001,
        );

        final candidate = SafeRoutingService.findCandidateEscapePoint(
          start: start,
          destination: destination,
          containingHazards: [h1, h2],
          unrelatedHazards: [],
          bearingOffset: 0,
        );

        expect(candidate, isNotNull);
        final dist1 = SafeRoutingService.distanceMeters(
          LatLng(h1.latitude, h1.longitude),
          candidate!,
        );
        final dist2 = SafeRoutingService.distanceMeters(
          LatLng(h2.latitude, h2.longitude),
          candidate,
        );
        expect(
          dist1,
          greaterThan(SafetyConfig.dangerRadiusForSeverity(h1.severity)),
        );
        expect(
          dist2,
          greaterThan(SafetyConfig.dangerRadiusForSeverity(h2.severity)),
        );
      },
    );

    test(
      'candidate outside one hazard but inside another active hazard is rejected',
      () {
        final containing = hazard(
          id: 'containing',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );
        final unobstructedCandidate =
            SafeRoutingService.findCandidateEscapePoint(
              start: start,
              destination: destination,
              containingHazards: [containing],
              unrelatedHazards: const [],
              bearingOffset: 0,
            )!;
        final otherHazard = hazard(
          id: 'other',
          severity: 'Low',
          latitude: unobstructedCandidate.latitude,
          longitude: unobstructedCandidate.longitude,
        );

        final rejected = SafeRoutingService.findCandidateEscapePoint(
          start: start,
          destination: destination,
          containingHazards: [containing],
          unrelatedHazards: [otherHazard],
          bearingOffset: 0,
        );

        expect(rejected, isNull);
      },
    );

    test('first ORS 2009 escape candidate advances to next bearing', () async {
      final containing = hazard(
        id: 'containing',
        severity: 'High',
        latitude: start.latitude,
        longitude: start.longitude,
      );
      final service = serviceReturning(
        handler: (request, count) async {
          if (count == 1) {
            return http.Response(
              '{"error":{"code":2009,"message":"Route could not be found"}}',
              404,
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final coordinates = (body['coordinates'] as List)
              .map((coordinate) => List<double>.from(coordinate as List))
              .toList();
          return http.Response(routeResponse(coordinates: coordinates), 200);
        },
      );

      final result = await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [containing],
      );

      expect(requestCount, 3);
      final firstCandidate =
          (jsonDecode(capturedRequests[0].body)['coordinates'] as List)[1];
      final secondCandidate =
          (jsonDecode(capturedRequests[1].body)['coordinates'] as List)[1];
      expect(secondCandidate, isNot(orderedEquals(firstCandidate)));
      expect(result.startedInsideHazard, isTrue);
    });

    test('first ORS 2016 escape candidate advances to next bearing', () async {
      final containing = hazard(
        id: 'containing-2016',
        severity: 'High',
        latitude: start.latitude,
        longitude: start.longitude,
      );
      final service = serviceReturning(
        handler: (request, count) async {
          if (count == 1) {
            return http.Response(
              '{"error":{"code":2016,"message":"Could not find point within a radius of 350.0 meters"}}',
              404,
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final coordinates = (body['coordinates'] as List)
              .map((coordinate) => List<double>.from(coordinate as List))
              .toList();
          return http.Response(routeResponse(coordinates: coordinates), 200);
        },
      );

      final result = await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [containing],
      );

      expect(requestCount, 3);
      expect(result.startedInsideHazard, isTrue);
    });

    test('first ORS 2010 escape candidate advances to second bearing', () async {
      final containing = hazard(
        id: 'containing-2010',
        severity: 'High',
        latitude: start.latitude,
        longitude: start.longitude,
      );
      final service = serviceReturning(
        handler: (request, count) async {
          if (count == 1) {
            return http.Response(
              '{"error":{"code":2010,"message":"Could not find routable point within a radius of 350.0 meters of specified coordinate 1"}}',
              404,
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final coordinates = (body['coordinates'] as List)
              .map((coordinate) => List<double>.from(coordinate as List))
              .toList();
          return http.Response(routeResponse(coordinates: coordinates), 200);
        },
      );

      final result = await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [containing],
      );

      expect(requestCount, 3);
      final firstCandidate =
          (jsonDecode(capturedRequests[0].body)['coordinates'] as List)[1];
      final secondCandidate =
          (jsonDecode(capturedRequests[1].body)['coordinates'] as List)[1];
      expect(secondCandidate, isNot(orderedEquals(firstCandidate)));
      expect(result.startedInsideHazard, isTrue);
    });

    test('several ORS 2010 candidates do not stop later bearings', () async {
      final containing = hazard(
        id: 'containing-several-2010',
        severity: 'High',
        latitude: start.latitude,
        longitude: start.longitude,
      );
      final service = serviceReturning(
        handler: (request, count) async {
          if (count <= 3) {
            return http.Response(
              '{"error":{"code":2010,"message":"Candidate is not routable"}}',
              404,
            );
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final coordinates = (body['coordinates'] as List)
              .map((coordinate) => List<double>.from(coordinate as List))
              .toList();
          return http.Response(routeResponse(coordinates: coordinates), 200);
        },
      );

      final result = await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [containing],
      );

      expect(requestCount, 5);
      expect(result.startedInsideHazard, isTrue);
    });

    test(
      'all eight ORS 2010 candidates reach route-derived fallback',
      () async {
        final containing = hazard(
          id: 'containing-all-2010',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );
        final bearing = SafeRoutingService.initialBearingDegrees(
          start,
          destination,
        );
        final exit = SafeRoutingService.computeDestinationPoint(
          start,
          SafetyConfig.highSeverityRadiusMeters + 60,
          bearing,
        );
        final service = serviceReturning(
          handler: (request, count) async {
            if (count <= SafeRoutingService.escapeBearingOffsets.length) {
              return http.Response(
                '{"error":{"code":2010,"message":"Candidate is not routable"}}',
                404,
              );
            }
            if (count == SafeRoutingService.escapeBearingOffsets.length + 1) {
              return http.Response(
                routeResponse(
                  coordinates: [
                    [start.longitude, start.latitude],
                    [exit.longitude, exit.latitude],
                    [destination.longitude, destination.latitude],
                  ],
                ),
                200,
              );
            }
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final coordinates = (body['coordinates'] as List)
                .map((coordinate) => List<double>.from(coordinate as List))
                .toList();
            return http.Response(routeResponse(coordinates: coordinates), 200);
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        );

        expect(
          requestCount,
          SafeRoutingService.escapeBearingOffsets.length + 2,
        );
        final fallbackCoordinates =
            jsonDecode(
                  capturedRequests[SafeRoutingService
                          .escapeBearingOffsets
                          .length]
                      .body,
                )['coordinates']
                as List;
        expect(
          fallbackCoordinates.last,
          orderedEquals([destination.longitude, destination.latitude]),
        );
        expect(result.startedInsideHazard, isTrue);
      },
    );

    test('ORS 2010 never progressively relaxes escape avoidance', () async {
      final containing = hazard(
        id: 'containing-no-relax',
        severity: 'High',
        latitude: start.latitude,
        longitude: start.longitude,
      );
      final unrelatedLow = hazard(
        id: 'unrelated-low',
        severity: 'Low',
        latitude: 5.49,
        longitude: 100.40,
      );
      final service = serviceReturning(
        statusCode: 404,
        body: '{"error":{"code":2010,"message":"Candidate is not routable"}}',
      );

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing, unrelatedLow],
        ),
        throwsA(
          isA<SafeRoutingException>()
              .having(
                (error) => error.code,
                'code',
                SafeRoutingFailureCode.providerFailure,
              )
              .having((error) => error.orsErrorCode, 'orsErrorCode', 2010),
        ),
      );

      expect(requestCount, SafeRoutingService.escapeBearingOffsets.length + 1);
      for (final request in capturedRequests) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final polygons =
            ((body['options'] as Map<String, dynamic>)['avoid_polygons']
                    as Map<String, dynamic>)['coordinates']
                as List;
        expect(polygons, hasLength(1));
      }
    });

    for (final failure in <(int, SafeRoutingFailureCode)>[
      (401, SafeRoutingFailureCode.unauthorized),
      (403, SafeRoutingFailureCode.unauthorized),
      (404, SafeRoutingFailureCode.providerFailure),
      (429, SafeRoutingFailureCode.rateLimited),
      (500, SafeRoutingFailureCode.providerUnavailable),
    ]) {
      test(
        'escape candidate HTTP ${failure.$1} aborts without trying another bearing',
        () async {
          final containing = hazard(
            id: 'containing-provider-${failure.$1}',
            severity: 'High',
            latitude: start.latitude,
            longitude: start.longitude,
          );
          final service = serviceReturning(statusCode: failure.$1);

          await expectLater(
            service.calculateSafeRoute(
              start: start,
              destination: destination,
              hazards: [containing],
            ),
            throwsA(
              isA<SafeRoutingException>().having(
                (error) => error.code,
                'code',
                failure.$2,
              ),
            ),
          );
          expect(requestCount, 1);
        },
      );
    }

    test('escape candidate network failure aborts immediately', () async {
      requestCount = 0;
      final containing = hazard(
        id: 'containing-network',
        severity: 'High',
        latitude: start.latitude,
        longitude: start.longitude,
      );
      final service = SafeRoutingService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          requestCount++;
          throw http.ClientException('offline', request.url);
        }),
      );

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        ),
        throwsA(
          isA<SafeRoutingException>().having(
            (error) => error.code,
            'code',
            SafeRoutingFailureCode.networkFailure,
          ),
        ),
      );
      expect(requestCount, 1);
    });

    test('escape candidate timeout aborts immediately', () async {
      requestCount = 0;
      final pendingResponse = Completer<http.Response>();
      final containing = hazard(
        id: 'containing-timeout',
        severity: 'High',
        latitude: start.latitude,
        longitude: start.longitude,
      );
      final service = SafeRoutingService(
        apiKey: 'test-key',
        timeout: const Duration(milliseconds: 10),
        client: MockClient((request) {
          requestCount++;
          return pendingResponse.future;
        }),
      );

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        ),
        throwsA(
          isA<SafeRoutingException>().having(
            (error) => error.code,
            'code',
            SafeRoutingFailureCode.timeout,
          ),
        ),
      );
      expect(requestCount, 1);
    });

    test('malformed escape response aborts immediately', () async {
      final containing = hazard(
        id: 'containing-malformed',
        severity: 'High',
        latitude: start.latitude,
        longitude: start.longitude,
      );
      final service = serviceReturning(body: '{"features":"bad"}');

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        ),
        throwsA(
          isA<SafeRoutingException>().having(
            (error) => error.code,
            'code',
            SafeRoutingFailureCode.malformedResponse,
          ),
        ),
      );
      expect(requestCount, 1);
    });

    test(
      'Phase 1 exempts containing hazards but retains unrelated hazards',
      () async {
        final containing = hazard(
          id: 'containing-hazard',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );
        final unrelated = hazard(
          id: 'unrelated-hazard',
          severity: 'Low',
          latitude: 5.44,
          longitude: 100.35,
        );

        final service = serviceReturning();
        await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing, unrelated],
        );

        expect(capturedRequests, hasLength(2));

        final phase1Body =
            jsonDecode(capturedRequests[0].body) as Map<String, dynamic>;
        final phase1Options = phase1Body['options'] as Map<String, dynamic>;
        final phase1Avoid =
            phase1Options['avoid_polygons'] as Map<String, dynamic>;
        final phase1Coords = phase1Avoid['coordinates'] as List;
        expect(phase1Coords, hasLength(1));

        final phase2Body =
            jsonDecode(capturedRequests[1].body) as Map<String, dynamic>;
        final phase2Options = phase2Body['options'] as Map<String, dynamic>;
        final phase2Avoid =
            phase2Options['avoid_polygons'] as Map<String, dynamic>;
        final phase2Coords = phase2Avoid['coordinates'] as List;
        expect(phase2Coords, hasLength(2));
      },
    );

    test(
      'overlapping start hazards are all excluded only for the escape request',
      () async {
        final containingHigh = hazard(
          id: 'containing-high',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );
        final containingMedium = hazard(
          id: 'containing-medium',
          severity: 'Medium',
          latitude: start.latitude + 0.0002,
          longitude: start.longitude,
        );
        final unrelated = hazard(
          id: 'unrelated-low',
          severity: 'Low',
          latitude: 5.44,
          longitude: 100.35,
        );
        final service = serviceReturning();

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containingHigh, containingMedium, unrelated],
        );

        final escapeCoordinates =
            (((jsonDecode(capturedRequests[0].body)
                            as Map<String, dynamic>)['options']
                        as Map<String, dynamic>)['avoid_polygons']
                    as Map<String, dynamic>)['coordinates']
                as List;
        final normalCoordinates =
            (((jsonDecode(capturedRequests[1].body)
                            as Map<String, dynamic>)['options']
                        as Map<String, dynamic>)['avoid_polygons']
                    as Map<String, dynamic>)['coordinates']
                as List;

        expect(escapeCoordinates, hasLength(1));
        expect(normalCoordinates, hasLength(3));
        expect(
          result.escapeHazardIds,
          unorderedEquals([containingHigh.id, containingMedium.id]),
        );
      },
    );

    test(
      'combined route geometry correctly skips duplicate shared escape coordinate',
      () async {
        final containing = hazard(
          id: 'containing-hazard',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            return http.Response(
              routeResponse(
                coordinates: count == 1
                    ? [
                        [100.3288, 5.4141],
                        [100.334, 5.419],
                      ]
                    : [
                        [100.334, 5.419],
                        [100.345, 5.43],
                        [100.36, 5.45],
                      ],
              ),
              200,
            );
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        );

        expect(result.geometry, hasLength(4));
        expect(result.geometry[0], const LatLng(5.4141, 100.3288));
        expect(result.geometry[1], const LatLng(5.419, 100.334));
        expect(result.geometry[2], const LatLng(5.43, 100.345));
        expect(result.geometry[3], const LatLng(5.45, 100.36));
      },
    );

    test(
      'navigation step geometry indexes remain valid after merging',
      () async {
        final containing = hazard(
          id: 'containing-hazard',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            if (count == 1) {
              return http.Response(
                routeResponse(
                  coordinates: [
                    [100.3288, 5.4141],
                    [100.334, 5.419],
                  ],
                  steps: [
                    {
                      'instruction': 'Exit flood area',
                      'name': 'Escape St',
                      'distance': 600.0,
                      'duration': 80.0,
                      'type': 11,
                      'way_points': [0, 1],
                    },
                  ],
                ),
                200,
              );
            } else {
              return http.Response(
                routeResponse(
                  coordinates: [
                    [100.334, 5.419],
                    [100.345, 5.43],
                    [100.36, 5.45],
                  ],
                  steps: [
                    {
                      'instruction': 'Turn left onto Main St',
                      'name': 'Main St',
                      'distance': 2000.0,
                      'duration': 200.0,
                      'type': 0,
                      'way_points': [0, 1],
                    },
                    {
                      'instruction': 'Arrive at destination',
                      'name': '-',
                      'distance': 3000.0,
                      'duration': 300.0,
                      'type': 10,
                      'way_points': [1, 2],
                    },
                  ],
                ),
                200,
              );
            }
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        );

        expect(result.steps, hasLength(3));
        expect(result.steps[0].instruction, 'Exit flood area');
        expect(result.steps[0].startGeometryIndex, 0);
        expect(result.steps[0].endGeometryIndex, 1);

        expect(result.steps[1].instruction, 'Turn left onto Main St');
        expect(result.steps[1].startGeometryIndex, 1);
        expect(result.steps[1].endGeometryIndex, 2);

        expect(result.steps[2].instruction, 'Arrive at destination');
        expect(result.steps[2].startGeometryIndex, 2);
        expect(result.steps[2].endGeometryIndex, 3);
      },
    );

    test(
      'unroutable escape point produces controlled noRoute failure',
      () async {
        final containing = hazard(
          id: 'containing-hazard',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );

        final service = serviceReturning(body: '{"features":[]}');

        await expectLater(
          service.calculateSafeRoute(
            start: start,
            destination: destination,
            hazards: [containing],
          ),
          throwsA(
            isA<SafeRoutingException>().having(
              (error) => error.code,
              'code',
              SafeRoutingFailureCode.noRoute,
            ),
          ),
        );
      },
    );

    test('radial retries stay bounded before route-derived fallback', () async {
      final containing = hazard(
        id: 'containing-hazard',
        severity: 'High',
        latitude: start.latitude,
        longitude: start.longitude,
      );

      final service = serviceReturning(body: '{"features":[]}');

      try {
        await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        );
      } catch (_) {}

      expect(
        requestCount,
        lessThanOrEqualTo(SafeRoutingService.escapeBearingOffsets.length + 4),
      );
    });
  });

  group('route-derived escape fallback', () {
    List<List<double>> requestCoordinates(http.Request request) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return (body['coordinates'] as List)
          .map(
            (coordinate) => (coordinate as List)
                .map((value) => (value as num).toDouble())
                .toList(),
          )
          .toList();
    }

    http.Response roadRoute(
      List<LatLng> geometry, {
      double distance = 3000,
      double duration = 360,
    }) => http.Response(
      routeResponse(
        coordinates: geometry
            .map((point) => [point.longitude, point.latitude])
            .toList(),
        distance: distance,
        duration: duration,
      ),
      200,
    );

    for (final severity in ['High', 'Medium', 'Low']) {
      test(
        'start inside $severity succeeds when radial points are unroutable',
        () async {
          final containing = hazard(
            id: 'start-${severity.toLowerCase()}',
            severity: severity,
            latitude: start.latitude,
            longitude: start.longitude,
          );
          final bearing = SafeRoutingService.initialBearingDegrees(
            start,
            destination,
          );
          final inside = SafeRoutingService.computeDestinationPoint(
            start,
            SafetyConfig.dangerRadiusForSeverity(severity) / 2,
            bearing,
          );
          final exit = SafeRoutingService.computeDestinationPoint(
            start,
            SafetyConfig.dangerRadiusForSeverity(severity) + 60,
            bearing,
          );

          final service = serviceReturning(
            handler: (request, count) async {
              if (count <= SafeRoutingService.escapeBearingOffsets.length) {
                return http.Response('{"features":[]}', 200);
              }
              if (count == SafeRoutingService.escapeBearingOffsets.length + 1) {
                return roadRoute([start, inside, exit, destination]);
              }
              return roadRoute([exit, destination]);
            },
          );

          final result = await service.calculateSafeRoute(
            start: start,
            destination: destination,
            hazards: [containing],
          );

          expect(result.startedInsideHazard, isTrue);
          expect(result.escapeHazardIds, [containing.id]);
          expect(result.riskLevel, RouteRiskLevel.hazardFree);
          expect(
            SafeRoutingService.firstCompleteExitIndex(
              geometry: result.geometry,
              containingHazards: [containing],
            ),
            greaterThan(0),
          );
          expect(result.geometry.last, destination);
        },
      );
    }

    test(
      'start inside High hazard succeeds when radial points return HTTP 404 with code 2009',
      () async {
        final containing = hazard(
          id: 'start-high-2009',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );
        final bearing = SafeRoutingService.initialBearingDegrees(
          start,
          destination,
        );
        final inside = SafeRoutingService.computeDestinationPoint(
          start,
          SafetyConfig.dangerRadiusForSeverity('High') / 2,
          bearing,
        );
        final exit = SafeRoutingService.computeDestinationPoint(
          start,
          SafetyConfig.dangerRadiusForSeverity('High') + 60,
          bearing,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            if (count <= SafeRoutingService.escapeBearingOffsets.length) {
              return http.Response(
                '{"error":{"code":2009,"message":"Route could not be found - Unable to find a route between points"}}',
                404,
              );
            }
            if (count == SafeRoutingService.escapeBearingOffsets.length + 1) {
              return roadRoute([start, inside, exit, destination]);
            }
            return roadRoute([exit, destination]);
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        );

        expect(result.startedInsideHazard, isTrue);
        expect(result.escapeHazardIds, [containing.id]);
        expect(result.riskLevel, RouteRiskLevel.hazardFree);
        expect(
          SafeRoutingService.firstCompleteExitIndex(
            geometry: result.geometry,
            containingHazards: [containing],
          ),
          greaterThan(0),
        );
        expect(result.geometry.last, destination);
      },
    );

    test(
      'provider snap directly outside still retains the real start',
      () async {
        final containing = hazard(
          id: 'start-low',
          severity: 'Low',
          latitude: start.latitude,
          longitude: start.longitude,
        );
        final bearing = SafeRoutingService.initialBearingDegrees(
          start,
          destination,
        );
        final snappedExit = SafeRoutingService.computeDestinationPoint(
          start,
          SafetyConfig.lowSeverityRadiusMeters + 60,
          bearing,
        );
        final firstFallbackRequest =
            SafeRoutingService.escapeBearingOffsets.length + 1;
        final service = serviceReturning(
          handler: (request, count) async {
            if (count < firstFallbackRequest) {
              return http.Response('{"features":[]}', 200);
            }
            return roadRoute([snappedExit, destination]);
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        );

        expect(result.geometry.first, start);
        expect(result.geometry[1], snappedExit);
        expect(result.startedInsideHazard, isTrue);
      },
    );

    test(
      'route-derived probe retains all unrelated hazards and Phase 2 restores start hazards',
      () async {
        final containing = hazard(
          id: 'start-high',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );
        final unrelatedMedium = hazard(
          id: 'unrelated-medium',
          severity: 'Medium',
          latitude: 5.47,
          longitude: 100.38,
        );
        final unrelatedLow = hazard(
          id: 'unrelated-low',
          severity: 'Low',
          latitude: 5.49,
          longitude: 100.40,
        );
        final bearing = SafeRoutingService.initialBearingDegrees(
          start,
          destination,
        );
        final exit = SafeRoutingService.computeDestinationPoint(
          start,
          SafetyConfig.highSeverityRadiusMeters + 60,
          bearing,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            if (count <= SafeRoutingService.escapeBearingOffsets.length) {
              return http.Response('{"features":[]}', 200);
            }
            if (count == SafeRoutingService.escapeBearingOffsets.length + 1) {
              return roadRoute([start, exit, destination]);
            }
            return roadRoute([exit, destination]);
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing, unrelatedMedium, unrelatedLow],
        );

        final probeBody =
            jsonDecode(
                  capturedRequests[SafeRoutingService
                          .escapeBearingOffsets
                          .length]
                      .body,
                )
                as Map<String, dynamic>;
        final phase2Body =
            jsonDecode(
                  capturedRequests[SafeRoutingService
                              .escapeBearingOffsets
                              .length +
                          1]
                      .body,
                )
                as Map<String, dynamic>;
        final probePolygons =
            ((probeBody['options'] as Map<String, dynamic>)['avoid_polygons']
                    as Map<String, dynamic>)['coordinates']
                as List;
        final phase2Polygons =
            ((phase2Body['options'] as Map<String, dynamic>)['avoid_polygons']
                    as Map<String, dynamic>)['coordinates']
                as List;

        expect(probePolygons, hasLength(2));
        expect(phase2Polygons, hasLength(3));
        expect(result.riskLevel, RouteRiskLevel.hazardFree);
      },
    );

    test(
      'route-derived normal-route re-entry fails without relaxing safety',
      () async {
        final containing = hazard(
          id: 'start-high',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );
        final unrelatedLow = hazard(
          id: 'unrelated-low',
          severity: 'Low',
          latitude: 5.47,
          longitude: 100.38,
        );
        final bearing = SafeRoutingService.initialBearingDegrees(
          start,
          destination,
        );
        final exit = SafeRoutingService.computeDestinationPoint(
          start,
          SafetyConfig.highSeverityRadiusMeters + 60,
          bearing,
        );
        final reentry = SafeRoutingService.computeDestinationPoint(
          start,
          SafetyConfig.highSeverityRadiusMeters / 2,
          bearing,
        );

        final firstFallbackRequest =
            SafeRoutingService.escapeBearingOffsets.length + 1;
        final service = serviceReturning(
          handler: (request, count) async {
            if (count <= SafeRoutingService.escapeBearingOffsets.length) {
              return http.Response('{"features":[]}', 200);
            }
            if (count == firstFallbackRequest) {
              return roadRoute([start, exit, destination]);
            }
            if (count == firstFallbackRequest + 1) {
              return roadRoute([exit, reentry, destination]);
            }
            return roadRoute([exit, destination]);
          },
        );

        await expectLater(
          service.calculateSafeRoute(
            start: start,
            destination: destination,
            hazards: [containing, unrelatedLow],
          ),
          throwsA(
            isA<SafeRoutingException>().having(
              (error) => error.code,
              'code',
              SafeRoutingFailureCode.noRoute,
            ),
          ),
        );

        expect(requestCount, firstFallbackRequest + 1);
      },
    );

    test('Level 2 succeeds in Escape Mode', () async {
      final containingLow = hazard(
        id: 'start-low',
        severity: 'Low',
        latitude: start.latitude,
        longitude: start.longitude,
      );
      final bearing = SafeRoutingService.initialBearingDegrees(
        start,
        destination,
      );
      final exit = SafeRoutingService.computeDestinationPoint(
        start,
        SafetyConfig.lowSeverityRadiusMeters + 60,
        bearing,
      );
      final firstFallbackRequest =
          SafeRoutingService.escapeBearingOffsets.length + 1;
      final service = serviceReturning(
        handler: (request, count) async {
          if (count < firstFallbackRequest) {
            return http.Response('{"features":[]}', 200);
          }
          if (count == firstFallbackRequest) {
            return roadRoute([start, exit, destination]);
          }
          if (count == firstFallbackRequest + 1) {
            return http.Response('{"features":[]}', 200);
          }
          return roadRoute([exit, destination]);
        },
      );

      final result = await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [containingLow],
      );

      expect(result.riskLevel, RouteRiskLevel.lowRisk);
    });

    test('Level 3 succeeds in Escape Mode', () async {
      final containingHigh = hazard(
        id: 'start-high',
        severity: 'High',
        latitude: start.latitude,
        longitude: start.longitude,
      );
      final medium = hazard(
        id: 'medium',
        severity: 'Medium',
        latitude: 5.48,
        longitude: 100.39,
      );
      final low = hazard(
        id: 'low',
        severity: 'Low',
        latitude: 5.49,
        longitude: 100.40,
      );
      final bearing = SafeRoutingService.initialBearingDegrees(
        start,
        destination,
      );
      final exit = SafeRoutingService.computeDestinationPoint(
        start,
        SafetyConfig.highSeverityRadiusMeters + 60,
        bearing,
      );
      final firstFallbackRequest =
          SafeRoutingService.escapeBearingOffsets.length + 1;
      final service = serviceReturning(
        handler: (request, count) async {
          if (count < firstFallbackRequest) {
            return http.Response('{"features":[]}', 200);
          }
          if (count == firstFallbackRequest) {
            return roadRoute([start, exit, destination]);
          }
          if (count == firstFallbackRequest + 1 ||
              count == firstFallbackRequest + 2) {
            return http.Response('{"features":[]}', 200);
          }
          return roadRoute([exit, destination]);
        },
      );

      final result = await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [containingHigh, medium, low],
      );

      expect(result.riskLevel, RouteRiskLevel.moderateRisk);
    });

    test(
      'Level 4 succeeds in Escape Mode and remains unavoidable exposure',
      () async {
        final containingHigh = hazard(
          id: 'start-high',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );
        final unrelatedMedium = hazard(
          id: 'unrelated-medium',
          severity: 'Medium',
          latitude: 5.48,
          longitude: 100.39,
        );
        final unrelatedLow = hazard(
          id: 'unrelated-low',
          severity: 'Low',
          latitude: 5.49,
          longitude: 100.40,
        );
        final bearing = SafeRoutingService.initialBearingDegrees(
          start,
          destination,
        );
        final exit = SafeRoutingService.computeDestinationPoint(
          start,
          SafetyConfig.highSeverityRadiusMeters + 60,
          bearing,
        );
        final firstFallbackRequest =
            SafeRoutingService.escapeBearingOffsets.length + 1;
        final service = serviceReturning(
          handler: (request, count) async {
            if (count < firstFallbackRequest) {
              return http.Response('{"features":[]}', 200);
            }
            if (count == firstFallbackRequest) {
              return roadRoute([start, exit, destination]);
            }
            if (count <= firstFallbackRequest + 3) {
              return http.Response('{"features":[]}', 200);
            }
            return roadRoute([exit, destination]);
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containingHigh, unrelatedMedium, unrelatedLow],
        );

        expect(result.riskLevel, RouteRiskLevel.unavoidableExposure);
        final phase2Body = jsonDecode(capturedRequests.last.body);
        expect(phase2Body, isNot(contains('options')));
      },
    );

    test('route-derived escape preserves multi-stop order', () async {
      const firstStop = LatLng(5.44, 100.35);
      final containing = hazard(
        id: 'start-high',
        severity: 'High',
        latitude: start.latitude,
        longitude: start.longitude,
      );
      final bearing = SafeRoutingService.initialBearingDegrees(
        start,
        firstStop,
      );
      final exit = SafeRoutingService.computeDestinationPoint(
        start,
        SafetyConfig.highSeverityRadiusMeters + 60,
        bearing,
      );
      final orderedStops = [
        const NavigationStop(
          id: 'first',
          location: firstStop,
          displayName: 'First Stop',
        ),
        const NavigationStop(
          id: 'final',
          location: destination,
          displayName: 'Gurney Paragon',
          isDestination: true,
        ),
      ];
      final firstFallbackRequest =
          SafeRoutingService.escapeBearingOffsets.length + 1;
      final service = serviceReturning(
        handler: (request, count) async {
          if (count < firstFallbackRequest) {
            return http.Response('{"features":[]}', 200);
          }
          if (count == firstFallbackRequest) {
            return roadRoute([start, exit, firstStop]);
          }
          final coordinates = requestCoordinates(request);
          return http.Response(routeResponse(coordinates: coordinates), 200);
        },
      );

      final result = await service.calculateSafeRoute(
        start: start,
        stops: orderedStops,
        hazards: [containing],
      );

      final phase2Coordinates = requestCoordinates(capturedRequests.last);
      expect(phase2Coordinates, hasLength(3));
      expect(
        phase2Coordinates[1],
        orderedEquals([firstStop.longitude, firstStop.latitude]),
      );
      expect(
        phase2Coordinates[2],
        orderedEquals([destination.longitude, destination.latitude]),
      );
      expect(result.stops.map((stop) => stop.id), ['first', 'final']);
    });

    test('actual destination inside High hazard remains blocked', () async {
      final containing = hazard(
        id: 'start-low',
        severity: 'Low',
        latitude: start.latitude,
        longitude: start.longitude,
      );
      final destinationHazard = hazard(
        id: 'destination-high',
        severity: 'High',
        latitude: destination.latitude,
        longitude: destination.longitude,
      );
      final service = serviceReturning();

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing, destinationHazard],
        ),
        throwsA(
          isA<SafeRoutingException>().having(
            (error) => error.code,
            'code',
            SafeRoutingFailureCode.destinationInsideHazard,
          ),
        ),
      );
      expect(requestCount, 0);
    });
  });

  group('geometric safety hardening', () {
    test(
      'two route points outside hazard but segment crossing hazard is rejected',
      () {
        const hazardPoint = LatLng(5.4300, 100.3400);
        final h = hazard(
          id: 'hazard-high',
          severity: 'High',
          latitude: hazardPoint.latitude,
          longitude: hazardPoint.longitude,
        );
        final radius = SafetyConfig.dangerRadiusForSeverity(h.severity);

        final pointA = SafeRoutingService.computeDestinationPoint(
          hazardPoint,
          600.0,
          270.0,
        );
        final pointB = SafeRoutingService.computeDestinationPoint(
          hazardPoint,
          600.0,
          90.0,
        );

        expect(
          SafeRoutingService.distanceMeters(pointA, hazardPoint),
          greaterThan(radius),
        );
        expect(
          SafeRoutingService.distanceMeters(pointB, hazardPoint),
          greaterThan(radius),
        );

        final minDistance = SafeRoutingService.distanceSegmentToPointMeters(
          pointA,
          pointB,
          hazardPoint,
        );
        expect(minDistance, lessThan(5.0));

        final isValid = SafeRoutingService.verifyRouteSegmentsAvoidHazards(
          geometry: [pointA, pointB],
          hazards: [h],
        );
        expect(isValid, isFalse);
      },
    );

    test('segment passing just outside hazard radius is accepted', () {
      const hazardPoint = LatLng(5.4300, 100.3400);
      final h = hazard(
        id: 'hazard-high',
        severity: 'High',
        latitude: hazardPoint.latitude,
        longitude: hazardPoint.longitude,
      );
      final radius = SafetyConfig.dangerRadiusForSeverity(h.severity);

      final midPoint = SafeRoutingService.computeDestinationPoint(
        hazardPoint,
        520.0,
        0.0,
      );
      final pointA = SafeRoutingService.computeDestinationPoint(
        midPoint,
        600.0,
        270.0,
      );
      final pointB = SafeRoutingService.computeDestinationPoint(
        midPoint,
        600.0,
        90.0,
      );

      final minDistance = SafeRoutingService.distanceSegmentToPointMeters(
        pointA,
        pointB,
        hazardPoint,
      );
      expect(minDistance, greaterThanOrEqualTo(515.0));
      expect(minDistance, greaterThan(radius));

      final isValid = SafeRoutingService.verifyRouteSegmentsAvoidHazards(
        geometry: [pointA, pointB],
        hazards: [h],
      );
      expect(isValid, isTrue);
    });

    test(
      'Phase 2 route segment crossing starting hazard despite endpoints outside causes candidate rejection',
      () async {
        const startInside = LatLng(5.4300, 100.3400);
        final containing = hazard(
          id: 'start-hazard',
          severity: 'High',
          latitude: startInside.latitude,
          longitude: startInside.longitude,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final coords = (body['coordinates'] as List)
                .map(
                  (c) => (c as List).map((n) => (n as num).toDouble()).toList(),
                )
                .toList();
            final reqStart = LatLng(coords[0][1], coords[0][0]);
            final reqEnd = LatLng(coords[1][1], coords[1][0]);

            if (count == 1) {
              return http.Response(
                routeResponse(
                  coordinates: [
                    [coords[0][0], coords[0][1]],
                    [coords[1][0], coords[1][1]],
                  ],
                  distance: 550.0,
                ),
                200,
              );
            }

            if (count == 2) {
              final crossingWest = SafeRoutingService.computeDestinationPoint(
                startInside,
                600.0,
                270.0,
              );
              final crossingEast = SafeRoutingService.computeDestinationPoint(
                startInside,
                600.0,
                90.0,
              );
              return http.Response(
                routeResponse(
                  coordinates: [
                    [reqStart.longitude, reqStart.latitude],
                    [crossingWest.longitude, crossingWest.latitude],
                    [crossingEast.longitude, crossingEast.latitude],
                    [reqEnd.longitude, reqEnd.latitude],
                  ],
                  distance: 5000.0,
                ),
                200,
              );
            }

            if (count == 3) {
              return http.Response(
                routeResponse(
                  coordinates: [
                    [coords[0][0], coords[0][1]],
                    [coords[1][0], coords[1][1]],
                  ],
                  distance: 550.0,
                ),
                200,
              );
            }

            return http.Response(
              routeResponse(
                coordinates: [
                  [coords[0][0], coords[0][1]],
                  [coords[1][0], coords[1][1]],
                ],
                distance: 4000.0,
              ),
              200,
            );
          },
        );

        final result = await service.calculateSafeRoute(
          start: startInside,
          destination: destination,
          hazards: [containing],
        );

        expect(requestCount, greaterThanOrEqualTo(4));
        expect(result.startedInsideHazard, isTrue);
        expect(result.escapeHazardIds, contains('start-hazard'));
      },
    );

    test('Phase 1 route exiting once and staying outside is accepted', () {
      const hazardPoint = LatLng(5.4300, 100.3400);
      final h = hazard(
        id: 'hazard-high',
        severity: 'High',
        latitude: hazardPoint.latitude,
        longitude: hazardPoint.longitude,
      );

      final p0 = hazardPoint;
      final p1 = SafeRoutingService.computeDestinationPoint(
        hazardPoint,
        200.0,
        0.0,
      );
      final p2 = SafeRoutingService.computeDestinationPoint(
        hazardPoint,
        550.0,
        0.0,
      );
      final p3 = SafeRoutingService.computeDestinationPoint(
        hazardPoint,
        650.0,
        0.0,
      );

      final isValid = SafeRoutingService.verifyEscapeRouteExitAndNoReentry(
        geometry: [p0, p1, p2, p3],
        containingHazards: [h],
      );
      expect(isValid, isTrue);
    });

    test('Phase 1 route exiting and re-entering is rejected', () async {
      const hazardPoint = LatLng(5.4300, 100.3400);
      final h = hazard(
        id: 'hazard-high',
        severity: 'High',
        latitude: hazardPoint.latitude,
        longitude: hazardPoint.longitude,
      );

      final p0 = hazardPoint;
      final p1 = SafeRoutingService.computeDestinationPoint(
        hazardPoint,
        550.0,
        0.0,
      );
      final p2 = SafeRoutingService.computeDestinationPoint(
        hazardPoint,
        200.0,
        0.0,
      );
      final p3 = SafeRoutingService.computeDestinationPoint(
        hazardPoint,
        600.0,
        0.0,
      );

      expect(
        SafeRoutingService.verifyEscapeRouteExitAndNoReentry(
          geometry: [p0, p1, p2, p3],
          containingHazards: [h],
        ),
        isFalse,
      );

      final pExitNorth = SafeRoutingService.computeDestinationPoint(
        hazardPoint,
        550.0,
        0.0,
      );
      final pExitSouth = SafeRoutingService.computeDestinationPoint(
        hazardPoint,
        550.0,
        180.0,
      );
      expect(
        SafeRoutingService.verifyEscapeRouteExitAndNoReentry(
          geometry: [p0, pExitNorth, pExitSouth],
          containingHazards: [h],
        ),
        isFalse,
      );

      final service = serviceReturning(
        handler: (request, count) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final coords = (body['coordinates'] as List)
              .map(
                (c) => (c as List).map((n) => (n as num).toDouble()).toList(),
              )
              .toList();

          if (count == 1) {
            return http.Response(
              routeResponse(
                coordinates: [
                  [coords[0][0], coords[0][1]],
                  [p1.longitude, p1.latitude],
                  [p2.longitude, p2.latitude],
                  [coords[1][0], coords[1][1]],
                ],
                distance: 1200.0,
              ),
              200,
            );
          }

          return http.Response(
            routeResponse(
              coordinates: [
                [coords[0][0], coords[0][1]],
                [coords[1][0], coords[1][1]],
              ],
              distance: 1000.0,
            ),
            200,
          );
        },
      );

      final result = await service.calculateSafeRoute(
        start: hazardPoint,
        destination: destination,
        hazards: [h],
      );

      expect(requestCount, greaterThanOrEqualTo(3));
      expect(result.startedInsideHazard, isTrue);
    });

    test(
      'overlapping hazards: route must exit ALL containing hazards before escape is complete',
      () {
        const center1 = LatLng(5.4300, 100.3400);
        final center2 = SafeRoutingService.computeDestinationPoint(
          center1,
          600.0,
          90.0,
        );

        final h1 = hazard(
          id: 'hazard-1',
          severity: 'High',
          latitude: center1.latitude,
          longitude: center1.longitude,
        );
        final h2 = hazard(
          id: 'hazard-2',
          severity: 'High',
          latitude: center2.latitude,
          longitude: center2.longitude,
        );

        final startInsideBoth = SafeRoutingService.computeDestinationPoint(
          center1,
          300.0,
          90.0,
        );

        final exitedBothWest = SafeRoutingService.computeDestinationPoint(
          center1,
          600.0,
          270.0,
        );
        expect(
          SafeRoutingService.verifyEscapeRouteExitAndNoReentry(
            geometry: [startInsideBoth, exitedBothWest],
            containingHazards: [h1, h2],
          ),
          isTrue,
        );

        final exitH1InsideH2 = SafeRoutingService.computeDestinationPoint(
          center1,
          550.0,
          90.0,
        );
        expect(
          SafeRoutingService.verifyEscapeRouteExitAndNoReentry(
            geometry: [startInsideBoth, exitH1InsideH2],
            containingHazards: [h1, h2],
          ),
          isFalse,
        );

        final exitedBothEast = SafeRoutingService.computeDestinationPoint(
          center2,
          600.0,
          90.0,
        );
        expect(
          SafeRoutingService.verifyEscapeRouteExitAndNoReentry(
            geometry: [startInsideBoth, exitH1InsideH2, exitedBothEast],
            containingHazards: [h1, h2],
          ),
          isTrue,
        );
      },
    );
  });

  group('Phase 2.2–2.5: Multi-Stop Hazard-Aware Route Planner', () {
    const stop1 = LatLng(5.42, 100.33);
    const stop2 = LatLng(5.43, 100.34);
    const stop3 = LatLng(5.44, 100.35);

    test(
      'multi-stop request sends coordinates in exact user-defined order',
      () async {
        final service = serviceReturning();
        final stops = [
          const NavigationStop(
            id: 's1',
            location: stop1,
            displayName: 'Stop 1',
          ),
          const NavigationStop(
            id: 's2',
            location: stop2,
            displayName: 'Stop 2',
          ),
          const NavigationStop(
            id: 's3',
            location: stop3,
            displayName: 'Stop 3',
            isDestination: true,
          ),
        ];

        await service.calculateSafeRoute(
          start: start,
          stops: stops,
          hazards: [],
        );

        final body = capturedBody();
        final coords = body['coordinates'] as List;
        expect(coords, hasLength(4));
        expect(coords[0], orderedEquals([start.longitude, start.latitude]));
        expect(coords[1], orderedEquals([stop1.longitude, stop1.latitude]));
        expect(coords[2], orderedEquals([stop2.longitude, stop2.latitude]));
        expect(coords[3], orderedEquals([stop3.longitude, stop3.latitude]));
      },
    );

    test(
      'reordering multi-stops changes coordinates to match new order',
      () async {
        final service = serviceReturning();
        final reorderedStops = [
          const NavigationStop(
            id: 's3',
            location: stop3,
            displayName: 'Stop 3',
          ),
          const NavigationStop(
            id: 's1',
            location: stop1,
            displayName: 'Stop 1',
          ),
          const NavigationStop(
            id: 's2',
            location: stop2,
            displayName: 'Stop 2',
            isDestination: true,
          ),
        ];

        await service.calculateSafeRoute(
          start: start,
          stops: reorderedStops,
          hazards: [],
        );

        final body = capturedBody();
        final coords = body['coordinates'] as List;
        expect(coords, hasLength(4));
        expect(coords[0], orderedEquals([start.longitude, start.latitude]));
        expect(coords[1], orderedEquals([stop3.longitude, stop3.latitude]));
        expect(coords[2], orderedEquals([stop1.longitude, stop1.latitude]));
        expect(coords[3], orderedEquals([stop2.longitude, stop2.latitude]));
      },
    );

    test(
      'parses multi-segment response into RouteLegs with stop names and locations',
      () async {
        final stops = [
          const NavigationStop(
            id: 's1',
            location: stop1,
            displayName: 'Aman Central',
          ),
          const NavigationStop(
            id: 's2',
            location: stop2,
            displayName: 'Alor Setar Tower',
            isDestination: true,
          ),
        ];

        final customJson = jsonEncode({
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [start.longitude, start.latitude],
                  [stop1.longitude, stop1.latitude],
                  [stop2.longitude, stop2.latitude],
                ],
              },
              'properties': {
                'summary': {'distance': 5000.0, 'duration': 600.0},
                'segments': [
                  {
                    'distance': 2000.0,
                    'duration': 250.0,
                    'steps': [
                      {
                        'distance': 2000.0,
                        'duration': 250.0,
                        'type': 11,
                        'instruction': 'Head towards Aman Central',
                        'name': 'Jalan 1',
                        'way_points': [0, 1],
                      },
                    ],
                  },
                  {
                    'distance': 3000.0,
                    'duration': 350.0,
                    'steps': [
                      {
                        'distance': 3000.0,
                        'duration': 350.0,
                        'type': 11,
                        'instruction': 'Head towards Alor Setar Tower',
                        'name': 'Jalan 2',
                        'way_points': [1, 2],
                      },
                    ],
                  },
                ],
              },
            },
          ],
        });

        final service = serviceReturning(body: customJson);

        final result = await service.calculateSafeRoute(
          start: start,
          stops: stops,
          hazards: [],
        );

        expect(result.legs, hasLength(2));
        expect(result.legs[0].startStopName, 'Current Location');
        expect(result.legs[0].endStopName, 'Aman Central');
        expect(result.legs[0].distanceMeters, 2000.0);
        expect(result.legs[0].durationSeconds, 250.0);
        expect(result.legs[0].startLocation, start);
        expect(result.legs[0].endLocation, stop1);
        expect(result.legs[0].steps, hasLength(1));

        expect(result.legs[1].startStopName, 'Aman Central');
        expect(result.legs[1].endStopName, 'Alor Setar Tower');
        expect(result.legs[1].distanceMeters, 3000.0);
        expect(result.legs[1].durationSeconds, 350.0);
        expect(result.legs[1].startLocation, stop1);
        expect(result.legs[1].endLocation, stop2);
        expect(result.legs[1].steps, hasLength(1));

        expect(result.distanceMeters, 5000.0);
        expect(result.durationSeconds, 600.0);
        expect(result.riskLevel, RouteRiskLevel.hazardFree);
      },
    );

    test(
      'High-severity stop blocks routing with destinationInsideHazard before network call',
      () async {
        final service = serviceReturning();
        final highHazard = hazard(
          id: 'high-1',
          severity: 'High',
          latitude: stop2.latitude,
          longitude: stop2.longitude,
        );

        final stops = [
          const NavigationStop(
            id: 's1',
            location: stop1,
            displayName: 'Stop 1',
          ),
          const NavigationStop(
            id: 's2',
            location: stop2,
            displayName: 'Stop 2 (Inside High Hazard)',
          ),
        ];

        await expectLater(
          service.calculateSafeRoute(
            start: start,
            stops: stops,
            hazards: [highHazard],
          ),
          throwsA(
            isA<SafeRoutingException>()
                .having(
                  (e) => e.code,
                  'code',
                  SafeRoutingFailureCode.destinationInsideHazard,
                )
                .having((e) => e.hazardId, 'hazardId', 'high-1'),
          ),
        );
        expect(requestCount, 0);
      },
    );

    test(
      'Medium and Low stops are allowed without throwing destinationInsideHazard',
      () async {
        final service = serviceReturning();
        final lowHazard = hazard(
          id: 'low-1',
          severity: 'Low',
          latitude: stop1.latitude,
          longitude: stop1.longitude,
        );

        final stops = [
          const NavigationStop(
            id: 's1',
            location: stop1,
            displayName: 'Stop 1 (Inside Low Hazard)',
          ),
        ];

        final route = await service.calculateSafeRoute(
          start: start,
          stops: stops,
          hazards: [lowHazard],
        );

        expect(route, isNotNull);
        expect(requestCount, 1);
      },
    );

    test(
      'Progressive fallback: Level 1 succeeds when all hazards avoided',
      () async {
        final high = hazard(
          id: 'h-1',
          severity: 'High',
          latitude: 5.43,
          longitude: 100.34,
        );
        final medium = hazard(
          id: 'm-1',
          severity: 'Medium',
          latitude: 5.435,
          longitude: 100.345,
        );
        final low = hazard(
          id: 'l-1',
          severity: 'Low',
          latitude: 5.44,
          longitude: 100.35,
        );

        final service = serviceReturning();

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [high, medium, low],
        );

        expect(result.riskLevel, RouteRiskLevel.hazardFree);
        expect(requestCount, 1);
        final avoidPoly = avoidanceGeometry() as Map<String, dynamic>;
        expect(avoidPoly['coordinates'], hasLength(3));
      },
    );

    test(
      'Progressive fallback: Level 2 succeeds after a genuine no-route response (Low hazards crossed)',
      () async {
        final high = hazard(
          id: 'h-1',
          severity: 'High',
          latitude: 5.43,
          longitude: 100.34,
        );
        final medium = hazard(
          id: 'm-1',
          severity: 'Medium',
          latitude: 5.435,
          longitude: 100.345,
        );
        final low = hazard(
          id: 'l-1',
          severity: 'Low',
          latitude: 5.44,
          longitude: 100.35,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            if (count == 1) {
              // Level 1: ORS produced no route while avoiding all hazards.
              return http.Response('{"features":[]}', 200);
            }
            // Level 2: succeeds avoiding High and Medium
            return http.Response(
              routeResponse(
                coordinates: [
                  [start.longitude, start.latitude],
                  [destination.longitude, destination.latitude],
                ],
              ),
              200,
            );
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [high, medium, low],
        );

        expect(requestCount, 2);
        expect(result.riskLevel, RouteRiskLevel.lowRisk);
        // Verify second request avoided only High and Medium (2 polygons)
        final options =
            jsonDecode(capturedRequests[1].body)['options']
                as Map<String, dynamic>;
        final avoidPoly = options['avoid_polygons'] as Map<String, dynamic>;
        expect(avoidPoly['coordinates'], hasLength(2));
      },
    );

    test(
      'Progressive fallback: Level 3 succeeds after two genuine no-route responses',
      () async {
        final high = hazard(
          id: 'h-1',
          severity: 'High',
          latitude: 5.43,
          longitude: 100.34,
        );
        final medium = hazard(
          id: 'm-1',
          severity: 'Medium',
          latitude: 5.435,
          longitude: 100.345,
        );
        final low = hazard(
          id: 'l-1',
          severity: 'Low',
          latitude: 5.44,
          longitude: 100.35,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            if (count == 1 || count == 2) {
              return http.Response('{"features":[]}', 200);
            }
            // Level 3: succeeds avoiding High only
            return http.Response(
              routeResponse(
                coordinates: [
                  [start.longitude, start.latitude],
                  [destination.longitude, destination.latitude],
                ],
              ),
              200,
            );
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [high, medium, low],
        );

        expect(requestCount, 3);
        expect(result.riskLevel, RouteRiskLevel.moderateRisk);
        final options =
            jsonDecode(capturedRequests[2].body)['options']
                as Map<String, dynamic>;
        final avoidPoly = options['avoid_polygons'] as Map<String, dynamic>;
        expect(avoidPoly['coordinates'], hasLength(1));
      },
    );

    test(
      'Progressive fallback: Level 4 succeeds without avoid_polygons when 1-3 fail',
      () async {
        final high = hazard(
          id: 'h-1',
          severity: 'High',
          latitude: 5.43,
          longitude: 100.34,
        );
        final medium = hazard(
          id: 'm-1',
          severity: 'Medium',
          latitude: 5.435,
          longitude: 100.345,
        );
        final low = hazard(
          id: 'l-1',
          severity: 'Low',
          latitude: 5.44,
          longitude: 100.35,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            if (count <= 3) {
              return http.Response('{"features":[]}', 200);
            }
            // Level 4: succeeds without avoid_polygons
            return http.Response(
              routeResponse(
                coordinates: [
                  [start.longitude, start.latitude],
                  [destination.longitude, destination.latitude],
                ],
              ),
              200,
            );
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [high, medium, low],
        );

        expect(requestCount, 4);
        expect(result.riskLevel, RouteRiskLevel.unavoidableExposure);
        final lastReqBody =
            jsonDecode(capturedRequests[3].body) as Map<String, dynamic>;
        expect(lastReqBody.containsKey('options'), isFalse);
      },
    );

    test(
      'Progressive fallback: Level 2 succeeds when Level 1 returns HTTP 404 with ORS code 2009',
      () async {
        final high = hazard(
          id: 'h-1',
          severity: 'High',
          latitude: 5.43,
          longitude: 100.34,
        );
        final medium = hazard(
          id: 'm-1',
          severity: 'Medium',
          latitude: 5.435,
          longitude: 100.345,
        );
        final low = hazard(
          id: 'l-1',
          severity: 'Low',
          latitude: 5.44,
          longitude: 100.35,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            if (count == 1) {
              return http.Response(
                '{"error":{"code":2009,"message":"Route could not be found - Unable to find a route between points"}}',
                404,
              );
            }
            return http.Response(
              routeResponse(
                coordinates: [
                  [start.longitude, start.latitude],
                  [destination.longitude, destination.latitude],
                ],
              ),
              200,
            );
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [high, medium, low],
        );

        expect(requestCount, 2);
        expect(result.riskLevel, RouteRiskLevel.lowRisk);
        final options =
            jsonDecode(capturedRequests[1].body)['options']
                as Map<String, dynamic>;
        final avoidPoly = options['avoid_polygons'] as Map<String, dynamic>;
        expect(avoidPoly['coordinates'], hasLength(2));
      },
    );

    test(
      'Progressive fallback: Level 4 succeeds when Levels 1-3 return HTTP 404 with ORS code 2016',
      () async {
        final high = hazard(
          id: 'h-1',
          severity: 'High',
          latitude: 5.43,
          longitude: 100.34,
        );
        final medium = hazard(
          id: 'm-1',
          severity: 'Medium',
          latitude: 5.435,
          longitude: 100.345,
        );
        final low = hazard(
          id: 'l-1',
          severity: 'Low',
          latitude: 5.44,
          longitude: 100.35,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            if (count <= 3) {
              return http.Response(
                '{"error":{"code":2016,"message":"Could not find point within 350.0 meters"}}',
                404,
              );
            }
            return http.Response(
              routeResponse(
                coordinates: [
                  [start.longitude, start.latitude],
                  [destination.longitude, destination.latitude],
                ],
              ),
              200,
            );
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [high, medium, low],
        );

        expect(requestCount, 4);
        expect(result.riskLevel, RouteRiskLevel.unavoidableExposure);
        final lastReqBody =
            jsonDecode(capturedRequests[3].body) as Map<String, dynamic>;
        expect(lastReqBody.containsKey('options'), isFalse);
      },
    );

    for (final failure in <(int, SafeRoutingFailureCode)>[
      (400, SafeRoutingFailureCode.invalidRequest),
      (401, SafeRoutingFailureCode.unauthorized),
      (403, SafeRoutingFailureCode.unauthorized),
      (404, SafeRoutingFailureCode.providerFailure),
      (413, SafeRoutingFailureCode.requestTooLarge),
      (429, SafeRoutingFailureCode.rateLimited),
      (500, SafeRoutingFailureCode.providerUnavailable),
      (503, SafeRoutingFailureCode.providerUnavailable),
    ]) {
      test('HTTP ${failure.$1} never weakens hazard avoidance', () async {
        final service = serviceReturning(
          statusCode: failure.$1,
          body: '{"error":{"message":"provider error"}}',
        );

        await expectLater(
          service.calculateSafeRoute(
            start: start,
            destination: destination,
            hazards: [
              hazard(id: 'h', severity: 'High'),
              hazard(id: 'm', severity: 'Medium'),
              hazard(id: 'l', severity: 'Low'),
            ],
          ),
          throwsA(
            isA<SafeRoutingException>().having(
              (error) => error.code,
              'code',
              failure.$2,
            ),
          ),
        );
        expect(requestCount, 1);
        final polygons =
            (capturedBody()['options']
                    as Map<String, dynamic>)['avoid_polygons']
                as Map<String, dynamic>;
        expect(polygons['coordinates'], hasLength(3));
      });
    }

    test('network failure never weakens hazard avoidance', () async {
      requestCount = 0;
      final service = SafeRoutingService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          requestCount++;
          throw http.ClientException('offline', request.url);
        }),
      );

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [hazard(severity: 'Low')],
        ),
        throwsA(
          isA<SafeRoutingException>().having(
            (error) => error.code,
            'code',
            SafeRoutingFailureCode.networkFailure,
          ),
        ),
      );
      expect(requestCount, 1);
    });

    test('timeout never weakens hazard avoidance', () async {
      requestCount = 0;
      final pendingResponse = Completer<http.Response>();
      final service = SafeRoutingService(
        apiKey: 'test-key',
        timeout: const Duration(milliseconds: 10),
        client: MockClient((request) {
          requestCount++;
          return pendingResponse.future;
        }),
      );

      await expectLater(
        service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [hazard(severity: 'Low')],
        ),
        throwsA(
          isA<SafeRoutingException>().having(
            (error) => error.code,
            'code',
            SafeRoutingFailureCode.timeout,
          ),
        ),
      );
      expect(requestCount, 1);
    });

    test(
      'geometrically determines crossedHazardIds along final route polyline',
      () async {
        final nearHazard = hazard(
          id: 'crossed-hz',
          severity: 'Low',
          latitude: 5.43,
          longitude: 100.34,
        );
        final farHazard = hazard(
          id: 'far-hz',
          severity: 'Low',
          latitude: 6.0,
          longitude: 101.0,
        );

        final customJson = routeResponse(
          coordinates: [
            [100.3288, 5.4141],
            [100.3400, 5.4300],
            [100.3600, 5.4500],
          ],
        );

        final service = serviceReturning(body: customJson);

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [nearHazard, farHazard],
        );

        expect(result.crossedHazardIds, contains('crossed-hz'));
        expect(result.crossedHazardIds, isNot(contains('far-hz')));
      },
    );
  });

  group('Quota & Rate Limiting Awareness (HTTP 429)', () {
    test('HTTP 429 parses integer Retry-After header and populates retryAfter Duration', () async {
      final service = serviceReturning(
        statusCode: 429,
        body: '{"error":{"message":"Rate Limit Exceeded"}}',
        handler: (request, count) async {
          return http.Response(
            '{"error":{"message":"Rate Limit Exceeded"}}',
            429,
            headers: {'retry-after': '35'},
          );
        },
      );

      SafeRoutingException? thrown;
      try {
        await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [],
        );
      } on SafeRoutingException catch (e) {
        thrown = e;
      }

      expect(thrown, isNotNull);
      expect(thrown!.code, SafeRoutingFailureCode.rateLimited);
      expect(thrown.statusCode, 429);
      expect(thrown.retryAfter, const Duration(seconds: 35));
      expect(SafeRoutingService.isRateLimited, isTrue);
      expect(SafeRoutingService.rateLimitRemainingSeconds, greaterThanOrEqualTo(30));
    });

    test('HTTP 429 without Retry-After header falls back to defaultRateLimitCooldown', () async {
      final service = serviceReturning(
        statusCode: 429,
        body: '{"error":{"message":"Rate Limit Exceeded"}}',
      );

      SafeRoutingException? thrown;
      try {
        await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [],
        );
      } on SafeRoutingException catch (e) {
        thrown = e;
      }

      expect(thrown, isNotNull);
      expect(thrown!.code, SafeRoutingFailureCode.rateLimited);
      expect(thrown.retryAfter, SafeRoutingService.defaultRateLimitCooldown);
      expect(SafeRoutingService.isRateLimited, isTrue);
    });

    test('local rate-limit cooldown blocks subsequent requests locally without hitting ORS', () async {
      SafeRoutingService.rateLimitedUntil = DateTime.now().add(const Duration(seconds: 25));

      final service = serviceReturning(
        handler: (request, count) async {
          fail('Network call should not be made during rate limit cooldown');
        },
      );

      SafeRoutingException? thrown;
      try {
        await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [],
        );
      } on SafeRoutingException catch (e) {
        thrown = e;
      }

      expect(thrown, isNotNull);
      expect(thrown!.code, SafeRoutingFailureCode.rateLimited);
      expect(thrown.retryAfter, isNotNull);
      expect(requestCount, 0);
    });

    test('clearing rate-limit cooldown allows requests to proceed immediately', () async {
      SafeRoutingService.rateLimitedUntil = DateTime.now().add(const Duration(seconds: 25));
      expect(SafeRoutingService.isRateLimited, isTrue);

      SafeRoutingService.clearRateLimitCooldown();
      expect(SafeRoutingService.isRateLimited, isFalse);

      final service = serviceReturning();
      final route = await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [],
      );

      expect(route, isNotNull);
      expect(requestCount, 1);
    });

    test('Escape Mode aborts immediately on HTTP 429 without trying further radial candidates', () async {
      final containing = hazard(
        id: 'start-in-hazard-429',
        severity: 'High',
        latitude: start.latitude,
        longitude: start.longitude,
      );

      final service = serviceReturning(
        statusCode: 429,
        body: '{"error":{"message":"Rate Limit Exceeded"}}',
        handler: (request, count) async {
          return http.Response(
            '{"error":{"message":"Rate Limit Exceeded"}}',
            429,
            headers: {'retry-after': '20'},
          );
        },
      );

      SafeRoutingException? thrown;
      try {
        await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        );
      } on SafeRoutingException catch (e) {
        thrown = e;
      }

      expect(thrown, isNotNull);
      expect(thrown!.code, SafeRoutingFailureCode.rateLimited);
      expect(requestCount, 1);
    });

    test('HTTP 429 during normal fallback never triggers progressive hazard relaxation', () async {
      final service = serviceReturning(
        statusCode: 429,
        body: '{"error":{"message":"Rate Limit Exceeded"}}',
      );

      SafeRoutingException? thrown;
      try {
        await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [hazard(severity: 'Low'), hazard(severity: 'Medium')],
        );
      } on SafeRoutingException catch (e) {
        thrown = e;
      }

      expect(thrown, isNotNull);
      expect(thrown!.code, SafeRoutingFailureCode.rateLimited);
      expect(requestCount, 1);
    });

    group('Proven Radial Escape Ordering & 429 Safety', () {
      test('1. radial candidates are tried before route-derived fallback', () async {
        final containing = hazard(
          id: 'containing-radial-first',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final coords = body['coordinates'] as List;
            if (count == 1) {
              // Request 1 must be radial candidate 0 (start -> candidate escapePoint)
              // NOT start -> destination (which would be route-derived probe)
              final wp = coords[1] as List;
              final wpLon = (wp[0] as num).toDouble();
              final wpLat = (wp[1] as num).toDouble();
              expect(
                (wpLat - destination.latitude).abs() > 0.001 ||
                    (wpLon - destination.longitude).abs() > 0.001,
                isTrue,
                reason: 'First request must be radial escapePoint, not destination',
              );
              return http.Response(
                routeResponse(
                  coordinates: [
                    [start.longitude, start.latitude],
                    [wpLon, wpLat],
                  ],
                ),
                200,
              );
            }
            // Request 2: Phase 2 to destination
            final firstPoint =
                (coords[0] as List).map((e) => (e as num).toDouble()).toList();
            return http.Response(
              routeResponse(
                coordinates: [
                  firstPoint,
                  [destination.longitude, destination.latitude],
                ],
              ),
              200,
            );
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        );

        expect(result.startedInsideHazard, isTrue);
        expect(requestCount, 2);
      });

      test('2. first radial 2009 -> second bearing attempted', () async {
        final containing = hazard(
          id: 'containing-h1',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );

        final attemptedBearings = <List<double>>[];
        final service = serviceReturning(
          handler: (request, count) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final coords = body['coordinates'] as List;
            final wp = (coords.last as List).map((e) => (e as num).toDouble()).toList();
            attemptedBearings.add(wp);

            if (count == 1) {
              // Candidate 0 fails with ORS 2009 (HTTP 404)
              return http.Response(
                '{"error":{"code":2009,"message":"Route could not be found"}}',
                404,
              );
            }
            if (count == 2) {
              // Candidate 1 (bearing 45) Phase 1 succeeds
              return http.Response(
                routeResponse(coordinates: [[start.longitude, start.latitude], wp]),
                200,
              );
            }
            if (count == 3) {
              // Candidate 1 Phase 2 succeeds
              return http.Response(
                routeResponse(coordinates: [wp, [destination.longitude, destination.latitude]]),
                200,
              );
            }
            fail('Unexpected request count: $count');
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        );

        expect(result.startedInsideHazard, isTrue);
        expect(requestCount, 3);
        // Bearing 1 and Bearing 2 must have different coordinates
        expect(attemptedBearings.length >= 2, isTrue);
        expect(attemptedBearings[0], isNot(equals(attemptedBearings[1])));
      });

      test('3. first radial 2010 -> second bearing attempted', () async {
        final containing = hazard(
          id: 'containing-h1',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final coords = body['coordinates'] as List;
            final wp = (coords.last as List).map((e) => (e as num).toDouble()).toList();

            if (count == 1) {
              // Candidate 0 fails with ORS 2010 (unroutable point)
              return http.Response(
                '{"error":{"code":2010,"message":"Could not find routable point within a radius of 350.0 meters of specified coordinate 1"}}',
                404,
              );
            }
            if (count == 2) {
              // Candidate 1 Phase 1 succeeds
              return http.Response(
                routeResponse(coordinates: [[start.longitude, start.latitude], wp]),
                200,
              );
            }
            if (count == 3) {
              // Candidate 1 Phase 2 succeeds
              return http.Response(
                routeResponse(coordinates: [wp, [destination.longitude, destination.latitude]]),
                200,
              );
            }
            fail('Unexpected request count: $count');
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        );

        expect(result.startedInsideHazard, isTrue);
        expect(requestCount, 3);
      });

      test('4. several 2009/2010 failures -> later valid bearing succeeds', () async {
        final containing = hazard(
          id: 'containing-h1',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final coords = body['coordinates'] as List;
            final wp = (coords.last as List).map((e) => (e as num).toDouble()).toList();

            if (count == 1) {
              // Bearing 0 fails with 2009
              return http.Response('{"error":{"code":2009,"message":"No route"}}', 404);
            }
            if (count == 2) {
              // Bearing 45 fails with 2010
              return http.Response('{"error":{"code":2010,"message":"Unroutable point"}}', 404);
            }
            if (count == 3) {
              // Bearing -45 fails with 2010
              return http.Response('{"error":{"code":2010,"message":"Unroutable point"}}', 404);
            }
            if (count == 4) {
              // Bearing 90 Phase 1 succeeds
              return http.Response(
                routeResponse(coordinates: [[start.longitude, start.latitude], wp]),
                200,
              );
            }
            if (count == 5) {
              // Bearing 90 Phase 2 succeeds
              return http.Response(
                routeResponse(coordinates: [wp, [destination.longitude, destination.latitude]]),
                200,
              );
            }
            fail('Unexpected request count: $count');
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        );

        expect(result.startedInsideHazard, isTrue);
        expect(requestCount, 5);
      });

      test('5. all radial candidates fail -> route-derived fallback starts', () async {
        final containing = hazard(
          id: 'containing-h1',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );
        final bearing = SafeRoutingService.initialBearingDegrees(start, destination);
        final exit = SafeRoutingService.computeDestinationPoint(
          start,
          SafetyConfig.highSeverityRadiusMeters + 60,
          bearing,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final coords = body['coordinates'] as List;

            if (count <= 8) {
              // All 8 radial candidates fail with 2010
              return http.Response('{"error":{"code":2010,"message":"Unroutable"}}', 404);
            }
            if (count == 9) {
              // Route-derived probe: start -> destination
              expect((coords[1][1] as num).toDouble(), closeTo(destination.latitude, 0.0001));
              return http.Response(
                routeResponse(
                  coordinates: [
                    [start.longitude, start.latitude],
                    [exit.longitude, exit.latitude],
                    [destination.longitude, destination.latitude],
                  ],
                ),
                200,
              );
            }
            if (count == 10) {
              // Route-derived safe route: exit -> destination
              return http.Response(
                routeResponse(
                  coordinates: [
                    [exit.longitude, exit.latitude],
                    [destination.longitude, destination.latitude],
                  ],
                ),
                200,
              );
            }
            fail('Unexpected request count: $count');
          },
        );

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        );

        expect(result.startedInsideHazard, isTrue);
        expect(requestCount, 10);
      });

      test('6. 429 aborts candidate loop immediately', () async {
        final containing = hazard(
          id: 'containing-h1',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );

        final service = serviceReturning(
          handler: (request, count) async {
            return http.Response('{"error":"Rate limit exceeded"}', 429);
          },
        );

        SafeRoutingException? caught;
        try {
          await service.calculateSafeRoute(
            start: start,
            destination: destination,
            hazards: [containing],
          );
        } on SafeRoutingException catch (e) {
          caught = e;
        }

        expect(caught, isNotNull);
        expect(caught!.code, SafeRoutingFailureCode.rateLimited);
        // Must abort immediately on candidate 1: exactly 1 request made
        expect(requestCount, 1);
      });

      test('7. 429 does not trigger route-derived fallback', () async {
        final containing = hazard(
          id: 'containing-h1',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );

        var probeRequestAttempted = false;
        final service = serviceReturning(
          handler: (request, count) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final coords = body['coordinates'] as List;
            final wpLat = (coords.last[1] as num).toDouble();
            if ((wpLat - destination.latitude).abs() < 0.0001) {
              probeRequestAttempted = true;
            }
            return http.Response('{"error":"Rate limit exceeded"}', 429);
          },
        );

        try {
          await service.calculateSafeRoute(
            start: start,
            destination: destination,
            hazards: [containing],
          );
        } on SafeRoutingException {
          // Expected
        }

        expect(probeRequestAttempted, isFalse);
        expect(requestCount, 1);
      });

      test('8. unrelated hazards remain avoided during escape', () async {
        final containing = hazard(
          id: 'containing-h1',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );
        final unrelated = hazard(
          id: 'unrelated-h2',
          severity: 'Low',
          latitude: 5.44,
          longitude: 100.35,
        );

        final service = serviceReturning();
        await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing, unrelated],
        );

        final escapeRequest = jsonDecode(capturedRequests[0].body) as Map<String, dynamic>;
        final escapeAvoid = (escapeRequest['options'] as Map<String, dynamic>)['avoid_polygons'] as Map<String, dynamic>;
        final escapePolygons = escapeAvoid['coordinates'] as List;
        expect(escapePolygons, hasLength(1), reason: 'Unrelated hazard must be avoided during escape');
      });

      test('9. start-containing hazards are temporarily excluded only during escape', () async {
        final containing = hazard(
          id: 'containing-h1',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );

        final service = serviceReturning();
        await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        );

        final escapeBody = jsonDecode(capturedRequests[0].body) as Map<String, dynamic>;
        expect(escapeBody.containsKey('options'), isFalse, reason: 'Containing hazard excluded in Phase 1');
      });

      test('10. full avoidance restored after exit', () async {
        final containing = hazard(
          id: 'containing-h1',
          severity: 'High',
          latitude: start.latitude,
          longitude: start.longitude,
        );

        final service = serviceReturning();
        await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [containing],
        );

        final phase2Body = jsonDecode(capturedRequests[1].body) as Map<String, dynamic>;
        final phase2Avoid = (phase2Body['options'] as Map<String, dynamic>)['avoid_polygons'] as Map<String, dynamic>;
        expect((phase2Avoid['coordinates'] as List), hasLength(1), reason: 'Containing hazard restored in Phase 2');
      });

      test('11. cache safety remains working', () async {
        final h1 = hazard(id: 'cached-h1', severity: 'High', latitude: 5.44, longitude: 100.32);
        final service = serviceReturning();

        await service.calculateSafeRoute(start: start, destination: destination, hazards: [h1]);
        expect(requestCount, 1);

        // Same request -> cache hit (0 ORS calls)
        await service.calculateSafeRoute(start: start, destination: destination, hazards: [h1]);
        expect(requestCount, 1);

        // Changed severity -> cache miss (1 ORS call)
        final h1Modified = hazard(id: 'cached-h1', severity: 'Low', latitude: 5.44, longitude: 100.32);
        await service.calculateSafeRoute(start: start, destination: destination, hazards: [h1Modified]);
        expect(requestCount, 2);
      });

      test('12. normal start-outside-hazard routing unchanged', () async {
        final outsideHazard = hazard(id: 'outside-h1', severity: 'Medium', latitude: 5.44, longitude: 100.35);
        final service = serviceReturning();

        final result = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [outsideHazard],
        );

        expect(result.startedInsideHazard, isFalse);
        expect(requestCount, 1);
      });
    });

    test('1. same request + same hazard state => cache hit', () async {
      final h1 = hazard(id: 'cached-h1', severity: 'High', latitude: 5.44, longitude: 100.32);
      final service = serviceReturning();

      final route1 = await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [h1],
      );
      expect(requestCount, 1);

      final route2 = await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [h1],
      );
      expect(requestCount, 1);
      expect(identical(route1, route2) || route1.geometry.length == route2.geometry.length, isTrue);
    });

    test('2. same hazard ID but changed severity => cache miss', () async {
      final hLow = hazard(id: 'cached-h1', severity: 'Low', latitude: 5.44, longitude: 100.32);
      final hHigh = hazard(id: 'cached-h1', severity: 'High', latitude: 5.44, longitude: 100.32);
      final service = serviceReturning();

      await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [hLow],
      );
      expect(requestCount, 1);

      await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [hHigh],
      );
      expect(requestCount, 2);
    });

    test('3. same hazard ID but changed coordinates => cache miss', () async {
      final hPos1 = hazard(id: 'cached-h1', severity: 'High', latitude: 5.4400, longitude: 100.3200);
      final hPos2 = hazard(id: 'cached-h1', severity: 'High', latitude: 5.4410, longitude: 100.3210);
      final service = serviceReturning();

      await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [hPos1],
      );
      expect(requestCount, 1);

      await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [hPos2],
      );
      expect(requestCount, 2);
    });

    test('4. hazard becomes inactive => cache miss', () async {
      final hActive = hazard(
        id: 'cached-h1',
        severity: 'High',
        status: HazardReportStatus.verified,
        latitude: 5.44,
        longitude: 100.32,
      );
      final hInactive = hazard(
        id: 'cached-h1',
        severity: 'High',
        status: HazardReportStatus.resolved,
        latitude: 5.44,
        longitude: 100.32,
      );
      final service = serviceReturning();

      await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [hActive],
      );
      expect(requestCount, 1);

      await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [hInactive],
      );
      expect(requestCount, 2);
    });

    test('5. destination/stops change => cache miss', () async {
      final h1 = hazard(id: 'cached-h1', severity: 'High', latitude: 5.44, longitude: 100.32);
      final dest1 = LatLng(5.45, 100.36);
      final dest2 = LatLng(5.46, 100.37);
      final service = serviceReturning();

      await service.calculateSafeRoute(
        start: start,
        destination: dest1,
        hazards: [h1],
      );
      expect(requestCount, 1);

      await service.calculateSafeRoute(
        start: start,
        destination: dest2,
        hazards: [h1],
      );
      expect(requestCount, 2);
    });

    test('start position change => cache miss', () async {
      final h1 = hazard(id: 'cached-h1', severity: 'High', latitude: 5.44, longitude: 100.32);
      final service = serviceReturning();

      await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [h1],
      );
      expect(requestCount, 1);

      await service.calculateSafeRoute(
        start: LatLng(start.latitude + 0.005, start.longitude + 0.005),
        destination: destination,
        hazards: [h1],
      );
      expect(requestCount, 2);
    });

    test('cache never bypasses destination-inside-hazard validation', () async {
      final h1 = hazard(id: 'cached-h1', severity: 'High', latitude: 5.44, longitude: 100.32);
      final safeDest = LatLng(5.45, 100.36);
      final unsafeDest = LatLng(5.4401, 100.3201); // within 100m of h1 (radius 500m)
      final service = serviceReturning();

      await service.calculateSafeRoute(
        start: start,
        destination: safeDest,
        hazards: [h1],
      );
      expect(requestCount, 1);

      expect(
        () => service.calculateSafeRoute(
          start: start,
          destination: unsafeDest,
          hazards: [h1],
        ),
        throwsA(
          isA<SafeRoutingException>().having(
            (e) => e.code,
            'code',
            SafeRoutingFailureCode.destinationInsideHazard,
          ),
        ),
      );
      expect(requestCount, 1); // rejected locally without hitting ORS
    });

    test('Result cache is bypassed when allowCache is false', () async {
      final h1 = hazard(id: 'cached-h1', severity: 'High', latitude: 5.44, longitude: 100.32);
      final service = serviceReturning();

      await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [h1],
        allowCache: false,
      );
      expect(requestCount, 1);

      await service.calculateSafeRoute(
        start: start,
        destination: destination,
        hazards: [h1],
        allowCache: false,
      );
      expect(requestCount, 2);
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
