import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:myheritage_explorer/models/navigation_stop.dart';
import 'package:myheritage_explorer/models/safe_route.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/route_progress_engine.dart';

void main() {
  const geometry = [
    LatLng(0, 0),
    LatLng(0, 0.001),
    LatLng(0.001, 0.001),
    LatLng(0.001, 0.002),
  ];
  const firstStop = NavigationStop(
    id: 'one',
    location: LatLng(0.001, 0.001),
    displayName: 'Aman Central',
  );
  const finalStop = NavigationStop(
    id: 'two',
    location: LatLng(0.001, 0.002),
    displayName: 'Gurney Paragon',
    isDestination: true,
  );
  const steps = [
    RouteStep(
      instruction: 'Head east on First Road',
      roadName: 'First Road',
      distanceMeters: 111,
      durationSeconds: 100,
      maneuverType: 11,
      startGeometryIndex: 0,
      endGeometryIndex: 1,
    ),
    RouteStep(
      instruction: 'Turn left onto Second Road',
      roadName: 'Second Road',
      distanceMeters: 111,
      durationSeconds: 80,
      maneuverType: 0,
      startGeometryIndex: 1,
      endGeometryIndex: 2,
    ),
    RouteStep(
      instruction: 'Turn right onto Third Road',
      roadName: 'Third Road',
      distanceMeters: 111,
      durationSeconds: 70,
      maneuverType: 1,
      startGeometryIndex: 2,
      endGeometryIndex: 3,
    ),
    RouteStep(
      instruction: 'Arrive at Gurney Paragon',
      roadName: '',
      distanceMeters: 0,
      durationSeconds: 0,
      maneuverType: 10,
      startGeometryIndex: 3,
      endGeometryIndex: 3,
    ),
  ];

  SafeRoute route({List<RouteStep> routeSteps = steps}) => SafeRoute(
    geometry: geometry,
    distanceMeters: 333,
    durationSeconds: 250,
    steps: routeSteps,
    stops: const [firstStop, finalStop],
    legs: routeSteps.isEmpty
        ? const []
        : [
            RouteLeg(
              startStopName: 'Current Location',
              endStopName: firstStop.displayName,
              startLocation: geometry.first,
              endLocation: firstStop.location,
              distanceMeters: 222,
              durationSeconds: 180,
              steps: routeSteps.take(2),
            ),
            RouteLeg(
              startStopName: firstStop.displayName,
              endStopName: finalStop.displayName,
              startLocation: firstStop.location,
              endLocation: finalStop.location,
              distanceMeters: 111,
              durationSeconds: 70,
              steps: routeSteps.skip(2),
            ),
          ],
  );

  const engine = RouteProgressEngine();

  test('GPS point projects to the closest route segment in meters', () {
    final projection = engine.project(
      geometry,
      const LatLng(0.00045, 0.00108),
    )!;

    expect(projection.segmentIndex, 1);
    expect(projection.segmentFraction, closeTo(0.45, 0.01));
    expect(projection.distanceFromRouteMeters, closeTo(8.9, 0.5));
  });

  test('active step and next maneuver advance with route progress', () {
    final beforeTurn = engine.calculate(
      route: route(),
      stops: const [firstStop, finalStop],
      gps: const LatLng(0, 0.0005),
    )!;
    final afterTurn = engine.calculate(
      route: route(),
      stops: const [firstStop, finalStop],
      gps: const LatLng(0.0005, 0.001),
    )!;

    expect(beforeTurn.activeStepIndex, 0);
    expect(beforeTurn.maneuverStepIndex, 1);
    expect(beforeTurn.maneuver, NavigationManeuver.turnLeft);
    expect(afterTurn.activeStepIndex, 1);
    expect(afterTurn.maneuverStepIndex, 2);
    expect(afterTurn.maneuver, NavigationManeuver.turnRight);
  });

  test('distance to maneuver follows route geometry', () {
    final progress = engine.calculate(
      route: route(),
      stops: const [firstStop, finalStop],
      gps: const LatLng(0.0001, 0.0005),
    )!;

    // The GPS is diagonally displaced; distance is measured along the route.
    expect(progress.distanceToManeuverMeters, closeTo(55.6, 1));
  });

  test('remaining route distance and step-weighted ETA decrease', () {
    final early = engine.calculate(
      route: route(),
      stops: const [firstStop, finalStop],
      gps: const LatLng(0, 0.0002),
    )!;
    final later = engine.calculate(
      route: route(),
      stops: const [firstStop, finalStop],
      gps: const LatLng(0.0007, 0.001),
    )!;

    expect(
      later.remainingDistanceMeters,
      lessThan(early.remainingDistanceMeters),
    );
    expect(
      later.remainingDurationSeconds,
      lessThan(early.remainingDurationSeconds),
    );
    expect(early.remainingDurationSeconds, closeTo(230, 2));
  });

  test('current road comes from active ORS step', () {
    final progress = engine.calculate(
      route: route(),
      stops: const [firstStop, finalStop],
      gps: const LatLng(0, 0.0004),
    )!;

    expect(progress.currentRoadName, 'First Road');
    expect(progress.instruction, 'Turn left onto Second Road');
  });

  test('missing road and unknown maneuver use safe fallbacks', () {
    const unknownSteps = [
      RouteStep(
        instruction: '',
        roadName: '',
        distanceMeters: 333,
        durationSeconds: 250,
        maneuverType: 999,
        startGeometryIndex: 0,
        endGeometryIndex: 3,
      ),
    ];
    final progress = engine.calculate(
      route: route(routeSteps: unknownSteps),
      stops: const [finalStop],
      gps: const LatLng(0, 0.0004),
    )!;

    expect(progress.currentRoadName, 'Unnamed road');
    expect(progress.maneuver, NavigationManeuver.unknown);
    expect(progress.instruction, 'Continue on route');
  });

  test('route without step data remains usable for a single stop', () {
    final progress = engine.calculate(
      route: route(routeSteps: const []),
      stops: const [finalStop],
      gps: const LatLng(0, 0.0005),
    )!;

    expect(progress.activeStepIndex, isNull);
    expect(progress.nextStop, finalStop);
    expect(progress.remainingDistanceMeters, greaterThan(0));
    expect(progress.remainingDurationSeconds, greaterThan(0));
  });

  test('multi-stop leg and next stop are detected without reordering', () {
    final plannedStops = <NavigationStop>[firstStop, finalStop];
    final progress = engine.calculate(
      route: route(),
      stops: plannedStops,
      gps: const LatLng(0.0008, 0.001),
    )!;

    expect(progress.currentLegIndex, 0);
    expect(progress.nextStop, firstStop);
    expect(plannedStops, orderedEquals(const [firstStop, finalStop]));
  });

  test('intermediate and final arrival require GPS and route proximity', () {
    final intermediate = engine.calculate(
      route: route(),
      stops: const [firstStop, finalStop],
      gps: firstStop.location,
    )!;
    final finalArrival = engine.calculate(
      route: route(),
      stops: const [firstStop, finalStop],
      gps: finalStop.location,
      minimumLegIndex: 1,
    )!;
    final passingNearbyWrongLeg = engine.calculate(
      route: route(),
      stops: const [finalStop],
      gps: firstStop.location,
    )!;

    expect(intermediate.arrival, NavigationArrival.intermediateStop);
    expect(intermediate.instruction, 'Arriving at Aman Central');
    expect(finalArrival.arrival, NavigationArrival.finalDestination);
    expect(finalArrival.instruction, 'You have arrived at Gurney Paragon.');
    expect(passingNearbyWrongLeg.arrival, NavigationArrival.none);
  });

  test('projection does not mutate route geometry', () {
    final plannedRoute = route();
    final original = List<LatLng>.of(plannedRoute.geometry);

    engine.calculate(
      route: plannedRoute,
      stops: const [firstStop, finalStop],
      gps: const LatLng(0.0004, 0.0011),
    );

    expect(plannedRoute.geometry, orderedEquals(original));
    expect(() => plannedRoute.geometry.clear(), throwsUnsupportedError);
  });
}
