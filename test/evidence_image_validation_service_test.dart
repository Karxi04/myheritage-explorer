import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:myheritage_explorer/models/evidence_validation_result.dart';
import 'package:myheritage_explorer/services/evidence_image_validation_service.dart';

void main() {
  Uint8List encode(image_lib.Image image) =>
      Uint8List.fromList(image_lib.encodeJpg(image, quality: 92));

  image_lib.Image checkerboard({int size = 900}) {
    final image = image_lib.Image(width: size, height: size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final light = ((x ~/ 18) + (y ~/ 18)).isEven;
        image.setPixelRgb(
          x,
          y,
          light ? 230 : 35,
          light ? 220 : 45,
          light ? 190 : 70,
        );
      }
    }
    return image;
  }

  test('clear supported image is accepted with useful quality', () {
    final result = validateEvidenceImage(
      encode(checkerboard()),
      evidenceSource: EvidenceSource.camera,
    );

    expect(result.isValid, isTrue);
    expect(result.canSubmit, isTrue);
    expect(
      result.validationLevel,
      isIn([EvidenceValidationLevel.strong, EvidenceValidationLevel.good]),
    );
    expect(result.semanticValidationAvailable, isFalse);
  });

  test('very blurry image is retained but classified low quality', () {
    final image = image_lib.Image(width: 900, height: 900);
    image_lib.fill(image, color: image_lib.ColorRgb8(120, 125, 130));

    final result = validateEvidenceImage(
      encode(image),
      evidenceSource: EvidenceSource.camera,
    );

    expect(result.isValid, isTrue);
    expect(result.validationLevel, EvidenceValidationLevel.lowQuality);
    expect(result.warnings.join(' '), contains('blurry'));
  });

  test('very dark evidence warns without being automatically invalid', () {
    final image = image_lib.Image(width: 900, height: 900);
    image_lib.fill(image, color: image_lib.ColorRgb8(8, 9, 12));

    final result = validateEvidenceImage(
      encode(image),
      evidenceSource: EvidenceSource.camera,
    );

    expect(result.isValid, isTrue);
    expect(result.exposureStatus, 'VERY_DARK');
    expect(result.warnings.join(' '), contains('dark'));
  });

  test('corrupted or unsupported bytes are rejected', () {
    final result = validateEvidenceImage(
      Uint8List.fromList([1, 2, 3, 4, 5]),
      evidenceSource: EvidenceSource.gallery,
    );

    expect(result.isValid, isFalse);
    expect(result.validationLevel, EvidenceValidationLevel.invalid);
  });

  test('image below minimum dimensions is rejected', () {
    final image = image_lib.Image(width: 100, height: 120);
    image_lib.fill(image, color: image_lib.ColorRgb8(80, 120, 160));

    final result = validateEvidenceImage(
      encode(image),
      evidenceSource: EvidenceSource.gallery,
    );

    expect(result.isValid, isFalse);
    expect(result.warnings.join(' '), contains('too small'));
  });

  test('overexposed image stays usable without an evidence bonus', () {
    final image = image_lib.Image(width: 900, height: 900);
    image_lib.fill(image, color: image_lib.ColorRgb8(255, 255, 255));
    final result = validateEvidenceImage(
      encode(image),
      evidenceSource: EvidenceSource.gallery,
    );
    expect(result.exposureStatus, 'OVEREXPOSED');
    expect(result.canSubmit, isTrue);
    expect(result.earnsEvidenceBonus, isFalse);
  });

  test('empty, oversized and unknown-source images are rejected', () {
    expect(
      validateEvidenceImage(
        Uint8List(0),
        evidenceSource: EvidenceSource.camera,
      ).canSubmit,
      isFalse,
    );
    expect(
      validateEvidenceImage(
        Uint8List(12 * 1024 * 1024 + 1),
        evidenceSource: EvidenceSource.camera,
      ).canSubmit,
      isFalse,
    );
    expect(
      validateEvidenceImage(
        encode(checkerboard()),
        evidenceSource: 'UNKNOWN',
      ).canSubmit,
      isFalse,
    );
  });

  test('re-encoded image is detected by perceptual hash', () {
    final original = image_lib.Image(width: 900, height: 900);
    for (var y = 0; y < 900; y++) {
      for (var x = 0; x < 900; x++) {
        final shade = 30 + (x * 200 ~/ 900);
        original.setPixelRgb(x, y, shade, shade, shade);
      }
    }
    final first = validateEvidenceImage(
      encode(original),
      evidenceSource: EvidenceSource.camera,
    );
    final second = validateEvidenceImage(
      Uint8List.fromList(image_lib.encodePng(original)),
      evidenceSource: EvidenceSource.gallery,
      existingPerceptualHashes: [first.perceptualHash],
    );
    expect(second.sha256Fingerprint, isNot(first.sha256Fingerprint));
    expect(second.duplicateDetected, isTrue);
    expect(second.canSubmit, isFalse);
  });

  test('scene matching handles every boundary and malformed hashes', () {
    const reference = '0000000000000000';
    for (final entry in {
      0: 1.0,
      4: 1.0,
      5: .7,
      8: .7,
      9: .4,
      14: .4,
      15: 0.0,
      64: 0.0,
    }.entries) {
      final hash = ((BigInt.one << entry.key) - BigInt.one)
          .toRadixString(16)
          .padLeft(16, '0');
      expect(
        EvidenceImageValidationService.computeSceneMatchScore(reference, hash),
        entry.value,
      );
    }
    expect(
      EvidenceImageValidationService.computeSceneMatchScore(reference, ''),
      0,
    );
    expect(
      EvidenceImageValidationService.computeSceneMatchScore(
        'invalid',
        reference,
      ),
      0,
    );
    final result = validateEvidenceImage(
      encode(checkerboard()),
      evidenceSource: EvidenceSource.camera,
    ).withSceneMatchScore(null);
    expect(result.sceneMatchScore, isNull);
    expect(
      EvidenceValidationResult.fromMap(result.toMap()).sceneMatchScore,
      isNull,
    );
  });

  test('exactly reused evidence is classified as possible duplicate', () {
    final bytes = encode(checkerboard());
    final first = validateEvidenceImage(
      bytes,
      evidenceSource: EvidenceSource.camera,
    );
    final duplicate = validateEvidenceImage(
      bytes,
      evidenceSource: EvidenceSource.camera,
      existingSha256Fingerprints: [first.sha256Fingerprint],
    );

    expect(duplicate.duplicateDetected, isTrue);
    expect(duplicate.canSubmit, isFalse);
    expect(
      duplicate.validationLevel,
      EvidenceValidationLevel.possibleDuplicate,
    );
  });
}
