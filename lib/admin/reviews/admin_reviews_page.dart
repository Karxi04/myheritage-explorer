part of '../admin_pages.dart';

class AdminReviewsPage extends StatefulWidget {
  const AdminReviewsPage({super.key});

  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage> {
  String filter = 'flagged';
  final search = TextEditingController();
  bool seeding = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _seedReviews() async {
    setState(() => seeding = true);
    try {
      final count = await AppServices.seedVendorReviews(force: true);
      if (mounted) {
        showMessage(
          context,
          'Successfully synced $count reviews for all vendors and places.',
        );
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Error generating reviews: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => seeding = false);
    }
  }

  Future<void> recalculatePlace(String placeId) async {
    final all = await AppServices.db
        .collection('reviews')
        .where('placeId', isEqualTo: placeId)
        .get();
    final valid = all.docs
        .where((doc) => doc.data()['status'] == 'valid')
        .toList();
    final flagged = all.docs
        .where((doc) => doc.data()['status'] == 'flagged')
        .length;
    final average = valid.isEmpty
        ? 0.0
        : valid
                  .map((doc) => (doc.data()['rating'] ?? 0) as num)
                  .reduce((a, b) => a + b) /
              valid.length;
    String trust;
    if (valid.length < 3) {
      trust = 'Insufficient Data';
    } else {
      final accuracy = valid.length / max(1, valid.length + flagged);
      trust = accuracy >= 0.85
          ? 'High Trust'
          : accuracy >= 0.6
          ? 'Medium Trust'
          : 'Low Trust';
    }
    final placeRef = AppServices.db.collection('places').doc(placeId);
    final placeDocument = await placeRef.get();

    // Geoapify locations may not have a matching document in the places
    // collection. Their score is calculated directly from reviews.
    if (placeDocument.exists) {
      await placeRef.update({
        'score': double.parse(average.toStringAsFixed(1)),
        'trustLabel': trust,
        'reviewCount': valid.length,
        'flaggedReviewCount': flagged,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db.collection('reviews').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ExplorerEmptyState(
            title: 'Unable to load reviews',
            subtitle: '${snapshot.error}'.replaceFirst('Exception: ', ''),
            icon: Icons.rate_review_outlined,
            action: OutlinedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allDocs = snapshot.data!.docs;
        final q = search.text.trim().toLowerCase();
        final docs = allDocs.where((doc) {
          final data = doc.data();
          final matchesStatus = _matchesFilter(data, filter);
          final haystack =
              '${data['comment']} ${data['placeId']} ${data['placeName']} '
                      '${data['userId']} ${data['reviewerName']} ${data['flagReason']} '
                      '${data['flagReasons']} ${data['mlDecision']} ${data['mlRiskLevel']}'
                  .toLowerCase();
          return matchesStatus && haystack.contains(q);
        }).toList();
        final flagged = allDocs
            .where((doc) => _displayModerationStatus(doc.data()) == 'flagged')
            .length;
        final needsReview = allDocs
            .where(
              (doc) => _displayModerationStatus(doc.data()) == 'needs_review',
            )
            .length;
        final normal = allDocs
            .where((doc) => _displayModerationStatus(doc.data()) == 'normal')
            .length;
        final hidden = allDocs
            .where((doc) => _displayModerationStatus(doc.data()) == 'hidden')
            .length;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const ExplorerAdminPageTitle(
              title: 'Review Moderation',
              subtitle:
                  'Inspect suspicious patterns, protect review quality and maintain trustworthy place scores.',
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ExplorerMetricCard(
                    label: 'Flagged Reviews',
                    value: '$flagged',
                    icon: Icons.flag_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ExplorerMetricCard(
                    label: 'Needs Review',
                    value: '$needsReview',
                    icon: Icons.rule_folder_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ExplorerMetricCard(
                    label: 'Normal Reviews',
                    value: '$normal',
                    icon: Icons.verified_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ExplorerMetricCard(
                    label: 'Hidden Reviews',
                    value: '$hidden',
                    icon: Icons.visibility_off_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            ExplorerCard(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ExplorerSearchField(
                    controller: search,
                    hintText: 'Search review, place or user...',
                    width: 360,
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<String>(
                      initialValue: filter,
                      decoration: const InputDecoration(
                        labelText: 'Moderation status',
                        isDense: true,
                      ),
                      items:
                          ['flagged', 'needs_review', 'normal', 'hidden', 'all']
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(_statusLabel(value)),
                                ),
                              )
                              .toList(),
                      onChanged: (value) => setState(() => filter = value!),
                    ),
                  ),
                  ExplorerStatusBadge(
                    label: '${docs.length} IN QUEUE',
                    tone: docs.isEmpty
                        ? ExplorerStatusTone.success
                        : ExplorerStatusTone.warning,
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ExplorerColors.navy,
                    ),
                    onPressed: seeding ? null : _seedReviews,
                    icon: seeding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.auto_fix_high_rounded, size: 16),
                    label: Text(
                      seeding ? 'Syncing...' : 'Sync All Vendor Reviews',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (docs.isEmpty)
              ExplorerCard(
                child: ExplorerEmptyState(
                  title: 'No reviews in this category',
                  subtitle: allDocs.isEmpty
                      ? 'No reviews exist in the database yet. Click below to generate sample reviews and flagged review queue for all vendors.'
                      : 'Try another filter or search term.',
                  icon: Icons.rate_review_outlined,
                  action: allDocs.isEmpty
                      ? FilledButton.icon(
                          onPressed: seeding ? null : _seedReviews,
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          label: const Text(
                            'Generate Vendor Reviews & Flagged Queue',
                          ),
                        )
                      : null,
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final reviewStatus = '${data['status'] ?? 'flagged'}';
                final displayStatus = _displayModerationStatus(data);
                final rating = (data['rating'] ?? 0) as num;
                final riskScore =
                    ((data['mlRiskScore'] as num?) ??
                            (data['mlSuspiciousProbability'] as num?) ??
                            0)
                        .toDouble();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ExplorerCard(
                    borderColor:
                        displayStatus == 'flagged' ||
                            displayStatus == 'needs_review'
                        ? const Color(0xFFF2D390)
                        : ExplorerColors.border,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: ExplorerColors.goldSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$rating',
                                style: const TextStyle(
                                  color: ExplorerColors.navy,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Icon(
                                Icons.star_rounded,
                                color: ExplorerColors.goldDark,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${data['comment'] ?? 'No review comment'}',
                                      style: const TextStyle(
                                        color: ExplorerColors.navy,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  ExplorerStatusBadge(
                                    label: _statusLabel(
                                      displayStatus,
                                    ).toUpperCase(),
                                    tone: _tone(displayStatus),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Wrap(
                                spacing: 16,
                                runSpacing: 5,
                                children: [
                                  _ReviewMeta(
                                    icon: Icons.place_outlined,
                                    text:
                                        'Place: ${data['placeName'] ?? data['placeId'] ?? '-'}',
                                  ),
                                  _ReviewMeta(
                                    icon: Icons.person_outline,
                                    text:
                                        'Traveler: ${data['reviewerName'] ?? data['userId'] ?? '-'}',
                                  ),
                                  if ((data['flagReason'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    _ReviewMeta(
                                      icon: Icons.report_problem_outlined,
                                      text: '${data['flagReason']}',
                                      danger: true,
                                    ),
                                  if (data['mlSuspiciousProbability'] is num)
                                    _ReviewMeta(
                                      icon: Icons.psychology_outlined,
                                      text:
                                          'Risk: ${(riskScore * 100).toStringAsFixed(0)}% '
                                          '(${data['mlRiskLevel'] ?? _riskLevelFromScore(riskScore)}) • '
                                          'sentiment ${data['mlSentiment'] ?? '-'} '
                                          '(${(((data['mlSentimentConfidence'] as num?)?.toDouble() ?? 0) * 100).toStringAsFixed(0)}%) • '
                                          '${data['mlRatingMismatch'] == true ? 'rating mismatch' : 'rating aligned'} • '
                                          '${data['mlModelVersion'] ?? 'model'}',
                                      danger:
                                          displayStatus == 'flagged' ||
                                          displayStatus == 'needs_review',
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Wrap(
                          spacing: 5,
                          children: [
                            if (reviewStatus != 'valid' ||
                                displayStatus == 'needs_review')
                              IconButton(
                                tooltip: 'Mark as valid',
                                onPressed: () async {
                                  await doc.reference.update({
                                    'status': 'valid',
                                    'flagReason': null,
                                    'flagReasons': const <String>[],
                                    'mlDecision': 'normal',
                                    'mlRiskLevel': 'low',
                                    'mlNeedsReview': false,
                                    'moderatedAt': FieldValue.serverTimestamp(),
                                    'moderatedBy':
                                        AppServices.auth.currentUser?.uid,
                                  });
                                  await recalculatePlace('${data['placeId']}');
                                },
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: ExplorerColors.success,
                                ),
                              ),
                            if (reviewStatus != 'flagged')
                              IconButton(
                                tooltip: 'Flag review',
                                onPressed: () async {
                                  await doc.reference.update({
                                    'status': 'flagged',
                                    'flagReason':
                                        'Manually flagged by administrator',
                                    'flagReasons': [
                                      'Manually flagged by administrator',
                                    ],
                                    'mlDecision': 'flagged',
                                    'mlRiskLevel': 'high',
                                    'mlNeedsReview': false,
                                    'moderatedAt': FieldValue.serverTimestamp(),
                                    'moderatedBy':
                                        AppServices.auth.currentUser?.uid,
                                  });
                                  await recalculatePlace('${data['placeId']}');
                                },
                                icon: const Icon(
                                  Icons.flag_outlined,
                                  color: ExplorerColors.warning,
                                ),
                              ),
                            if (reviewStatus != 'hidden')
                              IconButton(
                                tooltip: 'Hide review',
                                onPressed: () async {
                                  await doc.reference.update({
                                    'status': 'hidden',
                                    'mlNeedsReview': false,
                                    'moderatedAt': FieldValue.serverTimestamp(),
                                    'moderatedBy':
                                        AppServices.auth.currentUser?.uid,
                                  });
                                  await recalculatePlace('${data['placeId']}');
                                },
                                icon: const Icon(Icons.visibility_off_outlined),
                              ),
                            IconButton(
                              tooltip: 'Delete review',
                              onPressed: () async {
                                final placeId = '${data['placeId']}';
                                await doc.reference.delete();
                                await recalculatePlace(placeId);
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: ExplorerColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  static bool _matchesFilter(Map<String, dynamic> data, String filter) {
    if (filter == 'all') return true;
    return _displayModerationStatus(data) == filter;
  }

  static String _displayModerationStatus(Map<String, dynamic> data) {
    final status = '${data['status'] ?? ''}'.toLowerCase();
    if (status == 'hidden' || status == 'flagged') return status;

    final decision = '${data['mlDecision'] ?? ''}'.toLowerCase();
    final riskLevel = '${data['mlRiskLevel'] ?? ''}'.toLowerCase();
    if (decision == 'flagged') return 'flagged';
    if (decision == 'needs_review' ||
        riskLevel == 'medium' ||
        data['mlNeedsReview'] == true) {
      return 'needs_review';
    }
    if (decision == 'normal' || riskLevel == 'low') return 'normal';

    final legacyRisk =
        ((data['mlRiskScore'] as num?) ??
                (data['mlSuspiciousProbability'] as num?))
            ?.toDouble();
    if (legacyRisk != null && legacyRisk >= 0.55) return 'needs_review';
    return 'normal';
  }

  static String _statusLabel(String status) => switch (status) {
    'flagged' => 'Flagged',
    'needs_review' => 'Needs review',
    'normal' => 'Normal',
    'hidden' => 'Hidden',
    'all' => 'All reviews',
    _ => status,
  };

  static String _riskLevelFromScore(double score) {
    if (score >= 0.82) return 'high';
    if (score >= 0.55) return 'medium';
    return 'low';
  }

  static ExplorerStatusTone _tone(String status) => switch (status) {
    'normal' => ExplorerStatusTone.success,
    'flagged' => ExplorerStatusTone.warning,
    'needs_review' => ExplorerStatusTone.warning,
    'hidden' => ExplorerStatusTone.neutral,
    _ => ExplorerStatusTone.neutral,
  };
}

class _ReviewMeta extends StatelessWidget {
  const _ReviewMeta({
    required this.icon,
    required this.text,
    this.danger = false,
  });

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? ExplorerColors.danger : ExplorerColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }
}
