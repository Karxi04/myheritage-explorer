import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:myheritage_explorer/core/safety_config.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/models/navigation_stop.dart';
import 'package:myheritage_explorer/models/safe_route.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/hazard_proximity_controller.dart';
import 'package:myheritage_explorer/traveler/safety/navigation/navigation_session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const origin = LatLng(5.42, 100.34);
  const destination = LatLng(5.43, 100.35);

  HazardReport hazard({
    String id = 'hazard',
    String severity = 'High',
    String status = HazardReportStatus.verified,
    double latitude = 5.421,
    double longitude = 100.341,
  }) => HazardReport(
    id: id,
    userId: 'reporter',
    category: 'Structural Hazard',
    severity: severity,
    description: 'Unstable scaffolding reported nearby.',
    latitude: latitude,
    longitude: longitude,
    status: status,
  );

  SafeRoute route({
    Iterable<String> crossedHazardIds = const [],
    bool startedInsideHazard = false,
  }) => SafeRoute(
    geometry: const [origin, destination],
    distanceMeters: 1500,
    durationSeconds: 300,
    steps: const [],
    crossedHazardIds: crossedHazardIds,
    startedInsideHazard: startedInsideHazard,
  );

  const stops = [
    NavigationStop(
      id: 'destination',
      location: destination,
      displayName: 'Destination',
      isDestination: true,
    ),
  ];

  Position position() => Position(
    latitude: origin.latitude,
    longitude: origin.longitude,
    timestamp: DateTime.now(),
    accuracy: 8,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 1,
    speedAccuracy: 0,
  );

  group('HazConfig', () {
    test('warning buffers preserve danger radii', () {
      expect(SafetyConfig.dangerRadiusForSeverity('High'), 500);
      expect(SafetyConfig.dangerRadiusForSeverity('Medium'), 300);
      expect(SafetyConfig.dangerRadiusForSeverity('Low'), 150);
      expect(SafetyConfig.warningRadiusForSeverity('High'), 600);
      expect(SafetyConfig.warningRadiusForSeverity('Medium'), 400);
      expect(SafetyConfig.warningRadiusForSeverity('Low'), 200);
      expect(
        SafetyConfig.navigationHazardAlertDuration,
        const Duration(seconds: 3),
      );
    });
  });

  group('HazardProximityController', () {
    late StreamController<Position> positions;
    late NavigationSessionController navigation;
    late HazardProximityController monitor;
    late Map<String, double> distances;
    late DateTime clock;

    setUp(() {
      positions = StreamController<Position>.broadcast(sync: true);
      navigation = NavigationSessionController(
        ensureLocationAccess: () async {},
        positionStream: () => positions.stream,
      );
      distances = {};
      clock = DateTime(2026, 9, 8, 12);
      monitor = HazardProximityController(
        navigationController: navigation,
        distanceCalculator: (_, report) => distances[report.id]!,
        now: () => clock,
        prominentAlertDuration: const Duration(minutes: 1),
      );
    });

    tearDown(() async {
      monitor.dispose();
      navigation.dispose();
      await positions.close();
    });

    Future<void> start({
      SafeRoute? activeRoute,
      LatLng? initialPosition = origin,
    }) async {
      await navigation.start(
        route: activeRoute ?? route(),
        stops: stops,
        initialPosition: initialPosition,
      );
    }

    void updateDistance(String id, double distance) {
      distances[id] = distance;
      positions.add(position());
    }

    test('no alert outside warning threshold', () async {
      distances['hazard'] = 601;
      monitor.updateHazards([hazard()]);
      await start();

      expect(monitor.primaryProximity, isNull);
      expect(monitor.prominentAlert, isNull);
      expect(monitor.proximities.single.state, HazardZoneState.safe);
    });

    for (final entry in const {
      'High': 550.0,
      'Medium': 350.0,
      'Low': 175.0,
    }.entries) {
      test('${entry.key} hazard approaching triggers alert', () async {
        distances['hazard'] = entry.value;
        monitor.updateHazards([hazard(severity: entry.key)]);
        await start();

        expect(monitor.prominentAlert?.state, HazardZoneState.approaching);
        expect(monitor.primaryProximity?.hazard.severity, entry.key);
      });
    }

    test('inside hazard triggers stronger state', () async {
      distances['hazard'] = 499;
      monitor.updateHazards([hazard()]);
      await start();

      expect(monitor.prominentAlert?.state, HazardZoneState.inside);
    });

    test('starting navigation inside alerts immediately', () async {
      distances['hazard'] = 20;
      monitor.updateHazards([hazard()]);

      await start(activeRoute: route(startedInsideHazard: true));

      expect(monitor.prominentAlert?.state, HazardZoneState.inside);
      expect(navigation.state.route?.startedInsideHazard, isTrue);
      expect(navigation.state.isNavigating, isTrue);
    });

    for (final status in const [
      HazardReportStatus.pendingReview,
      HazardReportStatus.rejected,
      HazardReportStatus.resolved,
    ]) {
      test('$status hazard does not alert', () async {
        distances['hazard'] = 10;
        monitor.updateHazards([hazard(status: status)]);
        await start();

        expect(monitor.proximities, isEmpty);
        expect(monitor.prominentAlert, isNull);
      });
    }

    test('Verified hazard alerts and retains notification payload', () async {
      distances['hazard'] = 550;
      monitor.updateHazards([hazard()]);
      await start(activeRoute: route(crossedHazardIds: const ['hazard']));

      final proximity = monitor.prominentAlert!;
      expect(proximity.hazard.status, HazardReportStatus.verified);
      expect(proximity.isOnCurrentRoute, isTrue);
      expect(proximity.notificationPayload.hazardId, 'hazard');
      expect(proximity.notificationPayload.category, 'Structural Hazard');
    });

    test('inside is prioritized over approaching', () async {
      distances.addAll({'inside': 100, 'approaching': 550});
      monitor.updateHazards([
        hazard(id: 'approaching'),
        hazard(id: 'inside', severity: 'Low'),
      ]);
      await start();

      expect(monitor.primaryProximity?.hazard.id, 'inside');
      expect(monitor.prominentAlert?.hazard.id, 'inside');
      expect(monitor.relevantProximities, hasLength(2));
    });

    test('High is prioritized over Medium and Low', () async {
      distances.addAll({'high': 550, 'medium': 350, 'low': 175});
      monitor.updateHazards([
        hazard(id: 'low', severity: 'Low'),
        hazard(id: 'medium', severity: 'Medium'),
        hazard(id: 'high'),
      ]);
      await start();

      expect(monitor.primaryProximity?.hazard.id, 'high');
      expect(monitor.relevantProximities.map((item) => item.hazard.id), [
        'high',
        'medium',
        'low',
      ]);
      expect(monitor.prominentAlert?.hazard.id, 'high');
    });

    test('nearest same-severity hazard is prioritized', () async {
      distances.addAll({'far': 590, 'near': 510});
      monitor.updateHazards([hazard(id: 'far'), hazard(id: 'near')]);
      await start();

      expect(monitor.primaryProximity?.hazard.id, 'near');
    });

    test(
      'same hazard and state does not replace alert on GPS updates',
      () async {
        distances['hazard'] = 550;
        monitor.updateHazards([hazard()]);
        await start();
        final originalAlert = monitor.prominentAlert;

        updateDistance('hazard', 540);
        updateDistance('hazard', 530);

        expect(identical(monitor.prominentAlert, originalAlert), isTrue);
      },
    );

    test('approaching to inside triggers an immediate escalation', () async {
      distances['hazard'] = 550;
      monitor.updateHazards([hazard()]);
      await start();
      final approachingAlert = monitor.prominentAlert;

      updateDistance('hazard', 490);

      expect(monitor.prominentAlert?.state, HazardZoneState.inside);
      expect(identical(monitor.prominentAlert, approachingAlert), isFalse);
    });

    test('leaving warning zone clears indicator and visible alert', () async {
      distances['hazard'] = 550;
      monitor.updateHazards([hazard()]);
      await start();

      updateDistance('hazard', 601);

      expect(monitor.primaryProximity, isNull);
      expect(monitor.prominentAlert, isNull);
      expect(monitor.hazardsThatLeftWarningZone, contains('hazard'));
    });

    test(
      'leaving then re-entering allows a new alert before cooldown',
      () async {
        distances['hazard'] = 550;
        monitor.updateHazards([hazard()]);
        await start();
        final first = monitor.prominentAlert;

        updateDistance('hazard', 650);
        updateDistance('hazard', 550);

        expect(monitor.prominentAlert, isNotNull);
        expect(identical(monitor.prominentAlert, first), isFalse);
      },
    );

    test('cooldown allows a same-state repeat', () async {
      distances['hazard'] = 550;
      monitor.updateHazards([hazard()]);
      await start();
      final first = monitor.prominentAlert;
      monitor.dismissProminentAlert();

      clock = clock.add(SafetyConfig.navigationHazardAlertCooldown);
      updateDistance('hazard', 540);

      expect(monitor.prominentAlert, isNotNull);
      expect(identical(monitor.prominentAlert, first), isFalse);
    });

    test('dismiss keeps persistent proximity and monitoring active', () async {
      distances['hazard'] = 550;
      monitor.updateHazards([hazard()]);
      await start();

      monitor.dismissProminentAlert();

      expect(monitor.prominentAlert, isNull);
      expect(monitor.primaryProximity?.hazard.id, 'hazard');
      updateDistance('hazard', 490);
      expect(monitor.prominentAlert?.state, HazardZoneState.inside);
    });

    test('resolved primary clears and next hazard is re-evaluated', () async {
      distances.addAll({'high': 550, 'medium': 350});
      monitor.updateHazards([
        hazard(id: 'high'),
        hazard(id: 'medium', severity: 'Medium'),
      ]);
      await start();
      expect(monitor.prominentAlert?.hazard.id, 'high');

      monitor.updateHazards([
        hazard(id: 'high', status: HazardReportStatus.resolved),
        hazard(id: 'medium', severity: 'Medium'),
      ]);

      expect(monitor.primaryProximity?.hazard.id, 'medium');
      expect(monitor.prominentAlert?.hazard.id, 'medium');
    });

    test('invalid hazard coordinates are ignored', () async {
      distances['invalid'] = 1;
      monitor.updateHazards([hazard(id: 'invalid', latitude: double.nan)]);
      await start();

      expect(monitor.proximities, isEmpty);
    });

    test('GPS unavailable does not crash or alert', () async {
      distances['hazard'] = 1;
      monitor.updateHazards([hazard()]);

      await start(initialPosition: null);

      expect(monitor.prominentAlert, isNull);
      expect(monitor.proximities, isEmpty);
    });

    test('hazard load failure can clear state safely', () async {
      distances['hazard'] = 1;
      monitor.updateHazards([hazard()]);
      await start();

      monitor.clearHazards();

      expect(monitor.prominentAlert, isNull);
      expect(monitor.primaryProximity, isNull);
    });

    test(
      'ending navigation clears alerts, timers, and session state',
      () async {
        distances['hazard'] = 1;
        monitor.updateHazards([hazard()]);
        await start();
        expect(monitor.hasProminentTimer, isTrue);

        await navigation.end();

        expect(monitor.prominentAlert, isNull);
        expect(monitor.primaryProximity, isNull);
        expect(monitor.proximities, isEmpty);
        expect(monitor.previousStates, isEmpty);
        expect(monitor.hasProminentTimer, isFalse);
      },
    );

    test(
      'hazard monitoring does not alter route or HUD progress state',
      () async {
        distances['hazard'] = 550;
        monitor.updateHazards([hazard()]);
        final activeRoute = route();
        await start(activeRoute: activeRoute);
        final progress = navigation.state.progress;

        distances['hazard'] = 490;
        monitor.updateHazards([hazard()]);

        expect(identical(navigation.state.route, activeRoute), isTrue);
        expect(identical(navigation.state.progress, progress), isTrue);
        expect(navigation.state.isNavigating, isTrue);
      },
    );
  });

  test('prominent alert auto-dismisses while proximity remains', () async {
    final positions = StreamController<Position>.broadcast(sync: true);
    final navigation = NavigationSessionController(
      ensureLocationAccess: () async {},
      positionStream: () => positions.stream,
    );
    final monitor = HazardProximityController(
      navigationController: navigation,
      distanceCalculator: (_, _) => 550,
      prominentAlertDuration: const Duration(milliseconds: 20),
    );
    monitor.updateHazards([hazard()]);
    await navigation.start(
      route: route(),
      stops: stops,
      initialPosition: origin,
    );
    expect(monitor.prominentAlert, isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(monitor.prominentAlert, isNull);
    expect(monitor.primaryProximity, isNotNull);
    monitor.dispose();
    navigation.dispose();
    await positions.close();
  });
}
