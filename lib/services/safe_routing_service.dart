import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/safety_config.dart';
import '../models/hazard_report.dart';
import '../models/safe_route.dart';

enum SafeRoutingFailureCode {
  missingApiKey('MISSING_API_KEY'),
  invalidStart('INVALID_START'),
  invalidDestination('INVALID_DESTINATION'),
  startInsideHazard('START_INSIDE_HAZARD'),
  destinationInsideHazard('DESTINATION_INSIDE_HAZARD'),
  requestTooLarge('REQUEST_TOO_LARGE'),
  timeout('TIMEOUT'),
  unauthorized('UNAUTHORIZED'),
  rateLimited('RATE_LIMITED'),
  invalidRequest('INVALID_REQUEST'),
  providerUnavailable('PROVIDER_UNAVAILABLE'),
  networkFailure('NETWORK_FAILURE'),
  noRoute('NO_ROUTE'),
  malformedResponse('MALFORMED_RESPONSE'),
  providerFailure('PROVIDER_FAILURE');

  const SafeRoutingFailureCode(this.code);

  final String code;
}

/// A controlled domain/provider failure from [SafeRoutingService].
class SafeRoutingException implements Exception {
  const SafeRoutingException({
    required this.code,
    required this.message,
    this.hazardId,
    this.statusCode,
  });

  final SafeRoutingFailureCode code;
  final String message;
  final String? hazardId;
  final int? statusCode;

  @override
  String toString() =>
      'SafeRoutingException(${code.code}): $message'
      '${hazardId == null ? '' : ' (hazard: $hazardId)'}';
}

