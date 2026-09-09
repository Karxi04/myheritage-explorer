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
    this.orsErrorCode,
    this.retryAfter,
  });

  final SafeRoutingFailureCode code;
  final String message;
  final String? hazardId;
  final int? statusCode;
  final int? orsErrorCode;
  final Duration? retryAfter;

  @override
  String toString() =>
      'SafeRoutingException(${code.code}): $message'
      '${hazardId == null ? '' : ' (hazard: $hazardId)'}'
      '${retryAfter == null ? '' : ' (retryAfter: ${retryAfter!.inSeconds}s)'}';
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

  static const String endpointUrl =
      'https://api.heigit.org/openrouteservice/v2/directions/driving-car/geojson';
  static final Uri endpoint = Uri.parse(endpointUrl);

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

  static const Duration defaultRateLimitCooldown = Duration(seconds: 20);
  static DateTime? rateLimitedUntil;

  static bool get isRateLimited {
    final until = rateLimitedUntil;
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    rateLimitedUntil = null;
    return false;
  }

  static int get rateLimitRemainingSeconds {
    final until = rateLimitedUntil;
    if (until == null) return 0;
    final remaining = until.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  static void clearRateLimitCooldown() {
    rateLimitedUntil = null;
  }

  static Duration? parseRetryAfter(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final seconds = int.tryParse(trimmed);
    if (seconds != null && seconds >= 0) {
      return Duration(seconds: seconds);
    }
    return null;
  }

  static _SafeRouteCacheEntry? _cache;

  static void clearCache() {
    _cache = null;
  }

  final http.Client _client;
  final bool _ownsClient;
  final String _apiKey;
  final Duration _timeout;
  final int _maxRequestBytes;
  int _requestSequence = 0;

  Future<SafeRoute> calculateSafeRoute({
    required LatLng start,
    List<NavigationStop>? stops,
    LatLng? destination,
    required List<HazardReport> hazards,
    bool allowCache = true,
  }) async {
    _requestSequence = 0;
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

    final cacheKey = _computeCacheKey(
      start: start,
      stops: effectiveStops,
      activeHazards: activeHazards,
    );

    if (allowCache && _cache != null) {
      final now = DateTime.now();
      if (_cache!.isValid(now) && _cache!.cacheKey == cacheKey) {
        final cachedRoute = _cache!.route;
        final isSafe = _verifyCachedRouteSafety(
          cachedRoute: cachedRoute,
          start: start,
          activeHazards: activeHazards,
        );
        if (isSafe) {
          debugPrint('[SafeRouting] cache hit for key=$cacheKey');
          debugPrint('[SafeRouting] operation completed with 0 ORS requests');
          return cachedRoute;
        } else {
          _debugLog(
            '[SafeRouting] cached route failed safety verification; discarding cache',
          );
          _cache = null;
        }
      } else {
        _cache = null;
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

    final SafeRoute route;
    // Case A: Start is outside all verified hazards -> progressive fallback routing.
    if (containingHazards.isEmpty) {
      route = await _calculateWithFallback(
        start: start,
        stops: effectiveStops,
        allActiveHazards: activeHazards,
      );
      _debugLog('[SafeRouting] normal safe route success');
    } else {
      // Case B: Start is inside one or more verified hazards -> ESCAPE MODE.
      _debugLog(
        '[EscapeMode] start inside hazards=${containingHazards.length} '
        'ids=[${containingHazards.map((hazard) => hazard.id).join(',')}]',
      );
      route = await _calculateEscapeRoute(
        start: start,
        stops: effectiveStops,
        containingHazards: containingHazards,
        allActiveHazards: activeHazards,
      );
    }

    if (allowCache) {
      _cache = _SafeRouteCacheEntry(
        cacheKey: cacheKey,
        route: route,
        timestamp: DateTime.now(),
      );
    }

    debugPrint(
      '[SafeRouting] operation completed with $_requestSequence ORS requests',
    );
    return route;
  }

  static String _computeCacheKey({
    required LatLng start,
    required List<NavigationStop> stops,
    required List<HazardReport> activeHazards,
  }) {
    final startStr =
        '${start.latitude.toStringAsFixed(5)},${start.longitude.toStringAsFixed(5)}';
    final stopsStr = stops
        .map(
          (s) =>
              '${s.location.latitude.toStringAsFixed(5)},${s.location.longitude.toStringAsFixed(5)}',
        )
        .join(';');
    final fingerprints = activeHazards.map(_hazardFingerprint).toList()..sort();
    return '$startStr|$stopsStr|${fingerprints.join(';')}';
  }

  static String _hazardFingerprint(HazardReport hazard) {
    final lat = hazard.latitude.toStringAsFixed(5);
    final lon = hazard.longitude.toStringAsFixed(5);
    final sev = hazard.severity.trim().toLowerCase();
    final radius =
        SafetyConfig.dangerRadiusForSeverity(hazard.severity).toStringAsFixed(1);
    return '${hazard.id}:$lat,$lon:$sev:$radius';
  }

  static bool _verifyCachedRouteSafety({
    required SafeRoute cachedRoute,
    required LatLng start,
    required List<HazardReport> activeHazards,
  }) {
    if (cachedRoute.geometry.isEmpty) return false;

    final containingHazards = <HazardReport>[];
    for (final hazard in activeHazards) {
      final radius = SafetyConfig.dangerRadiusForSeverity(hazard.severity);
      final hazardPoint = LatLng(hazard.latitude, hazard.longitude);
      if (distanceMeters(start, hazardPoint) <= radius) {
        containingHazards.add(hazard);
      }
    }

    if (containingHazards.isNotEmpty) {
      if (!cachedRoute.startedInsideHazard) return false;
      if (!verifyEscapeRouteExitAndNoReentry(
        geometry: cachedRoute.geometry,
        containingHazards: containingHazards,
      )) {
        return false;
      }
    } else {
      if (cachedRoute.startedInsideHazard) return false;
    }

    final highHazards = activeHazards
        .where((h) => h.severity.trim().toLowerCase() == 'high')
        .toList(growable: false);
    final mediumHazards = activeHazards
        .where((h) => h.severity.trim().toLowerCase() == 'medium')
        .toList(growable: false);

    final containingIds = containingHazards.map((h) => h.id).toSet();
    final List<HazardReport> requiredAvoidHazards;

    switch (cachedRoute.riskLevel) {
      case RouteRiskLevel.hazardFree:
        requiredAvoidHazards = activeHazards
            .where((h) => !containingIds.contains(h.id))
            .toList(growable: false);
      case RouteRiskLevel.lowRisk:
        requiredAvoidHazards = [...highHazards, ...mediumHazards]
            .where((h) => !containingIds.contains(h.id))
            .toList(growable: false);
      case RouteRiskLevel.moderateRisk:
        requiredAvoidHazards = highHazards
            .where((h) => !containingIds.contains(h.id))
            .toList(growable: false);
      case RouteRiskLevel.unavoidableExposure:
        requiredAvoidHazards = const [];
    }

    if (requiredAvoidHazards.isNotEmpty) {
      if (!verifyRouteSegmentsAvoidHazards(
        geometry: cachedRoute.geometry,
        hazards: requiredAvoidHazards,
      )) {
        return false;
      }
    }

    return true;
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
      if (escapePoint == null) {
        _debugLog(
          '[EscapeMode] candidate bearingOffset=$offset '
          'rejected=insideAnotherHazard',
        );
        continue;
      }

      _debugLog(
        '[EscapeMode] candidate bearingOffset=$offset '
        'point=(${escapePoint.latitude.toStringAsFixed(6)},'
        '${escapePoint.longitude.toStringAsFixed(6)})',
      );
      _debugLog(
        '[EscapeMode] escape avoidPolygons=${unrelatedHazards.length} '
        'temporarilyExcludedContaining=${containingHazards.length}',
      );

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
            ) ||
            !verifyRouteSegmentsAvoidHazards(
              geometry: escapeRoute.geometry,
              hazards: unrelatedHazards,
            )) {
          _debugLog(
            '[EscapeMode] candidate bearingOffset=$offset '
            'rejected=unsafeEscapeGeometry',
          );
          continue;
        }

        // Phase 2: escapePoint -> all stops (with progressive fallback!)
        final safeRoute = await _calculateWithFallback(
          start: escapePoint,
          stops: stops,
          allActiveHazards: allActiveHazards,
        );

        // A geometrically unsafe response is a rejected candidate, not a
        // provider no-route result, so it must not weaken hazard avoidance.
        if (!verifyRouteSegmentsAvoidHazards(
          geometry: safeRoute.geometry,
          hazards: containingHazards,
        )) {
          _debugLog(
            '[EscapeMode] candidate bearingOffset=$offset '
            'rejected=normalRouteReentry',
          );
          continue;
        }

        _debugLog('[EscapeMode] full avoidance restored');
        _debugLog('[EscapeMode] valid escape route found');
        _debugLog('[SafeRouting] normal safe route success');

        return _combineRoutes(
          escapeRoute: escapeRoute,
          safeRoute: safeRoute,
          escapeHazardIds: containingHazards.map((h) => h.id),
          allActiveHazards: allActiveHazards,
        );
      } on SafeRoutingException catch (error) {
        if (error.code == SafeRoutingFailureCode.rateLimited) {
          _debugLog('[EscapeMode] rateLimited aborting remaining candidates');
          rethrow;
        }
        if (error.code == SafeRoutingFailureCode.missingApiKey ||
            error.code == SafeRoutingFailureCode.unauthorized ||
            error.code == SafeRoutingFailureCode.requestTooLarge ||
            error.code == SafeRoutingFailureCode.timeout ||
            error.code == SafeRoutingFailureCode.networkFailure ||
            error.code == SafeRoutingFailureCode.providerUnavailable ||
            error.code == SafeRoutingFailureCode.destinationInsideHazard) {
          rethrow;
        }
        if (_isUnroutableEscapeCandidate(error)) {
          _debugLog(
            '[EscapeMode] candidate bearingOffset=$offset '
            'rejected=unroutable ORS=2010',
          );
          _debugLog('[EscapeMode] trying next candidate');
          continue;
        }
        if (_isRetryableRouteFailure(error)) {
          final orsCode = error.orsErrorCode == null
              ? ''
              : ' ORS=${error.orsErrorCode}';
          _debugLog(
            '[EscapeMode] candidate bearingOffset=$offset '
            'failure=noRoute$orsCode tryingNextCandidate',
          );
          continue;
        }
        rethrow;
      }
    }

    _debugLog('[EscapeMode] radial candidates exhausted');
    _debugLog('[EscapeMode] trying route-derived fallback');
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
    final probeAvoidHazards = allActiveHazards
        .where((hazard) => !containingIds.contains(hazard.id))
        .toList(growable: false);

    _debugLog(
      '[EscapeMode] routeDerived avoidPolygons=${probeAvoidHazards.length} '
      'temporarilyExcludedContaining=${containingHazards.length}',
    );

    try {
      // Escape discovery always excludes only the polygons containing the start.
      // Progressive relaxation is deliberately deferred until a safe exit exists.
      final probeRoute = await _fetchRoute(
        start: start,
        waypoints: [stops.first.location],
        stops: [stops.first],
        avoidHazards: probeAvoidHazards,
        avoidedHazardIds: probeAvoidHazards.map((hazard) => hazard.id),
        riskLevel: RouteRiskLevel.hazardFree,
        allActiveHazards: allActiveHazards,
      );

      final exitIndex = firstCompleteExitIndex(
        geometry: probeRoute.geometry,
        containingHazards: containingHazards,
        clearanceMeters: escapeSafetyMarginMeters,
      );
      if (exitIndex < 0) {
        throw const SafeRoutingException(
          code: SafeRoutingFailureCode.noRoute,
          message: 'The road route did not reach a safe hazard exit point.',
        );
      }

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
        throw const SafeRoutingException(
          code: SafeRoutingFailureCode.noRoute,
          message: 'The road-derived escape route failed safety validation.',
        );
      }

      final safeRoute = await _calculateWithFallback(
        start: escapeRoute.geometry.last,
        stops: stops,
        allActiveHazards: allActiveHazards,
      );

      if (!verifyRouteSegmentsAvoidHazards(
        geometry: safeRoute.geometry,
        hazards: containingHazards,
      )) {
        throw const SafeRoutingException(
          code: SafeRoutingFailureCode.noRoute,
          message: 'The normal route would re-enter the escaped hazard region.',
        );
      }

      _debugLog('[EscapeMode] full avoidance restored');
      _debugLog('[EscapeMode] valid route-derived escape found');
      _debugLog('[SafeRouting] normal safe route success');
      return _combineRoutes(
        escapeRoute: escapeRoute,
        safeRoute: safeRoute,
        escapeHazardIds: containingHazards.map((hazard) => hazard.id),
        allActiveHazards: allActiveHazards,
      );
    } on SafeRoutingException catch (error) {
      if (error.code == SafeRoutingFailureCode.rateLimited) {
        _debugLog('[EscapeMode] rateLimited aborting remaining candidates');
        rethrow;
      }
      if (error.code == SafeRoutingFailureCode.missingApiKey ||
          error.code == SafeRoutingFailureCode.unauthorized ||
          error.code == SafeRoutingFailureCode.requestTooLarge ||
          error.code == SafeRoutingFailureCode.timeout ||
          error.code == SafeRoutingFailureCode.networkFailure ||
          error.code == SafeRoutingFailureCode.providerUnavailable ||
          error.code == SafeRoutingFailureCode.destinationInsideHazard) {
        rethrow;
      }
      if (_isRetryableRouteFailure(error)) {
        throw const SafeRoutingException(
          code: SafeRoutingFailureCode.noRoute,
          message: 'Could not find a safe escape route from the hazard area.',
        );
      }
      rethrow;
    }
  }

  static String _avoidSignature(List<HazardReport> hazards) {
    final sortedIds = hazards.map((hazard) => hazard.id).toList()..sort();
    return sortedIds.join(',');
  }

  static bool _isRetryableRouteFailure(SafeRoutingException error) =>
      error.code == SafeRoutingFailureCode.noRoute;

  /// ORS 2010 means the requested coordinate could not be snapped to the
  /// driving graph. It is retryable only while evaluating a generated escape
  /// candidate; it remains a provider failure everywhere else.
  static bool _isUnroutableEscapeCandidate(SafeRoutingException error) =>
      error.orsErrorCode == 2010 &&
      (error.code == SafeRoutingFailureCode.invalidRequest ||
          error.code == SafeRoutingFailureCode.providerFailure);

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
    if (isRateLimited) {
      final remaining = Duration(seconds: rateLimitRemainingSeconds);
      debugPrint(
        '[SafeRouting] rate limited locally (remaining=${remaining.inSeconds}s)',
      );
      throw SafeRoutingException(
        code: SafeRoutingFailureCode.rateLimited,
        message: 'OpenRouteService rate limit cooldown in effect.',
        retryAfter: remaining,
      );
    }

    _requestSequence++;
    final endpointStr = endpoint.toString();
    final keyConfigured = _apiKey.isNotEmpty;
    final destPoint = waypoints.isNotEmpty
        ? waypoints.last
        : (stops.isNotEmpty ? stops.last.location : null);
    final startStr =
        '${start.latitude.toStringAsFixed(6)},${start.longitude.toStringAsFixed(6)}';
    final destStr = destPoint != null
        ? '${destPoint.latitude.toStringAsFixed(6)},${destPoint.longitude.toStringAsFixed(6)}'
        : 'none';

    debugPrint(
      '[SafeRouting] request sequence=$_requestSequence endpoint=$endpointStr '
      'start=($startStr) dest=($destStr) hazards=${allActiveHazards.length} '
      'avoid_polygons=${avoidHazards.length}',
    );

    if (!keyConfigured) {
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
      debugPrint('[SafeRouting] failure=timeout');
      throw const SafeRoutingException(
        code: SafeRoutingFailureCode.timeout,
        message: 'OpenRouteService did not respond before the timeout.',
      );
    } on http.ClientException {
      debugPrint('[SafeRouting] failure=networkFailure');
      throw const SafeRoutingException(
        code: SafeRoutingFailureCode.networkFailure,
        message: 'OpenRouteService could not be reached.',
      );
    }

    debugPrint('[SafeRouting] HTTP=${response.statusCode}');
    if (response.statusCode != 200) {
      if (response.statusCode == 429) {
        final retryAfterHeader =
            response.headers['retry-after'] ?? response.headers['Retry-After'];
        final cooldown =
            parseRetryAfter(retryAfterHeader) ?? defaultRateLimitCooldown;
        rateLimitedUntil = DateTime.now().add(cooldown);
        debugPrint(
          '[SafeRouting] rateLimited retryAfter=${cooldown.inSeconds}s',
        );
        final orsError = _parseOrsError(response.body);
        if (orsError != null) {
          final code = orsError.code == null ? 'unknown' : '${orsError.code}';
          final message = orsError.message == null
              ? 'unavailable'
              : _safeLogText(orsError.message!);
          debugPrint('[SafeRouting] ORS error code=$code message=$message');
        }
        debugPrint('[SafeRouting] failure=rateLimited');
        throw SafeRoutingException(
          code: SafeRoutingFailureCode.rateLimited,
          message: 'OpenRouteService rate limit was reached.',
          statusCode: 429,
          orsErrorCode: orsError?.code,
          retryAfter: cooldown,
        );
      }

      final orsError = _parseOrsError(response.body);
      if (orsError != null) {
        final code = orsError.code == null ? 'unknown' : '${orsError.code}';
        final message = orsError.message == null
            ? 'unavailable'
            : _safeLogText(orsError.message!);
        debugPrint('[SafeRouting] ORS error code=$code message=$message');
      }
      final exception = _exceptionForHttpStatus(
        response.statusCode,
        orsErrorCode: orsError?.code,
      );
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
    } on SafeRoutingException catch (error) {
      debugPrint('[SafeRouting] failure=${error.code.name}');
      rethrow;
    } on Object {
      debugPrint('[SafeRouting] failure=malformedResponse');
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
    double clearanceMeters = 0,
  }) {
    if (geometry.isEmpty || containingHazards.isEmpty) return -1;
    for (var index = 0; index < geometry.length; index++) {
      final point = geometry[index];
      final isOutsideAll = containingHazards.every((hazard) {
        final radius = SafetyConfig.dangerRadiusForSeverity(hazard.severity);
        final center = LatLng(hazard.latitude, hazard.longitude);
        return distanceMeters(point, center) > radius + clearanceMeters;
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

  static void _debugLog(String message) {
    if (kDebugMode) debugPrint(message);
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

  static SafeRoutingException _exceptionForHttpStatus(
    int statusCode, {
    int? orsErrorCode,
    Duration? retryAfter,
  }) {
    if (statusCode == 400) {
      if (_isOrsNoRouteErrorCode(orsErrorCode)) {
        return SafeRoutingException(
          code: SafeRoutingFailureCode.noRoute,
          message:
              'OpenRouteService could not find a route between the points.',
          statusCode: statusCode,
          orsErrorCode: orsErrorCode,
        );
      }
      return SafeRoutingException(
        code: SafeRoutingFailureCode.invalidRequest,
        message: 'OpenRouteService rejected the routing request.',
        statusCode: statusCode,
        orsErrorCode: orsErrorCode,
      );
    }
    if (statusCode == 401 || statusCode == 403) {
      return SafeRoutingException(
        code: SafeRoutingFailureCode.unauthorized,
        message: statusCode == 401
            ? 'OpenRouteService authorization failed (401 Unauthorized).'
            : 'OpenRouteService access denied (403 Forbidden). Check key restrictions or quota.',
        statusCode: statusCode,
        orsErrorCode: orsErrorCode,
      );
    }
    if (statusCode == 429) {
      return SafeRoutingException(
        code: SafeRoutingFailureCode.rateLimited,
        message: 'OpenRouteService rate limit was reached.',
        statusCode: statusCode,
        orsErrorCode: orsErrorCode,
        retryAfter: retryAfter,
      );
    }
    if (statusCode == 404) {
      if (_isOrsNoRouteErrorCode(orsErrorCode)) {
        return SafeRoutingException(
          code: SafeRoutingFailureCode.noRoute,
          message:
              'OpenRouteService could not find a route between the points.',
          statusCode: statusCode,
          orsErrorCode: orsErrorCode,
        );
      }
      return SafeRoutingException(
        code: SafeRoutingFailureCode.providerFailure,
        message:
            'OpenRouteService returned 404 for the configured Directions endpoint.',
        statusCode: statusCode,
        orsErrorCode: orsErrorCode,
      );
    }
    if (statusCode == 413) {
      return SafeRoutingException(
        code: SafeRoutingFailureCode.requestTooLarge,
        message: 'OpenRouteService rejected the request as too large.',
        statusCode: statusCode,
        orsErrorCode: orsErrorCode,
      );
    }
    if (statusCode >= 500) {
      return SafeRoutingException(
        code: SafeRoutingFailureCode.providerUnavailable,
        message: 'OpenRouteService is temporarily unavailable.',
        statusCode: statusCode,
        orsErrorCode: orsErrorCode,
      );
    }
    return SafeRoutingException(
      code: SafeRoutingFailureCode.providerFailure,
      message: 'OpenRouteService returned HTTP $statusCode.',
      statusCode: statusCode,
      orsErrorCode: orsErrorCode,
    );
  }

  static bool _isOrsNoRouteErrorCode(int? code) => code == 2009 || code == 2016;

  static _OrsErrorDetails? _parseOrsError(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map) return null;
      final root = Map<String, dynamic>.from(decoded);
      final rawError = root['error'];
      if (rawError is String) {
        return _OrsErrorDetails(message: rawError);
      }
      if (rawError is! Map) return null;
      final error = Map<String, dynamic>.from(rawError);
      final rawCode = error['code'];
      final code = rawCode is int
          ? rawCode
          : rawCode is num
          ? rawCode.toInt()
          : int.tryParse('$rawCode');
      final rawMessage = error['message'];
      final message = rawMessage is String && rawMessage.trim().isNotEmpty
          ? rawMessage.trim()
          : null;
      if (code == null && message == null) return null;
      return _OrsErrorDetails(code: code, message: message);
    } on Object {
      return null;
    }
  }

  String _safeLogText(String value) {
    var sanitized = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
    if (_apiKey.isNotEmpty) {
      sanitized = sanitized.replaceAll(_apiKey, '[redacted]');
    }
    const maxLength = 240;
    if (sanitized.length > maxLength) {
      return '${sanitized.substring(0, maxLength)}...';
    }
    return sanitized;
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

class _OrsErrorDetails {
  const _OrsErrorDetails({this.code, this.message});

  final int? code;
  final String? message;
}

class _SafeRouteCacheEntry {
  _SafeRouteCacheEntry({
    required this.cacheKey,
    required this.route,
    required this.timestamp,
  });

  static const Duration defaultTtl = Duration(seconds: 45);

  final String cacheKey;
  final SafeRoute route;
  final DateTime timestamp;

  bool get isExpired => DateTime.now().difference(timestamp) > defaultTtl;
  bool isValid(DateTime now) => now.difference(timestamp) <= defaultTtl;
}
