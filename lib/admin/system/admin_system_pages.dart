
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/explorer_ui.dart';
import '../../core/helpers.dart';
import '../../core/services.dart';

class AdminManagementPage extends StatelessWidget {
  const AdminManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final admins = snapshot.data!.docs;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const ExplorerAdminPageTitle(
              title: 'Admin Management',
              subtitle:
                  'Manage administrator access and review active controller accounts.',
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ExplorerMetricCard(
                    label: 'Active Administrators',
                    value: '${admins.length}',
                    icon: Icons.admin_panel_settings_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: ExplorerMetricCard(
                    label: '2FA Enforcement',
                    value: 'Enabled',
                    icon: Icons.verified_user_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: ExplorerMetricCard(
                    label: 'Session Timeout',
                    value: '30 min',
                    icon: Icons.timer_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const ExplorerSectionTitle('Administrator Directory'),
            const SizedBox(height: 10),
            ExplorerCard(
              padding: EdgeInsets.zero,
              child: admins.isEmpty
                  ? const ExplorerEmptyState(
                      title: 'No administrators found',
                    )
                  : Column(
                      children: admins
                          .map(
                            (doc) => Column(
                              children: [
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        ExplorerColors.navySoft,
                                    foregroundColor:
                                        ExplorerColors.navy,
                                    child: Text(
                                      '${doc.data()['displayName'] ?? 'A'}'
                                          .substring(0, 1)
                                          .toUpperCase(),
                                    ),
                                  ),
                                  title: Text(
                                    '${doc.data()['displayName'] ?? 'Administrator'}',
                                    style: const TextStyle(
                                      color: ExplorerColors.navy,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${doc.data()['email'] ?? ''}',
                                  ),
                                  trailing: ExplorerStatusBadge(
                                    label:
                                        '${doc.data()['status'] ?? 'active'}'
                                            .toUpperCase(),
                                    tone: doc.data()['status'] == 'active'
                                        ? ExplorerStatusTone.success
                                        : ExplorerStatusTone.neutral,
                                  ),
                                ),
                                if (doc != admins.last)
                                  const Divider(height: 1, indent: 70),
                              ],
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class AdminEmergencyPage extends StatelessWidget {
  const AdminEmergencyPage({super.key});

  Future<void> resolve(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    await doc.reference.update({
      'status': 'resolved',
      'resolvedBy': AppServices.auth.currentUser!.uid,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db.collection('sos_alerts').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.toList()
          ..sort(
            (a, b) => (asDate(b.data()['createdAt']) ?? DateTime(2000))
                .compareTo(
              asDate(a.data()['createdAt']) ?? DateTime(2000),
            ),
          );
        final active =
            docs.where((doc) => doc.data()['status'] != 'resolved').length;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const ExplorerAdminPageTitle(
              title: 'Location & SOS Monitoring',
              subtitle:
                  'Real-time oversight of explorer safety and emergency location data.',
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ExplorerMetricCard(
                    label: 'Active SOS Alerts',
                    value: '$active',
                    icon: Icons.sos,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: ExplorerMetricCard(
                    label: 'Network Health',
                    value: '98%',
                    icon: Icons.wifi_tethering,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ExplorerMetricCard(
                    label: 'Resolved Alerts',
                    value: '${docs.length - active}',
                    icon: Icons.task_alt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const ExplorerSectionTitle('SOS Alerts'),
            const SizedBox(height: 10),
            if (docs.isEmpty)
              const ExplorerEmptyState(
                title: 'No SOS alerts',
                subtitle:
                    'Emergency alerts sent by travelers will appear here.',
                icon: Icons.health_and_safety_outlined,
              )
            else
              ...docs.map(
                (doc) {
                  final data = doc.data();
                  final status = '${data['status'] ?? 'active'}';
                  final geo = data['location'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ExplorerCard(
                      borderColor: status == 'resolved'
                          ? ExplorerColors.border
                          : const Color(0xFFF0B8B3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: status == 'resolved'
                                  ? ExplorerColors.successSoft
                                  : ExplorerColors.dangerSoft,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              status == 'resolved'
                                  ? Icons.task_alt
                                  : Icons.sos,
                              color: status == 'resolved'
                                  ? ExplorerColors.success
                                  : ExplorerColors.danger,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SOS Alert: ${data['userId'] ?? 'Traveler'}',
                                  style: const TextStyle(
                                    color: ExplorerColors.navy,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Group: ${data['groupId'] ?? '-'}',
                                  style: const TextStyle(
                                    color: ExplorerColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                                if (geo is GeoPoint)
                                  Text(
                                    'Coordinates: ${geo.latitude.toStringAsFixed(5)}, ${geo.longitude.toStringAsFixed(5)}',
                                    style: const TextStyle(
                                      color: ExplorerColors.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  asDate(data['createdAt']) == null
                                      ? 'Recently triggered'
                                      : DateFormat.yMMMd()
                                          .add_jm()
                                          .format(
                                            asDate(
                                              data['createdAt'],
                                            )!,
                                          ),
                                  style: const TextStyle(
                                    color: ExplorerColors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (status != 'resolved')
                            FilledButton(
                              onPressed: () => resolve(doc),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(110, 40),
                                backgroundColor:
                                    ExplorerColors.danger,
                              ),
                              child: const Text('Resolve'),
                            )
                          else
                            const ExplorerStatusBadge(
                              label: 'RESOLVED',
                              tone: ExplorerStatusTone.success,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() =>
      _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final platformName =
      TextEditingController(text: 'MyHeritage Explorer');
  final supportEmail =
      TextEditingController(text: 'support@myheritage.gov');
  final welcome = TextEditingController(
    text:
        'Welcome to the central hub for heritage exploration. Manage your journeys, reviews and safety alerts securely.',
  );
  bool profanity = true;
  bool manualImageReview = true;
  bool criticalOverride = true;
  bool smsFallback = false;
  bool busy = false;

  Future<void> load() async {
    final doc =
        await AppServices.db.collection('settings').doc('platform').get();
    final data = doc.data();
    if (data == null || !mounted) return;
    setState(() {
      platformName.text = '${data['platformName'] ?? platformName.text}';
      supportEmail.text = '${data['supportEmail'] ?? supportEmail.text}';
      welcome.text = '${data['welcomeMessage'] ?? welcome.text}';
      profanity = data['autoFlagProfanity'] ?? profanity;
      manualImageReview =
          data['manualImageReview'] ?? manualImageReview;
      criticalOverride =
          data['criticalAlertOverride'] ?? criticalOverride;
      smsFallback = data['smsFallback'] ?? smsFallback;
    });
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await AppServices.db.collection('settings').doc('platform').set(
        {
          'platformName': platformName.text.trim(),
          'supportEmail': supportEmail.text.trim(),
          'welcomeMessage': welcome.text.trim(),
          'autoFlagProfanity': profanity,
          'manualImageReview': manualImageReview,
          'criticalAlertOverride': criticalOverride,
          'smsFallback': smsFallback,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': AppServices.auth.currentUser!.uid,
        },
        SetOptions(merge: true),
      );
      if (mounted) {
        showMessage(context, 'Configuration saved.');
      }
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    platformName.dispose();
    supportEmail.dispose();
    welcome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ExplorerAdminPageTitle(
          title: 'Basic Settings',
          subtitle:
              'Manage platform-wide configurations and operational rules.',
          actions: [
            OutlinedButton(
              onPressed: busy ? null : load,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(120, 42),
              ),
              child: const Text('Discard Changes'),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: busy ? null : save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(145, 42),
              ),
              child: Text(
                busy ? 'Saving...' : 'Save Configuration',
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        ExplorerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExplorerSectionTitle('Platform Profile'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: platformName,
                      decoration: const InputDecoration(
                        labelText: 'Platform Name',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: supportEmail,
                      decoration: const InputDecoration(
                        labelText: 'Support Email',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: welcome,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Global Welcome Message',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ExplorerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ExplorerSectionTitle('Moderation Rules'),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-flag profanity'),
                      value: profanity,
                      onChanged: (value) =>
                          setState(() => profanity = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title:
                          const Text('Require manual image review'),
                      value: manualImageReview,
                      onChanged: (value) =>
                          setState(() => manualImageReview = value),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ExplorerCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ExplorerSectionTitle(
                      'Safety & Hazard Alerts',
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title:
                          const Text('Critical Alert Override'),
                      value: criticalOverride,
                      onChanged: (value) =>
                          setState(() => criticalOverride = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('SMS Fallback'),
                      value: smsFallback,
                      onChanged: (value) =>
                          setState(() => smsFallback = value),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
