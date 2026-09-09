part of '../traveler_pages.dart';

Future<bool> showSafetyPrioritySheet({
  required BuildContext context,
  required HazardReport report,
  required double distanceMeters,
  required SafetyAlertPriorityResult priority,
}) async {
  final shouldReview = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: ExplorerColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => StreamBuilder<HazardReport?>(
      stream: HazardReportService().watchReport(report.id),
      initialData: report,
      builder: (context, snapshot) {
        if (snapshot.hasError || snapshot.data?.isVerified != true) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('This alert is no longer available.'),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          );
        }
        return _SafetyPrioritySheet(
          report: snapshot.data!,
          distanceMeters: distanceMeters,
          priority: priority,
        );
      },
    ),
  );
  return shouldReview == true;
}

class _SafetyPrioritySheet extends StatelessWidget {
  const _SafetyPrioritySheet({
    required this.report,
    required this.distanceMeters,
    required this.priority,
  });

  final HazardReport report;
  final double distanceMeters;
  final SafetyAlertPriorityResult priority;

  @override
  Widget build(BuildContext context) {
    final tone = _priorityTone(priority.priorityLevel);
    final distance = distanceMeters < 1000
        ? '${distanceMeters.round()}m away'
        : '${(distanceMeters / 1000).toStringAsFixed(1)}km away';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: ExplorerColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tone.$2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.crisis_alert_rounded, color: tone.$1),
            ),
            const SizedBox(height: 14),
            ExplorerStatusBadge(
              label: '${priority.priorityLevel} PRIORITY',
              tone: tone.$3,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 10),
            Text(
              '${report.category} reported nearby',
              style: const TextStyle(
                color: ExplorerColors.navy,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              distance,
              style: TextStyle(
                color: tone.$1,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DetailChip(
                  icon: Icons.speed_rounded,
                  label: '${report.severity} severity',
                ),
                const _DetailChip(
                  icon: Icons.verified_outlined,
                  label: 'Official status: Verified',
                ),
                if (priority.communityScore >= .65)
                  const _DetailChip(
                    icon: Icons.groups_outlined,
                    label: 'Recently confirmed nearby',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              report.description,
              style: const TextStyle(
                color: ExplorerColors.text,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Review Hazard'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Dismiss'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

(Color, Color, ExplorerStatusTone) _priorityTone(String level) =>
    switch (level) {
      'CRITICAL' => (
        ExplorerColors.danger,
        ExplorerColors.dangerSoft,
        ExplorerStatusTone.danger,
      ),
      'HIGH' => (
        ExplorerColors.goldDark,
        ExplorerColors.warningSoft,
        ExplorerStatusTone.warning,
      ),
      'MODERATE' => (
        ExplorerColors.navy,
        ExplorerColors.navySoft,
        ExplorerStatusTone.navy,
      ),
      _ => (
        ExplorerColors.muted,
        ExplorerColors.subtle,
        ExplorerStatusTone.neutral,
      ),
    };
