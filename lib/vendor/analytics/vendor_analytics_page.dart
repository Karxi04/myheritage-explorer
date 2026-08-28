part of '../vendor_pages.dart';

class VendorAnalyticsPage extends StatelessWidget {
  const VendorAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const ExplorerBrand(compact: true),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppServices.db
            .collection('vouchers')
            .where('vendorId', isEqualTo: uid)
            .snapshots(),
        builder: (context, voucherSnapshot) {
          if (!voucherSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final vouchers = voucherSnapshot.data!.docs;
          final totalIssued = vouchers.fold<num>(
            0,
            (total, doc) =>
                total + ((doc.data()['inventoryLimit'] ?? 0) as num),
          );
          final totalClaimed = vouchers.fold<num>(
            0,
            (total, doc) => total + ((doc.data()['claimCount'] ?? 0) as num),
          );

          QueryDocumentSnapshot<Map<String, dynamic>>? topVoucher;
          for (final voucher in vouchers) {
            if (topVoucher == null ||
                ((voucher.data()['claimCount'] ?? 0) as num) >
                    ((topVoucher.data()['claimCount'] ?? 0) as num)) {
              topVoucher = voucher;
            }
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: AppServices.db
                .collection('redemptions')
                .where('vendorId', isEqualTo: uid)
                .snapshots(),
            builder: (context, redemptionSnapshot) {
              if (!redemptionSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final redemptions = redemptionSnapshot.data!.docs.toList()
                ..sort(
                  (a, b) => (asDate(b.data()['redeemedAt']) ?? DateTime(2000))
                      .compareTo(
                        asDate(a.data()['redeemedAt']) ?? DateTime(2000),
                      ),
                );

              final rate = totalClaimed == 0
                  ? 0.0
                  : redemptions.length / totalClaimed * 100;

              final byDay = <String, int>{};
              for (final doc in redemptions) {
                final date = asDate(doc.data()['redeemedAt']);
                if (date != null) {
                  final key = DateFormat('MM/dd').format(date);
                  byDay[key] = (byDay[key] ?? 0) + 1;
                }
              }
              final trend = byDay.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key));
              final trendValues = trend
                  .take(8)
                  .map((entry) => entry.value.toDouble())
                  .toList();
              final interestCounts = <String, int>{};
              for (final doc in redemptions) {
                final rawTags = doc.data()['interestTags'];
                if (rawTags is! Iterable) continue;
                for (final rawTag in rawTags) {
                  final tag = '$rawTag'.trim();
                  if (tag.isNotEmpty) {
                    interestCounts[tag] = (interestCounts[tag] ?? 0) + 1;
                  }
                }
              }
              final sortedInterests = interestCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final topInterests = sortedInterests.take(4).toList();
              final interestTotal = topInterests.fold<int>(
                0,
                (total, entry) => total + entry.value,
              );
              const interestColors = [
                ExplorerColors.navy,
                ExplorerColors.gold,
                Color(0xFF5D88C7),
                Color(0xFFBCC9D8),
              ];

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  const Text(
                    'Redemption Analytics',
                    style: TextStyle(
                      color: ExplorerColors.navy,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Monitor voucher performance and tourist interest trends.',
                    style: TextStyle(color: ExplorerColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ExplorerMetricCard(
                          label: 'Total Vouchers Issued',
                          value: '$totalIssued',
                          caption: '$totalClaimed claimed overall',
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ExplorerMetricCard(
                          label: 'Avg. Redemption Rate',
                          value: '${rate.toStringAsFixed(1)}%',
                          caption:
                              '${redemptions.length} completed redemptions',
                          compact: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ExplorerCard(
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: ExplorerColors.goldSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emoji_events_outlined,
                            color: ExplorerColors.goldDark,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Top Performer',
                                style: TextStyle(
                                  color: ExplorerColors.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                topVoucher == null
                                    ? 'No voucher data'
                                    : '${topVoucher.data()['title'] ?? 'No voucher data'}',
                                style: const TextStyle(
                                  color: ExplorerColors.navy,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ExplorerStatusBadge(
                          label: topVoucher == null
                              ? '0 CLAIMS'
                              : '${topVoucher.data()['claimCount'] ?? 0} CLAIMS',
                          tone: ExplorerStatusTone.warning,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const ExplorerSectionTitle('Redemption Trend'),
                  const SizedBox(height: 10),
                  if (trendValues.isEmpty)
                    const ExplorerEmptyState(
                      title: 'No redemption trend yet',
                      subtitle: 'Completed QR scans will build this chart.',
                      icon: Icons.show_chart,
                    )
                  else
                    ExplorerCard(
                      child: SizedBox(
                        height: 170,
                        child: CustomPaint(
                          painter: _VendorLineChartPainter(values: trendValues),
                          child: const Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              'REDEMPTIONS BY DAY',
                              style: TextStyle(
                                color: ExplorerColors.muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  const ExplorerSectionTitle('Claimed vs Redeemed'),
                  const SizedBox(height: 10),
                  ExplorerCard(
                    child: SizedBox(
                      height: 170,
                      child: CustomPaint(
                        painter: _VendorBarChartPainter(
                          claimed: totalClaimed.toDouble(),
                          redeemed: redemptions.length.toDouble(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const ExplorerSectionTitle('Interest Tags Distribution'),
                  const SizedBox(height: 10),
                  if (topInterests.isEmpty)
                    const ExplorerEmptyState(
                      title: 'No interest data yet',
                      subtitle:
                          'Anonymous tourist interests are captured at redemption.',
                      icon: Icons.pie_chart_outline,
                    )
                  else
                    ExplorerCard(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CustomPaint(
                              painter: _VendorDonutPainter(
                                segments: [
                                  for (var i = 0; i < topInterests.length; i++)
                                    (
                                      color: interestColors[i],
                                      ratio:
                                          topInterests[i].value / interestTotal,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              children: [
                                for (var i = 0; i < topInterests.length; i++)
                                  _LegendRow(
                                    color: interestColors[i],
                                    label: topInterests[i].key,
                                    value:
                                        '${(topInterests[i].value / interestTotal * 100).round()}%',
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  const ExplorerSectionTitle('Recent Redemptions'),
                  const SizedBox(height: 10),
                  if (redemptions.isEmpty)
                    const ExplorerEmptyState(
                      title: 'No analytics available',
                      subtitle:
                          'Redemption activity will appear after QR scans.',
                      icon: Icons.analytics_outlined,
                    )
                  else
                    ...redemptions
                        .take(8)
                        .map(
                          (doc) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: ExplorerCard(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: const BoxDecoration(
                                      color: ExplorerColors.successSoft,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_circle_outline,
                                      color: ExplorerColors.success,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${doc.data()['voucherTitle'] ?? 'Voucher ${doc.data()['voucherId'] ?? ''}'}',
                                          style: const TextStyle(
                                            color: ExplorerColors.navy,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          asDate(doc.data()['redeemedAt']) ==
                                                  null
                                              ? 'Recently redeemed'
                                              : DateFormat.yMMMd()
                                                    .add_jm()
                                                    .format(
                                                      asDate(
                                                        doc.data()['redeemedAt'],
                                                      )!,
                                                    ),
                                          style: const TextStyle(
                                            color: ExplorerColors.muted,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const ExplorerStatusBadge(
                                    label: 'REDEEMED',
                                    tone: ExplorerStatusTone.success,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: ExplorerColors.muted, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: ExplorerColors.navy,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorLineChartPainter extends CustomPainter {
  _VendorLineChartPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = ExplorerColors.border
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    if (values.isEmpty) return;
    final maxValue = values.reduce(max);
    final line = Paint()
      ..color = ExplorerColors.navy
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = ExplorerColors.navySoft.withOpacity(.7)
      ..style = PaintingStyle.fill;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final normalized = maxValue == 0 ? 0 : values[i] / maxValue;
      final y = size.height - 18 - normalized * (size.height - 38);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _VendorLineChartPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _VendorBarChartPainter extends CustomPainter {
  _VendorBarChartPainter({required this.claimed, required this.redeemed});

  final double claimed;
  final double redeemed;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = max(1.0, max(claimed, redeemed));
    final barWidth = size.width * .22;
    final baseline = size.height - 20;

    final claimedHeight = (claimed / maxValue) * (size.height - 45);
    final redeemedHeight = (redeemed / maxValue) * (size.height - 45);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .22,
          baseline - claimedHeight,
          barWidth,
          claimedHeight,
        ),
        const Radius.circular(7),
      ),
      Paint()..color = ExplorerColors.navy,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .58,
          baseline - redeemedHeight,
          barWidth,
          redeemedHeight,
        ),
        const Radius.circular(7),
      ),
      Paint()..color = ExplorerColors.gold,
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final item in [
      ('Claimed', size.width * .22 + barWidth / 2),
      ('Redeemed', size.width * .58 + barWidth / 2),
    ]) {
      textPainter.text = TextSpan(
        text: item.$1,
        style: const TextStyle(color: ExplorerColors.muted, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(item.$2 - textPainter.width / 2, baseline + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VendorBarChartPainter oldDelegate) =>
      oldDelegate.claimed != claimed || oldDelegate.redeemed != redeemed;
}

class _VendorDonutPainter extends CustomPainter {
  _VendorDonutPainter({required this.segments});

  final List<({Color color, double ratio})> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = min(size.width, size.height) * .37;
    final strokeWidth = radius * .45;
    var start = -pi / 2;

    for (final segment in segments) {
      final sweep = pi * 2 * segment.ratio;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        Paint()
          ..color = segment.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _VendorDonutPainter oldDelegate) =>
      oldDelegate.segments != segments;
}
