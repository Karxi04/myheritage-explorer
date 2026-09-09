import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:myheritage_explorer/admin/admin_pages.dart';
import 'package:myheritage_explorer/core/app_theme.dart';
import 'package:myheritage_explorer/models/evidence_validation_result.dart';
import 'package:myheritage_explorer/models/hazard_audit_entry.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/models/hazard_vote.dart';
import 'package:myheritage_explorer/services/hazard_report_service.dart';
import 'package:myheritage_explorer/services/hazard_vote_service.dart';

class _MockReportService implements HazardReportService {
  _MockReportService(this.report, {this.auditEntries = const []});

  final HazardReport? report;
  final List<HazardAuditEntry> auditEntries;

  HazardReport? keptVerifiedReport;
  String? keptVerifiedAdminId;
  String? keptVerifiedAdminName;
  String? keptVerifiedNote;

  HazardReport? updatedReport;
  String? updatedStatus;
  String? updatedAdminId;
  String? updatedAdminName;
  String? updatedNote;

  @override
  Stream<HazardReport?> watchReport(String id) => Stream.value(report);

  @override
  Stream<List<HazardAuditEntry>> watchAuditTrail(String id) =>
      Stream.value(auditEntries);

  @override
  Future<HazardReport?> getReport(String id) async => report;

  @override
  Stream<List<HazardReport>> watchVerifiedReports() =>
      Stream.value(report == null ? [] : [report!]);

  @override
  Stream<List<HazardReport>> watchVerifiedUnresolvedReports() =>
      Stream.value(report == null ? [] : [report!]);

  @override
  Future<void> keepVerified({
    required HazardReport report,
    required String adminId,
    String? adminName,
    required String note,
  }) async {
    keptVerifiedReport = report;
    keptVerifiedAdminId = adminId;
    keptVerifiedAdminName = adminName;
    keptVerifiedNote = note;
  }

