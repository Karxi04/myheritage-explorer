import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:myheritage_explorer/services/hazard_report_service.dart';

void main() {
  test('hazard evidence is converted to a size-limited JPEG', () {
    final source = image_lib.Image(width: 1800, height: 1200);
    image_lib.fill(source, color: image_lib.ColorRgb8(28, 104, 166));
    final sourceBytes = Uint8List.fromList(image_lib.encodePng(source));

    final compressed = compressHazardEvidence(sourceBytes);
    final decoded = image_lib.decodeJpg(compressed);

    expect(compressed, isNotEmpty);
    expect(
      compressed.lengthInBytes,
      lessThanOrEqualTo(HazardReportService.maxEvidenceBytes),
    );
    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(960));
    expect(decoded.height, lessThanOrEqualTo(960));
  });

  test('invalid photo data is rejected', () {
    expect(
      () => compressHazardEvidence(Uint8List.fromList([1, 2, 3])),
      throwsException,
    );
  });
}
