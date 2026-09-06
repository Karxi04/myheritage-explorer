import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:firebase_core/firebase_core.dart';
// Firebase's installed test helper is used only by this test harness.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:myheritage_explorer/core/app_theme.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/models/hazard_audit_entry.dart';
import 'package:myheritage_explorer/models/hazard_vote.dart';
import 'package:myheritage_explorer/services/hazard_report_service.dart';
import 'package:myheritage_explorer/services/hazard_vote_service.dart';
import 'package:myheritage_explorer/services/location_service.dart';
import 'package:myheritage_explorer/traveler/traveler_pages.dart';
import 'package:myheritage_explorer/admin/admin_pages.dart';

class Reports implements HazardReportService {
  Reports(this.report);
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

class Votes implements HazardVoteService {
  @override
  Stream<List<HazardVote>> watchVotes(String id) => Stream.value([
    for (var i = 0; i < 26; i++)
      HazardVote(
        id: '$i',
        userId: '$i',
        voteType: i == 0
            ? HazardVoteType.hazardExists
            : HazardVoteType.hazardResolved,
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
        distanceFromHazardMeters: 70,
        proximityBand: 'STRONG',
        isGpsValidated: true,
        hasPhotoEvidence: false,
      ),
  ]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Location extends LocationService {
  const Location({this.denied = false});
  final bool denied;
  @override
  Future<Position> getCurrentPosition() async {
    if (denied) {
      throw const LocationAccessException(
        'Allow location access in device settings, then retry.',
      );
    }
    return Position(
      latitude: 5.4141,
      longitude: 100.3288,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

const report = HazardReport(
  id: 'sample',
  userId: 'owner',
  category: 'Road obstruction',
  severity: 'High',
  description:
      'A fallen branch blocks part of the walkway. Use the opposite side.',
  latitude: 5.4141,
  longitude: 100.3288,
  status: HazardReportStatus.verified,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  var font = 'Roboto';
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await Firebase.initializeApp();
    if (Platform.isWindows &&
        File('C:/Windows/Fonts/segoeui.ttf').existsSync()) {
      final loader = FontLoader('SafetyAuditFont');
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync(),
          ),
        ),
      );
      await loader.load();
      font = 'SafetyAuditFont';
    }
  });
  Widget app(Widget page, {double scale = 1}) => MaterialApp(
    theme: AppTheme.light.copyWith(
      textTheme: AppTheme.light.textTheme.apply(fontFamily: font),
      appBarTheme: AppTheme.light.appBarTheme.copyWith(
        titleTextStyle: AppTheme.light.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: font,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: AppTheme.light.filledButtonTheme.style?.copyWith(
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontFamily: font, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppTheme.light.outlinedButtonTheme.style?.copyWith(
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontFamily: font, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: AppTheme.light.textButtonTheme.style?.copyWith(
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontFamily: font, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: RepaintBoundary(key: const ValueKey('capture'), child: page),
  );
  void size(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/safety-audit').createSync(recursive: true);
      await File(
        'build/safety-audit/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'create report severity dimensions stay equal at $width / $scale',
        (tester) async {
          size(tester, width);
          await tester.pumpWidget(
            app(
              CreateHazardPage(
                reportService: Reports(null),
                locationService: const Location(),
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Severity level'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          final boxes = ['Low', 'Medium', 'High']
              .map(
                (label) => find
                    .ancestor(
                      of: find.text(label),
                      matching: find.byType(AnimatedContainer),
                    )
                    .first,
              )
              .toList();
          final sizes = boxes.map(tester.getSize).toList();
          expect(sizes[0].width, closeTo(sizes[1].width, .01));
          expect(sizes[1].width, closeTo(sizes[2].width, .01));
          expect(sizes[0].height, sizes[2].height);
          await tester.tap(find.text('High'));
          await tester.pumpAndSettle();
          expect(tester.getSize(boxes[0]), tester.getSize(boxes[2]));
          expect(tester.takeException(), isNull);
          if (width == 390 && scale == 1) {
            await capture(tester, 'create-hazard-mobile');
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('denied GPS gives a helpful retry without a crash', (
    tester,
  ) async {
    size(tester, 390);
    await tester.pumpWidget(
      app(
        CreateHazardPage(
          reportService: Reports(null),
          locationService: const Location(denied: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('device settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'missing hazard details and alert exit loading and retain back navigation',
    (tester) async {
      for (final page in [
        HazardDetailPage(hazardId: 'missing', reportService: Reports(null)),
        SafetyAlertPage(
          hazardId: 'missing',
          distanceMeters: 70,
          reportService: Reports(null),
          voteService: Votes(),
          locationService: const Location(),
        ),
        AdminHazardManagementPage(
          hazardId: 'missing',
          reportService: Reports(null),
          voteService: Votes(),
        ),
      ]) {
        await tester.pumpWidget(app(page));
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining('not found'), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  for (final width in [390.0, 1200.0]) {
    testWidgets('administrator review layout at $width', (tester) async {
      size(tester, width);
      await tester.pumpWidget(
        app(
          AdminHazardManagementPage(
            hazardId: 'sample',
            reportService: Reports(report),
            voteService: Votes(),
            reporterLoader: (_) async => {
              'displayName': 'Test traveler',
              'email': 'traveler@example.test',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Keep Verified'), findsOneWidget);
      expect(find.text('Mark Resolved'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Community Resolution Analysis'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, 'admin-review-${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final width in [320.0, 390.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('danger zone map layout fits $width with text scale $scale', (
        tester,
      ) async {
        size(tester, width);
        await tester.pumpWidget(
          app(
            DangerZoneMapPage(
              reports: const [report],
              height: 250,
              locationService: const Location(),
            ),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DangerZoneMapPage), findsOneWidget);
        expect(find.text('Low'), findsOneWidget);
        expect(find.text('Medium'), findsOneWidget);
        expect(find.text('High'), findsOneWidget);
        expect(find.textContaining('150 m'), findsNothing);
        expect(find.textContaining('300 m'), findsNothing);
        expect(find.textContaining('500 m'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('danger zone map empty state layout on narrow width 320', (
    tester,
  ) async {
    size(tester, 320.0);
    await tester.pumpWidget(
      app(
        const DangerZoneMapPage(
          reports: [],
          height: 250,
          locationService: Location(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No verified hazards are active right now.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [320.0, 390.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'verified hazard card layout fits $width with text scale $scale and long description',
        (tester) async {
          size(tester, width);
          const longReport = HazardReport(
            id: 'long_desc_report',
            userId: 'user_123',
            category: 'Road obstruction',
            severity: 'High',
            description:
                'This is an exceptionally long hazard description designed to verify that '
                'text overflowing is cleanly capped at two lines with ellipsis without causing '
                'any RenderFlex overflow on narrow devices or high accessibility font scales.',
            latitude: 5.4141,
            longitude: 100.3288,
            status: HazardReportStatus.verified,
          );
          await tester.pumpWidget(
            app(
              AdminVerifiedReportsTab(
                reportService: Reports(longReport),
                voteService: Votes(),
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('VERIFIED'), findsOneWidget);
          expect(find.text('HIGH SEVERITY'), findsOneWidget);
          expect(find.text('Manage'), findsOneWidget);
          expect(find.text('Road obstruction'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
