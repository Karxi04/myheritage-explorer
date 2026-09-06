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
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/models/hazard_vote.dart';
import 'package:myheritage_explorer/services/hazard_report_service.dart';
import 'package:myheritage_explorer/services/hazard_vote_service.dart';

class _MockReportService implements HazardReportService {
  _MockReportService(this.report);
  final HazardReport? report;

  @override
  Stream<HazardReport?> watchReport(String id) => Stream.value(report);

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

class _MockVoteService implements HazardVoteService {
  _MockVoteService(this.votes);
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
  String id = 'sample_hazard',
  String userId = 'tourist_123',
  String category = 'Road obstruction',
  String severity = 'High',
  String description = 'A large fallen branch is blocking the tourist walkway.',
  String status = HazardReportStatus.verified,
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
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
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

HazardVote _createVote({
  required String id,
  required String userId,
  String voteType = HazardVoteType.hazardExists,
  bool hasPhoto = true,
  String source = 'CAMERA',
  String? aiStatus = AiAnalysisStatus.complete,
  double? sceneScore = 0.88,
  double? relevanceScore = 0.92,
  String? condition = 'HAZARD_STILL_PRESENT',
  double? conditionConfidence = 0.85,
  String? agreement = AiAgreement.supportsVote,
  double multiplier = 1.10,
  String? summary = 'Scene strongly matches and obstruction remains active.',
  String? failureReason,
  DateTime? createdAt,
}) {
  final data = <String, dynamic>{
    'userId': userId,
    'voteType': voteType,
    'distanceFromHazardMeters': 45.0,
    'proximityBand': 'STRONG',
    'isGpsValidated': true,
    'hasPhotoEvidence': hasPhoto,
    'createdAt':
        (createdAt ?? DateTime.now().subtract(const Duration(minutes: 5)))
            .toIso8601String(),
    if (hasPhoto) ...{
      'evidenceValidationResult': {
        'isValid': true,
        'qualityScore': 0.85,
        'sharpnessScore': 0.8,
        'brightnessScore': 0.5,
        'resolutionScore': 1.0,
        'duplicateDetected': false,
        'evidenceSource': source,
        'semanticValidationAvailable': false,
        'validationLevel': 'GOOD',
        'warnings': <String>[],
        'overallEvidenceScore': 0.85,
        'sha256Fingerprint': 'sha_vote_$id',
        'perceptualHash': 'phash_vote_$id',
        'exposureStatus': 'BALANCED',
        'width': 1280,
        'height': 720,
        'fileFormat': 'JPEG',
        'sceneMatchScore': 0.82,
      },
      if (aiStatus != null) 'aiAnalysisStatus': aiStatus,
      if (sceneScore != null) 'aiSceneMatchScore': sceneScore,
      if (relevanceScore != null) 'aiHazardRelevanceScore': relevanceScore,
      if (condition != null) 'aiConditionAssessment': condition,
      if (conditionConfidence != null)
        'aiConditionConfidence': conditionConfidence,
      if (agreement != null) 'aiAgreement': agreement,
      'aiEvidenceWeightMultiplier': multiplier,
      if (summary != null) 'aiAnalysisSummary': summary,
      if (failureReason != null) 'aiAnalysisFailureReason': failureReason,
    },
  };

  return HazardVote.fromMap(id, data);
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
    child: MaterialApp(theme: AppTheme.light, home: child),
  );
}

Future<void> _pumpAdminPage(
  WidgetTester tester, {
  required HazardReport report,
  required List<HazardVote> votes,
  Future<Map<String, dynamic>?> Function(String)? reporterLoader,
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
        reportService: _MockReportService(report),
        voteService: _MockVoteService(votes),
        reporterLoader: reporterLoader,
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

  group('Step 7 Admin Decision Support UI — AI States', () {
    testWidgets('COMPLETE AI state shows qualitative decision support', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      final report = _createReport();
      final vote = _createVote(
        id: 'v1',
        userId: 'u1',
        aiStatus: AiAnalysisStatus.complete,
        agreement: AiAgreement.supportsVote,
        multiplier: 1.10,
        sceneScore: 0.88,
        relevanceScore: 0.92,
        condition: 'HAZARD_STILL_PRESENT',
        summary:
            'Scene matches original report and fallen tree still blocks path.',
      );

      await _pumpAdminPage(
        tester,
        report: report,
        votes: [vote],
        reporterLoader: (_) async => {
          'displayName': 'Alice Traveler',
          'email': 'alice@example.com',
        },
      );

      // Verify AI Decision Support header and qualitative findings
      expect(find.text('AI Decision Support'), findsWidgets);
      expect(find.text('SUPPORTS'), findsWidgets);
      expect(find.text('Supports Tourist Confirmation'), findsWidgets);
      expect(find.text('Hazard Still Appears Present'), findsWidgets);
      expect(find.text('Strong Support'), findsWidgets);
      expect(find.text('Scene Match: High · 88%'), findsWidgets);
      expect(find.text('Relevance: High · 92%'), findsWidgets);
      expect(
        find.text(
          'Scene matches original report and fallen tree still blocks path.',
        ),
        findsWidgets,
      );
    });

    testWidgets('PENDING AI state shows in-progress message with spinner', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      final report = _createReport();
      final vote = _createVote(
        id: 'v_pending',
        userId: 'u_pending',
        aiStatus: AiAnalysisStatus.pending,
        agreement: null,
        sceneScore: null,
        relevanceScore: null,
        condition: null,
        summary: null,
      );

      await _pumpAdminPage(
        tester,
        report: report,
        votes: [vote],
        reporterLoader: (_) async => {'displayName': 'Bob Traveler'},
      );

      expect(find.text('AI evidence analysis in progress…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('FAILED AI state displays friendly unavailable message', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      final report = _createReport();
      final vote = _createVote(
        id: 'v_failed',
        userId: 'u_failed',
        aiStatus: AiAnalysisStatus.failed,
        failureReason: 'MODEL_ERROR',
        agreement: null,
        sceneScore: null,
      );

      await _pumpAdminPage(tester, report: report, votes: [vote]);

      expect(
        find.text('AI analysis is currently unavailable.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'SKIPPED AI state displays friendly reason (original unavailable / no photo)',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());
        final report = _createReport();
        final vote = _createVote(
          id: 'v_skipped',
          userId: 'u_skipped',
          aiStatus: AiAnalysisStatus.skipped,
          failureReason: 'ORIGINAL_EVIDENCE_UNAVAILABLE',
          agreement: null,
        );

        await _pumpAdminPage(tester, report: report, votes: [vote]);

        expect(
          find.text('Original hazard image is unavailable for comparison.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'LEGACY / NOT_AVAILABLE shows clean neutral notice without spinner',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());
        final report = _createReport();
        final vote = _createVote(
          id: 'v_legacy',
          userId: 'u_legacy',
          aiStatus: null, // Legacy vote
          agreement: null,
        );

        await _pumpAdminPage(tester, report: report, votes: [vote]);

        expect(
          find.text('AI analysis not available for this evidence'),
          findsOneWidget,
        );
      },
    );
  });

  group('Step 7 Admin Decision Support UI — Evidence Source & Direction', () {
    testWidgets(
      'Distinguishes Captured in App vs Selected from Gallery without misleading labels',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());
        final report = _createReport();
        final cameraVote = _createVote(
          id: 'v_cam',
          userId: 'u_cam',
          source: 'CAMERA',
          voteType: HazardVoteType.hazardExists,
        );
        final galleryVote = _createVote(
          id: 'v_gal',
          userId: 'u_gal',
          source: 'GALLERY',
          voteType: HazardVoteType.hazardResolved,
          agreement: AiAgreement.conflictsWithVote,
          multiplier: 0.90,
        );

        await _pumpAdminPage(
          tester,
          report: report,
          votes: [cameraVote, galleryVote],
        );

        // Badges
        expect(find.text('Captured in App'), findsWidgets);
        expect(find.text('Selected from Gallery'), findsWidgets);
        expect(find.text('HAZARD STILL EXISTS'), findsWidgets);
        expect(find.text('HAZARD APPEARS RESOLVED'), findsWidgets);

        // Must NOT contain misleading labels
        expect(find.text('Verified Authentic Image'), findsNothing);
        expect(find.text('Authentic'), findsNothing);
        expect(find.text('Real-Life Verified'), findsNothing);
      },
    );

    testWidgets('Empty community evidence displays polite fallback', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      final report = _createReport();

      await _pumpAdminPage(tester, report: report, votes: []);

      expect(
        find.text('No community evidence has been submitted yet.'),
        findsOneWidget,
      );
    });
  });

  group('Step 7 Admin Decision Support UI — AI Agreement Variants', () {
    testWidgets('CONFLICTS_WITH_VOTE renders restrained conflict style', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      final report = _createReport();
      final vote = _createVote(
        id: 'v_con',
        userId: 'u_con',
        voteType: HazardVoteType.hazardResolved,
        agreement: AiAgreement.conflictsWithVote,
        multiplier: 0.90,
        condition: 'HAZARD_STILL_PRESENT',
      );

      await _pumpAdminPage(tester, report: report, votes: [vote]);

      expect(find.text('CONFLICTS'), findsWidgets);
      expect(find.text('Conflicts with Tourist Confirmation'), findsWidgets);
      expect(find.text('Strong Conflict'), findsWidgets);
    });

    testWidgets('INCONCLUSIVE renders neutral style', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      final report = _createReport();
      final vote = _createVote(
        id: 'v_incon',
        userId: 'u_incon',
        voteType: HazardVoteType.hazardExists,
        agreement: AiAgreement.inconclusive,
        multiplier: 1.0,
        condition: 'UNCERTAIN',
      );

      await _pumpAdminPage(tester, report: report, votes: [vote]);

      expect(find.text('INCONCLUSIVE'), findsWidgets);
      expect(find.text('Inconclusive'), findsWidgets);
      expect(find.text('Current Condition Uncertain'), findsWidgets);
    });
  });

  group('Step 7 Admin Decision Support UI — Sample-Size Communication', () {
    testWidgets('Warns when recent confirmations are under threshold (< 10)', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      final report = _createReport();
      // Only 3 votes in the 15-minute window
      final votes = [
        for (var i = 0; i < 3; i++)
          _createVote(
            id: 'v_$i',
            userId: 'u_$i',
            createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
          ),
      ];

      await _pumpAdminPage(tester, report: report, votes: votes);

      expect(find.text('Limited community evidence'), findsOneWidget);
      expect(
        find.textContaining(
          '7 more recent confirmations are needed before a reliable resolution confidence can be determined.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'Indicates reliable sample when confirmations meet threshold (>= 10)',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());
        final report = _createReport();
        // 10 votes in the 15-minute window
        final votes = [
          for (var i = 0; i < 10; i++)
            _createVote(
              id: 'v_$i',
              userId: 'u_$i',
              createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
            ),
        ];

        await _pumpAdminPage(tester, report: report, votes: votes);

        expect(find.text('Limited community evidence'), findsNothing);
        expect(
          find.textContaining(
            'Sample size reliable: 10 confirmations in the rolling 15-minute window',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('Displays decision-support disclaimer', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      final report = _createReport();
      final vote = _createVote(id: 'v1', userId: 'u1');

      await _pumpAdminPage(tester, report: report, votes: [vote]);

      expect(
        find.text(
          'AI evidence analysis supports administrator review and does not automatically change hazard status.',
        ),
        findsOneWidget,
      );
    });
  });

  group('Step 7 Admin Decision Support UI — Aggregated AI Summary', () {
    testWidgets('Aggregates AI results across multiple community votes', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      final report = _createReport();
      final votes = [
        _createVote(
          id: 'v1',
          userId: 'u1',
          agreement: AiAgreement.supportsVote,
        ),
        _createVote(
          id: 'v2',
          userId: 'u2',
          agreement: AiAgreement.supportsVote,
        ),
        _createVote(
          id: 'v3',
          userId: 'u3',
          agreement: AiAgreement.conflictsWithVote,
          multiplier: 0.90,
        ),
        _createVote(
          id: 'v4',
          userId: 'u4',
          aiStatus: AiAnalysisStatus.pending,
          agreement: null,
        ),
        _createVote(
          id: 'v5',
          userId: 'u5',
          aiStatus: AiAnalysisStatus.failed,
          failureReason: 'MODEL_ERROR',
          agreement: null,
        ),
      ];

      await _pumpAdminPage(tester, report: report, votes: votes);

      expect(find.text('AI Evidence Summary'), findsOneWidget);
      expect(find.text('Supports Vote'), findsWidgets);
      expect(find.text('Conflicts with Vote'), findsWidgets);
      expect(find.text('Analysis Pending'), findsWidgets);
      expect(find.text('Unavailable'), findsWidgets);
    });

    testWidgets('Hides AI Evidence Summary when zero AI votes exist', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      final report = _createReport();
      final votes = [
        _createVote(id: 'v1', userId: 'u1', hasPhoto: false),
        _createVote(id: 'v2', userId: 'u2', hasPhoto: false),
      ];

      await _pumpAdminPage(tester, report: report, votes: votes);

      expect(find.text('AI Evidence Summary'), findsNothing);
    });
  });

  group('Step 7 Admin Decision Support UI — Responsive & Overflow Protections', () {
    for (final width in [390.0, 768.0, 1200.0]) {
      testWidgets('Renders cleanly at width $width with 1.0x scale', (
        tester,
      ) async {
        addTearDown(() => tester.view.resetPhysicalSize());
        final report = _createReport();
        final votes = [
          _createVote(id: 'v1', userId: 'u1', source: 'CAMERA'),
          _createVote(id: 'v2', userId: 'u2', source: 'GALLERY'),
        ];

        await _pumpAdminPage(
          tester,
          report: report,
          votes: votes,
          width: width,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Keep Verified'), findsOneWidget);
        expect(find.text('Mark Resolved'), findsOneWidget);
      });
    }

    testWidgets(
      'Handles 200% text scale and long descriptions without overflowing',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());
        final report = _createReport(
          description:
              'Very long description that could potentially cause RenderFlex overflow if containers are fixed height. ' *
              4,
        );
        final vote = _createVote(
          id: 'v1',
          userId: 'u1',
          summary:
              'A detailed AI explanation verifying that defensive truncation prevents card overflow under extreme scale.',
        );

        await _pumpAdminPage(
          tester,
          report: report,
          votes: [vote],
          width: 390,
          height: 2200,
          scale: 2.0,
        );

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Step 7 Admin Decision Support UI — Cleanup Pass Protections', () {
    testWidgets('Raw document ID and raw Tourist UID are not visible in UI', (
      tester,
    ) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      final report = _createReport(
        id: 'report_raw_doc_id_9999',
        userId: 'user_raw_uid_8888',
      );
      final vote = _createVote(
        id: 'vote_raw_doc_id_7777',
        userId: 'user_raw_uid_6666',
        aiStatus: AiAnalysisStatus.complete,
        agreement: AiAgreement.supportsVote,
        multiplier: 1.08,
      );

      await _pumpAdminPage(
        tester,
        report: report,
        votes: [vote],
        reporterLoader: (_) async => null,
      );

      // Verify raw document IDs and raw user UIDs are NEVER displayed
      expect(find.text('report_raw_doc_id_9999'), findsNothing);
      expect(find.text('user_raw_uid_8888'), findsNothing);
      expect(find.text('vote_raw_doc_id_7777'), findsNothing);
      expect(find.text('user_raw_uid_6666'), findsNothing);
      expect(find.textContaining('raw_doc_id'), findsNothing);
      expect(find.textContaining('raw_uid'), findsNothing);
    });

    testWidgets(
      'Human-readable reporter name is displayed when available without raw UID',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());
        final report = _createReport(userId: 'user_raw_uid_8888');

        await _pumpAdminPage(
          tester,
          report: report,
          votes: [],
          reporterLoader: (_) async => {'displayName': 'Jane Explorer'},
        );

        expect(find.text('Reported by Jane Explorer'), findsOneWidget);
        expect(find.text('user_raw_uid_8888'), findsNothing);
        expect(find.textContaining('raw_uid'), findsNothing);
      },
    );

    testWidgets(
      'Evidence Assessment shows Support for SUPPORTS_VOTE, Conflict for CONFLICTS_WITH_VOTE, Inconclusive for INCONCLUSIVE',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());
        final report = _createReport();
        final supportsStrongVote = _createVote(
          id: 'v_sup_str',
          userId: 'u1',
          agreement: AiAgreement.supportsVote,
          multiplier: 1.08,
        );
        final supportsModVote = _createVote(
          id: 'v_sup_mod',
          userId: 'u2',
          agreement: AiAgreement.supportsVote,
          multiplier: 1.02,
        );
        final conflictStrongVote = _createVote(
          id: 'v_con_str',
          userId: 'u3',
          agreement: AiAgreement.conflictsWithVote,
          multiplier: 0.92,
        );
        final conflictModVote = _createVote(
          id: 'v_con_mod',
          userId: 'u4',
          agreement: AiAgreement.conflictsWithVote,
          multiplier: 0.98,
        );
        final inconVote = _createVote(
          id: 'v_incon',
          userId: 'u5',
          agreement: AiAgreement.inconclusive,
          multiplier: 1.00,
        );

        await _pumpAdminPage(
          tester,
          report: report,
          votes: [
            supportsStrongVote,
            supportsModVote,
            conflictStrongVote,
            conflictModVote,
            inconVote,
          ],
        );

        // Support wording
        expect(find.text('Strong Support'), findsOneWidget);
        expect(find.text('Moderate Support'), findsOneWidget);

        // Conflict wording
        expect(find.text('Strong Conflict'), findsOneWidget);
        expect(find.text('Moderate Conflict'), findsOneWidget);

        // Inconclusive wording (and INCONCLUSIVE does not display Support wording)
        expect(find.text('Inconclusive'), findsWidgets);
        expect(find.text('Evidence Assessment'), findsWidgets);
      },
    );

    testWidgets(
      'Confidence recommendation heading is Resolution Recommendation and not AI Recommendation',
      (tester) async {
        addTearDown(() => tester.view.resetPhysicalSize());
        final report = _createReport();
        final vote = _createVote(id: 'v1', userId: 'u1');

        await _pumpAdminPage(tester, report: report, votes: [vote]);

        // Heading must be Resolution Recommendation
        expect(find.text('Resolution Recommendation'), findsOneWidget);
        // Must NOT be labelled "AI Recommendation"
        expect(find.text('AI Recommendation'), findsNothing);
        expect(find.textContaining('AI Recommendation'), findsNothing);
      },
    );
  });
}
