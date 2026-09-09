import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/models/navigation_stop.dart';
import 'package:myheritage_explorer/models/safe_route.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/navigation_session_controller.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/off_route_detector.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/reroute_coordinator.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/route_progress_engine.dart';

void main() {
  const origin = LatLng(5, 100);
  const destination = LatLng(5, 100.02);
  const destinationStop = NavigationStop(
    id: 'destination',
    location: destination,
    displayName: 'Museum',
    isDestination: true,
  );

  SafeRoute route({List<LatLng>? geometry}) => SafeRoute(
    geometry: geometry ?? const [origin, destination],
    distanceMeters: 2200,
    durationSeconds: 300,
    steps: const [],
    stops: const [destinationStop],
  );

  Position fix(LatLng point, DateTime timestamp) => Position(
    latitude: point.latitude,
    longitude: point.longitude,
    timestamp: timestamp,
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 90,
    headingAccuracy: 5,
    speed: 8,
    speedAccuracy: 1,
  );

  HazardReport hazard(String id) => HazardReport(
    id: id,
    userId: 'reporter',
    category: 'Road obstruction',
    severity: 'High',
    description: 'New obstruction',
    latitude: 5,
    longitude: 100.015,
    status: HazardReportStatus.verified,
  );

  test(
    'sustained wrong turn reroutes once without creating another GPS stream',
    () async {
      final positions = StreamController<Position>(sync: true);
      var listens = 0;
      final navigation = NavigationSessionController(
        ensureLocationAccess: () async {},
        positionStream: () {
          listens++;
          return positions.stream;
        },
      );
      var calls = 0;
      late LatLng rerouteStart;
      final replacement = route(
        geometry: const [LatLng(5.002, 100.002), destination],
      );
      final coordinator = RerouteCoordinator(
        navigationController: navigation,
        offRouteDetector: OffRouteDetector(
          offRouteDistanceMeters: 50,
          recoveryDistanceMeters: 20,
          requiredConsecutiveFixes: 2,
          minimumDuration: Duration.zero,
          minimumMovementMeters: 0,
        ),
        cooldown: Duration.zero,
        calculateRoute:
            ({required start, required stops, required hazards}) async {
              calls++;
              rerouteStart = start;
              expect(stops, const [destinationStop]);
              return replacement;
            },
      );
      addTearDown(() async {
        coordinator.dispose();
        navigation.dispose();
        await positions.close();
      });

      expect(
        await navigation.start(
          route: route(),
          stops: const [destinationStop],
          initialPosition: origin,
        ),
        isTrue,
      );
      final time = DateTime(2026, 9, 8, 12);
      positions.add(fix(const LatLng(5.002, 100.001), time));
      positions.add(
        fix(const LatLng(5.002, 100.002), time.add(const Duration(seconds: 1))),
      );
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
      expect(listens, 1);
      expect(rerouteStart, const LatLng(5.002, 100.002));
      expect(navigation.state.route, same(replacement));
      expect(navigation.state.isNavigating, isTrue);
    },
  );

  test(
    'new verified hazard on remaining geometry triggers hazard reroute',
    () async {
      final positions = StreamController<Position>(sync: true);
      final navigation = NavigationSessionController(
        ensureLocationAccess: () async {},
        positionStream: () => positions.stream,
      );
      final pending = Completer<SafeRoute>();
      var calls = 0;
      final coordinator = RerouteCoordinator(
        navigationController: navigation,
        cooldown: Duration.zero,
        calculateRoute: ({required start, required stops, required hazards}) {
          calls++;
          expect(hazards.map((item) => item.id), contains('new-hazard'));
          return pending.future;
        },
      );
      addTearDown(() async {
        coordinator.dispose();
        navigation.dispose();
        await positions.close();
      });

      coordinator.updateHazards(const []);
      await navigation.start(
        route: route(),
        stops: const [destinationStop],
        initialPosition: origin,
      );
      coordinator.updateHazards([hazard('new-hazard')]);

      expect(calls, 1);
      expect(coordinator.state.status, RerouteStatus.rerouting);
      expect(coordinator.state.reason, RerouteReason.newHazard);
      expect(coordinator.state.hazardId, 'new-hazard');

      final safer = route(
        geometry: const [origin, LatLng(5.01, 100.01), destination],
      );
      pending.complete(safer);
      await Future<void>.delayed(Duration.zero);
      expect(navigation.state.route, same(safer));
      expect(coordinator.state.status, RerouteStatus.succeeded);
    },
  );

  test('hazards behind current progress do not trigger rerouting', () {
    final oldHazard = HazardReport(
      id: 'behind',
      userId: 'reporter',
      category: 'Flood',
      severity: 'High',
      description: 'Behind traveler',
      latitude: 5,
      longitude: 100.002,
      status: HazardReportStatus.verified,
    );

    final conflicts = RerouteCoordinator.conflictingHazardsOnRemainingRoute(
      route: route(),
      currentPosition: const LatLng(5, 100.01),
      hazards: [oldHazard],
    );
    expect(conflicts, isEmpty);
  });

  test(
    'completed ordered stops are omitted from a replacement request',
    () async {
      const stopOne = NavigationStop(
        id: 'stop-one',
        location: LatLng(5, 100.01),
        displayName: 'First stop',
      );
      const firstStep = RouteStep(
        instruction: 'Arrive at first stop',
        roadName: 'Road one',
        distanceMeters: 1100,
        durationSeconds: 150,
        maneuverType: 10,
        startGeometryIndex: 0,
        endGeometryIndex: 1,
      );
      const secondStep = RouteStep(
        instruction: 'Arrive at destination',
        roadName: 'Road two',
        distanceMeters: 1100,
        durationSeconds: 150,
        maneuverType: 10,
        startGeometryIndex: 1,
        endGeometryIndex: 2,
      );
      final multiRoute = SafeRoute(
        geometry: const [origin, LatLng(5, 100.01), destination],
        distanceMeters: 2200,
        durationSeconds: 300,
        steps: const [firstStep, secondStep],
        stops: const [stopOne, destinationStop],
        legs: [
          RouteLeg(
            startStopName: 'Current Location',
            endStopName: stopOne.displayName,
            startLocation: origin,
            endLocation: stopOne.location,
            distanceMeters: 1100,
            durationSeconds: 150,
            steps: const [firstStep],
          ),
          RouteLeg(
            startStopName: stopOne.displayName,
            endStopName: destinationStop.displayName,
            startLocation: stopOne.location,
            endLocation: destination,
            distanceMeters: 1100,
            durationSeconds: 150,
            steps: const [secondStep],
          ),
        ],
      );
      final positions = StreamController<Position>(sync: true);
      final navigation = NavigationSessionController(
        ensureLocationAccess: () async {},
        positionStream: () => positions.stream,
      );
      addTearDown(() async {
        navigation.dispose();
        await positions.close();
      });
      await navigation.start(
        route: multiRoute,
        stops: const [stopOne, destinationStop],
        initialPosition: stopOne.location,
      );
      expect(
        navigation.state.progress?.arrival,
        NavigationArrival.intermediateStop,
      );
      navigation.continueToNextStop();

      expect(RerouteCoordinator.remainingStopsFor(navigation.state), const [
        destinationStop,
      ]);
    },
  );
}
