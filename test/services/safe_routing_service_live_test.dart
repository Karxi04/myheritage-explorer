import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:myheritage_explorer/core/safety_config.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/models/safe_route.dart';
import 'package:myheritage_explorer/services/safe_routing_service.dart';

const _orsApiKey = String.fromEnvironment('ORS_API_KEY', defaultValue: '');

void main() {
  test(
    'live ORS route avoids the configured hazard radius in George Town',
    () async {
      // Public road-adjacent points spanning central George Town, Penang.
      const start = LatLng(5.42085, 100.34385);
      const destination = LatLng(5.43710, 100.31070);
      const severity = 'High';
      final hazardRadius = SafetyConfig.dangerRadiusForSeverity(severity);
      final recordingClient = _RecordingClient(
        delegate: http.Client(),
        secretToRedact: _orsApiKey,
      );
      addTearDown(recordingClient.close);
      final service = SafeRoutingService(
        client: recordingClient,
        apiKey: _orsApiKey,
        timeout: const Duration(seconds: 30),
      );

      try {
        // Request A: ordinary driving route, with no avoidance geometry.
        final baseline = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: const [],
        );

        // Select the distance midpoint of the actual baseline road geometry.
        // This makes the in-memory hazard reproducibly sit on the route without
        // persisting any test data or relying on a visually estimated road.
        final hazardPoint = _pointAtHalfDistance(baseline.geometry);
        final syntheticHazard = HazardReport(
          id: 'live-ors-smoke-hazard',
          userId: 'live-smoke-test',
          category: 'Synthetic road hazard',
          severity: severity,
          description: 'In-memory only; never written to Firestore.',
          latitude: hazardPoint.latitude,
          longitude: hazardPoint.longitude,
          status: HazardReportStatus.verified,
        );

        expect(
          SafeRoutingService.distanceMeters(start, hazardPoint),
          greaterThan(hazardRadius),
          reason: 'The synthetic hazard must not contain the start point.',
        );
        expect(
          SafeRoutingService.distanceMeters(destination, hazardPoint),
          greaterThan(hazardRadius),
          reason: 'The synthetic hazard must not contain the destination.',
        );

        // Request B: same endpoints, now with the Verified hazard polygon.
        final safeRoute = await service.calculateSafeRoute(
          start: start,
          destination: destination,
          hazards: [syntheticHazard],
        );

        final baselineMinimum = _minimumPolylineDistanceMeters(
          baseline.geometry,
          hazardPoint,
        );
        final safeMinimum = _minimumPolylineDistanceMeters(
          safeRoute.geometry,
          hazardPoint,
        );
        const numericalToleranceMeters = 2.0;
        final avoidanceWasSent =
            recordingClient.avoidPolygonFlags.length == 2 &&
            !recordingClient.avoidPolygonFlags.first &&
            recordingClient.avoidPolygonFlags.last;
        final passed =
            baselineMinimum < hazardRadius &&
            safeMinimum >= hazardRadius - numericalToleranceMeters &&
            avoidanceWasSent;

        _printReport(
          start: start,
          destination: destination,
          hazardPoint: hazardPoint,
          severity: severity,
          hazardRadius: hazardRadius,
          baseline: baseline,
          baselineMinimum: baselineMinimum,
          safeRoute: safeRoute,
          safeMinimum: safeMinimum,
          avoidanceWasSent: avoidanceWasSent,
          passed: passed,
        );

        expect(recordingClient.requestCount, 2);
        expect(
          avoidanceWasSent,
          isTrue,
          reason: 'Only the safe request must contain options.avoid_polygons.',
        );
        expect(
          baselineMinimum,
          lessThan(hazardRadius),
          reason: 'The baseline route must enter the configured hazard radius.',
        );
        expect(
          safeMinimum,
          greaterThanOrEqualTo(hazardRadius - numericalToleranceMeters),
          reason: 'The safe route must stay outside the hazard radius.',
        );
      } on SafeRoutingException catch (error) {
        debugPrint('LIVE ORS RESULT: PROVIDER FAILURE (${error.code.code})');
        debugPrint('HTTP status: ${recordingClient.lastStatusCode ?? 'none'}');
        debugPrint(
          'Provider response: '
          '${recordingClient.lastSanitizedResponseBody ?? 'none received'}',
        );
        rethrow;
      }
    },
    skip: _orsApiKey.trim().isEmpty
        ? 'Requires --dart-define=ORS_API_KEY=<non-committed-key>.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient({required this.delegate, required this.secretToRedact});

  final http.Client delegate;
  final String secretToRedact;
  final List<bool> avoidPolygonFlags = [];
  int requestCount = 0;
  int? lastStatusCode;
  String? lastSanitizedResponseBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    if (request is http.Request) {
      final decoded = jsonDecode(request.body);
      final body = decoded is Map<String, dynamic> ? decoded : const {};
      final options = body['options'];
      avoidPolygonFlags.add(
        options is Map<String, dynamic> && options['avoid_polygons'] != null,
      );
    } else {
      avoidPolygonFlags.add(false);
    }

    final response = await delegate.send(request);
    final bytes = await response.stream.toBytes();
    lastStatusCode = response.statusCode;
    final responseText = utf8.decode(bytes, allowMalformed: true);
    lastSanitizedResponseBody = secretToRedact.isEmpty
        ? responseText
        : responseText.replaceAll(secretToRedact, '[REDACTED]');
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => delegate.close();
}

