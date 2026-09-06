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
                  label: 'Scene Match',
                  value: sceneScore >= 1
                      ? 'Strong visual-pattern match'
                      : sceneScore >= .7
                      ? 'Partial visual-pattern match'
                      : sceneScore >= .4
                      ? 'Weak visual-pattern match'
                      : 'No visual-pattern match',
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
                        value: validation.evidenceSource,
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
            ],
          ),
        ),
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
