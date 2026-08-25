import 'package:geolocator/geolocator.dart';

import '../core/helpers.dart';

class LocationService {
  const LocationService();

  Future<Position> getCurrentPosition() => determinePosition();

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
