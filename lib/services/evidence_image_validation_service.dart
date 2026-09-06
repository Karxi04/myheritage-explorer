import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_lib;

import '../core/safety_config.dart';
import '../models/evidence_validation_result.dart';

class EvidenceImageValidationService {
  const EvidenceImageValidationService();

  static bool isValidPerceptualHash(String hash) =>
      RegExp(r'^[0-9a-fA-F]{16}$').hasMatch(hash);

  Future<EvidenceValidationResult> validate({
    required Uint8List bytes,
    required String evidenceSource,
    Iterable<String> existingSha256Fingerprints = const [],
    Iterable<String> existingPerceptualHashes = const [],
  }) async {
    final result = await compute(_validateEvidenceRequest, {
      'bytes': bytes,
      'evidenceSource': evidenceSource,
      'sha256Fingerprints': existingSha256Fingerprints.toList(),
      'perceptualHashes': existingPerceptualHashes.toList(),
    });
    return EvidenceValidationResult.fromMap(result);
  }

  /// Compute a [0,1] scene-match score between two perceptual hashes.
  /// Higher score = more visually similar scenes.
  static double computeSceneMatchScore(String voteHash, String referenceHash) {
    final distance = _hashDistance(voteHash, referenceHash);
    if (distance <= SafetyConfig.strongSceneMatchMaxDistance) return 1.0;
    if (distance <= SafetyConfig.partialSceneMatchMaxDistance) return 0.7;
    if (distance <= SafetyConfig.weakSceneMatchMaxDistance) return 0.4;
    return 0.0;
  }
}

Map<String, dynamic> _validateEvidenceRequest(Map<String, dynamic> request) {
  final bytes = request['bytes'] as Uint8List;
  final source = '${request['evidenceSource']}';
  final existingSha = Set<String>.from(
    request['sha256Fingerprints'] as List? ?? const [],
  );
  final existingPerceptual = Set<String>.from(
    request['perceptualHashes'] as List? ?? const [],
  );
  return validateEvidenceImage(
    bytes,
    evidenceSource: source,
    existingSha256Fingerprints: existingSha,
    existingPerceptualHashes: existingPerceptual,
  ).toMap();
}

