part of '../admin_pages.dart';

// ---------------------------------------------------------------------------
// Existing helper widgets preserved for tab compatibility
// ---------------------------------------------------------------------------

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
// Shared Admin Hazard List Card & Formatting Helpers
// ---------------------------------------------------------------------------

ExplorerStatusTone _adminSeverityTone(String severity) =>
    switch (severity.toLowerCase()) {
      'high' => ExplorerStatusTone.danger,
      'medium' => ExplorerStatusTone.warning,
      _ => ExplorerStatusTone.navy,
    };

String _formatHazardDate(DateTime? date, {bool isVerified = false}) {
  if (date == null) {
    return isVerified ? 'Recently verified' : 'Recently submitted';
  }
  final prefix = isVerified ? 'Verified' : 'Submitted';
  final formatted =
      '${DateFormat.yMMMd().format(date)} · ${DateFormat.jm().format(date).replaceAll('\u202f', ' ')}';
  return '$prefix $formatted';
}

class _AdminHazardListCard extends StatelessWidget {
  const _AdminHazardListCard({
    required this.report,
    required this.statusLabel,
    required this.statusTone,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.formattedDate,
    this.communityVoteCount,
  });

  final HazardReport report;
  final String statusLabel;
  final ExplorerStatusTone statusTone;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final String? formattedDate;
  final String? communityVoteCount;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final isHighTextScale = textScale > 1.25;

    return ExplorerCard(
      onTap: onAction,
      padding: const EdgeInsets.all(16),
      borderColor: ExplorerColors.border,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650 || isHighTextScale;

          final headerBadges = Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ExplorerStatusBadge(label: statusLabel, tone: statusTone),
              ExplorerStatusBadge(
                label: '${report.severity.toUpperCase()} SEVERITY',
                tone: _adminSeverityTone(report.severity),
              ),
            ],
          );

          final metadataItems = Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _HazardInfo(
                icon: Icons.place_outlined,
                text:
                    'GPS: ${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
              ),
              if (formattedDate != null && formattedDate!.isNotEmpty)
                _HazardInfo(
                  icon: Icons.schedule_outlined,
                  text: formattedDate!,
                ),
              if (communityVoteCount != null && communityVoteCount!.isNotEmpty)
                _HazardInfo(
                  icon: Icons.how_to_vote_outlined,
                  text: communityVoteCount!,
                ),
            ],
          );

          final actionBtn = FilledButton.icon(
            onPressed: onAction,
            icon: Icon(actionIcon, size: 17),
            label: Text(actionLabel),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        report.category,
                        style: const TextStyle(
                          color: ExplorerColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                headerBadges,
                const SizedBox(height: 12),
                _AdminHazardImage(report: report),
                const SizedBox(height: 12),
                Text(
                  report.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ExplorerColors.text,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                metadataItems,
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: actionBtn),
              ],
            );
          }

          // Wide desktop/tablet layout
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _AdminHazardImage(report: report),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.category,
                      style: const TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    headerBadges,
                    const SizedBox(height: 8),
                    Text(
                      report.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ExplorerColors.text,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    metadataItems,
                  ],
                ),
              ),
              const SizedBox(width: 16),
              actionBtn,
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared detail row (two-column label-value pair with responsive stacking)
// ---------------------------------------------------------------------------

class _AdminDetailRow extends StatelessWidget {
  const _AdminDetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTight = constraints.maxWidth < 240;
          if (isTight) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? ExplorerColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? ExplorerColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 2: Original Hazard Evidence Card
// ---------------------------------------------------------------------------

class _OriginalHazardEvidenceCard extends StatelessWidget {
  const _OriginalHazardEvidenceCard({required this.report});

  final HazardReport report;

