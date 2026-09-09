import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:myheritage_explorer/core/app_theme.dart';
import 'package:myheritage_explorer/models/hazard_audit_entry.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/models/navigation_stop.dart';
import 'package:myheritage_explorer/services/hazard_address_resolver.dart';
import 'package:myheritage_explorer/services/hazard_report_service.dart';
import 'package:myheritage_explorer/services/location_service.dart';
import 'package:myheritage_explorer/services/place_geocoding_service.dart';
import 'package:myheritage_explorer/traveler/traveler_pages.dart';
import 'package:myheritage_explorer/widgets/safety_image_viewer.dart';

class _MockReportService implements HazardReportService {
  _MockReportService(this.report);
  final HazardReport? report;

  @override
  Stream<HazardReport?> watchReport(String id) => Stream.value(report);

  @override
  Stream<List<HazardAuditEntry>> watchAuditTrail(String id) =>
      Stream.value(const []);

  @override
  Future<HazardReport?> getReport(String id) async => report;

  @override
  Stream<List<HazardReport>> watchVerifiedReports() =>
      Stream.value(report == null ? [] : [report!]);

  @override
  Stream<List<HazardReport>> watchVerifiedUnresolvedReports() =>
      Stream.value(report == null ? [] : [report!]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockLocationService extends LocationService {
  _MockLocationService({this.mockPosition, this.shouldThrow = false});

  final Position? mockPosition;
  final bool shouldThrow;

  @override
  Future<Position> getCurrentPosition() async {
    if (shouldThrow) {
      throw const LocationAccessException(
        'Location access denied',
        code: LocationAccessFailure.denied,
      );
    }
    if (mockPosition != null) {
      return mockPosition!;
    }
    return Position(
      latitude: 5.4300,
      longitude: 100.3100,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    // If testing ~1.4 km:
    return 1400.0;
  }
}

class _MockGeocodingService extends PlaceGeocodingService {
  _MockGeocodingService({
    this.displayName = 'Jalan Tanjung Tokong',
    this.address = 'George Town, Penang',
    this.shouldFail = false,
  });

  final String displayName;
  final String? address;
  final bool shouldFail;

  @override
  Future<NavigationStop> reverseGeocode(latlng.LatLng location) async {
    if (shouldFail) {
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
    return NavigationStop(
      id: 'stop_mock_123',
      location: location,
      displayName: displayName,
      address: address,
    );
  }
}

HazardReport _sampleHazard({
  String id = 'DEMO-H02',
  double latitude = 5.44140,
  double longitude = 100.30685,
  String category = 'Fallen tree branch',
  String severity = 'High',
  String description =
      'Large branch blocking pedestrian walkway in Tanjung Tokong.',
  bool hasPhoto = false,
  String? imageUrl,
}) {
  return HazardReport(
    id: id,
    userId: 'user_123',
    category: category,
    severity: severity,
    description: description,
    latitude: latitude,
    longitude: longitude,
    status: HazardReportStatus.verified,
    hasPhotoEvidence: hasPhoto || (imageUrl != null && imageUrl.isNotEmpty),
    imageUrl: imageUrl,
  );
}

Widget _wrapDetailPage({
  Key? key,
  required HazardReport report,
  LocationService? locationService,
  PlaceGeocodingService? geocodingService,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: HazardDetailPage(
      key: key,
      hazardId: report.id,
      reportService: _MockReportService(report),
      locationService: locationService,
      geocodingService: geocodingService,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  setUp(() {
    HazardAddressResolver.clearCache();
  });

  group('Final Safety Location UX Improvement (Requirements 1–12)', () {
    testWidgets('1. Valid hazard coordinates show location section', (
      tester,
    ) async {
      final report = _sampleHazard();
      await tester.pumpWidget(
        _wrapDetailPage(
          report: report,
          locationService: _MockLocationService(shouldThrow: true),
          geocodingService: _MockGeocodingService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location'), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.textContaining('5.44140, 100.30685'), findsOneWidget);
    });

    testWidgets('2. Successful reverse geocode shows human-readable address', (
      tester,
    ) async {
      final report = _sampleHazard();
      await tester.pumpWidget(
        _wrapDetailPage(
          report: report,
          locationService: _MockLocationService(shouldThrow: true),
          geocodingService: _MockGeocodingService(
            displayName: 'Jalan Tanjung Tokong',
            address: 'George Town, Penang',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jalan Tanjung Tokong'), findsOneWidget);
      expect(find.text('George Town, Penang'), findsOneWidget);
      expect(find.textContaining('5.44140, 100.30685'), findsOneWidget);
    });

    testWidgets(
      '3. Reverse-geocode failure displays "Location name unavailable" as primary',
      (tester) async {
        final report = _sampleHazard();
        await tester.pumpWidget(
          _wrapDetailPage(
            report: report,
            locationService: _MockLocationService(shouldThrow: true),
            geocodingService: _MockGeocodingService(shouldFail: true),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Location'), findsOneWidget);
        expect(find.text('Location name unavailable'), findsOneWidget);
        expect(find.textContaining('5.44140, 100.30685'), findsOneWidget);
      },
    );

    testWidgets('4. Hazard marker is displayed on map with severity styling', (
      tester,
    ) async {
      final report = _sampleHazard(severity: 'High');
      await tester.pumpWidget(
        _wrapDetailPage(
          report: report,
          locationService: _MockLocationService(shouldThrow: true),
          geocodingService: _MockGeocodingService(),
        ),
      );
      await tester.pumpAndSettle();

      final hazardMarkerFinder = find.byKey(
        const ValueKey('hazard_map_marker'),
      );
      expect(hazardMarkerFinder, findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
    });

    testWidgets('5. Current-user marker is displayed when GPS available', (
      tester,
    ) async {
      final report = _sampleHazard();
      await tester.pumpWidget(
        _wrapDetailPage(
          report: report,
          locationService: _MockLocationService(
            mockPosition: Position(
              latitude: 5.4300,
              longitude: 100.3100,
              timestamp: DateTime.now(),
              accuracy: 5.0,
              altitude: 0.0,
              altitudeAccuracy: 0.0,
              heading: 0.0,
              headingAccuracy: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
            ),
          ),
          geocodingService: _MockGeocodingService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('user_location_marker')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('hazard_map_marker')), findsOneWidget);
    });

    testWidgets(
      '6. Current-location failure still displays hazard marker and address',
      (tester) async {
        final report = _sampleHazard();
        await tester.pumpWidget(
          _wrapDetailPage(
            report: report,
            locationService: _MockLocationService(shouldThrow: true),
            geocodingService: _MockGeocodingService(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('hazard_map_marker')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('user_location_marker')),
          findsNothing,
        );
        expect(find.text('Current location unavailable'), findsOneWidget);
        expect(find.text('Jalan Tanjung Tokong'), findsOneWidget);
      },
    );

    testWidgets(
      '7. Both markers use distinct visual identities and legend exists',
      (tester) async {
        final report = _sampleHazard();
        await tester.pumpWidget(
          _wrapDetailPage(
            report: report,
            locationService: _MockLocationService(),
            geocodingService: _MockGeocodingService(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('hazard_map_marker')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('user_location_marker')),
          findsOneWidget,
        );
        expect(find.text('You'), findsOneWidget);
        expect(find.text('Hazard'), findsOneWidget);
      },
    );

    testWidgets('8. Distance displayed when both positions exist', (
      tester,
    ) async {
      final report = _sampleHazard();
      await tester.pumpWidget(
        _wrapDetailPage(
          report: report,
          locationService: _MockLocationService(),
          geocodingService: _MockGeocodingService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1.4 km from your current location'), findsOneWidget);
      expect(find.byIcon(Icons.near_me_outlined), findsOneWidget);
    });

    testWidgets('9. No distance displayed when user position unavailable', (
      tester,
    ) async {
      final report = _sampleHazard();
      await tester.pumpWidget(
        _wrapDetailPage(
          report: report,
          locationService: _MockLocationService(shouldThrow: true),
          geocodingService: _MockGeocodingService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('from your current location'), findsNothing);
      expect(find.byIcon(Icons.near_me_outlined), findsNothing);
      expect(find.text('Current location unavailable'), findsOneWidget);
    });

    testWidgets('10. Invalid hazard coordinates handled safely', (
      tester,
    ) async {
      final report = _sampleHazard(latitude: 95.0, longitude: 100.3288);
      await tester.pumpWidget(
        _wrapDetailPage(
          report: report,
          locationService: _MockLocationService(),
          geocodingService: _MockGeocodingService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('Location unavailable'), findsOneWidget);
      expect(find.byIcon(Icons.location_off_outlined), findsOneWidget);
    });

    testWidgets(
      '11. Existing image enlargement affordance works on photo reports',
      (tester) async {
        final report = _sampleHazard(
          imageUrl: 'https://example.com/demo_branch.jpg',
        );
        await tester.pumpWidget(
          _wrapDetailPage(
            report: report,
            locationService: _MockLocationService(shouldThrow: true),
            geocodingService: _MockGeocodingService(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Report evidence card should render with enlargement affordance
        expect(find.byType(ExpandableEvidenceImage), findsOneWidget);
        expect(find.text('Enlarge'), findsOneWidget);
      },
    );

    testWidgets(
      '12. In-memory address cache prevents redundant reverse geocode calls',
      (tester) async {
        var callCount = 0;
        final countingGeocoder = _CountingGeocodingService(
          onCall: () => callCount++,
        );

        final details1 = await HazardAddressResolver.resolve(
          latitude: 5.44140,
          longitude: 100.30685,
          geocodingService: countingGeocoder,
        );
        expect(callCount, 1);
        expect(details1.primaryName, 'Jalan Tanjung Tokong');

        // Second resolve for same coordinates should hit cache
        final details2 = await HazardAddressResolver.resolve(
          latitude: 5.44140,
          longitude: 100.30685,
          geocodingService: countingGeocoder,
        );
        expect(callCount, 1); // Still 1
        expect(details2.primaryName, 'Jalan Tanjung Tokong');
      },
    );

    testWidgets(
      '13. Coordinates are never shown independently as primary location info',
      (tester) async {
        final report = _sampleHazard(latitude: 5.44140, longitude: 100.30685);
        await tester.pumpWidget(
          _wrapDetailPage(
            report: report,
            locationService: _MockLocationService(shouldThrow: true),
            geocodingService: _MockGeocodingService(
              displayName: 'Jalan Tanjung Tokong',
              address: 'George Town, Penang',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Primary is human-readable name, secondary is coordinates
        expect(find.text('Jalan Tanjung Tokong'), findsOneWidget);
        expect(find.text('George Town, Penang'), findsOneWidget);
        expect(find.textContaining('5.44140, 100.30685'), findsOneWidget);

        // Fallback case: when geocoding fails, primary is 'Location name unavailable'
        HazardAddressResolver.clearCache();
        await tester.pumpWidget(
          _wrapDetailPage(
            key: const ValueKey('fallback_detail_page'),
            report: report,
            locationService: _MockLocationService(shouldThrow: true),
            geocodingService: _MockGeocodingService(shouldFail: true),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Location name unavailable'), findsOneWidget);
        expect(find.textContaining('5.44140, 100.30685'), findsOneWidget);
      },
    );
  });
}

class _CountingGeocodingService extends PlaceGeocodingService {
  _CountingGeocodingService({required this.onCall});
  final VoidCallback onCall;

  @override
  Future<NavigationStop> reverseGeocode(latlng.LatLng location) async {
    onCall();
    return NavigationStop(
      id: 'stop_counting',
      location: location,
      displayName: 'Jalan Tanjung Tokong',
      address: 'George Town, Penang',
    );
  }
}
