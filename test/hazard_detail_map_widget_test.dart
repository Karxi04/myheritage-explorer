import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/core/app_theme.dart';
import 'package:myheritage_explorer/models/hazard_audit_entry.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/core/safety_config.dart';
import 'package:myheritage_explorer/services/hazard_report_service.dart';
import 'package:myheritage_explorer/traveler/traveler_pages.dart';

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

HazardReport _sampleReport({
  String id = 'sample_hazard_1',
  double latitude = 5.4141,
  double longitude = 100.3288,
  String severity = 'High',
  String category = 'Road obstruction',
  String description =
      'A large fallen tree branch blocks the pedestrian walkway.',
}) {
  return HazardReport(
    id: id,
    userId: 'tourist_user_1',
    category: category,
    severity: severity,
    description: description,
    latitude: latitude,
    longitude: longitude,
    status: HazardReportStatus.verified,
  );
}

Widget _wrapDetailPage({
  required HazardReport report,
  double width = 390,
  double height = 800,
  double scale = 1.0,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: Size(width, height),
        textScaler: TextScaler.linear(scale),
      ),
      child: child!,
    ),
    home: HazardDetailPage(
      hazardId: report.id,
      reportService: _MockReportService(report),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Hazard Details Map Widget Tests (Tests 16–23)', () {
    testWidgets('16. Valid coordinates render map & center', (tester) async {
      final report = _sampleReport(latitude: 5.4141, longitude: 100.3288);
      await tester.pumpWidget(_wrapDetailPage(report: report));
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      final mapWidget = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(mapWidget.options.initialCenter.latitude, 5.4141);
      expect(mapWidget.options.initialCenter.longitude, 100.3288);

      expect(find.byType(RichAttributionWidget), findsOneWidget);
      expect(
        find.textContaining('Approximate report location'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('17. Marker uses actual hazard coordinates', (tester) async {
      final report = _sampleReport(
        latitude: 5.4141,
        longitude: 100.3288,
        severity: 'High',
      );
      await tester.pumpWidget(_wrapDetailPage(report: report));
      await tester.pumpAndSettle();

      final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(markerLayer.markers.length, 1);
      expect(markerLayer.markers.first.point.latitude, 5.4141);
      expect(markerLayer.markers.first.point.longitude, 100.3288);

      final circleLayer = tester.widget<CircleLayer>(find.byType(CircleLayer));
      expect(circleLayer.circles.length, 1);
      expect(circleLayer.circles.first.point.latitude, 5.4141);
      expect(circleLayer.circles.first.point.longitude, 100.3288);
      expect(
        circleLayer.circles.first.radius,
        SafetyConfig.dangerRadiusForSeverity(report.severity),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('18. Invalid latitude handled safely', (tester) async {
      final report = _sampleReport(latitude: 95.0, longitude: 100.3288);
      await tester.pumpWidget(_wrapDetailPage(report: report));
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('Location unavailable'), findsOneWidget);
      expect(find.byIcon(Icons.location_off_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('19. Invalid longitude handled safely', (tester) async {
      final report = _sampleReport(latitude: 5.4141, longitude: 195.0);
      await tester.pumpWidget(_wrapDetailPage(report: report));
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('Location unavailable'), findsOneWidget);
      expect(find.byIcon(Icons.location_off_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('20. Missing coordinates show "Location unavailable"', (
      tester,
    ) async {
      final report = _sampleReport(latitude: double.nan, longitude: double.nan);
      await tester.pumpWidget(_wrapDetailPage(report: report));
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsNothing);
      expect(find.text('Location unavailable'), findsOneWidget);
      expect(find.byIcon(Icons.location_off_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('21. Map has bounded height (180)', (tester) async {
      final report = _sampleReport();
      await tester.pumpWidget(_wrapDetailPage(report: report));
      await tester.pumpAndSettle();

      final mapFinder = find.byType(FlutterMap);
      expect(mapFinder, findsOneWidget);

      final sizedBoxFinder = find
          .ancestor(of: mapFinder, matching: find.byType(SizedBox))
          .first;
      final sizedBox = tester.widget<SizedBox>(sizedBoxFinder);
      expect(sizedBox.height, 180.0);

      final ignorePointerFinder = find
          .ancestor(of: mapFinder, matching: find.byType(IgnorePointer))
          .first;
      final ignorePointer = tester.widget<IgnorePointer>(ignorePointerFinder);
      expect(ignorePointer.ignoring, isTrue);

      final renderSize = tester.getSize(mapFinder);
      expect(renderSize.height, 180.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('22. Narrow mobile layout (320px) does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final report = _sampleReport(
        description:
            'A very long description testing that nothing overflows on narrow screens when displaying the map and details together.',
      );
      await tester.pumpWidget(
        _wrapDetailPage(report: report, width: 320, height: 800),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(FlutterMap),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('23. 200% text scale does not overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final report = _sampleReport();
      await tester.pumpWidget(
        _wrapDetailPage(report: report, width: 320, height: 1000, scale: 2.0),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(FlutterMap),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(
        find.textContaining('Approximate report location'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
