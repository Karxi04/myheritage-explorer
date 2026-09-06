abstract final class EvidenceSource {
  static const camera = 'CAMERA';
  static const gallery = 'GALLERY';

  static const values = [camera, gallery];
}

abstract final class EvidenceValidationLevel {
  static const strong = 'STRONG';
  static const good = 'GOOD';
  static const acceptable = 'ACCEPTABLE';
  static const lowQuality = 'LOW_QUALITY';
  static const invalid = 'INVALID';
  static const possibleDuplicate = 'POSSIBLE_DUPLICATE';
}

class EvidenceValidationResult {
  const EvidenceValidationResult({
    required this.isValid,
    required this.qualityScore,
    required this.sharpnessScore,
    required this.brightnessScore,
    required this.resolutionScore,
    required this.duplicateDetected,
    required this.evidenceSource,
    required this.semanticValidationAvailable,
    required this.validationLevel,
    required this.warnings,
    required this.overallEvidenceScore,
    required this.sha256Fingerprint,
    required this.perceptualHash,
    required this.exposureStatus,
    required this.width,
    required this.height,
    required this.fileFormat,
    this.semanticRelevanceScore,
    this.sceneMatchScore,
  });

  final bool isValid;
  final double qualityScore;
  final double sharpnessScore;
  final double brightnessScore;
  final double resolutionScore;
  final bool duplicateDetected;
  final String evidenceSource;
  final double? semanticRelevanceScore;
  final bool semanticValidationAvailable;
  final String validationLevel;
  final List<String> warnings;
  final double overallEvidenceScore;
  final String sha256Fingerprint;
  final String perceptualHash;
  final String exposureStatus;
  final int width;
  final int height;
  final String fileFormat;

  /// Similarity score [0,1] comparing this evidence photo against the original
  /// hazard creation photo. Null when no reference photo is available.
  final double? sceneMatchScore;

  bool get canSubmit => isValid && !duplicateDetected;

  bool get earnsEvidenceBonus =>
      isValid &&
      !duplicateDetected &&
      validationLevel != EvidenceValidationLevel.lowQuality;

  /// True when the photo visually matches the original hazard scene.
  bool get hasStrongSceneMatch => (sceneMatchScore ?? 0) >= 0.7;

  String get touristTitle => switch (validationLevel) {
    EvidenceValidationLevel.strong => 'Photo quality looks excellent',
    EvidenceValidationLevel.good => 'Photo quality looks good',
    EvidenceValidationLevel.acceptable => 'Photo can be used as evidence',
    EvidenceValidationLevel.lowQuality =>
      'This photo may be difficult to review',
    EvidenceValidationLevel.possibleDuplicate =>
      'This photo appears to have been used previously',
    _ => 'This photo cannot be used',
  };

  String get touristMessage {
    if (duplicateDetected) {
      return 'Please provide a new, current photo of the hazard.';
    }
    if (!isValid) {
      return warnings.isEmpty
          ? 'Choose a valid JPEG, PNG or WebP image.'
          : warnings.first;
    }
    if (warnings.isNotEmpty) return warnings.first;
    return 'This image can be used as supporting evidence.';
  }

  Map<String, dynamic> toMap() => {
    'isValid': isValid,
    'qualityScore': qualityScore,
    'sharpnessScore': sharpnessScore,
    'brightnessScore': brightnessScore,
    'resolutionScore': resolutionScore,
    'duplicateDetected': duplicateDetected,
    'evidenceSource': evidenceSource,
    'semanticRelevanceScore': semanticRelevanceScore,
    'semanticValidationAvailable': semanticValidationAvailable,
    'validationLevel': validationLevel,
    'warnings': warnings,
    'overallEvidenceScore': overallEvidenceScore,
    'sha256Fingerprint': sha256Fingerprint,
    'perceptualHash': perceptualHash,
    'exposureStatus': exposureStatus,
    'width': width,
    'height': height,
    'fileFormat': fileFormat,
    if (sceneMatchScore != null) 'sceneMatchScore': sceneMatchScore,
  };

  factory EvidenceValidationResult.fromMap(Map<String, dynamic> map) {
    double score(String key) => (map[key] as num?)?.toDouble() ?? 0;
    return EvidenceValidationResult(
      isValid: map['isValid'] == true,
      qualityScore: score('qualityScore'),
      sharpnessScore: score('sharpnessScore'),
      brightnessScore: score('brightnessScore'),
      resolutionScore: score('resolutionScore'),
      duplicateDetected: map['duplicateDetected'] == true,
      evidenceSource: '${map['evidenceSource'] ?? EvidenceSource.gallery}',
      semanticRelevanceScore: (map['semanticRelevanceScore'] as num?)
          ?.toDouble(),
      semanticValidationAvailable: map['semanticValidationAvailable'] == true,
      validationLevel:
          '${map['validationLevel'] ?? EvidenceValidationLevel.invalid}',
      warnings: (map['warnings'] as List? ?? const [])
          .map((warning) => '$warning')
          .toList(),
      overallEvidenceScore: score('overallEvidenceScore'),
      sha256Fingerprint: '${map['sha256Fingerprint'] ?? ''}',
      perceptualHash: '${map['perceptualHash'] ?? ''}',
      exposureStatus: '${map['exposureStatus'] ?? 'UNKNOWN'}',
      width: (map['width'] as num?)?.round() ?? 0,
      height: (map['height'] as num?)?.round() ?? 0,
      fileFormat: '${map['fileFormat'] ?? 'UNKNOWN'}',
      sceneMatchScore: (map['sceneMatchScore'] as num?)?.toDouble(),
    );
  }

  /// Return a copy of this result with [sceneMatchScore] applied.
  EvidenceValidationResult withSceneMatchScore(double? score) {
    return EvidenceValidationResult(
      isValid: isValid,
      qualityScore: qualityScore,
      sharpnessScore: sharpnessScore,
      brightnessScore: brightnessScore,
      resolutionScore: resolutionScore,
      duplicateDetected: duplicateDetected,
      evidenceSource: evidenceSource,
      semanticRelevanceScore: semanticRelevanceScore,
      semanticValidationAvailable: semanticValidationAvailable,
      validationLevel: validationLevel,
      warnings: warnings,
      overallEvidenceScore: overallEvidenceScore,
      sha256Fingerprint: sha256Fingerprint,
      perceptualHash: perceptualHash,
      exposureStatus: exposureStatus,
      width: width,
      height: height,
      fileFormat: fileFormat,
      sceneMatchScore: score,
    );
  }
}
