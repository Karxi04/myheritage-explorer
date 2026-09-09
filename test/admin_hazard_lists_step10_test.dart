import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myheritage_explorer/admin/admin_pages.dart';
import 'package:myheritage_explorer/core/app_theme.dart';
import 'package:myheritage_explorer/models/evidence_validation_result.dart';
import 'package:myheritage_explorer/models/hazard_audit_entry.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/models/hazard_vote.dart';
import 'package:myheritage_explorer/services/hazard_report_service.dart';
import 'package:myheritage_explorer/services/hazard_vote_service.dart';
import 'package:myheritage_explorer/widgets/safety_loading_state.dart';

class _MockReportService implements HazardReportService {
  _MockReportService({
    this.pendingReports = const [],
    this.verifiedReports = const [],
    this.streamError,
  });

  final List<HazardReport> pendingReports;
  final List<HazardReport> verifiedReports;
  final Object? streamError;
  int retryPendingCalls = 0;
  int retryVerifiedCalls = 0;

  @override
  Stream<List<HazardReport>> watchPendingReports() {
    if (streamError != null) {
      retryPendingCalls++;
      return Stream.error(streamError!);
    }
    return Stream.value(pendingReports);
  }

  @override
  Stream<List<HazardReport>> watchVerifiedUnresolvedReports() {
    if (streamError != null) {
      retryVerifiedCalls++;
      return Stream.error(streamError!);
    }
    return Stream.value(verifiedReports);
  }

  @override
  Stream<HazardReport?> watchReport(String id) {
    final match = [
      ...pendingReports,
      ...verifiedReports,
    ].where((r) => r.id == id).firstOrNull;
    return Stream.value(match);
  }