/// Calculates real driving routes while asking OpenRouteService to avoid the
/// configured danger radius around every valid, Verified hazard.
class SafeRoutingService {
  SafeRoutingService({
    http.Client? client,
    String apiKey = const String.fromEnvironment(
      'ORS_API_KEY',
      defaultValue: '',
    ),
    Duration timeout = const Duration(seconds: 20),
    int maxRequestBytes = 512 * 1024,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _apiKey = apiKey,
       _timeout = timeout,
       _maxRequestBytes = maxRequestBytes;

  static final Uri endpoint = Uri.parse(
    'https://api.heigit.org/openrouteservice/v2/directions/'
    'driving-car/geojson',
  );

  static const int hazardPolygonSegments = 16;
  static const double _earthRadiusMeters = 6371008.8;

  final http.Client _client;
  final bool _ownsClient;
  final String _apiKey;
  final Duration _timeout;
  final int _maxRequestBytes;

  Future<SafeRoute> calculateSafeRoute({
    required LatLng start,
    required LatLng destination,
    required List<HazardReport> hazards,
  }) async {
    _validateRouteEndpoint(start, isStart: true);
    _validateRouteEndpoint(destination, isStart: false);

    final activeHazards = hazards
        .where((hazard) => hazard.isVerified && hazard.hasValidLocation)
        .toList(growable: false);

    for (final hazard in activeHazards) {
      final radius = SafetyConfig.dangerRadiusForSeverity(hazard.severity);
      final hazardPoint = LatLng(hazard.latitude, hazard.longitude);
      if (distanceMeters(start, hazardPoint) <= radius) {
        throw SafeRoutingException(
          code: SafeRoutingFailureCode.startInsideHazard,
          message: 'The route origin is inside an active hazard zone.',
          hazardId: hazard.id,
        );
      }
      if (distanceMeters(destination, hazardPoint) <= radius) {
        throw SafeRoutingException(
          code: SafeRoutingFailureCode.destinationInsideHazard,
          message: 'The route destination is inside an active hazard zone.',
          hazardId: hazard.id,
        );
      }
    }

    if (_apiKey.trim().isEmpty) {
      throw const SafeRoutingException(
        code: SafeRoutingFailureCode.missingApiKey,
        message: 'ORS_API_KEY was not supplied.',
      );
    }

    final requestBody = <String, Object>{
      'coordinates': [toOrsCoordinate(start), toOrsCoordinate(destination)],
      'instructions': true,
    };

    if (activeHazards.isNotEmpty) {
      requestBody['options'] = {
        'avoid_polygons': {
          'type': 'MultiPolygon',
          'coordinates': [
            for (final hazard in activeHazards) [buildHazardPolygon(hazard)],
          ],
        },
      };
    }

    final encodedBody = jsonEncode(requestBody);
    if (utf8.encode(encodedBody).length > _maxRequestBytes) {
      throw SafeRoutingException(
        code: SafeRoutingFailureCode.requestTooLarge,
        message:
            'The hazard avoidance request exceeds the configured '
            '$_maxRequestBytes-byte safety limit.',
      );
    }

    late final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: {
              'Authorization': _apiKey,
              'Content-Type': 'application/json',
              'Accept': 'application/json, application/geo+json',
            },
            body: encodedBody,
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const SafeRoutingException(
        code: SafeRoutingFailureCode.timeout,
        message: 'OpenRouteService did not respond before the timeout.',
      );
    } on http.ClientException {
      throw const SafeRoutingException(
        code: SafeRoutingFailureCode.networkFailure,
        message: 'OpenRouteService could not be reached.',
      );
    }

    if (response.statusCode != 200) {
      throw _exceptionForHttpStatus(response.statusCode);
    }

    try {
      return _parseRoute(
        response.body,
        avoidedHazardIds: activeHazards.map((hazard) => hazard.id),
      );
    } on SafeRoutingException {
      rethrow;
    } on Object {
      throw const SafeRoutingException(
        code: SafeRoutingFailureCode.malformedResponse,
        message: 'OpenRouteService returned an invalid route response.',
      );
    }
  }

  /// Converts Flutter's latitude/longitude value to GeoJSON's
  /// `[longitude, latitude]` coordinate order.
  static List<double> toOrsCoordinate(LatLng point) => [
    point.longitude,
    point.latitude,
  ];

  /// Converts a GeoJSON `[longitude, latitude]` coordinate into [LatLng].
  static LatLng fromOrsCoordinate(Object? coordinate) {
    if (coordinate is! List || coordinate.length < 2) {
      throw const FormatException('Expected a GeoJSON position.');
    }
    final longitude = _finiteDouble(coordinate[0]);
    final latitude = _finiteDouble(coordinate[1]);
    if (!SafetyConfig.validCoordinates(latitude, longitude)) {
      throw const FormatException('GeoJSON position is outside valid bounds.');
    }
    return LatLng(latitude, longitude);
  }

  /// Builds a closed GeoJSON linear ring around [hazard].
  ///
  /// A spherical destination-point calculation avoids the longitude scaling
  /// instability of simple `cos(latitude)` approximations near the poles.
  static List<List<double>> buildHazardPolygon(
    HazardReport hazard, {
    int segments = hazardPolygonSegments,
  }) {
    if (!hazard.hasValidLocation) {
      throw ArgumentError.value(hazard.id, 'hazard', 'Invalid location');
    }
    if (segments < 8) {
      throw ArgumentError.value(segments, 'segments', 'Must be at least 8');
    }

    final radius = SafetyConfig.dangerRadiusForSeverity(hazard.severity);
    final angularDistance = radius / _earthRadiusMeters;
    final latitude1 = _toRadians(hazard.latitude);
    final longitude1 = _toRadians(hazard.longitude);
    final ring = <List<double>>[];

    for (var index = 0; index < segments; index++) {
      final bearing = 2 * math.pi * index / segments;
      final latitude2 = math.asin(
        (math.sin(latitude1) * math.cos(angularDistance) +
                math.cos(latitude1) *
                    math.sin(angularDistance) *
                    math.cos(bearing))
            .clamp(-1.0, 1.0),
      );
      final longitude2 =
          longitude1 +
          math.atan2(
            math.sin(bearing) * math.sin(angularDistance) * math.cos(latitude1),
            math.cos(angularDistance) -
                math.sin(latitude1) * math.sin(latitude2),
          );
      ring.add([
        _normalizeLongitude(_toDegrees(longitude2)),
        _toDegrees(latitude2).clamp(-90.0, 90.0),
      ]);
    }

    ring.add(List<double>.from(ring.first));
    return ring;
  }

  static double distanceMeters(LatLng first, LatLng second) {
    final latitude1 = _toRadians(first.latitude);
    final latitude2 = _toRadians(second.latitude);
    final latitudeDelta = latitude2 - latitude1;
    final longitudeDelta = _toRadians(second.longitude - first.longitude);
    final sinLatitude = math.sin(latitudeDelta / 2);
    final sinLongitude = math.sin(longitudeDelta / 2);
    final haversine =
        sinLatitude * sinLatitude +
        math.cos(latitude1) * math.cos(latitude2) * sinLongitude * sinLongitude;
    final centralAngle = 2 * math.asin(math.sqrt(haversine.clamp(0.0, 1.0)));
    return _earthRadiusMeters * centralAngle;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }

  static void _validateRouteEndpoint(LatLng point, {required bool isStart}) {
    if (SafetyConfig.validCoordinates(point.latitude, point.longitude)) return;
    throw SafeRoutingException(
      code: isStart
          ? SafeRoutingFailureCode.invalidStart
          : SafeRoutingFailureCode.invalidDestination,
      message: isStart
          ? 'The route origin has invalid coordinates.'
          : 'The route destination has invalid coordinates.',
    );
  }

  static SafeRoutingException _exceptionForHttpStatus(int statusCode) {
    if (statusCode == 400) {
      return SafeRoutingException(
        code: SafeRoutingFailureCode.invalidRequest,
        message: 'OpenRouteService rejected the routing request.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 401 || statusCode == 403) {
      return SafeRoutingException(
        code: SafeRoutingFailureCode.unauthorized,
        message: 'OpenRouteService authorization failed.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 429) {
      return SafeRoutingException(
        code: SafeRoutingFailureCode.rateLimited,
        message: 'OpenRouteService rate limit was reached.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 404) {
      return SafeRoutingException(
        code: SafeRoutingFailureCode.noRoute,
        message: 'No road route is available for the requested points.',
        statusCode: statusCode,
      );
    }
    if (statusCode >= 500) {
      return SafeRoutingException(
        code: SafeRoutingFailureCode.providerUnavailable,
        message: 'OpenRouteService is temporarily unavailable.',
        statusCode: statusCode,
      );
    }
    return SafeRoutingException(
      code: SafeRoutingFailureCode.providerFailure,
      message: 'OpenRouteService returned HTTP $statusCode.',
      statusCode: statusCode,
    );
  }

  static SafeRoute _parseRoute(
    String responseBody, {
    required Iterable<String> avoidedHazardIds,
  }) {
    final decoded = jsonDecode(responseBody);
    final root = _stringMap(decoded);
    final features = root['features'];
    if (features is! List) {
      throw const FormatException('Missing route features.');
    }
    if (features.isEmpty) {
      throw const SafeRoutingException(
        code: SafeRoutingFailureCode.noRoute,
        message: 'No road route is available for the requested points.',
      );
    }

    final feature = _stringMap(features.first);
    final geometryMap = _stringMap(feature['geometry']);
    if (geometryMap['type'] != 'LineString') {
      throw const FormatException('Route geometry is not a LineString.');
    }
    final rawCoordinates = geometryMap['coordinates'];
    if (rawCoordinates is! List || rawCoordinates.length < 2) {
      throw const FormatException('Route geometry is missing coordinates.');
    }
    final geometry = rawCoordinates.map(fromOrsCoordinate).toList();

    final properties = _stringMap(feature['properties']);
    final summary = _stringMap(properties['summary']);
    final distance = _nonNegativeDouble(summary['distance']);
    final duration = _nonNegativeDouble(summary['duration']);

    final rawSegments = properties['segments'];
    if (rawSegments is! List) {
      throw const FormatException('Route segments are missing.');
    }
    final steps = <RouteStep>[];
    for (final rawSegment in rawSegments) {
      final segment = _stringMap(rawSegment);
      final rawSteps = segment['steps'];
      if (rawSteps is! List) {
        throw const FormatException('Route steps are missing.');
      }
      for (final rawStep in rawSteps) {
        final step = _stringMap(rawStep);
        final instruction = step['instruction'];
        final name = step['name'];
        final type = step['type'];
        final wayPoints = step['way_points'];
        if (instruction is! String ||
            name is! String ||
            type is! num ||
            !type.isFinite ||
            type != type.roundToDouble() ||
            wayPoints is! List ||
            wayPoints.length != 2) {
          throw const FormatException('A route step is malformed.');
        }
        steps.add(
          RouteStep(
            instruction: instruction,
            roadName: name,
            distanceMeters: _nonNegativeDouble(step['distance']),
            durationSeconds: _nonNegativeDouble(step['duration']),
            maneuverType: type.toInt(),
            startGeometryIndex: _nonNegativeInt(wayPoints[0]),
            endGeometryIndex: _nonNegativeInt(wayPoints[1]),
          ),
        );
      }
    }

    return SafeRoute(
      geometry: geometry,
      distanceMeters: distance,
      durationSeconds: duration,
      steps: steps,
      avoidedHazardIds: avoidedHazardIds,
    );
  }

  static Map<String, dynamic> _stringMap(Object? value) {
    if (value is! Map) throw const FormatException('Expected an object.');
    return Map<String, dynamic>.from(value);
  }

  static double _finiteDouble(Object? value) {
    if (value is! num || !value.isFinite) {
      throw const FormatException('Expected a finite number.');
    }
    return value.toDouble();
  }

  static double _nonNegativeDouble(Object? value) {
    final number = _finiteDouble(value);
    if (number < 0) throw const FormatException('Expected a positive number.');
    return number;
  }

  static int _nonNegativeInt(Object? value) {
    if (value is! num ||
        !value.isFinite ||
        value != value.roundToDouble() ||
        value < 0) {
      throw const FormatException('Expected a non-negative integer.');
    }
    return value.toInt();
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
  static double _toDegrees(double radians) => radians * 180 / math.pi;

  static double _normalizeLongitude(double longitude) {
    final normalized = (longitude + 540) % 360 - 180;
    return normalized == -180 ? 180 : normalized;
  }
}
