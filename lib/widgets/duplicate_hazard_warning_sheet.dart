import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/explorer_ui.dart';
import '../models/hazard_report.dart';

/// User action when resolving a duplicate hazard advisory warning.
enum DuplicateWarningAction { submitAnyway, cancel }

/// Advisory warning sheet presented when one or more nearby hazards matching
/// the selected category already exist in Firestore (Pending Review or Verified).
class DuplicateHazardWarningSheet extends StatelessWidget {
  const DuplicateHazardWarningSheet({
    super.key,
    required this.candidates,
    required this.onViewExisting,
    this.onSubmitAnyway,
    this.onCancel,
  });

  final List<HazardDuplicateCandidate> candidates;
  final void Function(HazardReport report) onViewExisting;
  final VoidCallback? onSubmitAnyway;
  final VoidCallback? onCancel;

  static String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m away';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final displayCandidates = candidates.take(3).toList();
    final remainingCount = candidates.length - displayCandidates.length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: ExplorerColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ExplorerColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: ExplorerColors.warningSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: ExplorerColors.goldDark,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Similar Hazard Nearby',
                          style: TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'A report already exists in this area',
                          style: TextStyle(
                            color: ExplorerColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () {
                      if (onCancel != null) {
                        onCancel!();
                      } else {
                        Navigator.pop(context, DuplicateWarningAction.cancel);
                      }
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: ExplorerColors.border),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'We found existing report(s) nearby in the same category. '
                      'Check whether your concern has already been reported before creating a duplicate.',
                      style: TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Candidate Cards
                    ...displayCandidates.map((candidate) {
                      final report = candidate.report;
                      final isVerified =
                          report.status == HazardReportStatus.verified;
                      final statusLabel = isVerified
                          ? 'VERIFIED'
                          : 'PENDING REVIEW';
                      final statusTone = isVerified
                          ? ExplorerStatusTone.success
                          : ExplorerStatusTone.warning;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ExplorerColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ExplorerColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Category + Status Badge
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    report.category,
                                    style: const TextStyle(
                                      color: ExplorerColors.navy,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  flex: 0,
                                  child: ExplorerStatusBadge(
                                    label: statusLabel,
                                    tone: statusTone,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Meta Chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _MetaChip(
                                  icon: Icons.near_me_outlined,
                                  label: _formatDistance(
                                    candidate.distanceMeters,
                                  ),
                                ),
                                _MetaChip(
                                  icon: Icons.priority_high_rounded,
                                  label: '${report.severity} severity',
                                ),
                                if (report.createdAt != null)
                                  _MetaChip(
                                    icon: Icons.schedule_outlined,
                                    label: DateFormat.yMMMd().format(
                                      report.createdAt!,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Description snippet
                            if (report.description.isNotEmpty)
                              Text(
                                report.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: ExplorerColors.text,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            const SizedBox(height: 12),

                            // View Existing button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => onViewExisting(report),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 16,
                                ),
                                label: const Text('View Existing Hazard'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    if (remainingCount > 0)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '+ $remainingCount more older or farther reports nearby',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: ExplorerColors.muted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: ExplorerColors.border),

            // Actions Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      if (onSubmitAnyway != null) {
                        onSubmitAnyway!();
                      } else {
                        Navigator.pop(
                          context,
                          DuplicateWarningAction.submitAnyway,
                        );
                      }
                    },
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: const Text('Submit New Report Anyway'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      if (onCancel != null) {
                        onCancel!();
                      } else {
                        Navigator.pop(context, DuplicateWarningAction.cancel);
                      }
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: const Text(
                      'Keep Editing / Cancel',
                      style: TextStyle(color: ExplorerColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ExplorerColors.subtle,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ExplorerColors.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ExplorerColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the duplicate hazard advisory bottom sheet.
Future<DuplicateWarningAction?> showDuplicateHazardWarning({
  required BuildContext context,
  required List<HazardDuplicateCandidate> candidates,
  required void Function(HazardReport report) onViewExisting,
}) {
  return showModalBottomSheet<DuplicateWarningAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => DuplicateHazardWarningSheet(
      candidates: candidates,
      onViewExisting: onViewExisting,
    ),
  );
}
