import 'package:geolocator/geolocator.dart';

import '../core/safety_config.dart';

class LocationService {
  const LocationService();

  Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationAccessException(
        'Turn on location services, then try again.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationAccessException(
        'Allow location access in your device settings, then return and retry.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationAccessException(
        'Location access is needed to place your report and confirm nearby hazards.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    if (!isUsablePosition(position)) {
      throw const LocationAccessException(
        'Your location is not accurate enough yet. Move to an open area and retry.',
      );
    }
    return position;
  }

  static bool isUsablePosition(Position position, {DateTime? now}) {
    final age = (now ?? DateTime.now()).difference(position.timestamp);
    return SafetyConfig.validCoordinates(
          position.latitude,
          position.longitude,
        ) &&
        position.accuracy.isFinite &&
        position.accuracy >= 0 &&
        position.accuracy <= 100 &&
        age >= const Duration(seconds: -5) &&
        age <= const Duration(minutes: 2);
  }

  Stream<Position> watchPosition({double distanceFilterMeters = 40}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters.toInt(),
      ),
    );
  }

  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}

class LocationAccessException implements Exception {
  const LocationAccessException(this.message);
  final String message;
  @override
  String toString() => message;
}
