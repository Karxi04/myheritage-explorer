import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:myheritage_explorer/models/navigation_stop.dart';
import 'package:myheritage_explorer/models/safe_route.dart';
import 'package:myheritage_explorer/services/location_service.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/navigation_session_controller.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/route_progress_engine.dart';

void main() {
  const origin = LatLng(6.1257, 100.3665);
  const destination = LatLng(6.1357, 100.3765);

  Position position({
    double latitude = 6.1257,
    double longitude = 100.3665,
    double heading = 0,
    double speed = 2,
    double accuracy = 8,
  }) => Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026, 9, 8, 12),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: heading,
    headingAccuracy: 5,
    speed: speed,
    speedAccuracy: 1,
  );

  SafeRoute route() => SafeRoute(
    geometry: const [origin, LatLng(6.13, 100.37), destination],
    distanceMeters: 1800,
    durationSeconds: 420,
    steps: const [],
  );

  List<NavigationStop> stops() => const [
    NavigationStop(
      id: 'destination',
      location: destination,
      displayName: 'Aman Central',
      isDestination: true,
    ),
  ];

  group('NavigationSessionController lifecycle', () {
    late StreamController<Position> positions;
    late NavigationSessionController controller;
    var listenCount = 0;
    var cancelCount = 0;

    setUp(() {
      listenCount = 0;
      cancelCount = 0;
      positions = StreamController<Position>(
        sync: true,
        onListen: () => listenCount++,
        onCancel: () => cancelCount++,
      );
      controller = NavigationSessionController(
        ensureLocationAccess: () async {},
        positionStream: () => positions.stream,
      );
    });

    tearDown(() async {
      controller.dispose();
      await positions.close();
    });

    test('start subscribes once and defaults Follow User to ON', () async {
      expect(await controller.start(route: route(), stops: stops()), isTrue);

      expect(listenCount, 1);
      expect(controller.hasActiveSubscription, isTrue);
      expect(controller.state.isNavigating, isTrue);
      expect(controller.state.isFollowingUser, isTrue);
    });

    test('duplicate start never creates a second subscription', () async {
      expect(await controller.start(route: route(), stops: stops()), isTrue);
      expect(await controller.start(route: route(), stops: stops()), isFalse);

      expect(listenCount, 1);
    });

    test('end cancels stream and clears temporary navigation state', () async {
      final plannedRoute = route();
      await controller.start(route: plannedRoute, stops: stops());
      positions.add(position());

      await controller.end();

      expect(cancelCount, 1);
      expect(controller.hasActiveSubscription, isFalse);
      expect(controller.state.isNavigating, isFalse);
      expect(controller.state.isFollowingUser, isFalse);
      expect(controller.state.currentPosition, isNull);
      expect(controller.state.route, same(plannedRoute));
    });

    test('dispose cancels the active stream', () async {
      await controller.start(route: route(), stops: stops());

      controller.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(cancelCount, 1);
    });

    test(
      'position stream updates location, speed, accuracy and timestamp',
      () async {
        await controller.start(route: route(), stops: stops());
        final update = position(
          latitude: 6.126,
          longitude: 100.367,
          speed: 4.2,
          accuracy: 12,
        );

        positions.add(update);

        expect(controller.state.currentPosition, const LatLng(6.126, 100.367));
        expect(controller.state.speed, 4.2);
        expect(controller.state.accuracy, 12);
        expect(controller.state.timestamp, update.timestamp);
      },
    );

    test(
      'manual interaction disables follow and recenter re-enables it',
      () async {
        await controller.start(route: route(), stops: stops());

        controller.disableFollowing();
        expect(controller.state.isFollowingUser, isFalse);

        controller.recenter();
        expect(controller.state.isFollowingUser, isTrue);
      },
    );

    test('route geometry and ordered stops remain unchanged', () async {
      final plannedRoute = route();
      final plannedStops = [
        ...stops(),
        const NavigationStop(
          id: 'second',
          location: LatLng(6.14, 100.38),
          displayName: 'Final Stop',
          isDestination: true,
        ),
      ];
      final originalGeometry = List<LatLng>.of(plannedRoute.geometry);

      await controller.start(route: plannedRoute, stops: plannedStops);
      positions.add(position(latitude: 6.13, longitude: 100.37));

      expect(controller.state.route, same(plannedRoute));
      expect(plannedRoute.geometry, orderedEquals(originalGeometry));
      expect(
        controller.state.stops.map((stop) => stop.id),
        orderedEquals(['destination', 'second']),
      );
      expect(() => controller.state.stops.clear(), throwsUnsupportedError);
    });

    test('minor GPS backward noise does not reverse route progress', () async {
      await controller.start(route: route(), stops: stops());
      positions.add(position(latitude: 6.1302, longitude: 100.3702));
      final forward = controller.state.progress!.geometryProgress;

      positions.add(position(latitude: 6.13015, longitude: 100.37015));

      expect(
        controller.state.progress!.geometryProgress,
        closeTo(forward, 1e-9),
      );
    });

    test('missing RouteStep data still publishes safe progress', () async {
      await controller.start(route: route(), stops: stops());
      positions.add(position());

      expect(controller.state.progress, isNotNull);
      expect(controller.state.progress!.activeStepIndex, isNull);
      expect(controller.state.progress!.currentRoadName, 'Unnamed road');
    });

    test(
      'intermediate stop remains locked until explicitly continued',
      () async {
        const middle = LatLng(6.13, 100.37);
        const orderedStops = [
          NavigationStop(id: 'middle', location: middle, displayName: 'Stop 1'),
          NavigationStop(
            id: 'final',
            location: destination,
            displayName: 'Final Stop',
            isDestination: true,
          ),
        ];
        const legOneStep = RouteStep(
          instruction: 'Continue to Stop 1',
          roadName: 'First Road',
          distanceMeters: 700,
          durationSeconds: 180,
          maneuverType: 6,
          startGeometryIndex: 0,
          endGeometryIndex: 1,
        );
        const legTwoStep = RouteStep(
          instruction: 'Continue to Final Stop',
          roadName: 'Second Road',
          distanceMeters: 1100,
          durationSeconds: 240,
          maneuverType: 6,
          startGeometryIndex: 1,
          endGeometryIndex: 2,
        );
        final multiRoute = SafeRoute(
          geometry: const [origin, middle, destination],
          distanceMeters: 1800,
          durationSeconds: 420,
          steps: const [legOneStep, legTwoStep],
          legs: [
            RouteLeg(
              startStopName: 'Current Location',
              endStopName: 'Stop 1',
              startLocation: origin,
              endLocation: middle,
              distanceMeters: 700,
              durationSeconds: 180,
              steps: const [legOneStep],
            ),
            RouteLeg(
              startStopName: 'Stop 1',
              endStopName: 'Final Stop',
              startLocation: middle,
              endLocation: destination,
              distanceMeters: 1100,
              durationSeconds: 240,
              steps: const [legTwoStep],
            ),
          ],
        );
        await controller.start(route: multiRoute, stops: orderedStops);

        positions.add(
          position(latitude: middle.latitude, longitude: middle.longitude),
        );
        expect(
          controller.state.progress!.arrival,
          NavigationArrival.intermediateStop,
        );

        positions.add(
          position(
            latitude: destination.latitude,
            longitude: destination.longitude,
          ),
        );
        expect(controller.state.progress!.currentLegIndex, 0);
        expect(controller.state.progress!.nextStop, orderedStops.first);

        controller.continueToNextStop();
        expect(controller.state.progress!.currentLegIndex, 1);
        expect(controller.state.progress!.nextStop, orderedStops.last);
      },
    );
  });

  group('heading stability', () {
    late StreamController<Position> positions;
    late NavigationSessionController controller;

    setUp(() async {
      positions = StreamController<Position>(sync: true);
      controller = NavigationSessionController(
        ensureLocationAccess: () async {},
        positionStream: () => positions.stream,
      );
      await controller.start(route: route(), stops: stops());
    });

    tearDown(() async {
      controller.dispose();
      await positions.close();
    });

    test('valid heading updates marker orientation', () {
      positions.add(position(heading: 90, speed: 3));

      expect(controller.state.currentHeading, 90);
      expect(controller.state.displayHeading, 90);
    });

    test('invalid heading preserves previous valid heading', () {
      positions.add(position(heading: 45, speed: 3));
      positions.add(position(heading: double.nan, speed: 3));

      expect(controller.state.currentHeading, 45);
      expect(controller.state.displayHeading, 45);
    });

    test('359 to 1 uses the shortest angle across north', () {
      positions.add(position(heading: 359, speed: 3));
      positions.add(position(heading: 1, speed: 3));

      expect(controller.state.currentHeading, 1);
      expect(controller.state.displayHeading, greaterThan(359));
      expect(controller.state.displayHeading, lessThan(361));
      expect(NavigationSessionController.shortestHeadingDelta(359, 1), 2);
    });

    test('stationary updates preserve an established orientation', () {
      positions.add(position(heading: 75, speed: 3));
      positions.add(position(heading: 210, speed: 0));

      expect(controller.state.currentHeading, 75);
      expect(controller.state.displayHeading, 75);
    });
  });

  group('failure and quality states', () {
    for (final (failure, expectedIssue) in [
      (LocationAccessFailure.denied, NavigationLocationIssue.permissionDenied),
      (
        LocationAccessFailure.deniedForever,
        NavigationLocationIssue.permissionDeniedForever,
      ),
      (
        LocationAccessFailure.servicesDisabled,
        NavigationLocationIssue.servicesDisabled,
      ),
    ]) {
      test('$failure is handled without subscribing', () async {
        var listened = false;
        final controller = NavigationSessionController(
          ensureLocationAccess: () async => throw LocationAccessException(
            'Friendly location message',
            code: failure,
          ),
          positionStream: () {
            listened = true;
            return const Stream.empty();
          },
        );
        addTearDown(controller.dispose);

        expect(await controller.start(route: route(), stops: stops()), isFalse);
        expect(listened, isFalse);
        expect(controller.state.locationIssue, expectedIssue);
        expect(controller.state.locationMessage, 'Friendly location message');
      });
    }

    test(
      'unexpected readiness failure becomes temporary unavailable',
      () async {
        final controller = NavigationSessionController(
          ensureLocationAccess: () async => throw StateError('GPS unavailable'),
          positionStream: () => const Stream.empty(),
        );
        addTearDown(controller.dispose);

        expect(await controller.start(route: route(), stops: stops()), isFalse);
        expect(
          controller.state.locationIssue,
          NavigationLocationIssue.temporarilyUnavailable,
        );
        expect(controller.state.locationMessage, isNot(contains('StateError')));
      },
    );

    test('stream errors are user-facing and do not crash navigation', () async {
      final positions = StreamController<Position>(sync: true);
      final controller = NavigationSessionController(
        ensureLocationAccess: () async {},
        positionStream: () => positions.stream,
      );
      addTearDown(() async {
        controller.dispose();
        await positions.close();
      });
      await controller.start(route: route(), stops: stops());

      positions.addError(StateError('technical details'));

      expect(controller.state.isNavigating, isTrue);
      expect(
        controller.state.locationIssue,
        NavigationLocationIssue.streamError,
      );
      expect(controller.state.locationMessage, isNot(contains('technical')));
    });

    test('poor accuracy warns but still updates position', () async {
      final positions = StreamController<Position>(sync: true);
      final controller = NavigationSessionController(
        ensureLocationAccess: () async {},
        positionStream: () => positions.stream,
      );
      addTearDown(() async {
        controller.dispose();
        await positions.close();
      });
      await controller.start(route: route(), stops: stops());

      positions.add(position(accuracy: 250));

      expect(controller.state.currentPosition, origin);
      expect(
        controller.state.locationIssue,
        NavigationLocationIssue.poorAccuracy,
      );
      expect(
        controller.state.locationMessage,
        'Location accuracy is currently low.',
      );
    });
  });

  group('reverse-geocoding cache', () {
    test('nearby rapid updates reuse the cached label', () async {
      final positions = StreamController<Position>(sync: true);
      var calls = 0;
      final controller = NavigationSessionController(
        ensureLocationAccess: () async {},
        positionStream: () => positions.stream,
        reverseGeocoder: (point) async {
          calls++;
          return 'Jalan Sultan Badlishah, Alor Setar';
        },
        now: () => DateTime(2026, 9, 8, 12),
      );
      addTearDown(() async {
        controller.dispose();
        await positions.close();
      });
      await controller.start(route: route(), stops: stops());

      positions.add(position());
      await Future<void>.delayed(Duration.zero);
      positions.add(position(latitude: 6.12571, longitude: 100.36651));
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
      expect(
        controller.state.currentLocationLabel,
        'Jalan Sultan Badlishah, Alor Setar',
      );
      expect(
        controller.state.progress!.currentRoadName,
        'Jalan Sultan Badlishah, Alor Setar',
      );
    });

    test('meaningful movement triggers a fresh reverse geocode', () async {
      final positions = StreamController<Position>(sync: true);
      var calls = 0;
      final controller = NavigationSessionController(
        ensureLocationAccess: () async {},
        positionStream: () => positions.stream,
        reverseGeocoder: (point) async => 'Address ${++calls}',
        now: () => DateTime(2026, 9, 8, 12),
      );
      addTearDown(() async {
        controller.dispose();
        await positions.close();
      });
      await controller.start(route: route(), stops: stops());

      positions.add(position());
      await Future<void>.delayed(Duration.zero);
      positions.add(position(latitude: 6.127, longitude: 100.368));
      await Future<void>.delayed(Duration.zero);

      expect(calls, 2);
      expect(controller.state.currentLocationLabel, 'Address 2');
    });

    test('geocoding failure safely falls back to coordinates', () async {
      final positions = StreamController<Position>(sync: true);
      final controller = NavigationSessionController(
        ensureLocationAccess: () async {},
        positionStream: () => positions.stream,
        reverseGeocoder: (point) async => throw StateError('offline'),
      );
      addTearDown(() async {
        controller.dispose();
        await positions.close();
      });
      await controller.start(route: route(), stops: stops());

      positions.add(position());
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.currentLocationLabel, '6.12570, 100.36650');
    });
  });
}
