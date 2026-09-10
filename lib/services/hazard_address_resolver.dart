import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/safety_config.dart';
import '../models/navigation_stop.dart';
import 'place_geocoding_service.dart';

/// Formatted hazard address containing resolved place names and coordinate fallbacks.
@immutable
class HazardAddressDetails {
  const HazardAddressDetails({
    required this.primaryName,
    required this.secondaryAddress,
    required this.coordinatesText,
    required this.isGeocoded,
  });

  /// Primary place / road / POI / area name (e.g. "Jalan Tanjung Tokong").
  final String primaryName;

  /// Secondary address line (e.g. "George Town, Penang") if distinct from [primaryName].
  final String? secondaryAddress;

  /// Exact coordinates formatted to 5 decimals (e.g. "5.44140, 100.30685").
  final String coordinatesText;

  /// Whether this address was successfully reverse-geocoded or fell back to coordinates.
  final bool isGeocoded;

  /// Combined one-line representation for compact displays.
  String get singleLine {
    if (!isGeocoded) return 'Location name unavailable';
    if (secondaryAddress == null || secondaryAddress!.isEmpty) {
      return primaryName;
    }
    return '$primaryName, $secondaryAddress';
  }

  /// Formats raw coordinates as a safe fallback.
  factory HazardAddressDetails.fromCoordinates(double lat, double lon) {
    final latStr = lat.toStringAsFixed(5);
    final lonStr = lon.toStringAsFixed(5);
    final coordText = '$latStr, $lonStr';
    return HazardAddressDetails(
      primaryName: 'Location name unavailable',
      secondaryAddress: null,
      coordinatesText: coordText,
      isGeocoded: false,
    );
  }
}

/// In-memory caching reverse-geocoder for hazard locations.
///
/// Prevents redundant Geoapify API network calls across widget rebuilds
/// and page navigations while the app is running.
class HazardAddressResolver {
  static final Map<String, HazardAddressDetails> _cache = {};
  static final Map<String, Future<HazardAddressDetails>> _inFlight = {};

  /// Key generator using 5 decimal places (~1.1 meter accuracy).
  static String coordinateKey(double lat, double lon) {
    return '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
  }

  /// Clears in-memory cache and in-flight requests (primarily for automated testing).
  static void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  /// Populates cache directly (useful for tests or prefetching).
  static void setCacheEntry(
    double lat,
    double lon,
    HazardAddressDetails details,
  ) {
    final key = coordinateKey(lat, lon);
    _cache[key] = details;
    _inFlight.remove(key);
  }

  /// Returns cached details if available for [latitude] and [longitude].
  static HazardAddressDetails? getCached(double latitude, double longitude) {
    return _cache[coordinateKey(latitude, longitude)];
  }

  /// Resolves the human-readable address for [latitude] and [longitude].
  ///
  /// Returns cached details if available. If an identical coordinate request
  /// is already in progress, deduplicates by reusing the active in-flight Future.
  /// Otherwise invokes [geocodingService], caches the result, and gracefully
  /// falls back to coordinates if geocoding fails.
  static Future<HazardAddressDetails> resolve({
    required double latitude,
    required double longitude,
    PlaceGeocodingService? geocodingService,
  }) async {
    if (!SafetyConfig.validCoordinates(latitude, longitude)) {
      return const HazardAddressDetails(
        primaryName: 'Location name unavailable',
        secondaryAddress: null,
        coordinatesText: 'Invalid coordinates',
        isGeocoded: false,
      );
    }

    final key = coordinateKey(latitude, longitude);
    final cached = _cache[key];
    if (cached != null) {
      return cached;
    }

    final inProgress = _inFlight[key];
    if (inProgress != null) {
      return inProgress;
    }

    final future = _doResolve(
      key: key,
      latitude: latitude,
      longitude: longitude,
      geocodingService: geocodingService,
    );
    _inFlight[key] = future;
    return future;
  }

  static Future<HazardAddressDetails> _doResolve({
    required String key,
    required double latitude,
    required double longitude,
    PlaceGeocodingService? geocodingService,
  }) async {
    final service = geocodingService ?? PlaceGeocodingService();
    try {
      final stop = await service.reverseGeocode(LatLng(latitude, longitude));
      final details = _extractDetails(stop, latitude, longitude);
      _cache[key] = details;
      return details;
    } catch (e) {
      debugPrint('[HazardAddressResolver] Reverse geocode failed: $e');
      final fallback = HazardAddressDetails.fromCoordinates(
        latitude,
        longitude,
      );
      _cache[key] = fallback;
      return fallback;
    } finally {
      _inFlight.remove(key);
    }
  }

  static HazardAddressDetails _extractDetails(
    NavigationStop stop,
    double lat,
    double lon,
  ) {
    final coordText = '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';

    // Check if the stop is a coordinate fallback generated by PlaceGeocodingService
    final isFallback =
        stop.id.startsWith('coord_') ||
        stop.displayName.startsWith('Location (') ||
        stop.displayName.contains(lat.toStringAsFixed(4));

    if (isFallback) {
      return HazardAddressDetails(
        primaryName: 'Location name unavailable',
        secondaryAddress: null,
        coordinatesText: coordText,
        isGeocoded: false,
      );
    }

    final primary = stop.displayName.trim();
    String? secondary = stop.address?.trim();

    // Clean up secondary if it's identical or redundant with primary
    if (secondary != null && secondary.isNotEmpty) {
      if (secondary.toLowerCase() == primary.toLowerCase()) {
        secondary = null;
      } else if (secondary.toLowerCase().startsWith(primary.toLowerCase())) {
        // e.g. primary = "Jalan Tanjung Tokong", secondary = "Jalan Tanjung Tokong, 10470 George Town, Penang"
        final remainder = secondary.substring(primary.length).trim();
        final cleaned = remainder.replaceFirst(RegExp(r'^,\s*'), '').trim();
        secondary = cleaned.isNotEmpty ? cleaned : null;
      }
    }

    return HazardAddressDetails(
      primaryName: primary.isNotEmpty ? primary : 'Location name unavailable',
      secondaryAddress: secondary,
      coordinatesText: coordText,
      isGeocoded: primary.isNotEmpty,
    );
  }
}
