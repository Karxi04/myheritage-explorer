import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/geoapify_config.dart';
import '../core/safety_config.dart';
import '../models/navigation_stop.dart';

/// Place search and reverse geocoding service backed by the Geoapify API.
class PlaceGeocodingService {
  PlaceGeocodingService({
    http.Client? client,
    String? apiKey,
    Duration timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _apiKey = (apiKey ?? GeoapifyConfig.apiKey).trim(),
       _timeout = timeout;

  final http.Client _client;
  final bool _ownsClient;
  final String _apiKey;
  final Duration _timeout;

  static const String _searchBaseUrl =
      'https://api.geoapify.com/v1/geocode/search';
  static const String _reverseBaseUrl =
      'https://api.geoapify.com/v1/geocode/reverse';
  static const String _placesBaseUrl = 'https://api.geoapify.com/v2/places';

  bool _lastSearchFailed = false;

  /// Whether the most recent [searchPlaces] call failed due to network or API error.
  bool get lastSearchFailed => _lastSearchFailed;

  /// Searches for places or addresses matching [query].
  ///
  /// Restricts search to Malaysia (`countrycode:my`) and biases towards [proximity]
  /// if provided. Returns empty list if query is blank, API key is missing, or
  /// network request fails.
  Future<List<NavigationStop>> searchPlaces(
    String query, {
    LatLng? proximity,
    int limit = 5,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || _apiKey.isEmpty) {
      _lastSearchFailed = false;
      return const [];
    }

    final queryParams = <String, String>{
      'text': trimmedQuery,
      'filter': 'countrycode:my',
      'limit': limit.clamp(1, 20).toString(),
      'apiKey': _apiKey,
    };

    if (proximity != null &&
        SafetyConfig.validCoordinates(
          proximity.latitude,
          proximity.longitude,
        )) {
      queryParams['bias'] =
          'proximity:${proximity.longitude},${proximity.latitude}';
    }

    final uri = Uri.parse(_searchBaseUrl).replace(queryParameters: queryParams);

    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint(
          '[PlaceGeocodingService] search returned HTTP ${response.statusCode}',
        );
        _lastSearchFailed = true;
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        _lastSearchFailed = true;
        return const [];
      }
      final features = decoded['features'];
      if (features is! List) {
        _lastSearchFailed = true;
        return const [];
      }

      final results = <NavigationStop>[];
      for (var index = 0; index < features.length; index++) {
        final feature = features[index];
        if (feature is! Map<String, dynamic>) continue;
        final stop = _stopFromFeature(feature, fallbackIndex: index);
        if (stop != null) {
          results.add(stop);
        }
      }
      _lastSearchFailed = false;
      return results;
    } catch (e) {
      debugPrint('[PlaceGeocodingService] searchPlaces failed: $e');
      _lastSearchFailed = true;
      return const [];
    }
  }

