import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/hazard_report.dart';
import '../models/hazard_vote.dart';
import '../services/hazard_report_service.dart';
import '../services/hazard_vote_service.dart';
import 'safety_image_viewer.dart';

class HazardEvidenceImage extends StatelessWidget {
  const HazardEvidenceImage({
    super.key,
    required this.report,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderBuilder,
    this.enableEnlargement = true,
    this.viewerTitle,
  });

  final HazardReport report;
  final double? width;
  final double? height;
  final BoxFit fit;
  final WidgetBuilder? placeholderBuilder;
  final bool enableEnlargement;
  final String? viewerTitle;

  @override
  Widget build(BuildContext context) {
    final title = viewerTitle ?? '${report.category} Evidence';
    final subtitle = 'Status: ${report.status}';

    final legacyUrl = report.imageUrl?.trim() ?? '';
    if (legacyUrl.isNotEmpty) {
      final img = Image.network(
        legacyUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
      if (!enableEnlargement) return img;
      return ExpandableEvidenceImage(
        imageProvider: NetworkImage(legacyUrl),
        title: title,
        subtitle: subtitle,
        child: img,
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
        final img = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _placeholder(context),
        );
        if (!enableEnlargement) return img;
        return ExpandableEvidenceImage(
          imageProvider: MemoryImage(bytes),
          title: title,
          subtitle: subtitle,
          child: img,
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

class HazardVoteEvidenceImage extends StatelessWidget {
  const HazardVoteEvidenceImage({
    super.key,
    required this.hazardId,
    required this.vote,
    this.voteService,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderBuilder,
    this.enableEnlargement = true,
    this.viewerTitle,
    this.viewerSubtitle,
    this.tooltip,
  });

  final String hazardId;
  final HazardVote vote;
  final HazardVoteService? voteService;
  final double? width;
  final double? height;
  final BoxFit fit;
  final WidgetBuilder? placeholderBuilder;
  final bool enableEnlargement;
  final String? viewerTitle;
  final String? viewerSubtitle;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final isStillExists = vote.voteType == HazardVoteType.hazardExists;
    final voteDirection = isStillExists
        ? 'Hazard Still Exists'
        : 'Hazard Appears Resolved';
    final title = viewerTitle ?? 'Community Evidence Photo';
    final subtitle = viewerSubtitle ?? 'Report update: $voteDirection';

    final legacyUrl = vote.photoUrl?.trim() ?? '';
    if (legacyUrl.isNotEmpty) {
      final img = Image.network(
        legacyUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
      if (!enableEnlargement) return img;
      return ExpandableEvidenceImage(
        imageProvider: NetworkImage(legacyUrl),
        title: title,
        subtitle: subtitle,
        tooltip: tooltip ?? 'Tap to enlarge community photo',
        child: img,
      );
    }

    if (!vote.hasPhotoEvidence) return _placeholder(context);

    return StreamBuilder<Uint8List?>(
      stream: (voteService ?? HazardVoteService()).watchEvidenceBytes(
        hazardId,
        vote.userId,
      ),
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
        final img = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _placeholder(context),
        );
        if (!enableEnlargement) return img;
        return ExpandableEvidenceImage(
          imageProvider: MemoryImage(bytes),
          title: title,
          subtitle: subtitle,
          tooltip: tooltip ?? 'Tap to enlarge community photo',
          child: img,
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
