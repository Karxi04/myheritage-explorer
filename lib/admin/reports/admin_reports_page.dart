part of '../admin_pages.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  Future<void> _warnAccount(
    BuildContext context, {
    required DocumentReference reportRef,
    required String reportedId,
    required String reportedName,
    required String reportedType,
    required String nature,
    required String description,
  }) async {
    final defaultMsg =
        'Warning from Admin: Your account was reported for "$nature". Details: "$description". Please adhere to community standards.';
    final msgController = TextEditingController(text: defaultMsg);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Warn $reportedType'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Target: $reportedName ($reportedType)'),
            const SizedBox(height: 12),
            const Text(
              'Warning Message for User:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: msgController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter warning message...',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'The user/vendor will receive a one-time warning popup the next time they open the application.',
              style: TextStyle(fontSize: 12, color: ExplorerColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Send Warning'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final targetRef = AppServices.profileRefForRole(reportedId, reportedType);
      await targetRef.update({
        'hasPendingWarning': true,
        'warningMessage': msgController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await reportRef.update({
        'status': 'resolved',
        'actionTaken': 'Warned target account',
        'warningMessage': msgController.text.trim(),
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showMessage(
            context, 'Warning sent to $reportedName. They will be warned on next launch.');
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Failed to send warning: $e', error: true);
      }
    }
    msgController.dispose();
  }

  Future<void> _disableAccount(
    BuildContext context, {
    required DocumentReference reportRef,
    required String reportedId,
    required String reportedName,
    required String reportedType,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disable / Remove Account?'),
        content: Text(
          'Are you sure you want to disable account "$reportedName"? The account will be rendered inactive and blocked from app access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ExplorerColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Disable Account'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final targetRef = AppServices.profileRefForRole(reportedId, reportedType);
      await targetRef.update({
        'status': 'disabled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await reportRef.update({
        'status': 'resolved',
        'actionTaken': 'Disabled target account',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showMessage(context, 'Account $reportedName has been disabled.');
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Failed to disable account: $e', error: true);
      }
    }
  }

  Future<void> _dismissReport(
    BuildContext context, {
    required DocumentReference reportRef,
  }) async {
    try {
      await reportRef.update({
        'status': 'resolved',
        'actionTaken': 'Dismissed (No violation)',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showMessage(context, 'Report dismissed.');
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Failed to dismiss report: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppServices.db.collection('user_reports').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final errStr = '${snapshot.error}';
            final isPermission = errStr.contains('permission-denied') ||
                errStr.contains('permission');

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: ExplorerCard(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined,
                              size: 52, color: ExplorerColors.danger),
                          const SizedBox(height: 14),
                          const Text(
                            'Firestore Permission Required',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: ExplorerColors.navy,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isPermission
                                ? 'To enable User & Vendor Reports, please add \'user_reports\' to your Firestore Database Rules in Firebase Console.'
                                : 'Error loading reports: $errStr',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ExplorerColors.muted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          if (isPermission) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ExplorerColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: ExplorerColors.border),
                              ),
                              child: const SelectableText(
                                '// Firebase Console -> Firestore -> Rules\n'
                                'match /{collection}/{document=**} {\n'
                                '  allow read, write: if signedIn()\n'
                                '      && collection in [\n'
                                '        ...\n'
                                '        \'user_reports\'\n'
                                '      ];\n'
                                '}',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: ExplorerColors.navy,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
              snapshot.data!.docs);
          // Sort client-side descending by createdAt
          docs.sort((a, b) {
            final dateA =
                asDate(a.data()['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dateB =
                asDate(b.data()['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });

          final unresolved = docs
              .where((doc) => doc.data()['status'] == 'unresolved')
              .toList();
          final resolved = docs
              .where((doc) => doc.data()['status'] == 'resolved')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const ExplorerAdminPageTitle(
                title: 'User & Vendor Moderation Reports',
                subtitle:
                    'Review submitted user and vendor reports, send warnings, or disable accounts.',
              ),
              const SizedBox(height: 20),

              // SECTION 1: UNRESOLVED REPORTS (TOP)
              Row(
                children: [
                  const Icon(Icons.error_outline, color: ExplorerColors.danger),
                  const SizedBox(width: 8),
                  Text(
                    'Unresolved Reports (${unresolved.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ExplorerColors.navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (unresolved.isEmpty)
                ExplorerCard(
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No pending unresolved reports. All clear!',
                        style: TextStyle(
                            color: ExplorerColors.muted,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: unresolved.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = unresolved[index];
                    final data = doc.data();
                    final nature = '${data['nature'] ?? 'General Violation'}';
                    final reportedName =
                        '${data['reportedName'] ?? 'Unknown'}';
                    final reportedType =
                        '${data['reportedType'] ?? 'user'}';
                    final reportedId = '${data['reportedId'] ?? ''}';
                    final reporterName =
                        '${data['reporterName'] ?? 'Anonymous'}';
                    final description = '${data['description'] ?? ''}';
                    final date = asDate(data['createdAt']);
                    final dateStr = date != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(date)
                        : 'Recently';

                    return ExplorerCard(
                      borderColor: ExplorerColors.danger.withOpacity(0.3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ExplorerColors.dangerSoft,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  nature,
                                  style: const TextStyle(
                                    color: ExplorerColors.danger,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ExplorerColors.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text(
                                'Reported: ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              Text(
                                '$reportedName ($reportedType)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: ExplorerColors.navy,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Reported by: $reporterName',
                            style: const TextStyle(
                              fontSize: 12,
                              color: ExplorerColors.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ExplorerColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ExplorerColors.border),
                            ),
                            child: Text(
                              description,
                              style: const TextStyle(
                                fontSize: 13,
                                color: ExplorerColors.navy,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.check_circle_outline,
                                    size: 16),
                                label: const Text('Dismiss'),
                                onPressed: () => _dismissReport(
                                  context,
                                  reportRef: doc.reference,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                icon: const Icon(Icons.warning_amber_outlined,
                                    size: 16),
                                label: const Text('Warn User'),
                                onPressed: () => _warnAccount(
                                  context,
                                  reportRef: doc.reference,
                                  reportedId: reportedId,
                                  reportedName: reportedName,
                                  reportedType: reportedType,
                                  nature: nature,
                                  description: description,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: ExplorerColors.danger,
                                ),
                                icon: const Icon(Icons.block_outlined, size: 16),
                                label: const Text('Disable Account'),
                                onPressed: () => _disableAccount(
                                  context,
                                  reportRef: doc.reference,
                                  reportedId: reportedId,
                                  reportedName: reportedName,
                                  reportedType: reportedType,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // SECTION 2: RESOLVED HISTORY (BOTTOM)
              Row(
                children: [
                  const Icon(Icons.history, color: ExplorerColors.success),
                  const SizedBox(width: 8),
                  Text(
                    'Resolved Reports History (${resolved.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ExplorerColors.navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (resolved.isEmpty)
                ExplorerCard(
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No resolved report history yet.',
                        style: TextStyle(
                            color: ExplorerColors.muted,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: resolved.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = resolved[index];
                    final data = doc.data();
                    final nature = '${data['nature'] ?? 'General Violation'}';
                    final reportedName =
                        '${data['reportedName'] ?? 'Unknown'}';
                    final reportedType =
                        '${data['reportedType'] ?? 'user'}';
                    final reporterName =
                        '${data['reporterName'] ?? 'Anonymous'}';
                    final actionTaken =
                        '${data['actionTaken'] ?? 'Resolved'}';
                    final description = '${data['description'] ?? ''}';
                    final date = asDate(data['resolvedAt'] ?? data['createdAt']);
                    final dateStr = date != null
                        ? DateFormat('dd MMM yyyy, hh:mm a').format(date)
                        : 'Recently';

                    return ExplorerCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ExplorerColors.successSoft,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  nature,
                                  style: const TextStyle(
                                    color: ExplorerColors.success,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ExplorerColors.navySoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Action: $actionTaken',
                                  style: const TextStyle(
                                    color: ExplorerColors.navy,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ExplorerColors.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Reported $reportedType: $reportedName | By: $reporterName',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: ExplorerColors.navy,
                              fontSize: 13,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Description: $description',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ExplorerColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