  @override
  Widget build(BuildContext context) {
    final validation = report.evidenceValidation;
    final dateStr = report.createdAt == null
        ? 'Recently submitted'
        : DateFormat.yMMMd().add_jm().format(report.createdAt!);

    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExplorerSectionTitle(
            'Original Hazard Evidence',
            subtitle: 'Evidence image submitted with the initial report.',
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: HazardEvidenceImage(
              report: report,
              width: double.infinity,
              height: 260,
              placeholderBuilder: (_) => _AdminHazardPlaceholder.image(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ExplorerStatusBadge(
                label: validation?.evidenceSource == 'CAMERA'
                    ? 'Captured in App'
                    : 'Selected from Gallery',
                tone: ExplorerStatusTone.neutral,
                icon: validation?.evidenceSource == 'CAMERA'
                    ? Icons.camera_alt_outlined
                    : Icons.photo_library_outlined,
              ),
              Text(
                'Submitted with original report • $dateStr',
                style: const TextStyle(
                  color: ExplorerColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (validation != null) ...[
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Technical Details',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ExplorerColors.navy,
                  ),
                ),
                children: [
                  _AdminDetailRow(
                    label: 'Resolution',
                    value: '${validation.width} × ${validation.height}',
                  ),
                  _AdminDetailRow(
                    label: 'Visibility',
                    value: validation.exposureStatus,
                  ),
                  if (validation.warnings.isNotEmpty)
                    _AdminDetailRow(
                      label: 'Validation Notes',
                      value: validation.warnings.join(' '),
                    ),
                  if (validation.sha256Fingerprint.isNotEmpty)
                    _AdminDetailRow(
                      label: 'SHA-256',
                      value: validation.sha256Fingerprint,
                    ),
                  if (validation.perceptualHash.isNotEmpty)
                    _AdminDetailRow(
                      label: 'Perceptual Hash',
                      value: validation.perceptualHash,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 3: Community Confirmation Summary Card
// ---------------------------------------------------------------------------

class _CommunityConfirmationSummaryCard extends StatelessWidget {
  const _CommunityConfirmationSummaryCard({required this.analysis});

  final ConfidenceAnalysisResult analysis;

  @override
  Widget build(BuildContext context) {
    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExplorerSectionTitle(
            'Community Confirmation Summary',
            subtitle: 'Real-time crowdsourced verification activity.',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth < 600
                  ? (constraints.maxWidth - 10) / 2
                  : (constraints.maxWidth - 30) / 4;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _ConfirmationMetricBox(
                      label: 'Hazard Still Exists',
                      value: '${analysis.existsVotes}',
                      icon: Icons.warning_amber_rounded,
                      color: ExplorerColors.danger,
                      bgColor: ExplorerColors.dangerSoft,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ConfirmationMetricBox(
                      label: 'Appears Resolved',
                      value: '${analysis.resolvedVotes}',
                      icon: Icons.task_alt,
                      color: ExplorerColors.success,
                      bgColor: ExplorerColors.successSoft,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ConfirmationMetricBox(
                      label: 'Recent GPS-Verified',
                      value: '${analysis.gpsValidatedCount}',
                      icon: Icons.my_location,
                      color: ExplorerColors.navy,
                      bgColor: ExplorerColors.subtle,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ConfirmationMetricBox(
                      label: 'Photo Evidence',
                      value: '${analysis.photoEvidenceCount}',
                      icon: Icons.photo_camera_outlined,
                      color: ExplorerColors.navy,
                      bgColor: ExplorerColors.subtle,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConfirmationMetricBox extends StatelessWidget {
  const _ConfirmationMetricBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ExplorerColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 4: Community Evidence Section & Cards
// ---------------------------------------------------------------------------

class _CommunityEvidenceSection extends StatelessWidget {
  const _CommunityEvidenceSection({
    required this.hazardId,
    required this.votes,
    this.voteService,
  });

  final String hazardId;
  final List<HazardVote> votes;
  final HazardVoteService? voteService;

  @override
  Widget build(BuildContext context) {
    final photoVotes = votes.where((v) => v.hasPhotoEvidence).toList()
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );

    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: ExplorerSectionTitle(
                  'Community Evidence Photos',
                  subtitle:
                      'Crowdsourced evidence photos with integrated AI semantic analysis.',
                ),
              ),
              if (photoVotes.isNotEmpty)
                ExplorerStatusBadge(
                  label: '${photoVotes.length} Photos',
                  tone: ExplorerStatusTone.neutral,
                  icon: Icons.photo_library_outlined,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (photoVotes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: ExplorerColors.subtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ExplorerColors.border),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.photo_outlined,
                    size: 40,
                    color: ExplorerColors.muted,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No community evidence has been submitted yet.',
                    style: TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: photoVotes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _CommunityEvidenceCard(
                hazardId: hazardId,
                vote: photoVotes[index],
                voteService: voteService,
              ),
            ),
        ],
      ),
    );
  }
}

class _CommunityEvidenceCard extends StatelessWidget {
  const _CommunityEvidenceCard({
    required this.hazardId,
    required this.vote,
    this.voteService,
  });

  final String hazardId;
  final HazardVote vote;
  final HazardVoteService? voteService;

  @override
  Widget build(BuildContext context) {
    final validation = vote.evidenceValidation;
    final isCamera = validation?.evidenceSource == 'CAMERA';
    final isStillExists = vote.voteType == HazardVoteType.hazardExists;
    final dateStr = vote.createdAt == null
        ? 'Recently submitted'
        : DateFormat.yMMMd().add_jm().format(vote.createdAt!);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ExplorerColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;
          final imageWidget = ClipRRect(
            borderRadius: isNarrow
                ? const BorderRadius.vertical(top: Radius.circular(13))
                : const BorderRadius.horizontal(left: Radius.circular(13)),
            child: _VoteEvidenceImage(
              hazardId: hazardId,
              vote: vote,
              voteService: voteService,
              width: isNarrow ? double.infinity : 240,
              height: isNarrow ? 200 : 260,
            ),
          );

          final contentWidget = Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vote Direction & Source Badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ExplorerStatusBadge(
                      label: isStillExists
                          ? 'HAZARD STILL EXISTS'
                          : 'HAZARD APPEARS RESOLVED',
                      tone: isStillExists
                          ? ExplorerStatusTone.danger
                          : ExplorerStatusTone.success,
                      icon: isStillExists
                          ? Icons.warning_amber_rounded
                          : Icons.task_alt,
                    ),
                    ExplorerStatusBadge(
                      label: isCamera
                          ? 'Captured in App'
                          : 'Selected from Gallery',
                      tone: ExplorerStatusTone.neutral,
                      icon: isCamera
                          ? Icons.camera_alt_outlined
                          : Icons.photo_library_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Proximity & Submission details
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _HazardInfo(
                      icon: Icons.place_outlined,
                      text:
                          '${vote.distanceFromHazardMeters.round()} m from hazard • ${vote.proximityBand}',
                    ),
                    _HazardInfo(icon: Icons.schedule_outlined, text: dateStr),
                  ],
                ),
                const SizedBox(height: 14),

                // Integrated AI Evidence Decision Support
                _AiEvidenceSection(ai: vote.aiAnalysis),

                // Collapsible Technical Details
                Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Technical Details',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ExplorerColors.navy,
                      ),
                    ),
                    children: [
                      if (vote.sceneMatchScore != null ||
                          validation?.sceneMatchScore != null)
                        _AdminDetailRow(
                          label: 'Visual Similarity',
                          value: _formatVisualSimilarity(
                            vote.sceneMatchScore ?? validation?.sceneMatchScore,
                          ),
                        ),
                      if (vote.aiAnalysis.isComplete)
                        _AdminDetailRow(
                          label: 'AI Multiplier',
                          value:
                              '${vote.aiAnalysis.evidenceWeightMultiplier.toStringAsFixed(2)}×',
                        ),
                      if (validation != null) ...[
                        _AdminDetailRow(
                          label: 'Resolution',
                          value: '${validation.width} × ${validation.height}',
                        ),
                        _AdminDetailRow(
                          label: 'Visibility',
                          value: validation.exposureStatus,
                        ),
                        if (validation.sha256Fingerprint.isNotEmpty)
                          _AdminDetailRow(
                            label: 'SHA-256',
                            value: validation.sha256Fingerprint,
                          ),
                        if (validation.perceptualHash.isNotEmpty)
                          _AdminDetailRow(
                            label: 'Perceptual Hash',
                            value: validation.perceptualHash,
                          ),
                        if (validation.warnings.isNotEmpty)
                          _AdminDetailRow(
                            label: 'Validation Notes',
                            value: validation.warnings.join(' '),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [imageWidget, contentWidget],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              imageWidget,
              Expanded(child: contentWidget),
            ],
          );
        },
      ),
    );
  }

  String _formatVisualSimilarity(double? score) {
    if (score == null) return 'Not Available';
    if (score >= 1.0) return 'Strong visual match (${(score * 100).round()}%)';
    if (score >= 0.7) return 'Partial visual match (${(score * 100).round()}%)';
    if (score >= 0.4) return 'Weak visual match (${(score * 100).round()}%)';
    return 'No visual match (${(score * 100).round()}%)';
  }
}

// ---------------------------------------------------------------------------
// SECTION 5: Integrated AI Evidence Decision Support
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
          'Original hazard image is unavailable for comparison.',
        'NO_PHOTO' => 'No community evidence image was submitted.',
        _ =>
          ai.isSkipped
              ? 'AI analysis skipped for this vote.'
              : 'AI analysis is currently unavailable.',
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
                skipMessage,
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
    final (
      agreementColor,
      agreementBg,
      agreementIcon,
      agreementLabel,
      agreementBadge,
      agreementTone,
    ) = _agreementMeta(
      agreement,
    );

    final sceneMatchLabel = _sceneQualitative(ai.sceneMatchScore);
    final relevanceLabel = _relevanceQualitative(ai.hazardRelevanceScore);
    final conditionText = _conditionLabel(ai.conditionAssessment);
    final supportLevel = _qualitativeEvidenceSupport(ai);

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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(agreementIcon, size: 16, color: agreementColor),
                  Text(
                    'AI Decision Support',
                    style: TextStyle(
                      color: agreementColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              ExplorerStatusBadge(label: agreementBadge, tone: agreementTone),
            ],
          ),
          const SizedBox(height: 12),

          // Qualitative Metrics
          _AdminDetailRow(
            label: 'Evidence Agreement',
            value: agreementLabel,
            valueColor: agreementColor,
          ),
          _AdminDetailRow(label: 'Current Condition', value: conditionText),
          _AdminDetailRow(label: 'Evidence Assessment', value: supportLevel),

          // Qualitative Pills for Scene Match & Relevance
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QualitativeScorePill(
                label: 'Scene Match',
                qualitative: sceneMatchLabel,
                score: ai.sceneMatchScore,
              ),
              _QualitativeScorePill(
                label: 'Relevance',
                qualitative: relevanceLabel,
                score: ai.hazardRelevanceScore,
              ),
              if (ai.conditionConfidence != null)
                _QualitativeScorePill(
                  label: 'Condition Confidence',
                  qualitative: _confidenceQualitative(ai.conditionConfidence!),
                  score: ai.conditionConfidence,
                ),
            ],
          ),

          // AI Analysis Summary (defensive maxLines: 3)
          if (ai.analysisSummary != null && ai.analysisSummary!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              ai.analysisSummary!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: ExplorerColors.text,
              ),
            ),
          ],
        ],
      ),
    );
  }

  (Color, Color, IconData, String, String, ExplorerStatusTone) _agreementMeta(
    String? agreement,
  ) => switch (agreement) {
    AiAgreement.supportsVote => (
      ExplorerColors.success,
      ExplorerColors.successSoft,
      Icons.thumb_up_alt_outlined,
      'Supports Tourist Confirmation',
      'SUPPORTS',
      ExplorerStatusTone.success,
    ),
    AiAgreement.conflictsWithVote => (
      ExplorerColors.danger,
      ExplorerColors.dangerSoft,
      Icons.thumb_down_alt_outlined,
      'Conflicts with Tourist Confirmation',
      'CONFLICTS',
      ExplorerStatusTone.danger,
    ),
    _ => (
      ExplorerColors.muted,
      ExplorerColors.subtle,
      Icons.help_outline,
      'Inconclusive',
      'INCONCLUSIVE',
      ExplorerStatusTone.neutral,
    ),
  };

  String _conditionLabel(String? raw) => switch (raw) {
    'HAZARD_STILL_PRESENT' => 'Hazard Still Appears Present',
    'APPEARS_RESOLVED' => 'Appears Improved / Possibly Resolved',
    _ => 'Current Condition Uncertain',
  };

  String _sceneQualitative(double? score) {
    if (score == null) return 'Not Available';
    if (score >= 0.80) return 'High';
    if (score >= 0.60) return 'Moderate';
    return 'Low';
  }

  String _relevanceQualitative(double? score) {
    if (score == null) return 'Not Available';
    if (score >= 0.80) return 'High';
    if (score >= 0.60) return 'Moderate';
    return 'Low';
  }

  String _confidenceQualitative(double score) => score >= 0.80
      ? 'High'
      : score >= 0.60
      ? 'Moderate'
      : 'Low';

  String _qualitativeEvidenceSupport(HazardVoteAi ai) {
    if (!ai.isComplete || ai.agreement == AiAgreement.inconclusive) {
      return 'Inconclusive';
    }
    final multiplier = ai.evidenceWeightMultiplier;
    if (ai.agreement == AiAgreement.supportsVote) {
      if (multiplier >= 1.05) return 'Strong Support';
      return 'Moderate Support';
    }
    if (ai.agreement == AiAgreement.conflictsWithVote) {
      if (multiplier <= 0.95) return 'Strong Conflict';
      return 'Moderate Conflict';
    }
    return 'Inconclusive';
  }
}

