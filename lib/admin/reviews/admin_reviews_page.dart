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
        showMessage(context, 'Successfully synced $count reviews for all vendors and places.');
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
          final matchesStatus = filter == 'all' || data['status'] == filter;
          final haystack =
              '${data['comment']} ${data['placeId']} ${data['placeName']} '
                      '${data['userId']} ${data['reviewerName']} ${data['flagReason']}'
                  .toLowerCase();
          return matchesStatus && haystack.contains(q);
        }).toList();
        final flagged = allDocs
            .where((doc) => doc.data()['status'] == 'flagged')
            .length;
        final valid = allDocs
            .where((doc) => doc.data()['status'] == 'valid')
            .length;
        final hidden = allDocs
            .where((doc) => doc.data()['status'] == 'hidden')
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
                    label: 'Valid Reviews',
                    value: '$valid',
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
                      value: filter,
                      decoration: const InputDecoration(
                        labelText: 'Moderation status',
                        isDense: true,
                      ),
                      items: ['flagged', 'valid', 'hidden', 'all']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value == 'all'
                                    ? 'All reviews'
                                    : '${value[0].toUpperCase()}${value.substring(1)}',
                              ),
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
                    label: Text(seeding ? 'Syncing...' : 'Sync All Vendor Reviews'),
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
                          label: const Text('Generate Vendor Reviews & Flagged Queue'),
                        )
                      : null,
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final reviewStatus = '${data['status'] ?? 'flagged'}';
                final rating = (data['rating'] ?? 0) as num;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ExplorerCard(
                    borderColor: reviewStatus == 'flagged'
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
                                    label: reviewStatus.toUpperCase(),
                                    tone: _tone(reviewStatus),
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
                                          'ML risk: ${(((data['mlSuspiciousProbability'] as num).toDouble()) * 100).toStringAsFixed(0)}% • '
                                          'sentiment ${data['mlSentiment'] ?? '-'} '
                                          '(${(((data['mlSentimentConfidence'] as num?)?.toDouble() ?? 0) * 100).toStringAsFixed(0)}%) • '
                                          '${data['mlRatingMismatch'] == true ? 'rating mismatch' : 'rating aligned'} • '
                                          '${data['mlModelVersion'] ?? 'model'}',
                                      danger:
                                          (data['mlSuspiciousProbability']
                                                      as num)
                                                  .toDouble() >=
                                              0.60 ||
                                          data['mlRatingMismatch'] == true,
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
                            if (reviewStatus != 'valid')
                              IconButton(
                                tooltip: 'Mark as valid',
                                onPressed: () async {
                                  await doc.reference.update({
                                    'status': 'valid',
                                    'flagReason': null,
                                    'flagReasons': const <String>[],
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
                            if (reviewStatus != 'hidden')
                              IconButton(
                                tooltip: 'Hide review',
                                onPressed: () async {
                                  await doc.reference.update({
                                    'status': 'hidden',
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

  static ExplorerStatusTone _tone(String status) => switch (status) {
    'valid' => ExplorerStatusTone.success,
    'flagged' => ExplorerStatusTone.warning,
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