  /// Searches for nearby points of interest (POIs) around [proximity].
  ///
  /// Restricts search to tourism, heritage, commercial, catering, and leisure
  /// places within [radiusMeters] (default 5,000 m). Returns up to [limit] places.
  Future<List<NavigationStop>> searchNearbyPlaces(
    LatLng proximity, {
    int radiusMeters = 5000,
    int limit = 30,
  }) async {
    if (_apiKey.isEmpty ||
        !SafetyConfig.validCoordinates(
          proximity.latitude,
          proximity.longitude,
        )) {
      return const [];
    }

    final queryParams = <String, String>{
      'categories':
          'tourism,heritage,commercial,catering,leisure,entertainment,healthcare',
      'filter':
          'circle:${proximity.longitude},${proximity.latitude},$radiusMeters',
      'bias': 'proximity:${proximity.longitude},${proximity.latitude}',
      'limit': limit.clamp(1, 50).toString(),
      'apiKey': _apiKey,
    };

    final uri = Uri.parse(_placesBaseUrl).replace(queryParameters: queryParams);

    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint(
          '[PlaceGeocodingService] searchNearbyPlaces returned HTTP ${response.statusCode}',
        );
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final features = decoded['features'];
      if (features is! List) return const [];

      final results = <NavigationStop>[];
      for (var index = 0; index < features.length; index++) {
        final feature = features[index];
        if (feature is! Map<String, dynamic>) continue;
        final stop = _stopFromFeature(feature, fallbackIndex: index);
        if (stop != null) {
          results.add(stop);
        }
      }
      return results;
    } catch (e) {
      debugPrint('[PlaceGeocodingService] searchNearbyPlaces failed: $e');
      return const [];
    }
  }

  /// Reverse geocodes [location] to find a human-readable place name and address.
  ///
  /// If the request fails or key is missing, gracefully falls back to formatted
  /// coordinates so navigation can proceed uninterrupted.
  Future<NavigationStop> reverseGeocode(LatLng location) async {
    final fallbackStop = _formatCoordinatesFallback(location);
    if (_apiKey.isEmpty) {
      return fallbackStop;
    }

    final queryParams = <String, String>{
      'lat': location.latitude.toString(),
      'lon': location.longitude.toString(),
      'apiKey': _apiKey,
    };

    final uri = Uri.parse(
      _reverseBaseUrl,
    ).replace(queryParameters: queryParams);

    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint(
          '[PlaceGeocodingService] reverseGeocode returned HTTP ${response.statusCode}',
        );
        return fallbackStop;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return fallbackStop;
      final features = decoded['features'];
      if (features is! List || features.isEmpty) return fallbackStop;

      final firstFeature = features.first;
      if (firstFeature is! Map<String, dynamic>) return fallbackStop;

      final stop = _stopFromFeature(
        firstFeature,
        exactLocation: location,
        fallbackIndex: 0,
      );
      return stop ?? fallbackStop;
    } catch (e) {
      debugPrint('[PlaceGeocodingService] reverseGeocode failed: $e');
      return fallbackStop;
    }
  }

  NavigationStop? _stopFromFeature(
    Map<String, dynamic> feature, {
    LatLng? exactLocation,
    required int fallbackIndex,
  }) {
    final properties = (feature['properties'] as Map<String, dynamic>?) ?? {};
    final geometry = (feature['geometry'] as Map<String, dynamic>?) ?? {};

    double? lat;
    double? lon;

    if (exactLocation != null) {
      lat = exactLocation.latitude;
      lon = exactLocation.longitude;
    } else {
      if (properties['lat'] is num && properties['lon'] is num) {
        lat = (properties['lat'] as num).toDouble();
        lon = (properties['lon'] as num).toDouble();
      } else if (geometry['coordinates'] is List) {
        final coords = geometry['coordinates'] as List;
        if (coords.length >= 2 && coords[0] is num && coords[1] is num) {
          lon = (coords[0] as num).toDouble();
          lat = (coords[1] as num).toDouble();
        }
      }
    }

    if (lat == null ||
        lon == null ||
        !SafetyConfig.validCoordinates(lat, lon)) {
      return null;
    }

    final placeId = (properties['place_id'] as String?)?.trim();
    final name = (properties['name'] as String?)?.trim();
    final addressLine1 = (properties['address_line1'] as String?)?.trim();
    final addressLine2 = (properties['address_line2'] as String?)?.trim();
    final formatted = (properties['formatted'] as String?)?.trim();

    final displayName = (name != null && name.isNotEmpty)
        ? name
        : (addressLine1 != null && addressLine1.isNotEmpty)
        ? addressLine1
        : (formatted != null && formatted.isNotEmpty)
        ? formatted
        : 'Location (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})';

    final address = (formatted != null && formatted.isNotEmpty)
        ? formatted
        : addressLine2;

    final id = (placeId != null && placeId.isNotEmpty)
        ? placeId
        : 'stop_${DateTime.now().millisecondsSinceEpoch}_${fallbackIndex}_${lat}_$lon';

    return NavigationStop(
      id: id,
      location: LatLng(lat, lon),
      displayName: displayName,
      address: address,
    );
  }

  NavigationStop _formatCoordinatesFallback(LatLng location) {
    final latStr = location.latitude.toStringAsFixed(4);
    final lonStr = location.longitude.toStringAsFixed(4);
    return NavigationStop(
      id: 'coord_${location.latitude}_${location.longitude}',
      location: location,
      displayName: 'Location ($latStr, $lonStr)',
      address:
          'Coordinates: ${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
    );
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
