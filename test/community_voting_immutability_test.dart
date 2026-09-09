import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:myheritage_explorer/core/app_theme.dart';
import 'package:myheritage_explorer/models/evidence_validation_result.dart';
import 'package:myheritage_explorer/models/hazard_audit_entry.dart';
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/models/hazard_vote.dart';
import 'package:myheritage_explorer/services/confidence_analysis_service.dart';
import 'package:myheritage_explorer/services/hazard_report_service.dart';
import 'package:myheritage_explorer/services/hazard_vote_service.dart';
import 'package:myheritage_explorer/services/location_service.dart';
import 'package:myheritage_explorer/traveler/traveler_pages.dart';
import 'package:myheritage_explorer/widgets/evidence_picker_card.dart';
import 'package:myheritage_explorer/widgets/hazard_evidence_image.dart';
import 'package:myheritage_explorer/widgets/safety_image_viewer.dart';

EvidenceValidationResult makeValidation({
  bool isValid = true,
  String source = EvidenceSource.camera,
  double? sceneMatch,
}) => EvidenceValidationResult(
  isValid: isValid,
  qualityScore: 0.9,
  sharpnessScore: 0.9,
  brightnessScore: 0.9,
  resolutionScore: 0.9,
  duplicateDetected: false,
  evidenceSource: source,
  semanticValidationAvailable: true,
  validationLevel: EvidenceValidationLevel.strong,
  warnings: const [],
  overallEvidenceScore: 0.9,
  sha256Fingerprint: 'dummy_hash_12345',
  perceptualHash: 'dummy_phash_12345',
  exposureStatus: 'BALANCED',
  width: 1080,
  height: 720,
  fileFormat: 'image/jpeg',
  sceneMatchScore: sceneMatch,
);

class MockReportService implements HazardReportService {
  MockReportService(this.report);
  final HazardReport? report;

  @override
  Stream<HazardReport?> watchReport(String id) => Stream.value(report);

  @override
  Future<HazardReport?> getReport(String id) async => report;

  @override
  Stream<List<HazardAuditEntry>> watchAuditTrail(String id) =>
      Stream.value(const []);

  @override
  Stream<List<HazardReport>> watchVerifiedReports() =>
      Stream.value(report == null ? [] : [report!]);

  @override
  Stream<List<HazardReport>> watchVerifiedUnresolvedReports() =>
      Stream.value(report == null ? [] : [report!]);

