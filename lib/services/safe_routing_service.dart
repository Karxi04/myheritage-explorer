import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/safety_config.dart';
import '../models/hazard_report.dart';
import '../models/navigation_stop.dart';
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
  /// Canonical single source of the compile-time ORS API key environment value.
  static const String defaultEnvironmentApiKey = String.fromEnvironment(
    'ORS_API_KEY',
    defaultValue: '',
  );

  /// Cleans an API key by stripping whitespace and surrounding quotation marks.
  static String sanitizeApiKey(String? raw) {
    if (raw == null) return '';
    var cleaned = raw.trim();
    if (cleaned.length >= 2) {
      if ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
          (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
        cleaned = cleaned.substring(1, cleaned.length - 1).trim();
      }
    }
    return cleaned;
  }

  /// Resolves the effective API key. If [injected] is null or empty/whitespace,
  /// falls back to [defaultEnvironmentApiKey]. An empty string does NOT override
  /// the environment key.
  static String resolveApiKey(String? injected) {
    final sanitizedInjected = sanitizeApiKey(injected);
    if (sanitizedInjected.isNotEmpty) {
      return sanitizedInjected;
    }
    return sanitizeApiKey(defaultEnvironmentApiKey);
  }

  SafeRoutingService({
    http.Client? client,
    String? apiKey,
    Duration timeout = const Duration(seconds: 20),
    int maxRequestBytes = 512 * 1024,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _apiKey = resolveApiKey(apiKey),
       _timeout = timeout,
       _maxRequestBytes = maxRequestBytes;

  String get apiKey => _apiKey;

  static final Uri endpoint = Uri.parse(
    'https://api.heigit.org/openrouteservice/v2/directions/'
    'driving-car/geojson',
  );

  static const int hazardPolygonSegments = 16;
  static const double _earthRadiusMeters = 6371008.8;

  /// Safety margin beyond hazard boundaries when generating escape points.
  static const double escapeSafetyMarginMeters =
      SafetyConfig.escapeSafetyMarginMeters;

  /// Bounded set of bearing offsets to try around the primary escape direction.
  static const List<double> escapeBearingOffsets = [
    0,
    45,
    -45,
    90,
    -90,
    135,
    -135,
    180,
  ];

  final http.Client _client;
  final bool _ownsClient;
  final String _apiKey;
  final Duration _timeout;
  final int _maxRequestBytes;

  Future<SafeRoute> calculateSafeRoute({
    required LatLng start,
    List<NavigationStop>? stops,
    LatLng? destination,
    required List<HazardReport> hazards,
  }) async {
    _validateRouteEndpoint(start, isStart: true);

    final effectiveStops = (stops != null && stops.isNotEmpty)
        ? stops
        : (destination != null
              ? [
                  NavigationStop(
                    id: 'destination',
                    location: destination,
                    displayName: 'Destination',
                    isDestination: true,
                  ),
                ]
              : <NavigationStop>[]);

    if (effectiveStops.isEmpty) {
      throw const SafeRoutingException(
        code: SafeRoutingFailureCode.invalidDestination,
        message: 'No destination or stops were provided.',
      );
    }

    for (final stop in effectiveStops) {
      _validateRouteEndpoint(stop.location, isStart: false);
    }

    final activeHazards = hazards
        .where((hazard) => hazard.isVerified && hazard.hasValidLocation)
        .toList(growable: false);

    // High-Severity Rule: Any stop / destination inside an active Verified HIGH-severity hazard blocks routing.
    for (final stop in effectiveStops) {
      for (final hazard in activeHazards) {
        if (hazard.severity.trim().toLowerCase() == 'high') {
          final radius = SafetyConfig.dangerRadiusForSeverity(hazard.severity);
          final hazardPoint = LatLng(hazard.latitude, hazard.longitude);
          if (distanceMeters(stop.location, hazardPoint) <= radius) {
            throw SafeRoutingException(
              code: SafeRoutingFailureCode.destinationInsideHazard,
              message:
                  'A route stop or destination is inside an active high-severity hazard zone.',
              hazardId: hazard.id,
            );
          }
        }
      }
    }

    // Determine every active verified hazard containing the start point.
    final containingHazards = <HazardReport>[];
    for (final hazard in activeHazards) {
      final radius = SafetyConfig.dangerRadiusForSeverity(hazard.severity);
      final hazardPoint = LatLng(hazard.latitude, hazard.longitude);
      if (distanceMeters(start, hazardPoint) <= radius) {
        containingHazards.add(hazard);
      }
    }

    // Case A: Start is outside all verified hazards -> progressive fallback routing.
    if (containingHazards.isEmpty) {
      return _calculateWithFallback(
        start: start,
        stops: effectiveStops,
        allActiveHazards: activeHazards,
      );
    }

    // Case B: Start is inside one or more verified hazards -> ESCAPE MODE.
    return _calculateEscapeRoute(
      start: start,
      stops: effectiveStops,
      containingHazards: containingHazards,
      allActiveHazards: activeHazards,
    );
  }

  Future<SafeRoute> _calculateWithFallback({
    required LatLng start,
    required List<NavigationStop> stops,
    required List<HazardReport> allActiveHazards,
  }) async {
    final attempts = _riskAttempts(allActiveHazards);

    SafeRoutingException? lastNoRouteException;
    final attemptedAvoidSignatures = <String>{};

    for (final attempt in attempts) {
      final avoidSig = _avoidSignature(attempt.avoidHazards);
      if (!attemptedAvoidSignatures.add(avoidSig)) continue;

      try {
        final route = await _fetchRoute(
          start: start,
          waypoints: stops.map((s) => s.location).toList(growable: false),
          stops: stops,
          avoidHazards: attempt.avoidHazards,
          avoidedHazardIds: attempt.avoidHazards.map((h) => h.id),
          riskLevel: attempt.riskLevel,
          allActiveHazards: allActiveHazards,
        );
        return route;
      } on SafeRoutingException catch (error) {
        if (_isRetryableRouteFailure(error)) {
          lastNoRouteException = error;
          continue;
        }
        rethrow;
      }
    }

    throw lastNoRouteException ??
        const SafeRoutingException(
          code: SafeRoutingFailureCode.noRoute,
          message: 'No road route is available for the requested points.',
        );
  }

  static List<({RouteRiskLevel riskLevel, List<HazardReport> avoidHazards})>
  _riskAttempts(List<HazardReport> allActiveHazards) {
    final highHazards = allActiveHazards
        .where((h) => h.severity.trim().toLowerCase() == 'high')
        .toList(growable: false);
    final mediumHazards = allActiveHazards
        .where((h) => h.severity.trim().toLowerCase() == 'medium')
        .toList(growable: false);
    final lowHazards = allActiveHazards
        .where(
          (h) =>
              h.severity.trim().toLowerCase() != 'high' &&
              h.severity.trim().toLowerCase() != 'medium',
        )
        .toList(growable: false);

    return [
      (
        riskLevel: RouteRiskLevel.hazardFree,
        avoidHazards: [...highHazards, ...mediumHazards, ...lowHazards],
      ),
      (
        riskLevel: RouteRiskLevel.lowRisk,
        avoidHazards: [...highHazards, ...mediumHazards],
      ),
      (riskLevel: RouteRiskLevel.moderateRisk, avoidHazards: [...highHazards]),
      (
        riskLevel: RouteRiskLevel.unavoidableExposure,
        avoidHazards: <HazardReport>[],
      ),
    ];
  }

  Future<SafeRoute> _calculateEscapeRoute({
    required LatLng start,
    required List<NavigationStop> stops,
    required List<HazardReport> containingHazards,
    required List<HazardReport> allActiveHazards,
  }) async {
    final containingIds = containingHazards.map((h) => h.id).toSet();
    final unrelatedHazards = allActiveHazards
        .where((h) => !containingIds.contains(h.id))
        .toList(growable: false);

    final firstDestination = stops.first.location;

    for (final offset in escapeBearingOffsets) {
      final escapePoint = findCandidateEscapePoint(
        start: start,
        destination: firstDestination,
        containingHazards: containingHazards,
        unrelatedHazards: unrelatedHazards,
        bearingOffset: offset,
      );
      if (escapePoint == null) continue;

      try {
        // Phase 1: start -> escapePoint (avoiding unrelated hazards only)
        final escapeRoute = await _fetchRoute(
          start: start,
          waypoints: [escapePoint],
          stops: [
            NavigationStop(
              id: 'escape_point',
              location: escapePoint,
              displayName: 'Safe Escape Point',
              isDestination: false,
            ),
          ],
          avoidHazards: unrelatedHazards,
          avoidedHazardIds: unrelatedHazards.map((h) => h.id),
          riskLevel: RouteRiskLevel.hazardFree,
          allActiveHazards: allActiveHazards,
        );

        // Verification 1: Phase 1 must exit containing hazards and NOT re-enter them
        if (!verifyEscapeRouteExitAndNoReentry(
          geometry: escapeRoute.geometry,
          containingHazards: containingHazards,
        )) {
          continue;
        }

        // Phase 2: escapePoint -> all stops (with progressive fallback!)
        final safeRoute = await _calculateWithFallback(
          start: escapePoint,
          stops: stops,
          allActiveHazards: allActiveHazards,
        );

        // Verification 2: Phase 2 road segments must NOT enter starting hazard(s)
        if (!verifyRouteSegmentsAvoidHazards(
          geometry: safeRoute.geometry,
          hazards: containingHazards,
        )) {
          continue;
        }

        return _combineRoutes(
          escapeRoute: escapeRoute,
          safeRoute: safeRoute,
          escapeHazardIds: containingHazards.map((h) => h.id),
          allActiveHazards: allActiveHazards,
        );
      } on SafeRoutingException catch (error) {
        if (error.code == SafeRoutingFailureCode.missingApiKey ||
            error.code == SafeRoutingFailureCode.unauthorized ||
            error.code == SafeRoutingFailureCode.rateLimited ||
            error.code == SafeRoutingFailureCode.requestTooLarge) {
          rethrow;
        }
        if (_isRetryableRouteFailure(error)) continue;
        rethrow;
      }
    }

    return _calculateRouteDerivedEscape(
      start: start,
      stops: stops,
      containingHazards: containingHazards,
      allActiveHazards: allActiveHazards,
    );
  }

  /// Falls back to escape points taken from real ORS road geometry when every
  /// radial point is off-road or otherwise unroutable.
  Future<SafeRoute> _calculateRouteDerivedEscape({
    required LatLng start,
    required List<NavigationStop> stops,
    required List<HazardReport> containingHazards,
    required List<HazardReport> allActiveHazards,
  }) async {
    final containingIds = containingHazards.map((hazard) => hazard.id).toSet();
    final attemptedAvoidSignatures = <String>{};
    SafeRoutingException? lastNoRouteException;

    for (final attempt in _riskAttempts(allActiveHazards)) {
      final avoidSig = _avoidSignature(attempt.avoidHazards);
      if (!attemptedAvoidSignatures.add(avoidSig)) continue;

      final probeAvoidHazards = attempt.avoidHazards
          .where((hazard) => !containingIds.contains(hazard.id))
          .toList(growable: false);
      try {
        // The start hazards alone are exempted while ORS finds a drivable way
        // out. Unrelated hazards remain active for this risk level.
        final probeRoute = await _fetchRoute(
          start: start,
          waypoints: [stops.first.location],
          stops: [stops.first],
          avoidHazards: probeAvoidHazards,
          avoidedHazardIds: probeAvoidHazards.map((hazard) => hazard.id),
          riskLevel: attempt.riskLevel,
          allActiveHazards: allActiveHazards,
        );

        final exitIndex = firstCompleteExitIndex(
          geometry: probeRoute.geometry,
          containingHazards: containingHazards,
        );
        if (exitIndex < 0) continue;

        final escapeRoute = _routePrefixThrough(
          route: probeRoute,
          endGeometryIndex: exitIndex,
          escapePoint: probeRoute.geometry[exitIndex],
          actualStart: start,
        );
        if (!verifyEscapeRouteExitAndNoReentry(
              geometry: escapeRoute.geometry,
              containingHazards: containingHazards,
            ) ||
            !verifyRouteSegmentsAvoidHazards(
              geometry: escapeRoute.geometry,
              hazards: probeAvoidHazards,
            )) {
          continue;
        }

        final safeRoute = await _fetchRoute(
          start: escapeRoute.geometry.last,
          waypoints: stops.map((stop) => stop.location).toList(growable: false),
          stops: stops,
          avoidHazards: attempt.avoidHazards,
          avoidedHazardIds: attempt.avoidHazards.map((hazard) => hazard.id),
          riskLevel: attempt.riskLevel,
          allActiveHazards: allActiveHazards,
        );

        // Once outside, start hazards that are prohibited at this risk level
        // are active again. Segment checks protect against provider snapping or
        // polygon approximation allowing an accidental re-entry.
        if (!verifyRouteSegmentsAvoidHazards(
          geometry: safeRoute.geometry,
          hazards: attempt.avoidHazards,
        )) {
          continue;
        }

        return _combineRoutes(
          escapeRoute: escapeRoute,
          safeRoute: safeRoute,
          escapeHazardIds: containingHazards.map((hazard) => hazard.id),
          allActiveHazards: allActiveHazards,
        );
      } on SafeRoutingException catch (error) {
        if (_isRetryableRouteFailure(error)) {
          lastNoRouteException = error;
          continue;
        }
        rethrow;
      }
    }

    throw lastNoRouteException ??
        const SafeRoutingException(
          code: SafeRoutingFailureCode.noRoute,
          message:
              'No hazard-avoiding route could be found from inside the hazard zone.',
        );
  }

  static String _avoidSignature(List<HazardReport> hazards) {
    final sortedIds = hazards.map((hazard) => hazard.id).toList()..sort();
    return sortedIds.join(',');
  }

  static bool _isRetryableRouteFailure(SafeRoutingException error) =>
      error.code == SafeRoutingFailureCode.noRoute ||
      error.code == SafeRoutingFailureCode.invalidRequest;

  static SafeRoute _routePrefixThrough({
    required SafeRoute route,
    required int endGeometryIndex,
    required LatLng escapePoint,
    required LatLng actualStart,
  }) {
    final providerPrefix = route.geometry.sublist(0, endGeometryIndex + 1);
    final prependActualStart =
        distanceMeters(actualStart, route.geometry.first) >= 1;
    final geometry = [if (prependActualStart) actualStart, ...providerPrefix];
    final fullGeometry = [
      if (prependActualStart) actualStart,
      ...route.geometry,
    ];
    final geometryIndexOffset = prependActualStart ? 1 : 0;
    final fullGeometryDistance = _polylineLength(fullGeometry);
    final prefixGeometryDistance = _polylineLength(geometry);
    final fraction = fullGeometryDistance <= 0
        ? 0.0
        : (prefixGeometryDistance / fullGeometryDistance).clamp(0.0, 1.0);
    final distance = route.distanceMeters * fraction;
    final duration = route.durationSeconds * fraction;
    final steps = <RouteStep>[];

    for (final step in route.steps) {
      if (step.startGeometryIndex > endGeometryIndex) break;
      final clippedEnd = math.min(step.endGeometryIndex, endGeometryIndex);
      final originalSpan = math.max(
        1,
        step.endGeometryIndex - step.startGeometryIndex,
      );
      final retainedSpan = math.max(0, clippedEnd - step.startGeometryIndex);
      final retainedFraction = step.endGeometryIndex <= endGeometryIndex
          ? 1.0
          : retainedSpan / originalSpan;
      steps.add(
        RouteStep(
          instruction: step.instruction,
          roadName: step.roadName,
          distanceMeters: step.distanceMeters * retainedFraction,
          durationSeconds: step.durationSeconds * retainedFraction,
          maneuverType: step.maneuverType,
          startGeometryIndex: step.startGeometryIndex + geometryIndexOffset,
          endGeometryIndex: clippedEnd + geometryIndexOffset,
        ),
      );
    }

    final escapeStop = NavigationStop(
      id: 'route_derived_escape_point',
      location: escapePoint,
      displayName: 'Safe Escape Point',
    );
    return SafeRoute(
      geometry: geometry,
      distanceMeters: distance,
      durationSeconds: duration,
      steps: steps,
      avoidedHazardIds: route.avoidedHazardIds,
      legs: [
        RouteLeg(
          startStopName: 'Current Location',
          endStopName: escapeStop.displayName,
          startLocation: geometry.first,
          endLocation: escapePoint,
          distanceMeters: distance,
          durationSeconds: duration,
          steps: steps,
        ),
      ],
      riskLevel: route.riskLevel,
      stops: [escapeStop],
    );
  }

  static double _polylineLength(List<LatLng> geometry) {
    var total = 0.0;
    for (var index = 1; index < geometry.length; index++) {
      total += distanceMeters(geometry[index - 1], geometry[index]);
    }
    return total;
  }

  static SafeRoute _combineRoutes({
    required SafeRoute escapeRoute,
    required SafeRoute safeRoute,
    required Iterable<String> escapeHazardIds,
    required List<HazardReport> allActiveHazards,
  }) {
    final escapeGeom = escapeRoute.geometry;
    final safeGeom = safeRoute.geometry;

    final bool isDuplicate;
    if (escapeGeom.isNotEmpty && safeGeom.isNotEmpty) {
      isDuplicate = distanceMeters(escapeGeom.last, safeGeom.first) < 1.0;
    } else {
      isDuplicate = false;
    }

    final combinedGeometry = <LatLng>[
      ...escapeGeom,
      if (isDuplicate) ...safeGeom.skip(1) else ...safeGeom,
    ];

    final geometryOffset = escapeGeom.length - (isDuplicate ? 1 : 0);

    final combinedSteps = <RouteStep>[
      ...escapeRoute.steps,
      for (final step in safeRoute.steps)
        RouteStep(
          instruction: step.instruction,
          roadName: step.roadName,
          distanceMeters: step.distanceMeters,
          durationSeconds: step.durationSeconds,
          maneuverType: step.maneuverType,
          startGeometryIndex: step.startGeometryIndex + geometryOffset,
          endGeometryIndex: step.endGeometryIndex + geometryOffset,
        ),
    ];

    final allAvoidedIds = {
      ...escapeRoute.avoidedHazardIds,
      ...safeRoute.avoidedHazardIds,
    }.toList();

    final combinedCrossedIds = <String>[];
    for (final hazard in allActiveHazards) {
      final radius = SafetyConfig.dangerRadiusForSeverity(hazard.severity);
      final center = LatLng(hazard.latitude, hazard.longitude);
      if (minimumPolylineDistanceMeters(combinedGeometry, center) <= radius) {
        combinedCrossedIds.add(hazard.id);
      }
    }

    final combinedLegs = <RouteLeg>[...escapeRoute.legs, ...safeRoute.legs];

    return SafeRoute(
      geometry: combinedGeometry,
      distanceMeters: escapeRoute.distanceMeters + safeRoute.distanceMeters,
      durationSeconds: escapeRoute.durationSeconds + safeRoute.durationSeconds,
      steps: combinedSteps,
      avoidedHazardIds: allAvoidedIds,
      startedInsideHazard: true,
      escapeHazardIds: escapeHazardIds,
      legs: combinedLegs,
      riskLevel: safeRoute.riskLevel,
      crossedHazardIds: combinedCrossedIds,
      stops: safeRoute.stops,
    );
  }

  Future<SafeRoute> _fetchRoute({
    required LatLng start,
    required List<LatLng> waypoints,
    required List<NavigationStop> stops,
    required List<HazardReport> avoidHazards,
    Iterable<String>? avoidedHazardIds,
    required RouteRiskLevel riskLevel,
    required List<HazardReport> allActiveHazards,
  }) async {
    final endpointStr = '${endpoint.host}${endpoint.path}';
    final keyConfigured = _apiKey.isNotEmpty;
    final keyLength = _apiKey.length;

    if (!keyConfigured) {
      debugPrint('[SafeRouting] keyConfigured=false');
      debugPrint('[SafeRouting] keyLength=0');
      debugPrint('[SafeRouting] endpoint=$endpointStr');
      debugPrint('[SafeRouting] failure=missingApiKey');
      throw const SafeRoutingException(
        code: SafeRoutingFailureCode.missingApiKey,
        message: 'ORS_API_KEY was not supplied.',
      );
    }

    final requestBody = <String, Object>{
      'coordinates': [
        toOrsCoordinate(start),
        for (final wp in waypoints) toOrsCoordinate(wp),
      ],
      'instructions': true,
    };

    if (avoidHazards.isNotEmpty) {
      requestBody['options'] = {
        'avoid_polygons': {
          'type': 'MultiPolygon',
          'coordinates': [
            for (final hazard in avoidHazards) [buildHazardPolygon(hazard)],
          ],
        },
      };
    }

    final encodedBody = jsonEncode(requestBody);
    if (utf8.encode(encodedBody).length > _maxRequestBytes) {
      debugPrint('[SafeRouting] keyConfigured=$keyConfigured');
      debugPrint('[SafeRouting] keyLength=$keyLength');
      debugPrint('[SafeRouting] endpoint=$endpointStr');
      debugPrint('[SafeRouting] failure=requestTooLarge');
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
      debugPrint('[SafeRouting] keyConfigured=$keyConfigured');
      debugPrint('[SafeRouting] keyLength=$keyLength');
      debugPrint('[SafeRouting] endpoint=$endpointStr');
      debugPrint('[SafeRouting] failure=timeout');
      throw const SafeRoutingException(
        code: SafeRoutingFailureCode.timeout,
        message: 'OpenRouteService did not respond before the timeout.',
      );
    } on http.ClientException {
      debugPrint('[SafeRouting] keyConfigured=$keyConfigured');
      debugPrint('[SafeRouting] keyLength=$keyLength');
      debugPrint('[SafeRouting] endpoint=$endpointStr');
      debugPrint('[SafeRouting] failure=networkFailure');
      throw const SafeRoutingException(
        code: SafeRoutingFailureCode.networkFailure,
        message: 'OpenRouteService could not be reached.',
      );
    }

    if (response.statusCode != 200) {
      final exception = _exceptionForHttpStatus(response.statusCode);
      debugPrint('[SafeRouting] keyConfigured=$keyConfigured');
      debugPrint('[SafeRouting] keyLength=$keyLength');
      debugPrint('[SafeRouting] endpoint=$endpointStr');
      debugPrint('[SafeRouting] HTTP=${response.statusCode}');
      debugPrint('[SafeRouting] failure=${exception.code.name}');
      throw exception;
    }

    try {
      return _parseRoute(
        response.body,
        start: start,
        stops: stops,
        avoidedHazardIds: avoidedHazardIds ?? avoidHazards.map((h) => h.id),
        riskLevel: riskLevel,
        allActiveHazards: allActiveHazards,
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

  /// Calculates the initial great-circle bearing from [from] to [to] in degrees [0, 360).
  static double initialBearingDegrees(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final radians = math.atan2(y, x);
    return (_toDegrees(radians) + 360) % 360;
  }

  /// Computes the spherical destination point from [start] along [bearingDegrees]
  /// for [distanceMeters].
  static LatLng computeDestinationPoint(
    LatLng start,
    double distanceMeters,
    double bearingDegrees,
  ) {
    final angularDistance = distanceMeters / _earthRadiusMeters;
    final bearing = _toRadians(bearingDegrees);
    final latitude1 = _toRadians(start.latitude);
    final longitude1 = _toRadians(start.longitude);

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
          math.cos(angularDistance) - math.sin(latitude1) * math.sin(latitude2),
        );

    return LatLng(
      _toDegrees(latitude2).clamp(-90.0, 90.0),
      _normalizeLongitude(_toDegrees(longitude2)),
    );
  }

  /// Generates a candidate escape point outside every hazard in [containingHazards]
  /// plus [safetyMargin], offset by [bearingOffset] from the base outward bearing.
  static LatLng? findCandidateEscapePoint({
    required LatLng start,
    required LatLng destination,
    required List<HazardReport> containingHazards,
    required List<HazardReport> unrelatedHazards,
    required double bearingOffset,
    double safetyMargin = escapeSafetyMarginMeters,
  }) {
    if (containingHazards.isEmpty) return null;

    final sorted = List<HazardReport>.from(containingHazards)
      ..sort((a, b) {
        final dA = distanceMeters(start, LatLng(a.latitude, a.longitude));
        final dB = distanceMeters(start, LatLng(b.latitude, b.longitude));
        return dA.compareTo(dB);
      });
    final primary = sorted.first;
    final primaryCenter = LatLng(primary.latitude, primary.longitude);
    final primaryRadius = SafetyConfig.dangerRadiusForSeverity(
      primary.severity,
    );
    final distToPrimaryCenter = distanceMeters(primaryCenter, start);

    final double baseBearing;
    if (distToPrimaryCenter < 5.0) {
      baseBearing = initialBearingDegrees(start, destination);
    } else {
      baseBearing = initialBearingDegrees(primaryCenter, start);
    }

    final candidateBearing = (baseBearing + bearingOffset + 360) % 360;

    var candidate = computeDestinationPoint(
      primaryCenter,
      primaryRadius + safetyMargin,
      candidateBearing,
    );

    for (var iter = 0; iter < containingHazards.length * 2; iter++) {
      HazardReport? insideHazard;
      for (final h in containingHazards) {
        final r = SafetyConfig.dangerRadiusForSeverity(h.severity);
        final c = LatLng(h.latitude, h.longitude);
        if (distanceMeters(candidate, c) <= r) {
          insideHazard = h;
          break;
        }
      }
      if (insideHazard == null) break;

      final r = SafetyConfig.dangerRadiusForSeverity(insideHazard.severity);
      final c = LatLng(insideHazard.latitude, insideHazard.longitude);
      final dist = distanceMeters(c, candidate);
      final b = dist < 1.0
          ? candidateBearing
          : initialBearingDegrees(c, candidate);
      candidate = computeDestinationPoint(c, r + safetyMargin, b);
    }

    if (!SafetyConfig.validCoordinates(
      candidate.latitude,
      candidate.longitude,
    )) {
      return null;
    }

    for (final h in containingHazards) {
      final r = SafetyConfig.dangerRadiusForSeverity(h.severity);
      final c = LatLng(h.latitude, h.longitude);
      if (distanceMeters(candidate, c) <= r) {
        return null;
      }
    }

    for (final h in unrelatedHazards) {
      final r = SafetyConfig.dangerRadiusForSeverity(h.severity);
      final c = LatLng(h.latitude, h.longitude);
      if (distanceMeters(candidate, c) <= r) {
        return null;
      }
    }

    return candidate;
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
    final hazardPoint = LatLng(hazard.latitude, hazard.longitude);
    final ring = <List<double>>[];

    for (var index = 0; index < segments; index++) {
      final bearing = 360.0 * index / segments;
      final point = computeDestinationPoint(hazardPoint, radius, bearing);
      ring.add(toOrsCoordinate(point));
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

  /// Computes the minimum distance in meters from the line segment [p1] -> [p2]
  /// to [point], using an equirectangular projection centered at [point].
  static double distanceSegmentToPointMeters(
    LatLng p1,
    LatLng p2,
    LatLng point,
  ) {
    final centerLatitudeRadians = _toRadians(point.latitude);
    ({double x, double y}) project(LatLng p) {
      final lonDelta = _toRadians(p.longitude - point.longitude);
      final latDelta = _toRadians(p.latitude - point.latitude);
      return (
        x: _earthRadiusMeters * lonDelta * math.cos(centerLatitudeRadians),
        y: _earthRadiusMeters * latDelta,
      );
    }

    final first = project(p1);
    final second = project(p2);
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
    return math.sqrt(closestX * closestX + closestY * closestY);
  }

  /// Computes the minimum distance in meters from any segment in [geometry]
  /// to [point].
  static double minimumPolylineDistanceMeters(
    List<LatLng> geometry,
    LatLng point,
  ) {
    if (geometry.isEmpty) return double.infinity;
    if (geometry.length == 1) return distanceMeters(geometry.first, point);

    var minimum = double.infinity;
    for (var index = 1; index < geometry.length; index++) {
      final dist = distanceSegmentToPointMeters(
        geometry[index - 1],
        geometry[index],
        point,
      );
      if (dist < minimum) minimum = dist;
    }
    return minimum;
  }

  /// Verifies that [geometry] exits all [containingHazards] and, after the first
  /// complete exit, never re-enters any of them.
  @visibleForTesting
  static int firstCompleteExitIndex({
    required List<LatLng> geometry,
    required List<HazardReport> containingHazards,
  }) {
    if (geometry.isEmpty || containingHazards.isEmpty) return -1;
    for (var index = 0; index < geometry.length; index++) {
      final point = geometry[index];
      final isOutsideAll = containingHazards.every((hazard) {
        final radius = SafetyConfig.dangerRadiusForSeverity(hazard.severity);
        final center = LatLng(hazard.latitude, hazard.longitude);
        return distanceMeters(point, center) > radius;
      });
      if (isOutsideAll) return index;
    }
    return -1;
  }

  static bool verifyEscapeRouteExitAndNoReentry({
    required List<LatLng> geometry,
    required List<HazardReport> containingHazards,
    double toleranceMeters = 2.0,
  }) {
    if (geometry.isEmpty || containingHazards.isEmpty) return true;

    final firstExitIndex = firstCompleteExitIndex(
      geometry: geometry,
      containingHazards: containingHazards,
    );

    // If the route never exited all containing hazards, escape is incomplete.
    if (firstExitIndex == -1) return false;

    // After first exit, no subsequent point or segment may re-enter any containing hazard.
    for (var index = firstExitIndex; index < geometry.length; index++) {
      final point = geometry[index];
      for (final h in containingHazards) {
        final r = SafetyConfig.dangerRadiusForSeverity(h.severity);
        final c = LatLng(h.latitude, h.longitude);
        if (distanceMeters(point, c) < r - toleranceMeters) {
          return false;
        }
      }
    }

    for (var index = firstExitIndex; index < geometry.length - 1; index++) {
      final p1 = geometry[index];
      final p2 = geometry[index + 1];
      for (final h in containingHazards) {
        final r = SafetyConfig.dangerRadiusForSeverity(h.severity);
        final c = LatLng(h.latitude, h.longitude);
        if (distanceSegmentToPointMeters(p1, p2, c) < r - toleranceMeters) {
          return false;
        }
      }
    }

    return true;
  }

  /// Verifies that all segments in [geometry] remain strictly outside the danger
  /// radius (minus [toleranceMeters]) of all [hazards].
  static bool verifyRouteSegmentsAvoidHazards({
    required List<LatLng> geometry,
    required List<HazardReport> hazards,
    double toleranceMeters = 2.0,
  }) {
    if (geometry.isEmpty || hazards.isEmpty) return true;

    for (final h in hazards) {
      final r = SafetyConfig.dangerRadiusForSeverity(h.severity);
      final c = LatLng(h.latitude, h.longitude);
      final minDistance = minimumPolylineDistanceMeters(geometry, c);
      if (minDistance < r - toleranceMeters) {
        return false;
      }
    }

    return true;
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
        message: statusCode == 401
            ? 'OpenRouteService authorization failed (401 Unauthorized).'
            : 'OpenRouteService access denied (403 Forbidden). Check key restrictions or quota.',
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
    required LatLng start,
    required List<NavigationStop> stops,
    required Iterable<String> avoidedHazardIds,
    required RouteRiskLevel riskLevel,
    required List<HazardReport> allActiveHazards,
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

    final allCoords = <LatLng>[start, ...stops.map((s) => s.location)];
    final allStopNames = <String>[
      'Current Location',
      ...stops.map((s) => s.displayName),
    ];

    final steps = <RouteStep>[];
    final legs = <RouteLeg>[];

    for (var segIdx = 0; segIdx < rawSegments.length; segIdx++) {
      final rawSegment = rawSegments[segIdx];
      final segment = _stringMap(rawSegment);
      final rawSteps = segment['steps'];
      if (rawSteps is! List) {
        throw const FormatException('Route steps are missing.');
      }
      final legSteps = <RouteStep>[];
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
        final routeStep = RouteStep(
          instruction: instruction,
          roadName: name,
          distanceMeters: _nonNegativeDouble(step['distance']),
          durationSeconds: _nonNegativeDouble(step['duration']),
          maneuverType: type.toInt(),
          startGeometryIndex: _nonNegativeInt(wayPoints[0]),
          endGeometryIndex: _nonNegativeInt(wayPoints[1]),
        );
        steps.add(routeStep);
        legSteps.add(routeStep);
      }

      final segDistance = segment['distance'] is num
          ? _nonNegativeDouble(segment['distance'])
          : legSteps.fold<double>(0.0, (sum, s) => sum + s.distanceMeters);
      final segDuration = segment['duration'] is num
          ? _nonNegativeDouble(segment['duration'])
          : legSteps.fold<double>(0.0, (sum, s) => sum + s.durationSeconds);

      final startName = segIdx < allStopNames.length
          ? allStopNames[segIdx]
          : 'Stop $segIdx';
      final endName = segIdx + 1 < allStopNames.length
          ? allStopNames[segIdx + 1]
          : (stops.isNotEmpty ? stops.last.displayName : 'Destination');
      final startLoc = segIdx < allCoords.length ? allCoords[segIdx] : start;
      final endLoc = segIdx + 1 < allCoords.length
          ? allCoords[segIdx + 1]
          : (stops.isNotEmpty ? stops.last.location : start);

      legs.add(
        RouteLeg(
          startStopName: startName,
          endStopName: endName,
          startLocation: startLoc,
          endLocation: endLoc,
          distanceMeters: segDistance,
          durationSeconds: segDuration,
          steps: legSteps,
        ),
      );
    }

    final crossedHazardIds = <String>[];
    for (final hazard in allActiveHazards) {
      final radius = SafetyConfig.dangerRadiusForSeverity(hazard.severity);
      final center = LatLng(hazard.latitude, hazard.longitude);
      if (minimumPolylineDistanceMeters(geometry, center) <= radius) {
        crossedHazardIds.add(hazard.id);
      }
    }

    return SafeRoute(
      geometry: geometry,
      distanceMeters: distance,
      durationSeconds: duration,
      steps: steps,
      avoidedHazardIds: avoidedHazardIds,
      legs: legs,
      riskLevel: riskLevel,
      crossedHazardIds: crossedHazardIds,
      stops: stops,
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