LatLng _pointAtHalfDistance(List<LatLng> geometry) {
  if (geometry.length < 2) {
    throw StateError('The baseline route has insufficient geometry.');
  }
  final segmentLengths = <double>[];
  var totalLength = 0.0;
  for (var index = 1; index < geometry.length; index++) {
    final length = SafeRoutingService.distanceMeters(
      geometry[index - 1],
      geometry[index],
    );
    segmentLengths.add(length);
    totalLength += length;
  }

  final targetLength = totalLength / 2;
  var traversed = 0.0;
  for (var index = 0; index < segmentLengths.length; index++) {
    final segmentLength = segmentLengths[index];
    if (traversed + segmentLength >= targetLength) {
      final fraction = segmentLength == 0
          ? 0.0
          : (targetLength - traversed) / segmentLength;
      final first = geometry[index];
      final second = geometry[index + 1];
      return LatLng(
        first.latitude + (second.latitude - first.latitude) * fraction,
        first.longitude + (second.longitude - first.longitude) * fraction,
      );
    }
    traversed += segmentLength;
  }
  return geometry[geometry.length ~/ 2];
}

double _minimumPolylineDistanceMeters(List<LatLng> geometry, LatLng center) {
  if (geometry.length < 2) {
    throw StateError('Route geometry must contain at least two points.');
  }
  const earthRadiusMeters = 6371008.8;
  final centerLatitudeRadians = center.latitude * math.pi / 180;

  ({double x, double y}) project(LatLng point) {
    final longitudeDeltaRadians =
        (point.longitude - center.longitude) * math.pi / 180;
    final latitudeDeltaRadians =
        (point.latitude - center.latitude) * math.pi / 180;
    return (
      x:
          earthRadiusMeters *
          longitudeDeltaRadians *
          math.cos(centerLatitudeRadians),
      y: earthRadiusMeters * latitudeDeltaRadians,
    );
  }

  var minimum = double.infinity;
  for (var index = 1; index < geometry.length; index++) {
    final first = project(geometry[index - 1]);
    final second = project(geometry[index]);
    final deltaX = second.x - first.x;
    final deltaY = second.y - first.y;
    final lengthSquared = deltaX * deltaX + deltaY * deltaY;
    final projection = lengthSquared == 0
        ? 0.0
        : (-(first.x * deltaX + first.y * deltaY) / lengthSquared).clamp(
            0.0,
            1.0,
          );
    final closestX = first.x + projection * deltaX;
    final closestY = first.y + projection * deltaY;
    minimum = math.min(
      minimum,
      math.sqrt(closestX * closestX + closestY * closestY),
    );
  }
  return minimum;
}

void _printReport({
  required LatLng start,
  required LatLng destination,
  required LatLng hazardPoint,
  required String severity,
  required double hazardRadius,
  required SafeRoute baseline,
  required double baselineMinimum,
  required SafeRoute safeRoute,
  required double safeMinimum,
  required bool avoidanceWasSent,
  required bool passed,
}) {
  debugPrint('LIVE ORS HAZARD AVOIDANCE REPORT');
  debugPrint('Start: ${start.latitude}, ${start.longitude}');
  debugPrint('Destination: ${destination.latitude}, ${destination.longitude}');
  debugPrint(
    'Synthetic hazard: ${hazardPoint.latitude}, ${hazardPoint.longitude}',
  );
  debugPrint('Hazard severity: $severity');
  debugPrint('Hazard radius: ${hazardRadius.toStringAsFixed(1)} m');
  debugPrint(
    'Baseline distance: ${(baseline.distanceMeters / 1000).toStringAsFixed(3)} km',
  );
  debugPrint(
    'Baseline duration: ${(baseline.durationSeconds / 60).toStringAsFixed(3)} min',
  );
  debugPrint(
    'Baseline closest distance: ${baselineMinimum.toStringAsFixed(2)} m',
  );
  debugPrint(
    'Safe distance: ${(safeRoute.distanceMeters / 1000).toStringAsFixed(3)} km',
  );
  debugPrint(
    'Safe duration: ${(safeRoute.durationSeconds / 60).toStringAsFixed(3)} min',
  );
  debugPrint('Safe closest distance: ${safeMinimum.toStringAsFixed(2)} m');
  debugPrint('avoid_polygons sent: $avoidanceWasSent');
  debugPrint('RESULT: ${passed ? 'PASS' : 'FAIL'}');
}