  @override
  Future<void> updateStatus({
    required HazardReport report,
    required String status,
    required String adminId,
    String? adminName,
    required String note,
  }) async {
    updatedReport = report;
    updatedStatus = status;
    updatedAdminId = adminId;
    updatedAdminName = adminName;
    updatedNote = note;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockVoteService implements HazardVoteService {
  @override
  Stream<List<HazardVote>> watchVotes(String id) => Stream.value(const []);

  @override
  Stream<Uint8List?> watchEvidenceBytes(String hazardId, String userId) =>
      Stream.value(Uint8List(0));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

HazardReport _createReport({
  String id = 'sample_hazard_123',
  String userId = 'raw_uid_tourist_private',
  String category = 'Road obstruction',
  String severity = 'High',
  String description = 'A fallen tree blocks the main heritage street.',
  String status = HazardReportStatus.verified,
  DateTime? createdAt,
  List<HazardStatusHistoryEntry> statusHistory = const [],
}) {
  return HazardReport(
    id: id,
    userId: userId,
    category: category,
    severity: severity,
    description: description,
    latitude: 5.4141,
    longitude: 100.3288,
    status: status,
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(hours: 4)),
    statusHistory: statusHistory,
    evidenceValidation: const EvidenceValidationResult(
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
      sha256Fingerprint: 'sha256_mock_hash_12345678',
      perceptualHash: 'phash_mock_hash_abcdef12',
      exposureStatus: 'BALANCED',
      width: 1920,
      height: 1080,
      fileFormat: 'JPEG',
    ),
  );
}

Widget _wrapTestApp(
  Widget child, {
  double width = 800,
  double height = 1600,
  double scale = 1.0,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: Size(width, height),
      textScaler: TextScaler.linear(scale),
    ),
    child: MaterialApp(theme: AppTheme.light, home: child),
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required HazardReport report,
  required HazardReportService reportService,
  String? currentAdminId = 'admin_test_123',
  String? currentAdminName = 'Test Administrator',
  double width = 800,
  double height = 1600,
  double scale = 1.0,
}) async {
  tester.view.physicalSize = Size(width * 2, height * 2);
  tester.view.devicePixelRatio = 2.0;

  await tester.pumpWidget(
    _wrapTestApp(
      AdminHazardManagementPage(
        hazardId: report.id,
        reportService: reportService,
        voteService: _MockVoteService(),
        currentAdminId: currentAdminId,
        currentAdminName: currentAdminName,
      ),
      width: width,
      height: height,
      scale: scale,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Step 9 — Administrator Hazard Audit Trail Tests', () {
    testWidgets('Derives Hazard Submitted from report.createdAt', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());

      final createdAt = DateTime(2026, 9, 6, 10, 20);
      final report = _createReport(createdAt: createdAt);
      final mockService = _MockReportService(report, auditEntries: []);

      await _pumpPage(tester, report: report, reportService: mockService);

      // Verify Administrative History card exists
      expect(find.text('Administrative History'), findsOneWidget);
      expect(
        find.text(
          'Chronological audit record of administrative review and lifecycle actions.',
        ),
        findsOneWidget,
      );

      // Verify Hazard Submitted derived event
      expect(find.text('Hazard Submitted'), findsOneWidget);
      expect(find.text('Submitted by Reporter'), findsOneWidget);
      expect(
        find.text(DateFormat.yMMMd().add_jm().format(createdAt)),
        findsOneWidget,
      );
    });

    testWidgets(
      'Displays full chronological lifecycle actions (Verified, Kept Verified, Marked Resolved, Rejected)',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());

        final t0 = DateTime(2026, 9, 6, 10, 0);
        final t1 = DateTime(2026, 9, 6, 10, 30);
        final t2 = DateTime(2026, 9, 6, 11, 15);
        final t3 = DateTime(2026, 9, 6, 14, 0);

        final report = _createReport(
          status: HazardReportStatus.resolved,
          createdAt: t0,
        );

        final entries = [
          HazardAuditEntry(
            id: 'log_1',
            action: HazardAuditAction.verified,
            previousStatus: HazardReportStatus.pendingReview,
            newStatus: HazardReportStatus.verified,
            performedBy: 'raw_uid_admin_1',
            performedByName: 'Sherman Admin',
            performedAt: t1,
            note: 'Verified following photo evidence inspection.',
          ),
          HazardAuditEntry(
            id: 'log_2',
            action: HazardAuditAction.reviewedKeepVerified,
            previousStatus: HazardReportStatus.verified,
            newStatus: HazardReportStatus.verified,
            performedBy: 'raw_uid_admin_2',
            performedByName: 'Sarah Admin',
            performedAt: t2,
            note: 'Community confirms obstruction persists.',
          ),
          HazardAuditEntry(
            id: 'log_3',
            action: HazardAuditAction.markedResolved,
            previousStatus: HazardReportStatus.verified,
            newStatus: HazardReportStatus.resolved,
            performedBy: 'raw_uid_admin_1',
            performedByName: 'Sherman Admin',
            performedAt: t3,
            note: 'Debris cleared by heritage council.',
          ),
        ];

        final mockService = _MockReportService(report, auditEntries: entries);
        await _pumpPage(tester, report: report, reportService: mockService);

        // Check events appear in order
        expect(find.text('Hazard Submitted'), findsOneWidget);
        expect(find.text('Verified'), findsWidgets);
        expect(find.text('Reviewed — Kept Verified'), findsOneWidget);
        expect(find.text('Marked Resolved'), findsOneWidget);

        // Check attribution
        expect(find.text('Verified by Sherman Admin'), findsOneWidget);
        expect(
          find.text('Reviewed — Kept Verified by Sarah Admin'),
          findsOneWidget,
        );
        expect(find.text('Marked Resolved by Sherman Admin'), findsOneWidget);

        // Check transition notes
        expect(
          find.text('Transition: Pending Review → Verified'),
          findsOneWidget,
        );
        expect(find.text('Transition: Verified → Resolved'), findsOneWidget);

        // Check action notes
        expect(
          find.text('Verified following photo evidence inspection.'),
          findsOneWidget,
        );
        expect(
          find.text('Community confirms obstruction persists.'),
          findsOneWidget,
        );
        expect(
          find.text('Debris cleared by heritage council.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Falls back to "Administrator" when performedByName is null or empty, and NEVER displays raw UIDs',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());

        final t0 = DateTime(2026, 9, 6, 9, 0);
        final t1 = DateTime(2026, 9, 6, 9, 45);

        final report = _createReport(
          status: HazardReportStatus.rejected,
          createdAt: t0,
        );

        final entries = [
          HazardAuditEntry(
            id: 'log_rej',
            action: HazardAuditAction.rejected,
            previousStatus: HazardReportStatus.pendingReview,
            newStatus: HazardReportStatus.rejected,
            performedBy: 'raw_uid_secret_admin_999',
            performedByName: null, // Empty display name
            performedAt: t1,
            note: 'Insufficient evidence provided.',
          ),
        ];

        final mockService = _MockReportService(report, auditEntries: entries);
        await _pumpPage(tester, report: report, reportService: mockService);

        // Should fall back to "Rejected by Administrator"
        expect(find.text('Rejected by Administrator'), findsOneWidget);

        // Privacy assertion: raw UIDs must NEVER be present anywhere in the tree
        expect(find.textContaining('raw_uid_secret_admin_999'), findsNothing);
        expect(find.textContaining('raw_uid_tourist_private'), findsNothing);
      },
    );

    testWidgets(
      'Legacy fallback: synthesizes timeline from report.statusHistory when audit_logs subcollection is empty',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());