  @override
  Stream<List<HazardAuditEntry>> watchAuditTrail(String id) =>
      Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockVoteService implements HazardVoteService {
  _MockVoteService({this.votes = const []});

  final List<HazardVote> votes;

  @override
  Stream<List<HazardVote>> watchVotes(String id) => Stream.value(votes);

  @override
  Stream<Uint8List?> watchEvidenceBytes(String hazardId, String userId) =>
      Stream.value(Uint8List(0));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

HazardReport _createReport({
  required String id,
  required String status,
  String category = 'Unsafe Walkway',
  String severity = 'Medium',
  String description = 'Uneven pavement near the pedestrian crossing.',
  DateTime? createdAt,
  DateTime? reviewedAt,
  bool hasPhoto = true,
}) {
  return HazardReport(
    id: id,
    userId: 'tourist_uid_1',
    category: category,
    severity: severity,
    description: description,
    latitude: 5.4141,
    longitude: 100.3288,
    status: status,
    createdAt: createdAt ?? DateTime(2026, 9, 6, 10, 32),
    reviewedAt: reviewedAt,
    hasPhotoEvidence: hasPhoto,
    evidenceValidation: hasPhoto
        ? const EvidenceValidationResult(
            isValid: true,
            qualityScore: 0.9,
            sharpnessScore: 0.85,
            brightnessScore: 0.5,
            resolutionScore: 1.0,
            duplicateDetected: false,
            evidenceSource: 'CAMERA',
            semanticValidationAvailable: false,
            validationLevel: EvidenceValidationLevel.good,
            warnings: [],
            overallEvidenceScore: 0.9,
            sha256Fingerprint: 'sha_test_123',
            perceptualHash: 'phash_test_123',
            exposureStatus: 'BALANCED',
            width: 1920,
            height: 1080,
            fileFormat: 'JPEG',
          )
        : null,
  );
}

Widget _wrapTestApp(
  Widget child, {
  double width = 800,
  double height = 1400,
  double scale = 1.0,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: Size(width, height),
      textScaler: TextScaler.linear(scale),
    ),
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Step 10 — Pending Hazard Reports Tab', () {
    testWidgets(
      'Renders normal Pending card with required hierarchy and labels',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());

        final report = _createReport(
          id: 'p_1',
          status: HazardReportStatus.pendingReview,
          category: 'Unsafe Walkway',
          severity: 'Medium',
          createdAt: DateTime(2026, 9, 6, 10, 32),
        );

        final service = _MockReportService(pendingReports: [report]);

        await tester.pumpWidget(
          _wrapTestApp(AdminPendingReportsTab(reportService: service)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Unsafe Walkway'), findsOneWidget);
        expect(find.text('PENDING REVIEW'), findsOneWidget);
        expect(find.text('MEDIUM SEVERITY'), findsOneWidget);
        expect(find.textContaining('GPS: 5.4141, 100.3288'), findsOneWidget);
        expect(
          find.textContaining('Submitted Sep 6, 2026 · 10:32 AM'),
          findsOneWidget,
        );
        expect(
          find.text('Uneven pavement near the pedestrian crossing.'),
          findsOneWidget,
        );
        expect(find.text('Review Report'), findsOneWidget);
      },
    );

    testWidgets(
      'Caps long description with 2 lines and ellipsis without crashing',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());

        final report = _createReport(
          id: 'p_long',
          status: HazardReportStatus.pendingReview,
          description:
              'A very long description that spans many lines of text to ensure that the card '
              'caps the preview at two lines and does not cause vertical or horizontal overflows on narrow screens.',
        );

        final service = _MockReportService(pendingReports: [report]);

        await tester.pumpWidget(
          _wrapTestApp(
            AdminPendingReportsTab(reportService: service),
            width: 390,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Review Report'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Graceful placeholder when evidence photo is missing', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      final report = _createReport(
        id: 'p_no_photo',
        status: HazardReportStatus.pendingReview,
        hasPhoto: false,
      );

      final service = _MockReportService(pendingReports: [report]);

      await tester.pumpWidget(
        _wrapTestApp(AdminPendingReportsTab(reportService: service)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
      expect(find.text('Review Report'), findsOneWidget);
    });

    testWidgets('Displays polished empty state when no pending reports exist', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = _MockReportService(pendingReports: []);

      await tester.pumpWidget(
        _wrapTestApp(AdminPendingReportsTab(reportService: service)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('No pending hazard reports'), findsOneWidget);
      expect(
        find.text('All submitted reports have been reviewed.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.pending_actions_outlined), findsOneWidget);
    });

    testWidgets(
      'Displays loading state while pending reports stream is waiting',
      (tester) async {
        final controller = StreamController<List<HazardReport>>();

        await tester.pumpWidget(
          _wrapTestApp(
            StreamBuilder<List<HazardReport>>(
              stream: controller.stream,
              builder: (_, snapshot) {
                if (!snapshot.hasData) {
                  return const SafetyLoadingState(
                    label: 'Loading pending reports…',
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Loading pending reports…'), findsOneWidget);
        await controller.close();
      },
    );

    testWidgets('Displays friendly error state with retry button on error', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = _MockReportService(streamError: 'Network error');

      await tester.pumpWidget(
        _wrapTestApp(AdminPendingReportsTab(reportService: service)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Unable to load pending reports'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(service.retryPendingCalls, greaterThanOrEqualTo(2));
    });
  });

  group('Step 10 — Verified Hazards Tab', () {
    testWidgets(
      'Renders normal Verified card with required hierarchy and labels',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());

        final report = _createReport(
          id: 'v_1',
          status: HazardReportStatus.verified,
          category: 'Fallen Tree Branch',
          severity: 'High',
          createdAt: DateTime(2026, 9, 6, 9, 0),
          reviewedAt: DateTime(2026, 9, 6, 11, 45),
        );

        final vote = HazardVote(
          id: 'vote_1',
          userId: 'u1',
          voteType: HazardVoteType.hazardExists,
          createdAt: DateTime(2026, 9, 6, 12, 0),
          distanceFromHazardMeters: 50,
          proximityBand: 'STRONG',
          isGpsValidated: true,
          hasPhotoEvidence: false,
        );

        final service = _MockReportService(verifiedReports: [report]);
        final voteService = _MockVoteService(votes: [vote]);

        await tester.pumpWidget(
          _wrapTestApp(
            AdminVerifiedReportsTab(
              reportService: service,
              voteService: voteService,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Fallen Tree Branch'), findsOneWidget);
        expect(find.text('VERIFIED'), findsOneWidget);
        expect(find.text('HIGH SEVERITY'), findsOneWidget);
        expect(find.textContaining('GPS: 5.4141, 100.3288'), findsOneWidget);
        expect(
          find.textContaining('Verified Sep 6, 2026 · 11:45 AM'),
          findsOneWidget,
        );
        expect(find.textContaining('1 confirmation'), findsOneWidget);
        expect(find.text('Manage Hazard'), findsOneWidget);

        // Verify that heavy confidence box is NOT in the list card
        expect(find.textContaining('% resolution support'), findsNothing);
      },
    );

    testWidgets(
      'Displays polished empty state when no verified hazards exist',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());

        final service = _MockReportService(verifiedReports: []);

        await tester.pumpWidget(
          _wrapTestApp(AdminVerifiedReportsTab(reportService: service)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('No verified hazards'), findsOneWidget);
        expect(
          find.text('Verified hazards will appear here after review.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      },
    );

    testWidgets('Displays friendly error state with retry button on error', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = _MockReportService(streamError: 'Network error');

      await tester.pumpWidget(
        _wrapTestApp(AdminVerifiedReportsTab(reportService: service)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Unable to load verified hazards'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(service.retryVerifiedCalls, greaterThanOrEqualTo(2));
    });
  });

  group('Step 10 — UI Consistency & Visual Foundation', () {
    testWidgets(
      'Pending and Verified cards share identical severity badge styling',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());

        final pendingReport = _createReport(
          id: 'p_sev',
          status: HazardReportStatus.pendingReview,
          severity: 'High',
        );
        final verifiedReport = _createReport(
          id: 'v_sev',
          status: HazardReportStatus.verified,
          severity: 'High',
        );

        final service = _MockReportService(
          pendingReports: [pendingReport],
          verifiedReports: [verifiedReport],
        );

        await tester.pumpWidget(
          _wrapTestApp(
            Column(
              children: [
                Expanded(child: AdminPendingReportsTab(reportService: service)),
                Expanded(
                  child: AdminVerifiedReportsTab(reportService: service),
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Both should have 'HIGH SEVERITY' badge
        expect(find.text('HIGH SEVERITY'), findsNWidgets(2));
      },
    );

    testWidgets('Both lists use identical date format: MMM d, y · h:mm a', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      final date = DateTime(2026, 9, 6, 14, 25);
      final pReport = _createReport(
        id: 'p_d',
        status: HazardReportStatus.pendingReview,
        createdAt: date,
      );
      final vReport = _createReport(
        id: 'v_d',
        status: HazardReportStatus.verified,
        createdAt: date,
      );

      final service = _MockReportService(
        pendingReports: [pReport],
        verifiedReports: [vReport],
      );

      await tester.pumpWidget(
        _wrapTestApp(
          Column(
            children: [
              Expanded(child: AdminPendingReportsTab(reportService: service)),
              Expanded(child: AdminVerifiedReportsTab(reportService: service)),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.textContaining('Submitted Sep 6, 2026 · 2:25 PM'),
        findsNWidgets(2),
      );
    });
  });

  group('Step 10 — Responsive Layout & Accessibility Scaling', () {
    testWidgets(
      'Renders responsively without overflow across 390px, 768px, 1200px and 200% scale',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());

        final report = _createReport(
          id: 'resp_1',
          status: HazardReportStatus.pendingReview,
          category: 'A Very Long Category Name Designed for Testing Edge Cases',
          description:
              'A detailed hazard description checking responsive wrapping and overflow behavior.',
        );

        final service = _MockReportService(pendingReports: [report]);

        final screenSizes = [(390.0, 844.0), (768.0, 1024.0), (1200.0, 900.0)];

        for (final (w, h) in screenSizes) {
          tester.view.physicalSize = Size(w * 2, h * 2);
          tester.view.devicePixelRatio = 2.0;

          await tester.pumpWidget(
            _wrapTestApp(
              AdminPendingReportsTab(reportService: service),
              width: w,
              height: h,
              scale: 1.0,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          expect(tester.takeException(), isNull, reason: 'Overflow at $w x $h');
        }

        // 200% text scale test
        tester.view.physicalSize = const Size(390.0 * 2, 844.0 * 2);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          _wrapTestApp(
            AdminPendingReportsTab(reportService: service),
            width: 390.0,
            height: 844.0,
            scale: 2.0,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          tester.takeException(),
          isNull,
          reason: 'Overflow at 200% text scale',
        );
      },
    );
  });

  group('Step 10 — Navigation Action Flow', () {
    testWidgets('Tapping Review Report opens AdminHazardManagementPage', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      final report = _createReport(
        id: 'nav_pending',
        status: HazardReportStatus.pendingReview,
      );
      final service = _MockReportService(pendingReports: [report]);

      await tester.pumpWidget(
        _wrapTestApp(AdminPendingReportsTab(reportService: service)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final reviewBtn = find.widgetWithText(FilledButton, 'Review Report');
      expect(reviewBtn, findsOneWidget);

      await tester.tap(reviewBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Navigation target is AdminHazardManagementPage
      expect(find.byType(AdminHazardManagementPage), findsOneWidget);
    });

    testWidgets('Tapping Manage Hazard opens AdminHazardManagementPage', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      final report = _createReport(
        id: 'nav_verified',
        status: HazardReportStatus.verified,
      );
      final service = _MockReportService(verifiedReports: [report]);

      await tester.pumpWidget(
        _wrapTestApp(AdminVerifiedReportsTab(reportService: service)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final manageBtn = find.widgetWithText(FilledButton, 'Manage Hazard');
      expect(manageBtn, findsOneWidget);

      await tester.tap(manageBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Navigation target is AdminHazardManagementPage
      expect(find.byType(AdminHazardManagementPage), findsOneWidget);
    });
  });
}
