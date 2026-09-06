import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:myheritage_explorer/core/app_theme.dart';
import 'package:myheritage_explorer/models/evidence_validation_result.dart';
import 'package:myheritage_explorer/widgets/evidence_picker_card.dart';
import 'package:myheritage_explorer/widgets/safety_loading_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var font = 'Roboto';
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    if (Platform.isWindows) {
      final file = File('C:/Windows/Fonts/segoeui.ttf');
      if (file.existsSync()) {
        final loader = FontLoader('SafetyAuditFont');
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
        await loader.load();
        font = 'SafetyAuditFont';
      }
    }
  });
  final photo = Uint8List.fromList(
    img.encodePng(
      img.fill(
        img.Image(width: 480, height: 270),
        color: img.ColorRgb8(112, 143, 157),
      ),
    ),
  );
  const low = EvidenceValidationResult(
    isValid: true,
    qualityScore: .3,
    sharpnessScore: .01,
    brightnessScore: .4,
    resolutionScore: 1,
    duplicateDetected: false,
    evidenceSource: EvidenceSource.gallery,
    semanticValidationAvailable: false,
    validationLevel: EvidenceValidationLevel.lowQuality,
    warnings: ['A clearer photo would be easier to review.'],
    overallEvidenceScore: .3,
    sha256Fingerprint: '',
    perceptualHash: '',
    exposureStatus: 'BALANCED',
    width: 480,
    height: 270,
    fileFormat: 'PNG',
  );
  Widget page(Widget body, {double scale = 1}) => MaterialApp(
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
    home: RepaintBoundary(
      key: const ValueKey('capture'),
      child: Scaffold(
        appBar: AppBar(title: const Text('Report a Hazard')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: body,
        ),
      ),
    ),
  );
  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/safety-audit')
        ..createSync(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'camera/gallery actions and disabled submission state are accessible',
    (tester) async {
      var camera = 0, gallery = 0;
      await tester.pumpWidget(
        page(
          EvidencePickerCard(
            imageBytes: null,
            validation: null,
            validating: false,
            onCamera: () => camera++,
            onGallery: () => gallery++,
            onRemove: () {},
          ),
        ),
      );
      await tester.tap(find.text('Take Photo'));
      await tester.tap(find.text('Choose from Gallery'));
      expect(camera, 1);
      expect(gallery, 1);
      await tester.pumpWidget(
        page(
          EvidencePickerCard(
            imageBytes: null,
            validation: null,
            validating: false,
            enabled: false,
            onCamera: () => camera++,
            onGallery: () => gallery++,
            onRemove: () {},
          ),
        ),
      );
      await tester.tap(find.text('Take Photo'));
      expect(camera, 1);
    },
  );

  for (final width in [320.0, 390.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('evidence picker fits width $width with text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          page(
            EvidencePickerCard(
              imageBytes: photo,
              validation: low,
              validating: false,
              onCamera: () {},
              onGallery: () {},
              onRemove: () {},
            ),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (width == 390 && scale == 1) {
          await capture(tester, 'evidence-low-quality-mobile');
        }
      });
    }
  }
  testWidgets('corrupt preview shows recoverable feedback without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      page(
        EvidencePickerCard(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          validation: null,
          checkError: 'The photo could not be checked.',
          validating: false,
          onRetry: () {},
          onCamera: () {},
          onRemove: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Photo preview unavailable'), findsOneWidget);
    expect(find.text('Retry Photo Check'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('error state exposes a working retry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      page(
        SafetyErrorState(
          title: 'Unable to load reports',
          message: 'Check your connection and retry.',
          onRetry: () => retries++,
        ),
      ),
    );
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });
}