@visibleForTesting
EvidenceValidationResult validateEvidenceImage(
  Uint8List bytes, {
  required String evidenceSource,
  Iterable<String> existingSha256Fingerprints = const [],
  Iterable<String> existingPerceptualHashes = const [],
}) {
  final sha = sha256.convert(bytes).toString();
  if (!EvidenceSource.values.contains(evidenceSource)) {
    return _invalidResult(
      sha: sha,
      source: evidenceSource,
      warning: 'The image capture source could not be verified.',
    );
  }
  if (bytes.isEmpty ||
      bytes.lengthInBytes > SafetyConfig.maxSourceEvidenceBytes) {
    return _invalidResult(
      sha: sha,
      source: evidenceSource,
      warning: bytes.isEmpty
          ? 'The selected file is empty.'
          : 'The selected image is too large. Choose an image below 12 MB.',
    );
  }

  final format = _supportedFormat(bytes);
  if (format == null) {
    return _invalidResult(
      sha: sha,
      source: evidenceSource,
      warning: 'Choose a JPEG, PNG or WebP image.',
    );
  }

  image_lib.Image? decoded;
  try {
    decoded = image_lib.decodeImage(bytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    return _invalidResult(
      sha: sha,
      source: evidenceSource,
      fileFormat: format,
      warning: 'The selected image is corrupted or cannot be decoded.',
    );
  }

  final image = image_lib.bakeOrientation(decoded);
  final minDimension = math.min(image.width, image.height);
  if (minDimension < SafetyConfig.minimumEvidenceDimensionPixels) {
    return _invalidResult(
      sha: sha,
      source: evidenceSource,
      width: image.width,
      height: image.height,
      fileFormat: format,
      warning:
          'This image is too small to review. Choose a higher-resolution photo.',
    );
  }

  final sample = image_lib.copyResize(
    image,
    width: 128,
    height: 128,
    interpolation: image_lib.Interpolation.average,
  );
  final luminance = List<double>.filled(sample.width * sample.height, 0);
  var luminanceTotal = 0.0;
  var darkPixels = 0;
  var brightPixels = 0;
  for (var y = 0; y < sample.height; y++) {
    for (var x = 0; x < sample.width; x++) {
      final pixel = sample.getPixel(x, y);
      final value = (.2126 * pixel.r + .7152 * pixel.g + .0722 * pixel.b) / 255;
      luminance[y * sample.width + x] = value;
      luminanceTotal += value;
      if (value < .06) darkPixels++;
      if (value > .96) brightPixels++;
    }
  }

  final pixelCount = sample.width * sample.height;
  final brightness = (luminanceTotal / pixelCount).clamp(0.0, 1.0);
  final darkRatio = darkPixels / pixelCount;
  final brightRatio = brightPixels / pixelCount;
  final exposureStatus = _exposureStatus(
    brightness,
    darkRatio: darkRatio,
    brightRatio: brightRatio,
  );
  final exposureQuality = _exposureQuality(brightness);

  var laplacianTotal = 0.0;
  var laplacianCount = 0;
  for (var y = 1; y < sample.height - 1; y++) {
    for (var x = 1; x < sample.width - 1; x++) {
      final center = luminance[y * sample.width + x];
      final laplacian =
          (4 * center -
                  luminance[y * sample.width + x - 1] -
                  luminance[y * sample.width + x + 1] -
                  luminance[(y - 1) * sample.width + x] -
                  luminance[(y + 1) * sample.width + x])
              .abs();
      laplacianTotal += laplacian;
      laplacianCount++;
    }
  }
  final sharpness = (laplacianTotal / math.max(1, laplacianCount) * 3).clamp(
    0.0,
    1.0,
  );
  final sharpnessQuality = (sharpness / SafetyConfig.goodSharpnessScore).clamp(
    0.0,
    1.0,
  );
  final resolution =
      (minDimension / SafetyConfig.recommendedEvidenceDimensionPixels).clamp(
        0.0,
        1.0,
      );
  final quality =
      (resolution * .25 + sharpnessQuality * .40 + exposureQuality * .35).clamp(
        0.0,
        1.0,
      );

  final perceptualHash = _averageHash(image);
  final duplicate =
      existingSha256Fingerprints.contains(sha) ||
      existingPerceptualHashes.any(
        (existing) => _hashDistance(existing, perceptualHash) <= 4,
      );
  final warnings = <String>[];
  if (sharpness < SafetyConfig.minimumUsableSharpnessScore) {
    warnings.add(
      'The image appears blurry. A clearer photo would be easier to review.',
    );
  }
  if (brightness < SafetyConfig.lowBrightness) {
    warnings.add(
      'The image is quite dark. Retake it with more light if it is safe to do so.',
    );
  } else if (brightness > SafetyConfig.highBrightness) {
    warnings.add(
      'The image appears overexposed. Some details may be difficult to review.',
    );
  }
  if (resolution < .55) {
    warnings.add(
      'The image resolution is low. A larger photo would provide clearer evidence.',
    );
  }
  if (duplicate) {
    warnings.insert(0, 'This image matches evidence used previously.');
  }

  final sourceReliability = evidenceSource == EvidenceSource.camera ? 1.0 : .8;
  final overall = duplicate
      ? 0.0
      : (quality * .85 + sourceReliability * .15).clamp(0.0, 1.0);
  final level = duplicate
      ? EvidenceValidationLevel.possibleDuplicate
      : sharpness < SafetyConfig.minimumUsableSharpnessScore ||
            exposureStatus == 'VERY_DARK' ||
            exposureStatus == 'OVEREXPOSED' ||
            resolution < .35
      ? EvidenceValidationLevel.lowQuality
      : quality >= .88
      ? EvidenceValidationLevel.strong
      : quality >= .70
      ? EvidenceValidationLevel.good
      : quality >= .50
      ? EvidenceValidationLevel.acceptable
      : EvidenceValidationLevel.lowQuality;

  return EvidenceValidationResult(
    isValid: true,
    qualityScore: quality,
    sharpnessScore: sharpness,
    brightnessScore: brightness,
    resolutionScore: resolution,
    duplicateDetected: duplicate,
    evidenceSource: evidenceSource,
    semanticValidationAvailable: false,
    validationLevel: level,
    warnings: warnings,
    overallEvidenceScore: overall,
    sha256Fingerprint: sha,
    perceptualHash: perceptualHash,
    exposureStatus: exposureStatus,
    width: image.width,
    height: image.height,
    fileFormat: format,
  );
}

EvidenceValidationResult _invalidResult({
  required String sha,
  required String source,
  required String warning,
  int width = 0,
  int height = 0,
  String fileFormat = 'UNKNOWN',
}) {
  return EvidenceValidationResult(
    isValid: false,
    qualityScore: 0,
    sharpnessScore: 0,
    brightnessScore: 0,
    resolutionScore: 0,
    duplicateDetected: false,
    evidenceSource: source,
    semanticValidationAvailable: false,
    validationLevel: EvidenceValidationLevel.invalid,
    warnings: [warning],
    overallEvidenceScore: 0,
    sha256Fingerprint: sha,
    perceptualHash: '',
    exposureStatus: 'UNKNOWN',
    width: width,
    height: height,
    fileFormat: fileFormat,
  );
}

String? _supportedFormat(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'JPEG';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return 'PNG';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'WEBP';
  }
  return null;
}

