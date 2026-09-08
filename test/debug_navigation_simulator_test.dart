import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/models/navigation_stop.dart';
import 'package:myheritage_explorer/models/safe_route.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/debug_navigation_simulator.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/hazard_proximity_controller.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/navigation_session_controller.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/off_route_detector.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/reroute_coordinator.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/route_progress_engine.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/safe_navigation_page.dart';

void main() {
  const start = LatLng(5.4141, 100.3288);
  const mid = LatLng(5.4200, 100.3350);
  const destination = LatLng(5.4300, 100.3400);

  Position makePosition({
    double latitude = 5.4141,
    double longitude = 100.3288,
    double heading = 0,
    double speed = 5,
    double accuracy = 4,
    DateTime? timestamp,
  }) => Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: heading,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: 0,
  );

  SafeRoute makeRoute() => SafeRoute(
    geometry: const [start, mid, destination],
    distanceMeters: 2500,
    durationSeconds: 400,
    steps: const [],
  );

  List<NavigationStop> makeStops() => const [
    NavigationStop(
      id: 'dest',
      location: destination,
      displayName: 'Gurney Plaza',
      isDestination: true,
    ),
  ];

  HazardReport makeHazard({
    String id = 'hazard-1',
    String severity = 'High',
    String status = 'Verified',
    double latitude = 5.4220,
    double longitude = 100.3360,
  }) => HazardReport(
    id: id,
    userId: 'u1',
    category: 'Road obstruction',
    severity: severity,
    description: 'Fallen tree blocking lane',
    latitude: latitude,
    longitude: longitude,
    status: status,
  );

  group('DebugNavigationSimulator Unit Tests', () {
    late StreamController<Position> positionStream;
    late NavigationSessionController controller;

    setUp(() {
      positionStream = StreamController<Position>.broadcast();
      controller = NavigationSessionController(
        ensureLocationAccess: () async {},
        positionStream: () => positionStream.stream,
      );
    });

    tearDown(() async {
      await controller.end();
      controller.dispose();
      await positionStream.close();
    });

    test(
      'Release gating and compile-time flag controls simulator default state',
      () async {
        // Without overrides, default simulator reflects compile-time flag in debug mode
        const defaultSimulator = DebugNavigationSimulator();
        expect(defaultSimulator.isEnabled, kDebugMode && enableNavigationDebug);

        const disabledSimulator = DebugNavigationSimulator(
          enabledOverride: false,
        );
        expect(disabledSimulator.isEnabled, isFalse);

        const enabledSimulator = DebugNavigationSimulator(
          enabledOverride: true,
        );
        expect(enabledSimulator.isEnabled, isTrue);

        await controller.start(
          route: makeRoute(),
          stops: makeStops(),
          initialPosition: start,
        );

        final onRoute = disabledSimulator.simulateOnRoute(
          controller: controller,
        );
        expect(onRoute.success, isFalse);
        expect(onRoute.message, contains('disabled in release builds'));

        final offRouteSingle = disabledSimulator.simulateOffRouteSingle(
          controller: controller,
        );
        expect(offRouteSingle.success, isFalse);

        final offRouteConfirmed = await disabledSimulator
            .simulateOffRouteConfirmed(controller: controller);
        expect(offRouteConfirmed.success, isFalse);

        final approaching = disabledSimulator.simulateApproachingHazard(
          controller: controller,
          hazards: [makeHazard()],
        );
        expect(approaching.success, isFalse);

        final inside = disabledSimulator.simulateInsideHazard(
          controller: controller,
          hazards: [makeHazard()],
        );
        expect(inside.success, isFalse);

        final restore = disabledSimulator.restoreRealGps(
          controller: controller,
        );
        expect(restore.success, isFalse);
      },
    );

    test(
      'Simulate On-Route advances position and flags simulated location',
      () async {
        const simulator = DebugNavigationSimulator(enabledOverride: true);

        await controller.start(
          route: makeRoute(),
          stops: makeStops(),
          initialPosition: start,
        );

        final result = simulator.simulateOnRoute(
          controller: controller,
          stepMeters: 30,
        );

        expect(result.success, isTrue);
        expect(result.simulatedPosition, isNotNull);
        expect(controller.state.isSimulatedLocation, isTrue);
        expect(controller.isSimulatingLocation, isTrue);
        expect(controller.state.currentPosition, result.simulatedPosition);
        expect(controller.state.progress, isNotNull);
      },
    );

    test(
      'Simulate Off-Route 80m single fix produces suspect state without reroute',
      () async {
        const simulator = DebugNavigationSimulator(enabledOverride: true);

        var rerouteRequested = false;
        final rerouteCoordinator = RerouteCoordinator(
          navigationController: controller,
          calculateRoute:
              ({required start, required stops, required hazards}) async {
                rerouteRequested = true;
                return makeRoute();
              },
        );

        await controller.start(
          route: makeRoute(),
          stops: makeStops(),
          initialPosition: start,
        );

        final result = simulator.simulateOffRouteSingle(
          controller: controller,
          distanceMeters: 80,
        );

        expect(result.success, isTrue);
        expect(controller.state.isSimulatedLocation, isTrue);
        expect(rerouteCoordinator.offRouteState, OffRouteState.suspect);
        expect(rerouteCoordinator.state.status, RerouteStatus.idle);
        expect(rerouteRequested, isFalse);

        rerouteCoordinator.dispose();
      },
    );

    test(
      'Simulate Off-Route 80m confirmed (3 fixes) triggers automatic reroute',
      () async {
        const simulator = DebugNavigationSimulator(enabledOverride: true);

        final completer = Completer<SafeRoute>();
        var rerouteRequested = false;
        final rerouteCoordinator = RerouteCoordinator(
          navigationController: controller,
          calculateRoute: ({required start, required stops, required hazards}) {
            rerouteRequested = true;
            return completer.future;
          },
        );

        await controller.start(
          route: makeRoute(),
          stops: makeStops(),
          initialPosition: start,
        );

        final result = await simulator.simulateOffRouteConfirmed(
          controller: controller,
          distanceMeters: 80,
        );

        expect(result.success, isTrue);
        expect(controller.state.isSimulatedLocation, isTrue);
        expect(rerouteCoordinator.offRouteState, OffRouteState.confirmed);
        expect(rerouteCoordinator.state.status, RerouteStatus.rerouting);
        expect(rerouteRequested, isTrue);

        completer.complete(makeRoute());
        await pumpEventQueue();
        expect(rerouteCoordinator.offRouteState, OffRouteState.onRoute);
        expect(rerouteCoordinator.state.status, RerouteStatus.succeeded);

        rerouteCoordinator.dispose();
      },
    );

    test(
      'Simulate Off-Route 150m confirmed triggers automatic reroute',
      () async {
        const simulator = DebugNavigationSimulator(enabledOverride: true);

        final completer = Completer<SafeRoute>();
        var rerouteRequested = false;
        final rerouteCoordinator = RerouteCoordinator(
          navigationController: controller,
          calculateRoute: ({required start, required stops, required hazards}) {
            rerouteRequested = true;
            return completer.future;
          },
        );

        await controller.start(
          route: makeRoute(),
          stops: makeStops(),
          initialPosition: start,
        );

        final result = await simulator.simulateOffRouteConfirmed(
          controller: controller,
          distanceMeters: 150,
        );

        expect(result.success, isTrue);
        expect(controller.state.isSimulatedLocation, isTrue);
        expect(rerouteCoordinator.offRouteState, OffRouteState.confirmed);
        expect(rerouteCoordinator.state.status, RerouteStatus.rerouting);
        expect(rerouteRequested, isTrue);

        completer.complete(makeRoute());
        await pumpEventQueue();
        expect(rerouteCoordinator.offRouteState, OffRouteState.onRoute);
        expect(rerouteCoordinator.state.status, RerouteStatus.succeeded);

        rerouteCoordinator.dispose();
      },
    );

    test(
      'Off-route point calculates perpendicular distance accurately on arbitrary coords',
      () {
        const simulator = DebugNavigationSimulator(enabledOverride: true);
        final route = makeRoute();

        final offPoint80 = simulator.computeOffRoutePoint(
          route: route,
          referencePoint: start,
          distanceMeters: 80,
        );

        expect(offPoint80, isNotNull);
        final projection80 = const RouteProgressEngine().project(
          route.geometry,
          offPoint80!,
        );
        expect(projection80, isNotNull);
        expect(projection80!.distanceFromRouteMeters, closeTo(80.0, 1.0));

        final offPoint150 = simulator.computeOffRoutePoint(
          route: route,
          referencePoint: start,
          distanceMeters: 150,
        );
        expect(offPoint150, isNotNull);
        final projection150 = const RouteProgressEngine().project(
          route.geometry,
          offPoint150!,
        );
        expect(projection150, isNotNull);
        expect(projection150!.distanceFromRouteMeters, closeTo(150.0, 1.0));
      },
    );

    test(
      'Simulation preserves route geometry and ordered stops unchanged',
      () async {
        const simulator = DebugNavigationSimulator(enabledOverride: true);
        final originalRoute = makeRoute();
        final originalStops = makeStops();

        await controller.start(
          route: originalRoute,
          stops: originalStops,
          initialPosition: start,
        );

        simulator.simulateOnRoute(controller: controller, stepMeters: 40);
        simulator.simulateOffRouteSingle(
          controller: controller,
          distanceMeters: 80,
        );

        expect(
          controller.state.route!.geometry,
          equals(originalRoute.geometry),
        );
        expect(controller.state.stops.length, equals(originalStops.length));
        expect(controller.state.stops.first.id, equals(originalStops.first.id));
      },
    );

    test(
      'Restore Real GPS resumes live tracking from cached background fix',
      () async {
        const simulator = DebugNavigationSimulator(enabledOverride: true);

        await controller.start(
          route: makeRoute(),
          stops: makeStops(),
          initialPosition: start,
        );

        final realFix1 = makePosition(latitude: 5.4145, longitude: 100.3290);
        positionStream.add(realFix1);
        await pumpEventQueue();

        expect(
          controller.state.currentPosition,
          const LatLng(5.4145, 100.3290),
        );
        expect(controller.state.isSimulatedLocation, isFalse);

        simulator.simulateOffRouteSingle(
          controller: controller,
          distanceMeters: 80,
        );
        expect(controller.state.isSimulatedLocation, isTrue);
        expect(controller.isSimulatingLocation, isTrue);
        final simulatedPos = controller.state.currentPosition!;

        // Background real GPS emits while simulation is active
        final realFix2 = makePosition(latitude: 5.4150, longitude: 100.3300);
        positionStream.add(realFix2);
        await pumpEventQueue();

        // Controller should NOT update visible position to real GPS yet
        expect(controller.state.currentPosition, simulatedPos);
        expect(controller.latestRealPosition, realFix2);

        // Restore real GPS
        final restoreResult = simulator.restoreRealGps(controller: controller);
        expect(restoreResult.success, isTrue);
        expect(controller.state.isSimulatedLocation, isFalse);
        expect(controller.isSimulatingLocation, isFalse);
        expect(
          controller.state.currentPosition,
          const LatLng(5.4150, 100.3300),
        );
      },
    );

    test(
      'Single subscription maintained throughout simulation lifecycle',
      () async {
        const simulator = DebugNavigationSimulator(enabledOverride: true);

        await controller.start(
          route: makeRoute(),
          stops: makeStops(),
          initialPosition: start,
        );

        expect(controller.hasActiveSubscription, isTrue);

        simulator.simulateOnRoute(controller: controller);
        expect(controller.hasActiveSubscription, isTrue);

        simulator.simulateOffRouteSingle(controller: controller);
        expect(controller.hasActiveSubscription, isTrue);

        simulator.restoreRealGps(controller: controller);
        expect(controller.hasActiveSubscription, isTrue);

        await controller.end();
        expect(controller.hasActiveSubscription, isFalse);
      },
    );

    test('Simulate Approaching Hazard triggers approaching alert', () async {
      const simulator = DebugNavigationSimulator(enabledOverride: true);
      final hazard = makeHazard(
        id: 'h-high',
        severity: 'High',
        latitude: 5.4200,
        longitude: 100.3350,
      );

      final hazardController = HazardProximityController(
        navigationController: controller,
      );
      hazardController.updateHazards([hazard]);

      await controller.start(
        route: makeRoute(),
        stops: makeStops(),
        initialPosition: start,
      );

      final result = simulator.simulateApproachingHazard(
        controller: controller,
        hazards: [hazard],
      );

      expect(result.success, isTrue);
      expect(controller.state.isSimulatedLocation, isTrue);
      expect(hazardController.primaryProximity, isNotNull);
      expect(
        hazardController.primaryProximity!.state,
        HazardZoneState.approaching,
      );
      expect(hazardController.prominentAlert, isNotNull);

      hazardController.dispose();
    });

    test('Simulate Inside Hazard triggers inside hazard alert', () async {
      const simulator = DebugNavigationSimulator(enabledOverride: true);
      final hazard = makeHazard(
        id: 'h-high',
        severity: 'High',
        latitude: 5.4200,
        longitude: 100.3350,
      );

      final hazardController = HazardProximityController(
        navigationController: controller,
      );
      hazardController.updateHazards([hazard]);

      await controller.start(
        route: makeRoute(),
        stops: makeStops(),
        initialPosition: start,
      );

      final result = simulator.simulateInsideHazard(
        controller: controller,
        hazards: [hazard],
      );

      expect(result.success, isTrue);
      expect(controller.state.isSimulatedLocation, isTrue);
      expect(hazardController.primaryProximity, isNotNull);
      expect(hazardController.primaryProximity!.state, HazardZoneState.inside);
      expect(hazardController.prominentAlert, isNotNull);

      hazardController.dispose();
    });

    test(
      'Hazard simulation with no active verified hazards returns friendly error',
      () async {
        const simulator = DebugNavigationSimulator(enabledOverride: true);

        await controller.start(
          route: makeRoute(),
          stops: makeStops(),
          initialPosition: start,
        );

        final resultApproaching = simulator.simulateApproachingHazard(
          controller: controller,
          hazards: const [],
        );
        expect(resultApproaching.success, isFalse);
        expect(
          resultApproaching.message,
          'No active Verified hazard available for simulation.',
        );

        final resultInside = simulator.simulateInsideHazard(
          controller: controller,
          hazards: [
            makeHazard(status: 'Pending'), // Unverified
          ],
        );
        expect(resultInside.success, isFalse);
        expect(
          resultInside.message,
          'No active Verified hazard available for simulation.',
        );
      },
    );
  });

  group('SafeNavigationPage Debug Simulator Integration Tests', () {
    Future<void> pumpSimulatorPage(
      WidgetTester tester, {
      bool? enableDebugSimulator,
      NavigationSessionController? navigationController,
    }) async {
      final controller =
          navigationController ??
          NavigationSessionController(
            ensureLocationAccess: () async {},
            positionStream: () => const Stream<Position>.empty(),
          );
      if (navigationController == null) {
        addTearDown(() async {
          await controller.end();
          controller.dispose();
        });
      }
      await tester.pumpWidget(
        MaterialApp(
          home: enableDebugSimulator != null
              ? SafeNavigationPage(
                  enableDebugSimulator: enableDebugSimulator,
                  locationLoader: () async => makePosition(),
                  hazardReports: Stream.value(const []),
                  routeCalculator:
                      ({
                        required start,
                        required destination,
                        required hazards,
                      }) async => makeRoute(),
                  navigationController: controller,
                )
              : SafeNavigationPage(
                  locationLoader: () async => makePosition(),
                  hazardReports: Stream.value(const []),
                  routeCalculator:
                      ({
                        required start,
                        required destination,
                        required hazards,
                      }) async => makeRoute(),
                  navigationController: controller,
                ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    Future<void> beginNavigationInTest(WidgetTester tester) async {
      final map = tester.widget<fm.FlutterMap>(find.byType(fm.FlutterMap));
      map.options.onTap!(
        const fm.TapPosition(Offset.zero, Offset.zero),
        destination,
      );
      await tester.pump();
      final action = find.byKey(const ValueKey('safe-navigation-find-route'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final startAction = find.byKey(
        const ValueKey('safe-navigation-start-navigation'),
      );
      await tester.ensureVisible(startAction);
      await tester.tap(startAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets(
      'Simulator toggle button default reflects ENABLE_NAV_DEBUG compile-time flag',
      (tester) async {
        await pumpSimulatorPage(tester);
        await beginNavigationInTest(tester);

        if (enableNavigationDebug) {
          expect(
            find.byKey(
              const ValueKey('safe-navigation-debug-simulator-toggle'),
            ),
            findsOneWidget,
          );
        } else {
          expect(
            find.byKey(
              const ValueKey('safe-navigation-debug-simulator-toggle'),
            ),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('safe-navigation-debug-simulator-panel')),
            findsNothing,
          );
        }
      },
    );

    testWidgets(
      'Simulator toggle button is omitted when enableDebugSimulator is explicitly false',
      (tester) async {
        await pumpSimulatorPage(tester, enableDebugSimulator: false);
        await beginNavigationInTest(tester);

        expect(
          find.byKey(const ValueKey('safe-navigation-debug-simulator-toggle')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('safe-navigation-debug-simulator-panel')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Simulator sheet opens and actions update simulated state and badge when enableDebugSimulator is true',
      (tester) async {
        final positionController = StreamController<Position>();
        final sessionController = NavigationSessionController(
          ensureLocationAccess: () async {},
          positionStream: () => positionController.stream,
        );
        addTearDown(() async {
          sessionController.dispose();
          await positionController.close();
        });

        await pumpSimulatorPage(
          tester,
          enableDebugSimulator: true,
          navigationController: sessionController,
        );
        await beginNavigationInTest(tester);

        // Toggle button should be visible on the map
        final toggle = find.byKey(
          const ValueKey('safe-navigation-debug-simulator-toggle'),
        );
        expect(toggle, findsOneWidget);

        // Before simulation, badge is not displayed
        expect(
          find.byKey(const ValueKey('safe-navigation-simulated-gps-badge')),
          findsNothing,
        );

        // Tap toggle to open the simulator sheet
        await tester.tap(toggle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Panel sheet should be displayed
        expect(
          find.byKey(const ValueKey('safe-navigation-debug-simulator-panel')),
          findsOneWidget,
        );

        // Tap Simulate Off-Route 80m (Suspect)
        final offRouteButton = find.byKey(
          const ValueKey('safe-navigation-simulate-off-route-80m-button'),
        );
        expect(offRouteButton, findsOneWidget);
        await tester.tap(offRouteButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Close the bottom sheet
        final closeButton = find.byTooltip('Close');
        await tester.tap(closeButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Prominent SIMULATED GPS badge should be displayed
        expect(
          find.byKey(const ValueKey('safe-navigation-simulated-gps-badge')),
          findsOneWidget,
        );
        expect(find.text('SIMULATED GPS'), findsOneWidget);

        // Open sheet again and tap Restore Real GPS
        await tester.tap(toggle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final restoreButton = find.byKey(
          const ValueKey('safe-navigation-restore-real-gps-button'),
        );
        expect(restoreButton, findsOneWidget);
        await tester.tap(restoreButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await tester.tap(closeButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Badge should disappear
        expect(
          find.byKey(const ValueKey('safe-navigation-simulated-gps-badge')),
          findsNothing,
        );
      },
    );
  });
}