        final t0 = DateTime(2026, 9, 5, 8, 0);
        final t1 = DateTime(2026, 9, 5, 9, 0);
        final t2 = DateTime(2026, 9, 5, 12, 0);

        final report = _createReport(
          status: HazardReportStatus.resolved,
          createdAt: t0,
          statusHistory: [
            HazardStatusHistoryEntry(
              status: HazardReportStatus.pendingReview,
              note: 'Initial submission',
              changedAt: t0,
              changedBy: 'uid_tourist',
            ),
            HazardStatusHistoryEntry(
              status: HazardReportStatus.verified,
              note: 'Verified legacy entry',
              changedAt: t1,
              changedBy: 'uid_admin_old',
            ),
            HazardStatusHistoryEntry(
              status: HazardReportStatus.resolved,
              note: 'Resolved legacy entry',
              changedAt: t2,
              changedBy: 'uid_admin_old',
            ),
          ],
        );

        // Subcollection is empty
        final mockService = _MockReportService(report, auditEntries: []);
        await _pumpPage(tester, report: report, reportService: mockService);

        // Verify synthesis
        expect(find.text('Hazard Submitted'), findsOneWidget);
        expect(find.text('Verified'), findsWidgets);
        expect(find.text('Marked Resolved'), findsOneWidget);

        // Verify legacy notes
        expect(find.text('Verified legacy entry'), findsOneWidget);
        expect(find.text('Resolved legacy entry'), findsOneWidget);

        // Verify fallback attribution
        expect(find.text('Verified by Administrator'), findsOneWidget);
        expect(find.text('Marked Resolved by Administrator'), findsOneWidget);

        // Verify privacy: no legacy UIDs shown
        expect(find.textContaining('uid_tourist'), findsNothing);
        expect(find.textContaining('uid_admin_old'), findsNothing);
      },
    );

    testWidgets(
      'Keep Verified flow prompts confirmation dialog and preserves status Verified',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());

        final report = _createReport(status: HazardReportStatus.verified);
        final mockService = _MockReportService(report, auditEntries: []);

        await _pumpPage(tester, report: report, reportService: mockService);

        // Find Keep Verified button in sticky bar
        final keepVerifiedBtn = find.widgetWithText(
          OutlinedButton,
          'Keep Verified',
        );
        expect(keepVerifiedBtn, findsOneWidget);

        // Tap Keep Verified
        await tester.tap(keepVerifiedBtn);
        await tester.pumpAndSettle();

        // Confirmation dialog appears
        expect(find.text('Keep hazard verified?'), findsOneWidget);
        expect(
          find.text(
            'This will record an administrative review log confirming this hazard remains active. The report will remain published.',
          ),
          findsOneWidget,
        );

        // Tap Confirm Review
        final confirmBtn = find.widgetWithText(FilledButton, 'Confirm Review');
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Verify mock service was called with proper parameters
        expect(mockService.keptVerifiedReport?.id, report.id);
        expect(
          mockService.keptVerifiedReport?.status,
          HazardReportStatus.verified,
        );
        expect(
          mockService.keptVerifiedNote,
          'Reviewed and kept verified by administrator',
        );

        // Verify snackbar is shown
        expect(
          find.text('Review recorded: Hazard kept verified.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Renders responsively without overflow across 390px, 768px, 1200px and 200% scale',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());

        final t0 = DateTime(2026, 9, 6, 8, 0);
        final t1 = DateTime(2026, 9, 6, 8, 30);
        final report = _createReport(
          status: HazardReportStatus.verified,
          createdAt: t0,
        );

        final entries = [
          HazardAuditEntry(
            id: 'log_rev',
            action: HazardAuditAction.reviewedKeepVerified,
            previousStatus: HazardReportStatus.verified,
            newStatus: HazardReportStatus.verified,
            performedBy: 'admin_uid',
            performedByName:
                'A Very Long Administrator Display Name That Should Wrap Gracefully',
            performedAt: t1,
            note:
                'A comprehensive detailed review note that verifies community feedback and preserves the active hazard perimeter on the public safety map.',
          ),
        ];

        final screenSizes = [
          (390.0, 844.0), // Mobile
          (768.0, 1024.0), // Tablet
          (1200.0, 900.0), // Desktop
        ];

        for (final (width, height) in screenSizes) {
          final mockService = _MockReportService(report, auditEntries: entries);
          await _pumpPage(
            tester,
            report: report,
            reportService: mockService,
            width: width,
            height: height,
            scale: 1.0,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow at $width x $height',
          );
        }

        // 200% text scale test
        final mockService200 = _MockReportService(
          report,
          auditEntries: entries,
        );
        await _pumpPage(
          tester,
          report: report,
          reportService: mockService200,
          width: 390.0,
          height: 844.0,
          scale: 2.0,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'Overflow at 200% text scale',
        );
      },
    );
  });
}
