import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as image_lib;
import 'package:intl/intl.dart';
import 'package:myheritage_explorer/core/app_theme.dart';
import 'package:myheritage_explorer/core/explorer_ui.dart';
import 'package:myheritage_explorer/core/safety_config.dart';
import 'package:myheritage_explorer/models/evidence_validation_result.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/services/hazard_report_service.dart';
import 'package:myheritage_explorer/services/location_service.dart';
import 'package:myheritage_explorer/services/evidence_image_validation_service.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:myheritage_explorer/traveler/traveler_pages.dart';
import 'package:myheritage_explorer/widgets/duplicate_hazard_warning_sheet.dart';

// Test mock for LocationService
class MockLocationService extends LocationService {
  const MockLocationService({
    this.latitude = 5.4141,
    this.longitude = 100.3288,
  });

  final double latitude;
  final double longitude;

  @override
  Future<Position> getCurrentPosition() async {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

// Test mock for HazardReportService
class MockHazardReportService implements HazardReportService {
  List<HazardDuplicateCandidate> candidatesToReturn = [];
  bool duplicateCheckShouldFail = false;
  int createReportCalls = 0;
  Map<String, dynamic>? lastCreatedReportParams;

  @override
  Future<List<HazardDuplicateCandidate>> findDuplicateCandidates({
    required String category,
    required double latitude,
    required double longitude,
    double radiusMeters = SafetyConfig.duplicateHazardRadiusMeters,
    Duration lookback = SafetyConfig.duplicateHazardLookback,
  }) async {
    if (duplicateCheckShouldFail) {
      throw Exception('Network connection failed');
    }
    return candidatesToReturn;
  }

  @override
  Future<EvidenceValidationResult> validateEvidence({
    required Uint8List imageBytes,
    required String evidenceSource,
    bool checkDuplicates = false,
  }) async {
    return validateEvidenceImage(imageBytes, evidenceSource: evidenceSource);
  }

  @override
  Future<String> createReport({
    required String category,
    required String severity,
    required String description,
    required double latitude,
    required double longitude,
    Uint8List? imageBytes,
    String evidenceSource = EvidenceSource.camera,
    EvidenceValidationResult? evidenceValidation,
  }) async {
    createReportCalls++;
    lastCreatedReportParams = {
      'category': category,
      'severity': severity,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'imageBytes': imageBytes,
      'evidenceSource': evidenceSource,
    };
    return 'created-hazard-id';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockImagePickerPlatform extends ImagePickerPlatform {
  _MockImagePickerPlatform(this.imageBytes);
  final Uint8List imageBytes;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions? options,
  }) async {
    debugPrint('_MockImagePickerPlatform.getImageFromSource CALLED!');
    return XFile.fromData(imageBytes, name: 'test_evidence.png');
  }
}

HazardReport createSampleReport({
  required String id,
  required String category,
  required String status,
  String severity = 'Medium',
  String description = 'Test hazard description',
  DateTime? createdAt,
}) {
  return HazardReport(
    id: id,
    userId: 'user-$id',
    category: category,
    severity: severity,
    description: description,
    latitude: 5.4141,
    longitude: 100.3288,
    status: status,
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(hours: 2)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List testPhotoBytes;

  setUpAll(() async {
    final img = image_lib.Image(width: 300, height: 300);
    image_lib.fill(img, color: image_lib.ColorRgb8(50, 100, 150));
    testPhotoBytes = Uint8List.fromList(image_lib.encodePng(img));

    ImagePickerPlatform.instance = _MockImagePickerPlatform(testPhotoBytes);
  });

  Widget testApp(Widget child, {double scale = 1.0}) {
    return MaterialApp(
      theme: AppTheme.light,
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: widget!,
      ),
      home: child,
    );
  }

  group('DuplicateHazardWarningSheet widget tests', () {
    testWidgets('renders single verified candidate accurately', (tester) async {
      final sample = createSampleReport(
        id: 'hz-1',
        category: 'Unsafe walkway',
        status: HazardReportStatus.verified,
        severity: 'High',
        description: 'Deep pothole on footpath near heritage museum.',
      );
      final candidate = HazardDuplicateCandidate(
        report: sample,
        distanceMeters: 42.4,
      );

      HazardReport? viewedReport;
      bool submitAnywayCalled = false;
      bool cancelCalled = false;

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: DuplicateHazardWarningSheet(
              candidates: [candidate],
              onViewExisting: (r) => viewedReport = r,
              onSubmitAnyway: () => submitAnywayCalled = true,
              onCancel: () => cancelCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & informational text
      expect(find.text('Similar Hazard Nearby'), findsOneWidget);
      expect(
        find.textContaining('We found existing report(s) nearby'),
        findsOneWidget,
      );

      // Verify candidate card details
      expect(find.text('Unsafe walkway'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('42 m away'), findsOneWidget);
      expect(find.text('High severity'), findsOneWidget);
      expect(
        find.text('Deep pothole on footpath near heritage museum.'),
        findsOneWidget,
      );

      // Verify actions
      expect(find.text('View Existing Hazard'), findsOneWidget);
      expect(find.text('Submit New Report Anyway'), findsOneWidget);
      expect(find.text('Keep Editing / Cancel'), findsOneWidget);

      // Tap View Existing
      await tester.tap(find.text('View Existing Hazard'));
      expect(viewedReport?.id, 'hz-1');

      // Tap Submit Anyway
      await tester.tap(find.text('Submit New Report Anyway'));
      expect(submitAnywayCalled, isTrue);

      // Tap Cancel
      await tester.tap(find.text('Keep Editing / Cancel'));
      expect(cancelCalled, isTrue);
    });

    testWidgets('renders pending review badge and kilometer distances correctly', (
      tester,
    ) async {
      final sample = createSampleReport(
        id: 'hz-2',
        category: 'Poor lighting',
        status: HazardReportStatus.pendingReview,
        severity: 'Low',
        description: 'Streetlight flickers intermittently.',
      );
      final candidate = HazardDuplicateCandidate(
        report: sample,
        distanceMeters: 1250.0,
      );

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: DuplicateHazardWarningSheet(
              candidates: [candidate],
              onViewExisting: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PENDING REVIEW'), findsOneWidget);
      expect(find.text('1.3 km away'), findsOneWidget);
      expect(find.text('Low severity'), findsOneWidget);
    });

    testWidgets('caps displayed candidates at 3 and shows remaining count note', (
      tester,
    ) async {
      final candidates = List.generate(
        5,
        (i) => HazardDuplicateCandidate(
          report: createSampleReport(
            id: 'hz-$i',
            category: 'Flooding',
            status: HazardReportStatus.verified,
            description: 'Flood issue #$i',
          ),
          distanceMeters: 20.0 + i * 15,
        ),
      );

      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: DuplicateHazardWarningSheet(
              candidates: candidates,
              onViewExisting: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top 3 should be rendered
      expect(find.text('Flood issue #0'), findsOneWidget);
      expect(find.text('Flood issue #1'), findsOneWidget);
      expect(find.text('Flood issue #2'), findsOneWidget);
      // 4th and 5th should not be rendered
      expect(find.text('Flood issue #3'), findsNothing);
      expect(find.text('Flood issue #4'), findsNothing);

      // Overflow indicator
      expect(
        find.text('+ 2 more older or farther reports nearby'),
        findsOneWidget,
      );
    });

    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('responsive layout without overflow at width $width and scale $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final candidate = HazardDuplicateCandidate(
            report: createSampleReport(
              id: 'hz-resp',
              category: 'Road obstruction',
              status: HazardReportStatus.verified,
              description:
                  'A very long descriptive explanation about construction debris completely blocking the narrow walkway.',
            ),
            distanceMeters: 55,
          );

          await tester.pumpWidget(
            testApp(
              Scaffold(
                body: DuplicateHazardWarningSheet(
                  candidates: [candidate],
                  onViewExisting: (_) {},
                ),
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Similar Hazard Nearby'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('CreateHazardPage duplicate detection integration tests', () {
    void setupScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<void> tapSubmit(WidgetTester tester) async {
      final submitButton = find.text('Submit Hazard Report');
      await tester.scrollUntilVisible(
        submitButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'submitting with NO duplicate candidate proceeds silently to createReport',
      (tester) async {
        setupScreen(tester);
        final mockService = MockHazardReportService()
          ..candidatesToReturn = [];
        final mockLocation = const MockLocationService();

        await tester.pumpWidget(
          testApp(
            CreateHazardPage(
              reportService: mockService,
              locationService: mockLocation,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fill in description
        await tester.enterText(
          find.byType(TextField),
          'Water pipe leaking on footpath',
        );
        await tester.pumpAndSettle();

        // Pick photo via mock
        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        // Tap submit
        await tapSubmit(tester);

        // Verify createReport was called directly without warning sheet
        expect(mockService.createReportCalls, 1);
        expect(mockService.lastCreatedReportParams?['description'],
            'Water pipe leaking on footpath');
        expect(find.text('Similar Hazard Nearby'), findsNothing);
      },
    );

    testWidgets(
      'submitting with duplicate candidates displays warning sheet; cancel retains form',
      (tester) async {
        setupScreen(tester);
        final candidate = HazardDuplicateCandidate(
          report: createSampleReport(
            id: 'dup-1',
            category: 'Unsafe walkway',
            status: HazardReportStatus.verified,
            description: 'Existing broken tiles report',
          ),
          distanceMeters: 35,
        );
        final mockService = MockHazardReportService()
          ..candidatesToReturn = [candidate];
        final mockLocation = const MockLocationService();

        await tester.pumpWidget(
          testApp(
            CreateHazardPage(
              reportService: mockService,
              locationService: mockLocation,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fill form
        await tester.enterText(
          find.byType(TextField),
          'Uneven tiles on pavement',
        );
        await tester.pumpAndSettle();

        // Pick photo
        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        // Tap submit
        await tapSubmit(tester);

        // Warning sheet appears
        expect(find.text('Similar Hazard Nearby'), findsOneWidget);
        expect(find.text('35 m away'), findsOneWidget);
        expect(mockService.createReportCalls, 0);

        // Tap Keep Editing / Cancel
        await tester.tap(find.text('Keep Editing / Cancel'));
        await tester.pumpAndSettle();

        // Warning sheet dismissed, form preserved, not submitted
        expect(find.text('Similar Hazard Nearby'), findsNothing);
        expect(mockService.createReportCalls, 0);
        expect(find.text('Uneven tiles on pavement'), findsOneWidget);
      },
    );

    testWidgets(
      'submitting with duplicate candidates; user chooses Submit New Report Anyway',
      (tester) async {
        setupScreen(tester);
        final candidate = HazardDuplicateCandidate(
          report: createSampleReport(
            id: 'dup-2',
            category: 'Unsafe walkway',
            status: HazardReportStatus.verified,
            description: 'Existing broken tiles report',
          ),
          distanceMeters: 50,
        );
        final mockService = MockHazardReportService()
          ..candidatesToReturn = [candidate];
        final mockLocation = const MockLocationService();

        await tester.pumpWidget(
          testApp(
            CreateHazardPage(
              reportService: mockService,
              locationService: mockLocation,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fill form
        await tester.enterText(
          find.byType(TextField),
          'My report is completely distinct',
        );
        await tester.pumpAndSettle();

        // Pick photo
        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        // Tap submit
        await tapSubmit(tester);

        // Warning sheet appears
        expect(find.text('Similar Hazard Nearby'), findsOneWidget);
        expect(mockService.createReportCalls, 0);

        // Tap Submit New Report Anyway
        await tester.tap(find.text('Submit New Report Anyway'));
        await tester.pumpAndSettle();

        // Report was successfully created
        expect(mockService.createReportCalls, 1);
        expect(mockService.lastCreatedReportParams?['description'],
            'My report is completely distinct');
      },
    );

    testWidgets(
      'network failure during duplicate check shows advisory dialog with options',
      (tester) async {
        setupScreen(tester);
        final mockService = MockHazardReportService()
          ..duplicateCheckShouldFail = true;
        final mockLocation = const MockLocationService();

        await tester.pumpWidget(
          testApp(
            CreateHazardPage(
              reportService: mockService,
              locationService: mockLocation,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Fill form
        await tester.enterText(
          find.byType(TextField),
          'Hazard report with offline duplicate check',
        );
        await tester.pumpAndSettle();

        // Pick photo
        await tester.tap(find.text('Take Photo'));
        await tester.pumpAndSettle();

        // Tap submit
        await tapSubmit(tester);

        // Advisory error dialog appears
        expect(find.text('Unable to Check for Nearby Hazards'), findsOneWidget);
        expect(find.text('Continue Submission'), findsOneWidget);
        expect(find.text('Try Again'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(mockService.createReportCalls, 0);

        // Choose Continue Submission
        await tester.tap(find.text('Continue Submission'));
        await tester.pumpAndSettle();

        // Submission proceeds
        expect(mockService.createReportCalls, 1);
        expect(mockService.lastCreatedReportParams?['description'],
            'Hazard report with offline duplicate check');
      },
    );
  });
}