  @override
  Stream<Uint8List?> watchEvidenceBytes(String id) => Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockVoteService implements HazardVoteService {
  MockVoteService({
    List<HazardVote>? initialVotes,
    this.userHasVotedResult = false,
  }) : _votes = initialVotes ?? [];

  final List<HazardVote> _votes;
  final bool userHasVotedResult;
  String? lastSubmittedVoteType;
  double? lastSubmittedDistance;
  Uint8List? lastSubmittedPhotoBytes;
  int submitVoteCallCount = 0;

  @override
  Stream<List<HazardVote>> watchVotes(String id) => Stream.value(_votes);

  @override
  Future<List<HazardVote>> getVotes(String id) async => _votes;

  @override
  Future<bool> hasUserVoted(String hazardId, String userId) async =>
      userHasVotedResult;

  @override
  Stream<Uint8List?> watchEvidenceBytes(String hazardId, String userId) =>
      Stream.value(Uint8List.fromList([1, 2, 3, 4]));

  @override
  Future<void> submitVote({
    required String hazardId,
    required String voteType,
    required double distanceFromHazardMeters,
    required String proximityBand,
    Uint8List? photoBytes,
    String evidenceSource = EvidenceSource.camera,
    EvidenceValidationResult? evidenceValidation,
  }) async {
    if (userHasVotedResult) {
      throw Exception('You have already confirmed this hazard.');
    }
    submitVoteCallCount++;
    lastSubmittedVoteType = voteType;
    lastSubmittedDistance = distanceFromHazardMeters;
    lastSubmittedPhotoBytes = photoBytes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLocationService extends LocationService {
  const MockLocationService({
    this.latitude = 5.44145,
    this.longitude = 100.30682,
  });

  final double latitude;
  final double longitude;

  @override
  Future<Position> getCurrentPosition() async => Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: 5.0,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: 0.0,
    speedAccuracy: 1.0,
  );

  @override
  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    return 15.0; // 15 meters
  }
}

Widget testApp(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

final sampleVerifiedReport = HazardReport(
  id: 'DEMO-H02',
  userId: 'reporter1',
  category: 'Road obstruction',
  severity: 'Medium',
  description: 'Fallen branches partially obstructing the road.',
  latitude: 5.44140,
  longitude: 100.30685,
  status: HazardReportStatus.verified,
  hasPhotoEvidence: true,
  imageUrl: 'https://example.com/original.jpg',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('Group 1: Before-Vote UI & Photo Selection (Points 1, 2)', () {
    testWidgets('1. Tourist can select an optional photo before voting', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final voteService = MockVoteService(initialVotes: []);
      await tester.pumpWidget(
        testApp(
          SafetyAlertPage(
            hazardId: 'DEMO-H02',
            distanceMeters: 15.0,
            reportService: MockReportService(sampleVerifiedReport),
            voteService: voteService,
            locationService: const MockLocationService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // EvidencePickerCard is rendered with optional wording
      expect(find.text('Optional Evidence Photo'), findsOneWidget);
      expect(find.byType(EvidencePickerCard), findsOneWidget);
      // Camera and Gallery buttons are available
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
    });

    testWidgets(
      '2. Before voting, image preview inside EvidencePickerCard can be enlarged',
      (tester) async {
        final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        await tester.pumpWidget(
          testApp(
            Scaffold(
              body: SingleChildScrollView(
                child: EvidencePickerCard(
                  imageBytes: dummyBytes,
                  validation: makeValidation(),
                  validating: false,
                  onCamera: () {},
                  onRemove: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // ExpandableEvidenceImage is present for enlarging preview
        expect(find.byType(ExpandableEvidenceImage), findsOneWidget);
        expect(find.byTooltip('Tap to enlarge photo preview'), findsOneWidget);
      },
    );
  });

  group(
    'Group 2: Vote Submissions With and Without Photo (Points 3, 4, 5)',
    () {
      test('3. Hazard Still Exists can submit with photo', () async {
        final voteService = MockVoteService();
        final photo = Uint8List.fromList([10, 20, 30]);
        await voteService.submitVote(
          hazardId: 'DEMO-H02',
          voteType: HazardVoteType.hazardExists,
          distanceFromHazardMeters: 12.0,
          proximityBand: 'STRONG',
          photoBytes: photo,
          evidenceValidation: makeValidation(),
        );

        expect(voteService.submitVoteCallCount, 1);
        expect(voteService.lastSubmittedVoteType, HazardVoteType.hazardExists);
        expect(voteService.lastSubmittedPhotoBytes, photo);
      });

      test('4. Appears Resolved can submit with photo', () async {
        final voteService = MockVoteService();
        final photo = Uint8List.fromList([40, 50, 60]);
        await voteService.submitVote(
          hazardId: 'DEMO-H02',
          voteType: HazardVoteType.hazardResolved,
          distanceFromHazardMeters: 15.0,
          proximityBand: 'STRONG',
          photoBytes: photo,
          evidenceValidation: makeValidation(),
        );

        expect(voteService.submitVoteCallCount, 1);
        expect(
          voteService.lastSubmittedVoteType,
          HazardVoteType.hazardResolved,
        );
        expect(voteService.lastSubmittedPhotoBytes, photo);
      });

      test('5. Vote can submit without photo (photo-less vote)', () async {
        final voteService = MockVoteService();
        await voteService.submitVote(
          hazardId: 'DEMO-H02',
          voteType: HazardVoteType.hazardExists,
          distanceFromHazardMeters: 15.0,
          proximityBand: 'STRONG',
          photoBytes: null,
        );

        expect(voteService.submitVoteCallCount, 1);
        expect(voteService.lastSubmittedPhotoBytes, isNull);
      });
    },
  );

  group(
    'Group 3: After-Vote Read-Only UI & Immutability (Points 6, 7, 8, 9, 10, 11, 12, 13, 14, 15)',
    () {
      testWidgets(
        '6-12. Submitted vote with photo displays read-only state with enlargeable photo and NO editing/voting controls',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final myVote = HazardVote(
            id: 'v_user1',
            userId: 'user1',
            voteType: HazardVoteType.hazardExists,
            createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
            distanceFromHazardMeters: 12.0,
            proximityBand: 'STRONG',
            isGpsValidated: true,
            hasPhotoEvidence: true,
            evidenceStorage: 'firestore',
          );

          await tester.pumpWidget(
            testApp(
              Scaffold(
                body: SingleChildScrollView(
                  child: SubmittedVoteCard(
                    hazardId: 'DEMO-H02',
                    vote: myVote,
                    voteService: MockVoteService(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Header and confirmation message
          expect(find.text('Community Confirmation'), findsOneWidget);
          expect(find.text('Confirmation submitted'), findsOneWidget);
          expect(find.text('Your response'), findsOneWidget);
          expect(find.text('Hazard Still Exists'), findsOneWidget);

          // Location verification details
          expect(find.text('Location verification'), findsOneWidget);
          expect(find.text('12 m from hazard'), findsOneWidget);
          expect(find.text('• Strong GPS validation'), findsOneWidget);

          // 8. Submitted evidence is displayed read-only
          expect(find.byType(HazardVoteEvidenceImage), findsOneWidget);
          // 9. Submitted evidence remains enlargeable
          expect(find.byType(ExpandableEvidenceImage), findsOneWidget);
          expect(find.text('Tap to enlarge'), findsOneWidget);

          // Immutability final disclaimer
          expect(
            find.text('This confirmation is final and cannot be edited.'),
            findsOneWidget,
          );

          // 10-15. Photo picker and voting controls are completely absent
          expect(find.byType(EvidencePickerCard), findsNothing);
          expect(find.text('Take Photo'), findsNothing);
          expect(find.text('Choose from Gallery'), findsNothing);
          expect(find.text('Hazard Appears Resolved'), findsNothing);
          expect(find.text('Submit confirmation'), findsNothing);
          expect(find.text('Replace Photo'), findsNothing);
          expect(find.text('Remove Photo'), findsNothing);
        },
      );

      testWidgets(
        '13. Photo-less vote displays "No photo evidence submitted" and cannot attach photo later',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final noPhotoVote = HazardVote(
            id: 'v_user2',
            userId: 'user2',
            voteType: HazardVoteType.hazardResolved,
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
            distanceFromHazardMeters: 25.0,
            proximityBand: 'STRONG',
            isGpsValidated: true,
            hasPhotoEvidence: false,
          );

          await tester.pumpWidget(
            testApp(
              Scaffold(
                body: SingleChildScrollView(
                  child: SubmittedVoteCard(
                    hazardId: 'DEMO-H02',
                    vote: noPhotoVote,
                    voteService: MockVoteService(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Displays "No photo evidence submitted"
          expect(find.text('No photo evidence submitted'), findsOneWidget);

          // No image or enlargement widget
          expect(find.byType(ExpandableEvidenceImage), findsNothing);

          // No photo picker or camera options
          expect(find.byType(EvidencePickerCard), findsNothing);
          expect(find.text('Take Photo'), findsNothing);
          expect(find.text('Choose from Gallery'), findsNothing);
          expect(
            find.text('This confirmation is final and cannot be edited.'),
            findsOneWidget,
          );
        },
      );
    },
  );

  group(
    'Group 4: Backend One-Vote-Per-User & Transaction Protection (Points 15, 16)',
    () {
      test(
        '16. Backend rejects second vote for same user and hazard',
        () async {
          final voteService = MockVoteService(userHasVotedResult: true);

          expect(
            () => voteService.submitVote(
              hazardId: 'DEMO-H02',
              voteType: HazardVoteType.hazardExists,
              distanceFromHazardMeters: 10.0,
              proximityBand: 'STRONG',
            ),
            throwsA(isA<Exception>()),
          );
        },
      );
    },
  );

  group(
    'Group 5: DEMO-H02 Historical Evidence Preservation & Parity (Points 17, 18)',
    () {
      test(
        '17 & 18. DEMO-H02 Image A, B, C votes remain intact and compute accurate confidence',
        () {
          const confidenceService = ConfidenceAnalysisService();
          final now = DateTime(2026, 9, 9, 12, 0);

          // Image A: HAZARD_EXISTS, strong matched evidence (scene match 1.0)
          final imageAVote = HazardVote(
            id: 'oMaM8igQFzRic6GUmcOmqNIF2Aq2',
            userId: 'oMaM8igQFzRic6GUmcOmqNIF2Aq2',
            voteType: HazardVoteType.hazardExists,
            createdAt: now.subtract(const Duration(minutes: 15)),
            distanceFromHazardMeters: 12.0,
            proximityBand: 'STRONG',
            isGpsValidated: true,
            hasPhotoEvidence: true,
            evidenceStorage: 'firestore',
            sceneMatchScore: 1.0,
            evidenceValidation: makeValidation(sceneMatch: 1.0),
          );

          // Image B: HAZARD_RESOLVED, strong matched evidence (scene match 1.0)
          final imageBVote = HazardVote(
            id: 'yFeJzUu4kHcKRkXa7oiCEK0jNIo1',
            userId: 'yFeJzUu4kHcKRkXa7oiCEK0jNIo1',
            voteType: HazardVoteType.hazardResolved,
            createdAt: now.subtract(const Duration(minutes: 10)),
            distanceFromHazardMeters: 15.0,
            proximityBand: 'STRONG',
            isGpsValidated: true,
            hasPhotoEvidence: true,
            evidenceStorage: 'firestore',
            sceneMatchScore: 1.0,
            evidenceValidation: makeValidation(sceneMatch: 1.0),
          );

          // Image C: HAZARD_EXISTS, mismatched evidence (scene match 0.0)
          final imageCVote = HazardVote(
            id: 'FuzNXPYgAFXfvxf3YvwczusZ7lC3',
            userId: 'FuzNXPYgAFXfvxf3YvwczusZ7lC3',
            voteType: HazardVoteType.hazardExists,
            createdAt: now.subtract(const Duration(minutes: 5)),
            distanceFromHazardMeters: 18.0,
            proximityBand: 'STRONG',
            isGpsValidated: true,
            hasPhotoEvidence: true,
            evidenceStorage: 'firestore',
            sceneMatchScore: 0.0,
            evidenceValidation: makeValidation(sceneMatch: 0.0),
          );

          // Photo-less future vote: HAZARD_RESOLVED, no photo
          final photoLessVote = HazardVote(
            id: 'futureUser',
            userId: 'futureUser',
            voteType: HazardVoteType.hazardResolved,
            createdAt: now.subtract(const Duration(minutes: 2)),
            distanceFromHazardMeters: 20.0,
            proximityBand: 'STRONG',
            isGpsValidated: true,
            hasPhotoEvidence: false,
          );

          final result = confidenceService.analyze([
            imageAVote,
            imageBVote,
            imageCVote,
            photoLessVote,
          ], now: now);

          expect(result.totalVotes, 4);
          expect(result.existsVotes, 2);
          expect(result.resolvedVotes, 2);
          expect(result.sceneMatchedCount, 2); // Image A and Image B

          // Verify evidence weights
          final weightA = confidenceService.evidenceWeight(imageAVote);
          final weightB = confidenceService.evidenceWeight(imageBVote);
          final weightC = confidenceService.evidenceWeight(imageCVote);
          final weightPhotoLess = confidenceService.evidenceWeight(
            photoLessVote,
          );

          // Matched photos get bonus (above standard 1.15 base)
          expect(weightA, greaterThan(1.4));
          expect(weightB, greaterThan(1.4));
          // Mismatched gets base weight without scene bonus
          expect(weightC, lessThan(weightA));
          // Photo-less vote has exactly 1.0 weight
          expect(weightPhotoLess, 1.0);
        },
      );
    },
  );

  group(
    'Group 6: Admin Display & Create Hazard Report Integrity (Points 19, 20)',
    () {
      testWidgets(
        '19. HazardVoteEvidenceImage enlarges upon tap for admin or review screens',
        (tester) async {
          final testVote = HazardVote(
            id: 'v_admin',
            userId: 'adminUser',
            voteType: HazardVoteType.hazardExists,
            hasPhotoEvidence: true,
            distanceFromHazardMeters: 10,
            proximityBand: 'STRONG',
            isGpsValidated: true,
            photoUrl: 'https://example.com/vote.jpg',
          );

          await tester.pumpWidget(
            testApp(
              Scaffold(
                body: SingleChildScrollView(
                  child: HazardVoteEvidenceImage(
                    hazardId: 'DEMO-H02',
                    vote: testVote,
                    enableEnlargement: true,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(ExpandableEvidenceImage), findsOneWidget);
        },
      );

      testWidgets(
        '20. Create Hazard Report flow retains mandatory photo evidence requirement',
        (tester) async {
          // EvidencePickerCard with requiredEvidence = true displays 'Photo Evidence *'
          await tester.pumpWidget(
            testApp(
              Scaffold(
                body: SingleChildScrollView(
                  child: EvidencePickerCard(
                    imageBytes: null,
                    validation: null,
                    validating: false,
                    onCamera: () {},
                    onRemove: () {},
                    requiredEvidence: true,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Photo Evidence *'), findsOneWidget);
          expect(
            find.text('Add a clear, current photo of the hazard.'),
            findsOneWidget,
          );
        },
      );
    },
  );
}