String _exposureStatus(
  double brightness, {
  required double darkRatio,
  required double brightRatio,
}) {
  if (brightness <= SafetyConfig.extremelyDarkBrightness || darkRatio > .88) {
    return 'VERY_DARK';
  }
  if (brightness < SafetyConfig.lowBrightness) return 'DARK';
  if (brightness >= SafetyConfig.extremelyBrightBrightness ||
      brightRatio > .88) {
    return 'OVEREXPOSED';
  }
  if (brightness > SafetyConfig.highBrightness) return 'BRIGHT';
  return 'BALANCED';
}

double _exposureQuality(double brightness) {
  if (brightness <= SafetyConfig.extremelyDarkBrightness ||
      brightness >= SafetyConfig.extremelyBrightBrightness) {
    return .25;
  }
  if (brightness < SafetyConfig.lowBrightness ||
      brightness > SafetyConfig.highBrightness) {
    return .60;
  }
  return 1.0;
}

String _averageHash(image_lib.Image source) {
  final tiny = image_lib.copyResize(
    source,
    width: 8,
    height: 8,
    interpolation: image_lib.Interpolation.average,
  );
  final values = <double>[];
  var total = 0.0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final pixel = tiny.getPixel(x, y);
      final luminance =
          (.2126 * pixel.r + .7152 * pixel.g + .0722 * pixel.b) / 255;
      values.add(luminance);
      total += luminance;
    }
  }
  final average = total / values.length;
  var bits = BigInt.zero;
  for (final value in values) {
    bits = (bits << 1) | (value >= average ? BigInt.one : BigInt.zero);
  }
  return bits.toRadixString(16).padLeft(16, '0');
}

int _hashDistance(String left, String right) {
  if (!EvidenceImageValidationService.isValidPerceptualHash(left) ||
      !EvidenceImageValidationService.isValidPerceptualHash(right)) {
    return 65;
  }
  try {
    var value = BigInt.parse(left, radix: 16) ^ BigInt.parse(right, radix: 16);
    var count = 0;
    while (value > BigInt.zero) {
      if ((value & BigInt.one) == BigInt.one) count++;
      value >>= 1;
    }
    return count;
  } catch (_) {
    return 65;
  }
}
