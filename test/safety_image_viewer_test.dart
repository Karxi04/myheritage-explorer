import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:myheritage_explorer/models/hazard_report.dart';
import 'package:myheritage_explorer/widgets/evidence_picker_card.dart';
import 'package:myheritage_explorer/widgets/hazard_evidence_image.dart';
import 'package:myheritage_explorer/widgets/safety_image_viewer.dart';

Uint8List createTestPngBytes() {
  final img = image_lib.Image(width: 20, height: 20);
  image_lib.fill(img, color: image_lib.ColorRgb8(200, 50, 50));
  return Uint8List.fromList(image_lib.encodePng(img));
}

void main() {
  final testBytes = createTestPngBytes();

  group('SafetyImageViewer', () {
    testWidgets(
      'renders InteractiveViewer with expected zoom constraints and close button',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SafetyImageViewer.showBytes(
                    context,
                    bytes: testBytes,
                    title: 'Fallen Branch Obstruction',
                    subtitle: 'Status: Verified',
                  ),
                  child: const Text('Open Viewer'),
                ),
              ),
            ),
          ),
        );

        // Initially viewer is closed
        expect(find.byType(SafetyImageViewer), findsNothing);

        // Open viewer
        await tester.tap(find.text('Open Viewer'));
        await tester.pumpAndSettle();

        expect(find.byType(SafetyImageViewer), findsOneWidget);
        expect(find.text('Fallen Branch Obstruction'), findsOneWidget);
        expect(find.text('Status: Verified'), findsOneWidget);

        // Verify InteractiveViewer configuration
        final interactiveViewer = tester.widget<InteractiveViewer>(
          find.byType(InteractiveViewer),
        );
        expect(interactiveViewer.minScale, 1.0);
        expect(interactiveViewer.maxScale, 5.0);

        // Verify close button exists with proper semantics and closes dialog
        final closeButtonFinder = find.byTooltip('Close image viewer');
        expect(closeButtonFinder, findsOneWidget);
        await tester.tap(closeButtonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(SafetyImageViewer), findsNothing);
      },
    );

    testWidgets('Escape key closes SafetyImageViewer dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SafetyImageViewer.showBytes(
                  context,
                  bytes: testBytes,
                  title: 'Escape Test',
                ),
                child: const Text('Open Viewer'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Viewer'));
      await tester.pumpAndSettle();
      expect(find.byType(SafetyImageViewer), findsOneWidget);

      // Simulate pressing Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(SafetyImageViewer), findsNothing);
    });

    testWidgets(
      'handles corrupt or broken image safely with error placeholder',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SafetyImageViewer.showBytes(
                    context,
                    bytes: Uint8List.fromList([1, 2, 3, 4, 5]), // Corrupt bytes
                    title: 'Corrupted Photo',
                  ),
                  child: const Text('Open Broken'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Broken'));
        await tester.pumpAndSettle();

        expect(find.byType(SafetyImageViewer), findsOneWidget);
        expect(
          find.text('Evidence image could not be loaded.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);

        // Still closes cleanly
        await tester.tap(find.byTooltip('Close image viewer'));
        await tester.pumpAndSettle();
        expect(find.byType(SafetyImageViewer), findsNothing);
      },
    );
  });

  group('ExpandableEvidenceImage', () {
    testWidgets(
      'shows enlargement affordance when enabled and opens viewer on tap',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ExpandableEvidenceImage(
                imageProvider: MemoryImage(testBytes),
                title: 'Road Obstruction',
                child: Image.memory(testBytes, width: 120, height: 90),
              ),
            ),
          ),
        );

        // Affordance label & icon exist
        expect(find.text('Enlarge'), findsOneWidget);
        expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);

        // Tap to open
        await tester.tap(find.text('Enlarge'));
        await tester.pumpAndSettle();

        expect(find.byType(SafetyImageViewer), findsOneWidget);
        expect(find.text('Road Obstruction'), findsOneWidget);

        // Close
        await tester.tap(find.byTooltip('Close image viewer'));
        await tester.pumpAndSettle();
        expect(find.byType(SafetyImageViewer), findsNothing);
      },
    );

    testWidgets('suppresses affordance and tap when enabled is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpandableEvidenceImage(
              enabled: false,
              imageProvider: MemoryImage(testBytes),
              title: 'Disabled Viewer',
              child: const Text('Plain Child'),
            ),
          ),
        ),
      );

      expect(find.text('Enlarge'), findsNothing);
      expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);

      await tester.tap(find.text('Plain Child'));
      await tester.pumpAndSettle();

      expect(find.byType(SafetyImageViewer), findsNothing);
    });
  });

  group('HazardEvidenceImage Integration', () {
    testWidgets(
      'missing photo evidence renders placeholder without enlargement control',
      (tester) async {
        const report = HazardReport(
          id: 'DEMO-NO-PHOTO',
          userId: 'user-1',
          category: 'Poor lighting',
          severity: 'Low',
          description: 'Street light broken',
          latitude: 5.42,
          longitude: 100.32,
          status: HazardReportStatus.pendingReview,
          hasPhotoEvidence: false,
          imageUrl: null,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: HazardEvidenceImage(report: report)),
          ),
        );

        expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
        expect(find.byType(ExpandableEvidenceImage), findsNothing);
        expect(find.text('Enlarge'), findsNothing);
      },
    );
  });

  group('Confidence Benchmark Independent Enlargement', () {
    testWidgets(
      'original evidence and community evidence enlarge independently',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ExpandableEvidenceImage(
                    imageProvider: MemoryImage(testBytes),
                    title: 'Original Hazard Evidence',
                    subtitle: 'Submitted by traveler',
                    child: Container(
                      key: const Key('original_hazard_thumbnail'),
                      width: 200,
                      height: 150,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ExpandableEvidenceImage(
                    imageProvider: MemoryImage(testBytes),
                    title: 'Community Evidence Photo',
                    subtitle: 'Report update: Hazard Still Exists',
                    child: Container(
                      key: const Key('community_vote_thumbnail'),
                      width: 200,
                      height: 150,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // 1. Tap original hazard evidence
        await tester.tap(find.byKey(const Key('original_hazard_thumbnail')));
        await tester.pumpAndSettle();

        expect(find.byType(SafetyImageViewer), findsOneWidget);
        expect(find.text('Original Hazard Evidence'), findsOneWidget);
        expect(find.text('Submitted by traveler'), findsOneWidget);
        expect(find.text('Community Evidence Photo'), findsNothing);

        // Close original evidence viewer
        await tester.tap(find.byTooltip('Close image viewer'));
        await tester.pumpAndSettle();
        expect(find.byType(SafetyImageViewer), findsNothing);

        // 2. Tap community evidence photo
        await tester.tap(find.byKey(const Key('community_vote_thumbnail')));
        await tester.pumpAndSettle();

        expect(find.byType(SafetyImageViewer), findsOneWidget);
        expect(find.text('Community Evidence Photo'), findsOneWidget);
        expect(find.text('Report update: Hazard Still Exists'), findsOneWidget);
        expect(find.text('Original Hazard Evidence'), findsNothing);

        // Close community evidence viewer
        await tester.tap(find.byTooltip('Close image viewer'));
        await tester.pumpAndSettle();
        expect(find.byType(SafetyImageViewer), findsNothing);
      },
    );
  });

  group('EvidencePickerCard Integration', () {
    testWidgets('selected photo preview is expandable with custom tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EvidencePickerCard(
                imageBytes: testBytes,
                validation: null,
                validating: false,
                onCamera: () {},
                onRemove: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Enlarge'), findsOneWidget);

      // Tap preview to open viewer
      await tester.tap(find.text('Enlarge'));
      await tester.pumpAndSettle();

      expect(find.byType(SafetyImageViewer), findsOneWidget);
      expect(find.text('Captured Photo Evidence'), findsOneWidget);

      // Close
      await tester.tap(find.byTooltip('Close image viewer'));
      await tester.pumpAndSettle();
      expect(find.byType(SafetyImageViewer), findsNothing);
    });
  });
}
