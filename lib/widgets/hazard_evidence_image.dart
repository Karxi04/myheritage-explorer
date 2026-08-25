import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/hazard_report.dart';
import '../services/hazard_report_service.dart';

class HazardEvidenceImage extends StatelessWidget {
  const HazardEvidenceImage({
    super.key,
    required this.report,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderBuilder,
  });

  final HazardReport report;
  final double? width;
  final double? height;
  final BoxFit fit;
  final WidgetBuilder? placeholderBuilder;

  @override
  Widget build(BuildContext context) {
    final legacyUrl = report.imageUrl?.trim() ?? '';
    if (legacyUrl.isNotEmpty) {
      return Image.network(
        legacyUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    }

    if (!report.hasPhotoEvidence) return _placeholder(context);

    return StreamBuilder<Uint8List?>(
      stream: HazardReportService().watchEvidenceBytes(report.id),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
              width: width,
              height: height,
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          return _placeholder(context);
        }
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _placeholder(context),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) {
    return placeholderBuilder?.call(context) ??
        SizedBox(
          width: width,
          height: height,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        );
  }
}
