part of '../admin_pages.dart';

class _AdminHazardImage extends StatelessWidget {
  const _AdminHazardImage({required this.report});

  final HazardReport report;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: HazardEvidenceImage(
        report: report,
        width: 118,
        height: 92,
        placeholderBuilder: (_) => _AdminHazardPlaceholder.image(),
      ),
    );
  }
}

class _AdminHazardPlaceholder {
  static Widget image() => Container(
    width: 118,
    height: 92,
    color: ExplorerColors.dangerSoft,
    child: const Icon(
      Icons.warning_amber_rounded,
      color: ExplorerColors.danger,
      size: 42,
    ),
  );
}

class _HazardInfo extends StatelessWidget {
  const _HazardInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(icon, size: 14, color: ExplorerColors.muted),
            ),
          ),
          TextSpan(
            text: text,
            style: const TextStyle(color: ExplorerColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Intelligent Resolve Hazard Confidence System card
// ---------------------------------------------------------------------------

class _ConfidenceAnalysisCard extends StatelessWidget {
  const _ConfidenceAnalysisCard({required this.analysis});
  final ConfidenceAnalysisResult analysis;
  @override
  Widget build(BuildContext context) {
    final color = analysis.hasSufficientRecentEvidence
        ? ExplorerColors.navy
        : ExplorerColors.muted;
    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExplorerSectionTitle(
            'Community Resolution Analysis',
            subtitle: 'Supporting evidence for the administrator’s decision.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ExplorerStatusBadge(
                label: analysis.displayLevel,
                tone: analysis.hasSufficientRecentEvidence
                    ? ExplorerStatusTone.navy
                    : ExplorerStatusTone.neutral,
              ),
              Text(
                '${analysis.totalRecentVotes} confirmations in the last 15 minutes',
                style: const TextStyle(
                  color: ExplorerColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${analysis.confidencePercent.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            'Weighted resolution support',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (analysis.confidencePercent / 100).clamp(0, 1),
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            color: color,
            backgroundColor: ExplorerColors.subtle,
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ConfidenceStat(
                  label: 'Hazard Still Exists',
                  value: '${analysis.existsVotes}',
                  icon: Icons.warning_amber_rounded,
                  iconColor: ExplorerColors.danger,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ConfidenceStat(
                  label: 'Hazard Appears Resolved',
                  value: '${analysis.resolvedVotes}',
                  icon: Icons.task_alt,
                  iconColor: ExplorerColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _EvidenceMetric(
                label: 'Location-verified',
                value: analysis.gpsValidatedCount,
                icon: Icons.my_location,
              ),
              _EvidenceMetric(
                label: 'Photos',
                value: analysis.photoEvidenceCount,
                icon: Icons.photo_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            analysis.recommendation,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'View Analysis Details',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              children: [
                _AdminDetailRow(
                  label: 'Evidence',
                  value: analysis.evidenceStrength,
                ),
                _AdminDetailRow(
                  label: 'Good photos',
                  value: '${analysis.strongOrGoodEvidenceCount}',
                ),
                _AdminDetailRow(
                  label: 'Low quality',
                  value: '${analysis.lowQualityEvidenceCount}',
                ),
                _AdminDetailRow(
                  label: 'Duplicates',
                  value: '${analysis.possibleDuplicateEvidenceCount}',
                ),
                _AdminDetailRow(
                  label: 'Similar scenes',
                  value: '${analysis.sceneMatchedCount}',
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Support weights consider proximity, photo quality and confirmations from the last hour. '
                    'Confidence requires enough confirmations in the last 15 minutes. '
                    'Scene comparison measures coarse visual patterns, not whether a hazard is present.',
                    style: TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceStat extends StatelessWidget {
  const _ConfidenceStat({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ExplorerColors.subtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Icon(icon, size: 18, color: iconColor ?? ExplorerColors.navy),
          if (icon != null) const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: ExplorerColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: ExplorerColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _VotePhotoEvidenceCard extends StatelessWidget {
  const _VotePhotoEvidenceCard({required this.hazardId, required this.votes});
  final String hazardId;
  final List<HazardVote> votes;

  @override
  Widget build(BuildContext context) {
    final evidence = votes.where((vote) => vote.hasPhotoEvidence).toList()
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExplorerSectionTitle(
            'Recent Community Photo Evidence',
            subtitle:
                'Supporting evidence only; administrator review is still required.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: evidence.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  _VoteEvidenceTile(hazardId: hazardId, vote: evidence[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteEvidenceTile extends StatelessWidget {
  const _VoteEvidenceTile({required this.hazardId, required this.vote});

  final String hazardId;
  final HazardVote vote;

  @override
  Widget build(BuildContext context) {
    final validation = vote.evidenceValidation;
    final hasSceneMatch = vote.hasSceneMatchedEvidence;
    return SizedBox(
      width: 190,
      child: Material(
        color: ExplorerColors.subtle,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetails(context),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: _VoteEvidenceImage(
                        hazardId: hazardId,
                        vote: vote,
                        width: 174,
                        height: 112,
                      ),
                    ),
                    // Scene-match badge
                    if (hasSceneMatch)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: ExplorerColors.goldDark,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.compare_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Scene comparison',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  vote.voteType == HazardVoteType.hazardExists
                      ? 'Hazard Still Exists'
                      : 'Hazard Appears Resolved',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${vote.distanceFromHazardMeters.round()}m • ${vote.proximityBand} • ${validation?.validationLevel ?? 'Legacy'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 9,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) {
    final validation = vote.evidenceValidation;
    final sceneScore = vote.sceneMatchScore ?? validation?.sceneMatchScore;
    final ai = vote.aiAnalysis;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExplorerSectionTitle('Community Evidence'),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _VoteEvidenceImage(
                  hazardId: hazardId,
                  vote: vote,
                  width: double.infinity,
                  height: 280,
                ),
              ),
              const SizedBox(height: 14),
              _AdminDetailRow(
                label: 'Update',
                value: vote.voteType == HazardVoteType.hazardExists
                    ? 'Hazard Still Exists'
                    : 'Hazard Appears Resolved',
              ),
              _AdminDetailRow(
                label: 'Proximity',
                value:
                    '${vote.distanceFromHazardMeters.round()} metres • ${vote.proximityBand}',
              ),
              _AdminDetailRow(
                label: 'Submitted',
                value: vote.createdAt == null
                    ? 'Recently'
                    : DateFormat.yMMMd().add_jm().format(vote.createdAt!),
              ),
              _AdminDetailRow(
                label: 'Validation',
                value: validation?.validationLevel ?? 'Legacy evidence',
              ),
              if (sceneScore != null)
                _AdminDetailRow(
                  label: 'Image Similarity',
                  value: sceneScore >= 1
                      ? 'Strong visual match'
                      : sceneScore >= .7
                      ? 'Partial visual match'
                      : sceneScore >= .4
                      ? 'Weak visual match'
                      : 'No visual match',
                ),
              if (validation != null)
                Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Evidence Details',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    children: [
                      _AdminDetailRow(
                        label: 'Capture',
                        value: validation.evidenceSource == 'CAMERA'
                            ? 'Captured in App'
                            : 'From Gallery',
                      ),
                      _AdminDetailRow(
                        label: 'Visibility',
                        value: validation.exposureStatus,
                      ),
                      _AdminDetailRow(
                        label: 'Resolution',
                        value: '${validation.width} × ${validation.height}',
                      ),
                      if (validation.warnings.isNotEmpty)
                        _AdminDetailRow(
                          label: 'Notes',
                          value: validation.warnings.join(' '),
                        ),
                    ],
                  ),
                ),
              // ── AI Evidence Decision Support ──────────────────────────────
              const SizedBox(height: 16),
              _AiEvidenceSection(ai: ai),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI Evidence Decision Support section (Admin-only — displayed in vote sheet)
// ---------------------------------------------------------------------------

class _AiEvidenceSection extends StatelessWidget {
  const _AiEvidenceSection({required this.ai});
  final HazardVoteAi ai;

  @override
  Widget build(BuildContext context) {
    // Legacy votes created before Step 6 or missing status: static neutral note, no spinner
    if (ai.isNotAvailable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ExplorerColors.subtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ExplorerColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: ExplorerColors.muted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI analysis not available for this evidence',
                style: TextStyle(color: ExplorerColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Explicit PENDING: server trigger is currently processing
    if (ai.isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ExplorerColors.subtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ExplorerColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI evidence analysis in progress…',
                style: TextStyle(color: ExplorerColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (ai.isSkipped || ai.isFailed) {
      final skipMessage = switch (ai.failureReason) {
        'ORIGINAL_EVIDENCE_UNAVAILABLE' =>
          'AI analysis skipped: Original hazard evidence photo is unavailable for comparison.',
        'NO_PHOTO' => 'AI analysis not available (no photo evidence).',
        _ => 'AI analysis not available for this evidence.',
      };

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ExplorerColors.subtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ExplorerColors.border),
        ),
        child: Row(
          children: [
            Icon(
              ai.isSkipped
                  ? Icons.do_not_disturb_outlined
                  : Icons.error_outline,
              size: 16,
              color: ExplorerColors.muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ai.isSkipped
                    ? skipMessage
                    : 'AI analysis could not be completed for this vote.',
                style: const TextStyle(
                  color: ExplorerColors.muted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // COMPLETE: Render qualitative decision support
    final agreement = ai.agreement;
    final (agreementColor, agreementBg, agreementIcon, agreementLabel) =
        _agreementStyle(agreement);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: agreementBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: agreementColor.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(agreementIcon, size: 16, color: agreementColor),
              const SizedBox(width: 8),
              Text(
                'AI Decision Support',
                style: TextStyle(
                  color: agreementColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              ExplorerStatusBadge(
                label: agreementLabel,
                tone: _agreementTone(agreement),
              ),
            ],
          ),
          if (ai.conditionAssessment != null) ...[
            const SizedBox(height: 10),
            _AdminDetailRow(
              label: 'Current Condition',
              value: _conditionLabel(ai.conditionAssessment!),
            ),
          ],
          if (ai.analysisSummary != null && ai.analysisSummary!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              ai.analysisSummary!,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (ai.sceneMatchScore != null)
                _AiScorePill(
                  label: 'Scene Match',
                  qualitativeText: _sceneQualitative(ai.sceneMatchScore!),
                  value: ai.sceneMatchScore!,
                  tooltip: 'AI semantic scene similarity with original hazard',
                ),
              if (ai.hazardRelevanceScore != null)
                _AiScorePill(
                  label: 'Relevance',
                  qualitativeText: _relevanceQualitative(
                    ai.hazardRelevanceScore!,
                  ),
                  value: ai.hazardRelevanceScore!,
                  tooltip: 'Relevance to reported hazard category',
                ),
              if (ai.conditionConfidence != null)
                _AiScorePill(
                  label: 'Confidence',
                  qualitativeText: _confidenceQualitative(
                    ai.conditionConfidence!,
                  ),
                  value: ai.conditionConfidence!,
                  tooltip: 'Model confidence in condition assessment',
                ),
            ],
          ),
          const SizedBox(height: 10),
          _AdminDetailRow(
            label: 'Evidence Support',
            value: _supportDescription(ai.evidenceWeightMultiplier),
          ),
          const SizedBox(height: 6),
          const Text(
            'AI is decision support only — it does not automatically change the hazard status.',
            style: TextStyle(
              color: ExplorerColors.muted,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, IconData, String) _agreementStyle(String? agreement) =>
      switch (agreement) {
        AiAgreement.supportsVote => (
          ExplorerColors.success,
          ExplorerColors.successSoft,
          Icons.thumb_up_alt_outlined,
          'SUPPORTS VOTE',
        ),
        AiAgreement.conflictsWithVote => (
          ExplorerColors.danger,
          ExplorerColors.dangerSoft,
          Icons.thumb_down_alt_outlined,
          'CONFLICTS WITH VOTE',
        ),
        _ => (
          ExplorerColors.muted,
          ExplorerColors.subtle,
          Icons.help_outline,
          'INCONCLUSIVE',
        ),
      };

  ExplorerStatusTone _agreementTone(String? agreement) => switch (agreement) {
    AiAgreement.supportsVote => ExplorerStatusTone.success,
    AiAgreement.conflictsWithVote => ExplorerStatusTone.danger,
    _ => ExplorerStatusTone.neutral,
  };

  String _conditionLabel(String raw) => switch (raw) {
    'HAZARD_STILL_PRESENT' => 'Hazard Still Present',
    'APPEARS_RESOLVED' => 'Hazard Appears Resolved',
    _ => 'Condition Uncertain',
  };

  String _sceneQualitative(double score) => score >= 0.80
      ? 'High'
      : score >= 0.55
      ? 'Moderate'
      : 'Low';

  String _relevanceQualitative(double score) => score >= 0.80
      ? 'High'
      : score >= 0.55
      ? 'Relevant'
      : 'Low';

  String _confidenceQualitative(double score) => score >= 0.80
      ? 'High'
      : score >= 0.60
      ? 'Moderate'
      : 'Low';

  String _supportDescription(double multiplier) {
    if (multiplier >= 1.08) {
      return 'Strong support weight (+10%)';
    } else if (multiplier >= 1.04) {
      return 'Moderate support weight (+5%)';
    } else if (multiplier > 1.00) {
      return 'Mild support weight (+2%)';
    } else if (multiplier <= 0.92) {
      return 'Strong conflict weight (-10%)';
    } else if (multiplier <= 0.96) {
      return 'Moderate conflict weight (-5%)';
    } else if (multiplier < 1.00) {
      return 'Mild conflict weight (-2%)';
    }
    return 'Neutral weight (no adjustment)';
  }
}

class _AiScorePill extends StatelessWidget {
  const _AiScorePill({
    required this.label,
    required this.qualitativeText,
    required this.value,
    this.tooltip,
  });

  final String label;
  final String qualitativeText;
  final double value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    final color = value >= 0.80
        ? ExplorerColors.success
        : value >= 0.55
        ? ExplorerColors.goldDark
        : ExplorerColors.muted;

    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ExplorerColors.subtle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        '$label: $qualitativeText ($percent%)',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (tooltip != null) {
      pill = Tooltip(message: tooltip!, child: pill);
    }
    return pill;
  }
}

class _EvidenceMetric extends StatelessWidget {
  const _EvidenceMetric({required this.label, required this.value, this.icon});

  final String label;
  final int value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    const effectiveColor = ExplorerColors.navy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: ExplorerColors.subtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ExplorerColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: effectiveColor),
            const SizedBox(width: 5),
          ],
          Text(
            '$label  $value',
            style: TextStyle(
              color: effectiveColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteEvidenceImage extends StatelessWidget {
  const _VoteEvidenceImage({
    required this.hazardId,
    required this.vote,
    this.width = 170,
    this.height = 130,
  });
  final String hazardId;
  final HazardVote vote;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final legacyUrl = vote.photoUrl?.trim() ?? '';
    if (legacyUrl.isNotEmpty) {
      return Image.network(
        legacyUrl,
        errorBuilder: (_, _, _) => SizedBox(
          width: width,
          height: height,
          child: const Icon(Icons.broken_image_outlined),
        ),
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }
    return StreamBuilder<Uint8List?>(
      stream: HazardVoteService().watchEvidenceBytes(hazardId, vote.userId),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(
            bytes,
            errorBuilder: (_, _, _) => SizedBox(
              width: width,
              height: height,
              child: const Icon(Icons.broken_image_outlined),
            ),
            width: width,
            height: height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return SizedBox(
          width: width,
          height: height,
          child: const Icon(Icons.broken_image_outlined),
        );
      },
    );
  }
}
