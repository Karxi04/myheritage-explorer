import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/models/safe_route.dart';
import 'package:myheritage_explorer/services/location_service.dart';
import 'package:myheritage_explorer/services/place_geocoding_service.dart';
import 'package:myheritage_explorer/services/safe_routing_service.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/navigation_session_controller.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/safe_navigation_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const start = LatLng(5.42085, 100.34385);
  const destination = LatLng(5.43710, 100.31070);

  Position position({
    double latitude = 5.42085,
    double longitude = 100.34385,
  }) => Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  HazardReport hazard({
    String id = 'verified-hazard',
    String status = HazardReportStatus.verified,
    String severity = 'High',
    double latitude = 5.429,
    double longitude = 100.329,
  }) => HazardReport(
    id: id,
    userId: 'reporter',
    category: 'Road obstruction',
    severity: severity,
    description: 'Test hazard',
    latitude: latitude,
    longitude: longitude,
    status: status,
  );

  SafeRoute route({
    Iterable<String> avoidedIds = const ['verified-hazard'],
    bool startedInsideHazard = false,
    Iterable<String> escapeHazardIds = const [],
  }) => SafeRoute(
    geometry: const [
      start,
      LatLng(5.425, 100.338),
      LatLng(5.433, 100.321),
      destination,
    ],
    distanceMeters: 8060,
    durationSeconds: 931.8,
    steps: const [],
    avoidedHazardIds: avoidedIds,
    startedInsideHazard: startedInsideHazard,
    escapeHazardIds: escapeHazardIds,
  );

  Future<SafeRoute> successfulCalculator({
    required LatLng start,
    required LatLng destination,
    required List<HazardReport> hazards,
  }) async => route(avoidedIds: hazards.map((item) => item.id));

  Future<void> pumpPage(
    WidgetTester tester, {
    SafeNavigationLocationLoader? locationLoader,
    SafeNavigationRouteCalculator? routeCalculator,
    SafeNavigationMultiStopCalculator? multiStopRouteCalculator,
    PlaceGeocodingService? geocodingService,
    NavigationSessionController? navigationController,
    Stream<List<HazardReport>>? hazards,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: SafeNavigationPage(
          locationLoader: locationLoader ?? () async => position(),
          routeCalculator:
              routeCalculator ??
              (multiStopRouteCalculator == null ? successfulCalculator : null),
          multiStopRouteCalculator: multiStopRouteCalculator,
          geocodingService: geocodingService,
          navigationController: navigationController,
          hazardReports: hazards ?? Stream.value(const []),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> selectDestination(WidgetTester tester) async {
    final map = tester.widget<fm.FlutterMap>(find.byType(fm.FlutterMap));
    map.options.onTap!(
      const fm.TapPosition(Offset.zero, Offset.zero),
      destination,
    );
    await tester.pump();
  }

  Future<void> calculate(WidgetTester tester) async {
    final action = find.byKey(const ValueKey('safe-navigation-find-route'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('initial page renders', (tester) async {
    await pumpPage(tester);

    expect(find.text('Safe Navigation'), findsOneWidget);
    expect(find.text('Plan a Safe Route'), findsOneWidget);
    expect(find.text('Current Location'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
    expect(find.byType(fm.FlutterMap), findsOneWidget);
  });

  testWidgets('shows loading while obtaining current location', (tester) async {
    final positionCompleter = Completer<Position>();
    await pumpPage(tester, locationLoader: () => positionCompleter.future);

    expect(find.text('Finding current location…'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('safe-navigation-find-route')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('map tap selects one destination and enables route action', (
    tester,
  ) async {
    await pumpPage(tester);

    var button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('safe-navigation-find-route')),
    );
    expect(button.onPressed, isNull);

    await selectDestination(tester);

    expect(find.textContaining('Destination selected'), findsOneWidget);
    final markerLayer = tester.widget<fm.MarkerLayer>(
      find.byType(fm.MarkerLayer),
    );
    expect(
      markerLayer.markers.any((marker) => marker.point == destination),
      isTrue,
    );
    button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('safe-navigation-find-route')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('successful route renders provider-backed summary', (
    tester,
  ) async {
    await pumpPage(tester, hazards: Stream.value([hazard()]));
    await selectDestination(tester);
    await calculate(tester);

    expect(find.text('Safe Route'), findsOneWidget);
    expect(find.text('8.1 km'), findsOneWidget);
    expect(find.text('16 min'), findsOneWidget);
    expect(find.text('1 verified hazard avoided'), findsOneWidget);
    expect(find.text('Choose Another Destination'), findsOneWidget);
  });

  testWidgets('SafeRoute geometry becomes the flutter_map road polyline', (
    tester,
  ) async {
    final expected = route();
    await pumpPage(
      tester,
      routeCalculator:
          ({required start, required destination, required hazards}) async =>
              expected,
    );
    await selectDestination(tester);
    await calculate(tester);

    final layer = tester.widget<fm.PolylineLayer>(
      find.byKey(const ValueKey('safe-navigation-route-layer')),
    );
    expect(layer.polylines, hasLength(1));
    expect(layer.polylines.single.points, orderedEquals(expected.geometry));
  });

  testWidgets('Verified hazards render SafetyConfig-backed avoidance circles', (
    tester,
  ) async {
    await pumpPage(tester, hazards: Stream.value([hazard()]));

    final circleLayer = tester.widget<fm.CircleLayer>(
      find.byType(fm.CircleLayer),
    );
    expect(circleLayer.circles, hasLength(1));
    expect(circleLayer.circles.single.radius, 500);
    expect(circleLayer.circles.single.useRadiusInMeter, isTrue);
  });

  testWidgets('non-Verified reports are neither rendered nor routed', (
    tester,
  ) async {
    late List<HazardReport> routedHazards;
    final reports = [
      hazard(id: 'verified'),
      hazard(id: 'pending', status: HazardReportStatus.pendingReview),
      hazard(id: 'rejected', status: HazardReportStatus.rejected),
      hazard(id: 'resolved', status: HazardReportStatus.resolved),
    ];
    await pumpPage(
      tester,
      hazards: Stream.value(reports),
      routeCalculator:
          ({required start, required destination, required hazards}) async {
            routedHazards = hazards;
            return route(avoidedIds: hazards.map((item) => item.id));
          },
    );
    await selectDestination(tester);
    await calculate(tester);

    final circles = tester.widget<fm.CircleLayer>(find.byType(fm.CircleLayer));
    expect(circles.circles, hasLength(1));
    expect(routedHazards.map((item) => item.id), ['verified']);
  });

  testWidgets(
    'shows warning when current location is inside verified hazard but allows route calculation',
    (tester) async {
      final containingHazard = hazard(
        id: 'containing-hazard',
        latitude: start.latitude,
        longitude: start.longitude,
      );

      await pumpPage(tester, hazards: Stream.value([containingHazard]));

      expect(
        find.byKey(const ValueKey('safe-navigation-start-inside-warning')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Your current location is inside a verified hazard area.',
        ),
        findsOneWidget,
      );

      await selectDestination(tester);
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('safe-navigation-find-route')),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'successful escape route renders escape notices and updated summary',
    (tester) async {
      final containingHazard = hazard(
        id: 'containing-hazard',
        latitude: start.latitude,
        longitude: start.longitude,
      );

      await pumpPage(
        tester,
        hazards: Stream.value([containingHazard]),
        routeCalculator:
            ({required start, required destination, required hazards}) async =>
                route(
                  avoidedIds: ['containing-hazard'],
                  startedInsideHazard: true,
                  escapeHazardIds: ['containing-hazard'],
                ),
      );
      await selectDestination(tester);
      await calculate(tester);

      expect(find.text('Escape-First Safe Route'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('safe-navigation-escape-notice')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Starting inside hazard — route first exits the affected area.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Escape segment included'), findsOneWidget);
    },
  );

  final routingFailures = <(String, SafeRoutingFailureCode, String)>[
    (
      'start inside hazard',
      SafeRoutingFailureCode.startInsideHazard,
      'Your current location is inside a verified hazard area.',
    ),
    (
      'destination inside hazard',
      SafeRoutingFailureCode.destinationInsideHazard,
      'The selected destination is inside a verified hazard area.',
    ),
    (
      'missing API key',
      SafeRoutingFailureCode.missingApiKey,
      'Safe routing is not configured.',
    ),
    (
      'network error',
      SafeRoutingFailureCode.networkFailure,
      'The routing service could not be reached.',
    ),
    (
      'no route',
      SafeRoutingFailureCode.noRoute,
      'No hazard-avoiding route could be found',
    ),
  ];

  for (final (name, code, expectedText) in routingFailures) {
    testWidgets('$name displays a controlled message', (tester) async {
      await pumpPage(
        tester,
        routeCalculator:
            ({required start, required destination, required hazards}) async {
              throw SafeRoutingException(code: code, message: 'technical');
            },
      );
      await selectDestination(tester);
      await calculate(tester);

      expect(find.textContaining(expectedText), findsOneWidget);
      expect(
        find.byKey(const ValueKey('safe-navigation-routing-error')),
        findsOneWidget,
      );
      expect(find.textContaining('technical'), findsNothing);
    });
  }

  testWidgets('location access failure is recoverable and user-facing', (
    tester,
  ) async {
    await pumpPage(
      tester,
      locationLoader: () async => throw const LocationAccessException(
        'Allow location access in device settings, then retry.',
      ),
    );

    expect(
      find.textContaining('Allow location access in device settings'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('safe-navigation-retry-location')),
      findsOneWidget,
    );
  });

  testWidgets(
    'SafeNavigationPage uses the canonical SafeRoutingService by default',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SafeNavigationPage(
            locationLoader: () async => position(),
            hazardReports: Stream.value(const []),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(SafeNavigationPage));
      final routingService = (state as dynamic).routingService;
      expect(routingService, isNotNull);
      expect(routingService, isA<SafeRoutingService>());
      expect(
        routingService.apiKey,
        SafeRoutingService.defaultEnvironmentApiKey,
      );
    },
  );

  testWidgets(
    'SafeNavigationPage supports injecting custom SafeRoutingService',
    (tester) async {
      final customService = SafeRoutingService(apiKey: 'custom-test-key');
      await tester.pumpWidget(
        MaterialApp(
          home: SafeNavigationPage(
            locationLoader: () async => position(),
            routingService: customService,
            hazardReports: Stream.value(const []),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(SafeNavigationPage));
      final routingService = (state as dynamic).routingService;
      expect(routingService, same(customService));
      expect(routingService.apiKey, 'custom-test-key');
    },
  );

  for (final (width, scale, label) in [
    (390.0, 1.0, '390px mobile'),
    (1200.0, 1.0, '1200px desktop'),
    (390.0, 2.0, '200% text scale'),
  ]) {
    testWidgets('$label layout has no overflow after route success', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await pumpPage(
        tester,
        textScale: scale,
        hazards: Stream.value([hazard()]),
      );
      await selectDestination(tester);
      await calculate(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Safe Route'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('safe-navigation-choose-another-destination'),
        ),
        findsOneWidget,
      );
    });
  }

  group('Phase 2.2–2.5: SafeNavigationPage multi-stop and search UI', () {
    testWidgets('multiple map taps add ordered stops and display stop items', (
      tester,
    ) async {
      await pumpPage(tester);

      final map = tester.widget<fm.FlutterMap>(find.byType(fm.FlutterMap));
      map.options.onTap!(
        const fm.TapPosition(Offset.zero, Offset.zero),
        const LatLng(5.43, 100.32),
      );
      await tester.pump();
      map.options.onTap!(
        const fm.TapPosition(Offset.zero, Offset.zero),
        const LatLng(5.44, 100.33),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('safe-navigation-stop-item-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('safe-navigation-stop-item-1')),
        findsOneWidget,
      );
      expect(find.textContaining('Final Destination:'), findsOneWidget);
      expect(find.textContaining('2 stops'), findsOneWidget);
    });

    testWidgets('up and down arrow buttons reorder stops in list', (
      tester,
    ) async {
      await pumpPage(tester);

      final map = tester.widget<fm.FlutterMap>(find.byType(fm.FlutterMap));
      map.options.onTap!(
        const fm.TapPosition(Offset.zero, Offset.zero),
        const LatLng(5.43, 100.32),
      );
      await tester.pump();
      map.options.onTap!(
        const fm.TapPosition(Offset.zero, Offset.zero),
        const LatLng(5.44, 100.33),
      );
      await tester.pump();

      final state = tester.state(find.byType(SafeNavigationPage));
      expect((state as dynamic).stops[0].location, const LatLng(5.43, 100.32));
      expect((state as dynamic).stops[1].location, const LatLng(5.44, 100.33));

      final moveUpAction = find.byKey(
        const ValueKey('safe-navigation-stop-up-1'),
      );
      await tester.ensureVisible(moveUpAction);
      await tester.tap(moveUpAction);
      await tester.pump();

      expect((state as dynamic).stops[0].location, const LatLng(5.44, 100.33));
      expect((state as dynamic).stops[1].location, const LatLng(5.43, 100.32));
    });

    testWidgets('remove button deletes stop from list', (tester) async {
      await pumpPage(tester);

      final map = tester.widget<fm.FlutterMap>(find.byType(fm.FlutterMap));
      map.options.onTap!(
        const fm.TapPosition(Offset.zero, Offset.zero),
        const LatLng(5.43, 100.32),
      );
      await tester.pump();
      map.options.onTap!(
        const fm.TapPosition(Offset.zero, Offset.zero),
        const LatLng(5.44, 100.33),
      );
      await tester.pump();

      final removeAction = find.byKey(
        const ValueKey('safe-navigation-stop-remove-0'),
      );
      await tester.ensureVisible(removeAction);
      await tester.tap(removeAction);
      await tester.pump();

      final state = tester.state(find.byType(SafeNavigationPage));
      expect((state as dynamic).stops, hasLength(1));
      expect((state as dynamic).stops[0].location, const LatLng(5.44, 100.33));
      expect((state as dynamic).stops[0].isDestination, isTrue);
    });

    testWidgets('route calculation renders legs and risk level badge', (
      tester,
    ) async {
      final multiRoute = SafeRoute(
        geometry: const [start, LatLng(5.43, 100.33), LatLng(5.44, 100.34)],
        distanceMeters: 6200,
        durationSeconds: 720,
        steps: const [],
        riskLevel: RouteRiskLevel.lowRisk,
        crossedHazardIds: const ['hz-low'],
        legs: [
          RouteLeg(
            startStopName: 'Current Location',
            endStopName: 'Aman Central',
            startLocation: start,
            endLocation: const LatLng(5.43, 100.33),
            distanceMeters: 2500,
            durationSeconds: 300,
            steps: const [],
          ),
          RouteLeg(
            startStopName: 'Aman Central',
            endStopName: 'Alor Setar Tower',
            startLocation: const LatLng(5.43, 100.33),
            endLocation: const LatLng(5.44, 100.34),
            distanceMeters: 3700,
            durationSeconds: 420,
            steps: const [],
          ),
        ],
      );

      await pumpPage(
        tester,
        multiStopRouteCalculator:
            ({required start, required stops, required hazards}) async =>
                multiRoute,
      );

      final map = tester.widget<fm.FlutterMap>(find.byType(fm.FlutterMap));
      map.options.onTap!(
        const fm.TapPosition(Offset.zero, Offset.zero),
        const LatLng(5.43, 100.33),
      );
      await tester.pump();
      map.options.onTap!(
        const fm.TapPosition(Offset.zero, Offset.zero),
        const LatLng(5.44, 100.34),
      );
      await tester.pump();

      await calculate(tester);

      expect(
        find.byKey(const ValueKey('safe-navigation-risk-badge')),
        findsOneWidget,
      );
      expect(find.textContaining('Level 2: Low-Risk Fallback'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('safe-navigation-crossed-warning')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('safe-navigation-leg-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('safe-navigation-leg-1')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Current Location → Aman Central'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Aman Central → Alor Setar Tower'),
        findsOneWidget,
      );
    });
  });

  group('Step 3: live navigation UI', () {
    testWidgets(
      'Start Navigation subscribes and live marker moves with heading',
      (tester) async {
        var listenCount = 0;
        final positions = StreamController<Position>(
          sync: true,
          onListen: () => listenCount++,
        );
        final navigationController = NavigationSessionController(
          ensureLocationAccess: () async {},
          positionStream: () => positions.stream,
        );
        addTearDown(() async {
          navigationController.dispose();
          await positions.close();
        });

        await pumpPage(tester, navigationController: navigationController);
        await selectDestination(tester);
        await calculate(tester);

        final startAction = find.byKey(
          const ValueKey('safe-navigation-start-navigation'),
        );
        await tester.ensureVisible(startAction);
        await tester.tap(startAction);
        await tester.pump();

        expect(listenCount, 1);
        expect(find.text('Navigation Active'), findsOneWidget);
        expect(navigationController.state.isFollowingUser, isTrue);

        final update = Position(
          latitude: 5.426,
          longitude: 100.337,
          timestamp: DateTime.now(),
          accuracy: 10,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 90,
          headingAccuracy: 5,
          speed: 4,
          speedAccuracy: 1,
        );
        positions.add(update);
        await tester.pump();

        final markerLayer = tester.widget<fm.MarkerLayer>(
          find.byType(fm.MarkerLayer),
        );
        expect(
          markerLayer.markers.any(
            (marker) => marker.point == const LatLng(5.426, 100.337),
          ),
          isTrue,
        );
        final markerRotation = tester.widget<Transform>(
          find.byKey(const ValueKey('safe-navigation-live-marker')),
        );
        expect(markerRotation.transform.entry(0, 0), closeTo(0, 0.001));
        expect(markerRotation.transform.entry(1, 0), closeTo(1, 0.001));
      },
    );

    testWidgets('End Navigation cancels tracking and keeps the route preview', (
      tester,
    ) async {
      var cancelCount = 0;
      final positions = StreamController<Position>(
        sync: true,
        onCancel: () => cancelCount++,
      );
      final navigationController = NavigationSessionController(
        ensureLocationAccess: () async {},
        positionStream: () => positions.stream,
      );
      addTearDown(() async {
        navigationController.dispose();
        await positions.close();
      });

      await pumpPage(tester, navigationController: navigationController);
      await selectDestination(tester);
      await calculate(tester);
      final expectedGeometry = route().geometry;
      final startAction = find.byKey(
        const ValueKey('safe-navigation-start-navigation'),
      );
      await tester.ensureVisible(startAction);
      await tester.tap(startAction);
      await tester.pump();

      final endAction = find.byKey(
        const ValueKey('safe-navigation-end-navigation'),
      );
      await tester.ensureVisible(endAction);
      await tester.tap(endAction);
      await tester.pump();

      expect(cancelCount, 1);
      expect(navigationController.state.isNavigating, isFalse);
      expect(
        find.byKey(const ValueKey('safe-navigation-route-layer')),
        findsOneWidget,
      );
      final layer = tester.widget<fm.PolylineLayer>(
        find.byKey(const ValueKey('safe-navigation-route-layer')),
      );
      expect(layer.polylines.single.points, orderedEquals(expectedGeometry));
    });

    testWidgets('map gesture disables follow and recenter restores it', (
      tester,
    ) async {
      final positions = StreamController<Position>(sync: true);
      final navigationController = NavigationSessionController(
        ensureLocationAccess: () async {},
        positionStream: () => positions.stream,
      );
      addTearDown(() async {
        navigationController.dispose();
        await positions.close();
      });

      await pumpPage(tester, navigationController: navigationController);
      await selectDestination(tester);
      await calculate(tester);
      final startAction = find.byKey(
        const ValueKey('safe-navigation-start-navigation'),
      );
      await tester.ensureVisible(startAction);
      await tester.tap(startAction);
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('safe-navigation-map')),
        const Offset(80, 0),
      );
      await tester.pump();
      expect(navigationController.state.isFollowingUser, isFalse);

      final recenter = find.byKey(
        const ValueKey('safe-navigation-recenter-button'),
      );
      await tester.tap(recenter);
      await tester.pump();
      expect(navigationController.state.isFollowingUser, isTrue);
    });
  });
}
