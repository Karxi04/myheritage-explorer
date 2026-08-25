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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: ExplorerColors.muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: ExplorerColors.muted, fontSize: 10),
        ),
      ],
    );
  }
}

class _ConfidenceAnalysisCard extends StatelessWidget {
  const _ConfidenceAnalysisCard({required this.analysis});

  final ConfidenceAnalysisResult analysis;

  @override
  Widget build(BuildContext context) {
    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExplorerSectionTitle('COMMUNITY RESOLUTION ANALYSIS'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              Text('Total Valid Votes: ${analysis.validVoteCount}'),
              Text('Recent Votes: ${analysis.totalRecentVotes}'),
              Text('GPS-Validated: ${analysis.gpsValidatedCount}'),
              Text('With Photo Evidence: ${analysis.photoEvidenceCount}'),
              Text('Evidence Strength: ${analysis.evidenceStrength}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ConfidenceStat(
                  label: 'Hazard Appears Resolved',
                  value: '${analysis.resolvedVotes}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ConfidenceStat(
                  label: 'Hazard Still Exists',
                  value: '${analysis.existsVotes}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Recent ${SafetyConfig.recencyMediumWeight.inMinutes}-minute window: '
            '${analysis.totalRecentVotes} votes '
            '(${analysis.recentResolvedVotes} resolved, '
            '${analysis.recentExistsVotes} still exists)',
            style: const TextStyle(color: ExplorerColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Text(
            'Weighted Resolution Support: '
            '${analysis.confidencePercent.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: ExplorerColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Confidence Level: ${analysis.displayLevel}',
            style: const TextStyle(color: ExplorerColors.text, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            analysis.recommendation,
            style: const TextStyle(
              color: ExplorerColors.muted,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceStat extends StatelessWidget {
  const _ConfidenceStat({required this.label, required this.value});

  final String label;
  final String value;

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
          Text(
            value,
            style: const TextStyle(
              color: ExplorerColors.navy,
              fontSize: 20,
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
    final evidence =
        votes
            .where(
              (vote) => vote.hasPhotoEvidence,
            )
            .toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
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
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: evidence.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _VoteEvidenceImage(
                  hazardId: hazardId,
                  vote: evidence[index],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteEvidenceImage extends StatelessWidget {
  const _VoteEvidenceImage({required this.hazardId, required this.vote});
  final String hazardId;
  final HazardVote vote;

  @override
  Widget build(BuildContext context) {
    final legacyUrl = vote.photoUrl?.trim() ?? '';
    if (legacyUrl.isNotEmpty) {
      return Image.network(
        legacyUrl,
        width: 170,
        height: 130,
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
            width: 170,
            height: 130,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 170,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return const SizedBox(
          width: 170,
          child: Icon(Icons.broken_image_outlined),
        );
      },
    );
  }
}