class _QualitativeScorePill extends StatelessWidget {
  const _QualitativeScorePill({
    required this.label,
    required this.qualitative,
    required this.score,
  });

  final String label;
  final String qualitative;
  final double? score;

  @override
  Widget build(BuildContext context) {
    final color = score == null
        ? ExplorerColors.muted
        : score! >= 0.80
        ? ExplorerColors.success
        : score! >= 0.60
        ? ExplorerColors.goldDark
        : ExplorerColors.danger;

    final percentText = score == null ? '' : ' · ${(score! * 100).round()}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        '$label: $qualitative$percentText',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 6: Aggregated AI Evidence Summary Card
// ---------------------------------------------------------------------------

class _AggregatedAiEvidenceCard extends StatelessWidget {
  const _AggregatedAiEvidenceCard({required this.votes});

  final List<HazardVote> votes;

  @override
  Widget build(BuildContext context) {
    int supports = 0;
    int conflicts = 0;
    int inconclusive = 0;
    int pending = 0;
    int unavailable = 0;

    for (final vote in votes) {
      if (!vote.hasPhotoEvidence) continue;
      final ai = vote.aiAnalysis;
      if (ai.isComplete) {
        if (ai.agreement == AiAgreement.supportsVote) {
          supports++;
        } else if (ai.agreement == AiAgreement.conflictsWithVote) {
          conflicts++;
        } else {
          inconclusive++;
        }
      } else if (ai.isPending) {
        pending++;
      } else if (ai.isSkipped || ai.isFailed || ai.isNotAvailable) {
        unavailable++;
      }
    }

    final totalAi = supports + conflicts + inconclusive + pending + unavailable;
    // If no AI analyses exist, do not display a useless all-zero panel
    if (totalAi == 0) {
      return const SizedBox.shrink();
    }

    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExplorerSectionTitle(
            'AI Evidence Summary',
            subtitle:
                'Locally aggregated findings across community photo evidence.',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth < 600
                  ? (constraints.maxWidth - 10) / 2
                  : (constraints.maxWidth - 40) / 5;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: _AiSummaryBox(
                      label: 'Supports Vote',
                      count: supports,
                      color: ExplorerColors.success,
                      bgColor: ExplorerColors.successSoft,
                      icon: Icons.thumb_up_alt_outlined,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _AiSummaryBox(
                      label: 'Conflicts with Vote',
                      count: conflicts,
                      color: ExplorerColors.danger,
                      bgColor: ExplorerColors.dangerSoft,
                      icon: Icons.thumb_down_alt_outlined,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _AiSummaryBox(
                      label: 'Inconclusive',
                      count: inconclusive,
                      color: ExplorerColors.muted,
                      bgColor: ExplorerColors.subtle,
                      icon: Icons.help_outline,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _AiSummaryBox(
                      label: 'Analysis Pending',
                      count: pending,
                      color: ExplorerColors.navy,
                      bgColor: ExplorerColors.subtle,
                      icon: Icons.hourglass_top_outlined,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _AiSummaryBox(
                      label: 'Unavailable',
                      count: unavailable,
                      color: ExplorerColors.muted,
                      bgColor: ExplorerColors.subtle,
                      icon: Icons.do_not_disturb_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AiSummaryBox extends StatelessWidget {
  const _AiSummaryBox({
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final Color bgColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ExplorerColors.text,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 7: Resolution Confidence Panel
// ---------------------------------------------------------------------------

class _ConfidenceAnalysisCard extends StatelessWidget {
  const _ConfidenceAnalysisCard({
    required this.analysis,
    required this.serverCalculated,
  });
  final ConfidenceAnalysisResult analysis;
  final bool serverCalculated;

  @override
  Widget build(BuildContext context) {
    final hasReliableSample =
        analysis.totalRecentVotes >= SafetyConfig.minimumReliableRecentVotes;
    final color = hasReliableSample
        ? ExplorerColors.navy
        : ExplorerColors.goldDark;

    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExplorerSectionTitle(
            'Community Resolution Analysis',
            subtitle:
                'Community resolution decision support computed from recent crowdsourced evidence.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                serverCalculated
                    ? Icons.verified_user_outlined
                    : Icons.sync_outlined,
                size: 13,
                color: ExplorerColors.muted,
              ),
              Text(
                serverCalculated
                    ? 'Server-calculated confidence'
                    : 'Latest server validation is pending',
                style: const TextStyle(
                  color: ExplorerColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Explicit Sample-Size Communication
          if (!hasReliableSample) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ExplorerColors.warningSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ExplorerColors.warning.withAlpha(120),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: ExplorerColors.goldDark,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Limited community evidence',
                          style: TextStyle(
                            color: ExplorerColors.goldDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${SafetyConfig.minimumReliableRecentVotes - analysis.totalRecentVotes} more recent confirmations are needed before a reliable resolution confidence can be determined.',
                          style: const TextStyle(
                            color: ExplorerColors.text,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: ExplorerColors.successSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ExplorerColors.success.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: ExplorerColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sample size reliable: ${analysis.totalRecentVotes} confirmations in the rolling 15-minute window',
                      style: const TextStyle(
                        color: ExplorerColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Confidence Percentage and Level
          const Text(
            'Resolution Confidence',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ExplorerColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${analysis.confidencePercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              ExplorerStatusBadge(
                label: analysis.displayLevel,
                tone: hasReliableSample
                    ? ExplorerStatusTone.navy
                    : ExplorerStatusTone.warning,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Weighted resolution support',
            style: TextStyle(fontSize: 12, color: ExplorerColors.muted),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (analysis.confidencePercent / 100).clamp(0, 1),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: color,
            backgroundColor: ExplorerColors.subtle,
          ),
          const SizedBox(height: 20),

          // Vote Breakdown Stats
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

          // Secondary Metrics
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _EvidenceMetric(
                label: 'Valid Confirmations',
                value: analysis.validVoteCount,
                icon: Icons.check_circle_outline,
              ),
              _EvidenceMetric(
                label: 'Recent (15m)',
                value: analysis.totalRecentVotes,
                icon: Icons.history,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Recommendation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ExplorerColors.subtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.recommend_outlined,
                  size: 18,
                  color: ExplorerColors.navy,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resolution Recommendation',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ExplorerColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        analysis.recommendation,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: ExplorerColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Collapsible Analysis Details
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'View Confidence Details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ExplorerColors.navy,
                ),
              ),
              children: [
                _AdminDetailRow(
                  label: 'Evidence Strength',
                  value: analysis.evidenceStrength,
                ),
                _AdminDetailRow(
                  label: 'High-Quality Photos',
                  value: '${analysis.strongOrGoodEvidenceCount}',
                ),
                _AdminDetailRow(
                  label: 'Low Quality Photos',
                  value: '${analysis.lowQualityEvidenceCount}',
                ),
                _AdminDetailRow(
                  label: 'Duplicates Flagged',
                  value: '${analysis.possibleDuplicateEvidenceCount}',
                ),
                _AdminDetailRow(
                  label: 'Visually Matched',
                  value: '${analysis.sceneMatchedCount}',
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Support weights factor in proximity, photo quality, recency, and AI evidence matching. '
                    'Confidence requires a sufficient sample size of recent confirmations in the 15-minute window.',
                    style: TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 24),

          // Subtle Decision-Support Disclaimer
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.gavel_outlined, size: 14, color: ExplorerColors.muted),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'AI evidence analysis supports administrator review and does not automatically change hazard status.',
                  style: TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
              ),
            ],
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
          Flexible(
            child: Text(
              '$label  $value',
              style: const TextStyle(
                color: effectiveColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image streaming widget for community vote evidence
// ---------------------------------------------------------------------------

class _VoteEvidenceImage extends StatelessWidget {
  const _VoteEvidenceImage({
    required this.hazardId,
    required this.vote,
    this.voteService,
    this.width = 170,
    this.height = 130,
  });
  final String hazardId;
  final HazardVote vote;
  final HazardVoteService? voteService;
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
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: ExplorerColors.muted,
            ),
          ),
        ),
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }
    return StreamBuilder<Uint8List?>(
      stream: (voteService ?? HazardVoteService()).watchEvidenceBytes(
        hazardId,
        vote.userId,
      ),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(
            bytes,
            errorBuilder: (_, _, _) => SizedBox(
              width: width,
              height: height,
              child: const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: ExplorerColors.muted,
                ),
              ),
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
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return SizedBox(
          width: width,
          height: height,
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: ExplorerColors.muted,
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// SECTION 8: Administrative History Card & Timeline
// ---------------------------------------------------------------------------

class _AdministrativeHistoryCard extends StatelessWidget {
  const _AdministrativeHistoryCard({
    required this.report,
    required this.auditTrailStream,
  });

  final HazardReport report;
  final Stream<List<HazardAuditEntry>> auditTrailStream;

  @override
  Widget build(BuildContext context) {
    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExplorerSectionTitle(
            'Administrative History',
            subtitle:
                'Chronological audit record of administrative review and lifecycle actions.',
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<HazardAuditEntry>>(
            stream: auditTrailStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Unable to load administrative history: ${snapshot.error}',
                  style: const TextStyle(
                    color: ExplorerColors.danger,
                    fontSize: 12,
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final entries = _synthesizeTimeline(
                report,
                snapshot.data ?? const <HazardAuditEntry>[],
              );

              if (entries.isEmpty) {
                return const Text(
                  'No administrative history recorded.',
                  style: TextStyle(color: ExplorerColors.muted, fontSize: 12),
                );
              }

              return Column(
                children: [
                  for (int i = 0; i < entries.length; i++)
                    _TimelineEventRow(
                      entry: entries[i],
                      isLast: i == entries.length - 1,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static List<HazardAuditEntry> _synthesizeTimeline(
    HazardReport report,
    List<HazardAuditEntry> liveEntries,
  ) {
    final results = <HazardAuditEntry>[];

    // 1. Initial submission event derived from report.createdAt
    results.add(
      HazardAuditEntry(
        id: 'initial_submission',
        action: HazardAuditAction.reportSubmitted,
        previousStatus: null,
        newStatus: HazardReportStatus.pendingReview,
        performedBy: null, // Never expose tourist UID
        performedByName: 'Reporter',
        performedAt: report.createdAt,
        note: 'Hazard report submitted',
      ),
    );

    if (liveEntries.isNotEmpty) {
      for (final e in liveEntries) {
        if (e.action == HazardAuditAction.reportSubmitted) {
          results[0] = e;
        } else {
          results.add(e);
        }
      }
    } else {
      // Legacy fallback: derive events from report.statusHistory
      for (int i = 0; i < report.statusHistory.length; i++) {
        final item = report.statusHistory[i];
        final action = switch (item.status) {
          HazardReportStatus.verified => HazardAuditAction.verified,
          HazardReportStatus.rejected => HazardAuditAction.rejected,
          HazardReportStatus.resolved => HazardAuditAction.markedResolved,
          _ => null,
        };
        if (action != null) {
          results.add(
            HazardAuditEntry(
              id: 'legacy_$i',
              action: action,
              previousStatus: i > 0
                  ? report.statusHistory[i - 1].status
                  : HazardReportStatus.pendingReview,
              newStatus: item.status,
              performedBy: null, // Never display raw UID
              performedByName: null, // Falls back to 'Administrator'
              performedAt: item.changedAt,
              note: item.note,
            ),
          );
        }
      }
    }

    results.sort((a, b) {
      final aTime = a.performedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.performedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });

    return results;
  }
}

class _TimelineEventRow extends StatelessWidget {
  const _TimelineEventRow({required this.entry, required this.isLast});

  final HazardAuditEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor, bgColor, tone) = switch (entry.action) {
      HazardAuditAction.reportSubmitted => (
        Icons.send_rounded,
        ExplorerColors.navy,
        ExplorerColors.subtle,
        ExplorerStatusTone.navy,
      ),
      HazardAuditAction.verified => (
        Icons.verified_outlined,
        ExplorerColors.success,
        ExplorerColors.successSoft,
        ExplorerStatusTone.success,
      ),
      HazardAuditAction.reviewedKeepVerified => (
        Icons.fact_check_outlined,
        ExplorerColors.navy,
        ExplorerColors.subtle,
        ExplorerStatusTone.navy,
      ),
      HazardAuditAction.markedResolved => (
        Icons.task_alt,
        ExplorerColors.success,
        ExplorerColors.successSoft,
        ExplorerStatusTone.success,
      ),
      HazardAuditAction.rejected => (
        Icons.cancel_outlined,
        ExplorerColors.danger,
        ExplorerColors.dangerSoft,
        ExplorerStatusTone.danger,
      ),
      _ => (
        Icons.history,
        ExplorerColors.muted,
        ExplorerColors.subtle,
        ExplorerStatusTone.neutral,
      ),
    };

    final title = switch (entry.action) {
      HazardAuditAction.reportSubmitted => 'Hazard Submitted',
      HazardAuditAction.verified => 'Verified',
      HazardAuditAction.reviewedKeepVerified => 'Reviewed — Kept Verified',
      HazardAuditAction.markedResolved => 'Marked Resolved',
      HazardAuditAction.rejected => 'Rejected',
      _ => entry.humanAction,
    };

    final attribution = switch (entry.action) {
      HazardAuditAction.reportSubmitted => 'Submitted by Reporter',
      _ => () {
        final name = (entry.performedByName ?? '').trim();
        final display = name.isNotEmpty ? name : 'Administrator';
        return '${entry.humanAction} by $display';
      }(),
    };

    final formattedTime = entry.performedAt != null
        ? DateFormat.yMMMd().add_jm().format(entry.performedAt!)
        : 'Date unavailable';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline node + connector line
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withAlpha(80), width: 1.5),
              ),
              child: Center(child: Icon(icon, size: 13, color: iconColor)),
            ),
            if (!isLast)
              Container(width: 2, height: 48, color: ExplorerColors.border),
          ],
        ),
        const SizedBox(width: 12),
        // Event content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    ExplorerStatusBadge(label: title.toUpperCase(), tone: tone),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      attribution,
                      style: const TextStyle(
                        color: ExplorerColors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      '•',
                      style: TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                if (entry.previousStatus != null &&
                    entry.newStatus != null &&
                    entry.previousStatus != entry.newStatus) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Transition: ${entry.previousStatus} → ${entry.newStatus}',
                    style: const TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if ((entry.note ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ExplorerColors.subtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: ExplorerColors.border),
                    ),
                    child: Text(
                      entry.note!.trim(),
                      style: const TextStyle(
                        color: ExplorerColors.navy,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
