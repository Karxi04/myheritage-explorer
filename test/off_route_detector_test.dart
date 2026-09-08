import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/off_route_detector.dart';

void main() {
  const first = LatLng(5.0, 100.0);

  test('requires persistent, meaningful deviation before confirmation', () {
    final detector = OffRouteDetector(
      requiredConsecutiveFixes: 3,
      minimumDuration: const Duration(seconds: 4),
      minimumMovementMeters: 10,
    );
    final time = DateTime(2026, 9, 8, 12);

    expect(
      detector.evaluate(
        distanceFromRouteMeters: 100,
        position: first,
        timestamp: time,
        accuracyMeters: 5,
      ),
      OffRouteState.suspect,
    );
    expect(
      detector.evaluate(
        distanceFromRouteMeters: 110,
        position: const LatLng(5.00005, 100.0),
        timestamp: time.add(const Duration(seconds: 2)),
        accuracyMeters: 5,
      ),
      OffRouteState.suspect,
    );
    expect(
      detector.evaluate(
        distanceFromRouteMeters: 120,
        position: const LatLng(5.0002, 100.0),
        timestamp: time.add(const Duration(seconds: 5)),
        accuracyMeters: 5,
      ),
      OffRouteState.confirmed,
    );
  });

  test('an isolated GPS spike resets when the next fix returns to route', () {
    final detector = OffRouteDetector(
      requiredConsecutiveFixes: 2,
      minimumDuration: Duration.zero,
      minimumMovementMeters: 0,
    );
    final time = DateTime(2026, 9, 8, 12);

    detector.evaluate(
      distanceFromRouteMeters: 200,
      position: first,
      timestamp: time,
      accuracyMeters: 5,
    );
    expect(
      detector.evaluate(
        distanceFromRouteMeters: 10,
        position: first,
        timestamp: time.add(const Duration(seconds: 1)),
        accuracyMeters: 5,
      ),
      OffRouteState.onRoute,
    );
    expect(detector.consecutiveFixes, 0);
  });

  test('poor-accuracy fixes cannot initiate an off-route event', () {
    final detector = OffRouteDetector(
      requiredConsecutiveFixes: 1,
      minimumDuration: Duration.zero,
      minimumMovementMeters: 0,
      maximumAccuracyMeters: 50,
    );

    expect(
      detector.evaluate(
        distanceFromRouteMeters: 500,
        position: first,
        timestamp: DateTime(2026, 9, 8, 12),
        accuracyMeters: 80,
      ),
      OffRouteState.onRoute,
    );
  });
}
