import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/explorer_ui.dart';
import '../../core/helpers.dart';
import '../../core/services.dart';

/// Complete admin monitoring page for Companion location sharing and SOS.
///
/// Tabs:
/// 1. SOS Records
/// 2. Location Consent
/// 3. Live Sharing
///
/// Normal SOS resolution belongs to the travel-group leader.
/// Admin can only force-resolve through an explicit override with a reason.
class AdminEmergencyPage extends StatelessWidget {
  const AdminEmergencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          _HeaderTabs(),
          Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _SosRecordsTab(),
                _LocationConsentTab(),
                _LiveSharingTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderTabs extends StatelessWidget {
  const _HeaderTabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      child: const TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: ExplorerColors.gold,
        indicatorWeight: 3,
        labelColor: ExplorerColors.navy,
        unselectedLabelColor: ExplorerColors.muted,
        labelStyle: TextStyle(fontWeight: FontWeight.w800),
        tabs: [
          Tab(
            icon: Icon(Icons.sos_rounded, size: 20),
            text: 'SOS Records',
          ),
          Tab(
            icon: Icon(Icons.privacy_tip_outlined, size: 20),
            text: 'Location Consent',
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SOS RECORDS
// =============================================================================

class _SosRecordsTab extends StatefulWidget {
  const _SosRecordsTab();

  @override
  State<_SosRecordsTab> createState() => _SosRecordsTabState();
}

class _SosRecordsTabState extends State<_SosRecordsTab> {
  String filter = 'all';
  String search = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db.collection('sos_alerts').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadError(
            title: 'Unable to load SOS records',
            error: snapshot.error,
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTime = _triggeredAt(a.data()) ?? DateTime(2000);
            final bTime = _triggeredAt(b.data()) ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });

        final now = DateTime.now();
        final active =
            docs.where((d) => _sosState(d.data()) == 'active').length;
        final responding =
            docs.where((d) => _sosState(d.data()) == 'responding').length;
        final resolvedToday = docs.where((d) {
          if (_sosState(d.data()) != 'resolved') return false;
          final date = asDate(d.data()['resolvedAt']);
          return date != null && _sameDay(date, now);
        }).length;

        final responseDurations = <Duration>[];
        for (final d in docs) {
          final data = d.data();
          final start = _triggeredAt(data);
          final response = asDate(data['acknowledgedAt']) ??
              asDate(data['routeStartedAt']) ??
              asDate(data['resolvedAt']);

          if (start == null || response == null) continue;

          final duration = response.difference(start);
          if (!duration.isNegative) responseDurations.add(duration);
        }

        final avgResponse = responseDurations.isEmpty
            ? '-'
            : _duration(
          Duration(
            milliseconds: responseDurations
                .fold<int>(
              0,
                  (sum, item) =>
              sum + item.inMilliseconds,
            ) ~/
                responseDurations.length,
          ),
        );

        final visible = docs.where((doc) {
          final data = doc.data();
          final state = _sosState(data);

          if (filter != 'all' && state != filter) return false;

          final q = search.trim().toLowerCase();
          if (q.isEmpty) return true;

          return [
            doc.id,
            data['senderName'],
            data['senderId'],
            data['groupName'],
            data['groupId'],
            data['leaderId'],
            data['acknowledgedByName'],
            data['resolvedByName'],
          ].join(' ').toLowerCase().contains(q);
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const ExplorerAdminPageTitle(
              title: 'Location & SOS Records',
              subtitle:
              'Monitor emergency incidents, response activity and resolution audit trails.',
            ),
            const SizedBox(height: 22),
            _MetricRow(
              specs: [
                _Metric(
                  'Active SOS',
                  '$active',
                  Icons.sos_rounded,
                ),
                _Metric(
                  'Responding',
                  '$responding',
                  Icons.directions_run,
                ),
                _Metric(
                  'Resolved Today',
                  '$resolvedToday',
                  Icons.task_alt,
                ),
                _Metric(
                  'Avg. Response',
                  avgResponse,
                  Icons.timer_outlined,
                ),
              ],
            ),
            const SizedBox(height: 22),
            ExplorerCard(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 780;

                  final searchField = TextField(
                    onChanged: (value) {
                      setState(() => search = value);
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText:
                      'Search SOS ID, traveler, group or responder...',
                    ),
                  );

                  final segmented = SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'all',
                        label: Text('All'),
                      ),
                      ButtonSegment(
                        value: 'active',
                        label: Text('Active'),
                      ),
                      ButtonSegment(
                        value: 'responding',
                        label: Text('Responding'),
                      ),
                      ButtonSegment(
                        value: 'resolved',
                        label: Text('Resolved'),
                      ),
                    ],
                    selected: {filter},
                    onSelectionChanged: (values) {
                      setState(() => filter = values.first);
                    },
                  );

                  if (compact) {
                    return Column(
                      children: [
                        searchField,
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: segmented,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 14),
                      segmented,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: ExplorerSectionTitle(
                    'SOS Incident Records',
                    subtitle:
                    'Open an incident to inspect GPS, timestamps and response history.',
                  ),
                ),
                Text(
                  '${visible.length} record${visible.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (visible.isEmpty)
              const ExplorerEmptyState(
                title: 'No matching SOS incidents',
                subtitle:
                'No records match the current search or status filter.',
                icon: Icons.health_and_safety_outlined,
              )
            else
              ...visible.map(_sosCard),
          ],
        );
      },
    );
  }

  Widget _sosCard(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();
    final state = _sosState(data);
    final sender = _text(data['senderName'], 'Traveler');
    final group = _text(
      data['groupName'],
      _text(data['groupId'], 'Travel Group'),
    );
    final triggered = _triggeredAt(data);
    final resolved = asDate(data['resolvedAt']);
    final gps = _gps(data);
    final count = (data['triggerCount'] as num?)?.toInt() ?? 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ExplorerCard(
        onTap: () => _showSosDetails(document),
        borderColor: state == 'active'
            ? const Color(0xFFF0B8B3)
            : state == 'responding'
            ? const Color(0xFFF0D99B)
            : ExplorerColors.border,
        backgroundColor: state == 'active'
            ? const Color(0xFFFFFBFA)
            : state == 'responding'
            ? const Color(0xFFFFFDF5)
            : Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusCircle(
              state: state,
              sos: true,
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
                          '$sender • $group',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: state == 'resolved'
                                ? ExplorerColors.navy
                                : ExplorerColors.danger,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      _stateBadge(state),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 18,
                    runSpacing: 7,
                    children: [
                      _SmallInfo(
                        Icons.fingerprint,
                        'ID: ${_shortId(document.id)}',
                      ),
                      _SmallInfo(
                        Icons.access_time,
                        _dateTime(triggered),
                      ),
                      if (gps != null)
                        _SmallInfo(
                          Icons.location_on_outlined,
                          '${gps.$1.toStringAsFixed(5)}, '
                              '${gps.$2.toStringAsFixed(5)}',
                        ),
                      if (count > 1)
                        _SmallInfo(
                          Icons.replay,
                          '$count triggers',
                        ),
                    ],
                  ),
                  if (resolved != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Resolved ${_dateTime(resolved)}'
                          '${triggered == null ? '' : ' • Incident duration ${_between(triggered, resolved)}'}',
                      style: const TextStyle(
                        color: ExplorerColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right,
              color: ExplorerColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSosDetails(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) async {
    final data = document.data();
    final state = _sosState(data);

    final triggered = _triggeredAt(data);
    final acknowledged = asDate(data['acknowledgedAt']);
    final routeStarted = asDate(data['routeStartedAt']);
    final resolved = asDate(data['resolvedAt']);
    final gps = _gps(data);

    final sender = _text(data['senderName'], 'Traveler');
    final senderId = _text(data['senderId']);
    final group = _text(data['groupName'], 'Travel Group');
    final groupId = _text(data['groupId']);
    final leaderId = _text(data['leaderId']);
    final ackBy = _text(
      data['acknowledgedByName'],
      _text(data['acknowledgedBy']),
    );
    final resolvedBy = _text(
      data['resolvedByName'],
      _text(data['resolvedBy']),
    );
    final resolutionType = _text(data['resolutionType']);
    final resolutionNote = _text(data['resolutionNote']);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.all(24),
        title: Row(
          children: [
            _StatusCircle(
              state: state,
              sos: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'SOS ${_shortId(document.id)}',
                style: const TextStyle(
                  color: ExplorerColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _stateBadge(state),
          ],
        ),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 14),
                const _Section('Incident'),
                const SizedBox(height: 8),
                _Grid(
                  children: [
                    _Info('Traveler', sender, Icons.person_outline),
                    _Info('Traveler UID', senderId, Icons.badge_outlined),
                    _Info('Group', group, Icons.groups_outlined),
                    _Info('Group ID', groupId, Icons.key_outlined),
                    _Info(
                      'Leader UID',
                      leaderId,
                      Icons.supervisor_account_outlined,
                    ),
                    _Info(
                      'Triggered',
                      _dateTime(triggered),
                      Icons.access_time,
                    ),
                    _Info(
                      'Response Time',
                      _between(
                        triggered,
                        acknowledged ?? routeStarted ?? resolved,
                      ),
                      Icons.timer_outlined,
                    ),
                    _Info(
                      'Total Duration',
                      _between(triggered, resolved),
                      Icons.timelapse,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _Section('Emergency GPS'),
                const SizedBox(height: 8),
                if (gps == null)
                  const _NoGps()
                else
                  _GpsCard(
                    latitude: gps.$1,
                    longitude: gps.$2,
                    danger: true,
                  ),
                const SizedBox(height: 20),
                const _Section('Response Timeline'),
                const SizedBox(height: 8),
                _TimelineRow(
                  icon: Icons.sos_rounded,
                  title: 'SOS triggered',
                  subtitle: _dateTime(triggered),
                  tone: ExplorerStatusTone.danger,
                ),
                if (acknowledged != null)
                  _TimelineRow(
                    icon: Icons.notifications_active_outlined,
                    title: 'Leader acknowledged',
                    subtitle:
                    '${_dateTime(acknowledged)}${ackBy == '-' ? '' : ' • $ackBy'}',
                    tone: ExplorerStatusTone.warning,
                  ),
                if (routeStarted != null)
                  _TimelineRow(
                    icon: Icons.directions_run,
                    title: 'Route guidance started',
                    subtitle: _dateTime(routeStarted),
                    tone: ExplorerStatusTone.navy,
                  ),
                if (resolved != null)
                  _TimelineRow(
                    icon: Icons.task_alt,
                    title: 'SOS resolved',
                    subtitle:
                    '${_dateTime(resolved)}${resolvedBy == '-' ? '' : ' • $resolvedBy'}',
                    tone: ExplorerStatusTone.success,
                  ),
                if (resolved != null) ...[
                  const SizedBox(height: 20),
                  const _Section('Resolution'),
                  const SizedBox(height: 8),
                  _Grid(
                    children: [
                      _Info(
                        'Resolved By',
                        resolvedBy,
                        Icons.verified_user_outlined,
                      ),
                      _Info(
                        'Resolution Type',
                        resolutionType,
                        Icons.rule_outlined,
                      ),
                    ],
                  ),
                  if (resolutionNote != '-') ...[
                    const SizedBox(height: 10),
                    _Note(
                      title: 'Resolution Note',
                      value: resolutionNote,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (state != 'resolved')
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ExplorerColors.danger,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _adminOverride(document);
              },
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Admin Override'),
            ),
        ],
      ),
    );
  }

  Future<void> _adminOverride(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.admin_panel_settings_outlined,
          color: ExplorerColors.danger,
          size: 40,
        ),
        title: const Text('Admin Emergency Override'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Normal SOS resolution should be completed by the group leader. '
                    'Only use this override when administrative intervention is required.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Mandatory override reason',
                  hintText:
                  'Example: Leader unavailable; admin confirmed traveler safety.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ExplorerColors.danger,
            ),
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                showMessage(
                  dialogContext,
                  'Please enter an override reason.',
                  error: true,
                );
                return;
              }

              Navigator.pop(dialogContext, true);
            },
            icon: const Icon(Icons.gavel_outlined),
            label: const Text('Resolve with Override'),
          ),
        ],
      ),
    );

    final reason = controller.text.trim();
    controller.dispose();

    if (confirmed != true || reason.isEmpty) return;

    try {
      final user = AppServices.auth.currentUser;
      if (user == null) {
        throw Exception('Administrator session was not found.');
      }

      var adminName = user.email ?? 'Administrator';

      try {
        final profile = await AppServices.currentProfile();
        final name = '${profile?['displayName'] ?? ''}'.trim();
        if (name.isNotEmpty) adminName = name;
      } catch (_) {}

      final data = document.data();
      final groupId = '${data['groupId'] ?? ''}'.trim();
      final senderId = '${data['senderId'] ?? ''}'.trim();

      final batch = AppServices.db.batch();

      batch.update(document.reference, {
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': user.uid,
        'resolvedByName': adminName,
        'resolutionType': 'admin_override',
        'resolutionNote': reason,
        'adminOverride': true,
      });

      if (groupId.isNotEmpty && senderId.isNotEmpty) {
        batch.set(
          AppServices.db
              .collection('travel_groups')
              .doc(groupId)
              .collection('locations')
              .doc(senderId),
          {
            'sosActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (mounted) {
        showMessage(
          context,
          'SOS resolved with an admin override.',
        );
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          'Unable to resolve SOS: '
              '${error.toString().replaceFirst('Exception: ', '')}',
          error: true,
        );
      }
    }
  }
}

// =============================================================================
// LOCATION CONSENT
// =============================================================================

class _LocationConsentTab extends StatefulWidget {
  const _LocationConsentTab();

  @override
  State<_LocationConsentTab> createState() =>
      _LocationConsentTabState();
}

class _LocationConsentTabState extends State<_LocationConsentTab> {
  String statusFilter = 'all';
  String typeFilter = 'all';
  String search = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
      AppServices.db.collection('location_requests').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadError(
            title: 'Unable to load location consent records',
            error: snapshot.error,
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTime =
                asDate(a.data()['createdAt']) ?? DateTime(2000);
            final bTime =
                asDate(b.data()['createdAt']) ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });

        int count(String status) => docs
            .where(
              (doc) =>
          _consentState(doc.data()['status']) == status,
        )
            .length;

        final visible = docs.where((doc) {
          final data = doc.data();
          final status = _consentState(data['status']);
          final type = _requestType(data);

          if (statusFilter != 'all' && status != statusFilter) {
            return false;
          }

          if (typeFilter != 'all' && type != typeFilter) {
            return false;
          }

          final q = search.trim().toLowerCase();
          if (q.isEmpty) return true;

          return [
            doc.id,
            data['requesterName'],
            data['requesterId'],
            data['targetName'],
            data['targetId'],
            data['targetUserId'],
            data['groupName'],
            data['groupId'],
            data['chatId'],
          ].join(' ').toLowerCase().contains(q);
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const ExplorerAdminPageTitle(
              title: 'Location Consent Audit',
              subtitle:
              'Track who requested location access and whether the traveler approved or rejected it.',
            ),
            const SizedBox(height: 22),
            _MetricRow(
              specs: [
                _Metric(
                  'Total Requests',
                  '${docs.length}',
                  Icons.location_searching,
                ),
                _Metric(
                  'Pending',
                  '${count('pending')}',
                  Icons.pending_actions,
                ),
                _Metric(
                  'Approved',
                  '${count('approved')}',
                  Icons.location_on_outlined,
                ),
                _Metric(
                  'Rejected',
                  '${count('rejected')}',
                  Icons.location_off_outlined,
                ),
              ],
            ),
            const SizedBox(height: 22),
            ExplorerCard(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 850;

                  final searchField = TextField(
                    onChanged: (value) {
                      setState(() => search = value);
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText:
                      'Search requester, target, group, chat or ID...',
                    ),
                  );

                  final type = DropdownButtonFormField<String>(
                    initialValue: typeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Types'),
                      ),
                      DropdownMenuItem(
                        value: 'group',
                        child: Text('Group'),
                      ),
                      DropdownMenuItem(
                        value: 'private',
                        child: Text('Private'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => typeFilter = value);
                      }
                    },
                  );

                  final status = DropdownButtonFormField<String>(
                    initialValue: statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Statuses'),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                      DropdownMenuItem(
                        value: 'approved',
                        child: Text('Approved'),
                      ),
                      DropdownMenuItem(
                        value: 'rejected',
                        child: Text('Rejected'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('Cancelled'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => statusFilter = value);
                      }
                    },
                  );

                  if (compact) {
                    return Column(
                      children: [
                        searchField,
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: type),
                            const SizedBox(width: 12),
                            Expanded(child: status),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      SizedBox(width: 170, child: type),
                      const SizedBox(width: 12),
                      SizedBox(width: 170, child: status),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            const ExplorerSectionTitle(
              'Consent Records',
              subtitle:
              'Requests remain as audit records after the traveler responds.',
            ),
            const SizedBox(height: 10),
            if (visible.isEmpty)
              const ExplorerEmptyState(
                title: 'No location consent records',
                subtitle:
                'Location requests will appear here when Companion users request access.',
                icon: Icons.privacy_tip_outlined,
              )
            else
              ...visible.map(_consentCard),
          ],
        );
      },
    );
  }

  Widget _consentCard(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();
    final status = _consentState(data['status']);
    final type = _requestType(data);

    final requester = _text(
      data['requesterName'],
      _text(data['requesterId'], 'Unknown requester'),
    );

    final target = _text(
      data['targetName'],
      _text(
        data['targetId'] ?? data['targetUserId'],
        'Unknown target',
      ),
    );

    final requested = asDate(data['createdAt']);
    final responded = asDate(data['respondedAt']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ExplorerCard(
        onTap: () => _showConsentDetails(document),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusCircle(
              state: status,
              sos: false,
              private: type == 'private',
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
                          type == 'private'
                              ? 'Private Location Request'
                              : 'Group Location Request',
                          style: const TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _stateBadge(status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 18,
                    runSpacing: 7,
                    children: [
                      _SmallInfo(
                        Icons.person_search_outlined,
                        'From: $requester',
                      ),
                      _SmallInfo(
                        Icons.person_outline,
                        'To: $target',
                      ),
                      _SmallInfo(
                        Icons.access_time,
                        _dateTime(requested),
                      ),
                      if (responded != null)
                        _SmallInfo(
                          Icons.timer_outlined,
                          'Response ${_between(requested, responded)}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: ExplorerColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showConsentDetails(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) async {
    final data = document.data();
    final status = _consentState(data['status']);
    final type = _requestType(data);
    final requested = asDate(data['createdAt']);
    final responded = asDate(data['respondedAt']);
    final gps = _gps(data);

    final requesterName = _text(data['requesterName']);
    final requesterId = _text(data['requesterId']);
    final targetName = _text(data['targetName']);
    final targetId =
    _text(data['targetId'] ?? data['targetUserId']);
    final groupName = _text(data['groupName']);
    final groupId = _text(data['groupId']);
    final chatId = _text(data['chatId']);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.all(24),
        title: Row(
          children: [
            _StatusCircle(
              state: status,
              sos: false,
              private: type == 'private',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                type == 'private'
                    ? 'Private Location Consent'
                    : 'Group Location Consent',
                style: const TextStyle(
                  color: ExplorerColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _stateBadge(status),
          ],
        ),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 14),
                _Grid(
                  children: [
                    _Info(
                      'Request ID',
                      document.id,
                      Icons.fingerprint,
                    ),
                    _Info(
                      'Type',
                      type.toUpperCase(),
                      Icons.category_outlined,
                    ),
                    _Info(
                      'Requester',
                      requesterName,
                      Icons.person_search_outlined,
                    ),
                    _Info(
                      'Requester UID',
                      requesterId,
                      Icons.badge_outlined,
                    ),
                    _Info(
                      'Target',
                      targetName,
                      Icons.person_outline,
                    ),
                    _Info(
                      'Target UID',
                      targetId,
                      Icons.badge_outlined,
                    ),
                    _Info(
                      'Requested At',
                      _dateTime(requested),
                      Icons.access_time,
                    ),
                    _Info(
                      'Responded At',
                      _dateTime(responded),
                      Icons.event_available_outlined,
                    ),
                    _Info(
                      'Response Time',
                      _between(requested, responded),
                      Icons.timer_outlined,
                    ),
                    if (groupId != '-')
                      _Info(
                        'Group',
                        groupName == '-' ? groupId : groupName,
                        Icons.groups_outlined,
                      ),
                    if (groupId != '-')
                      _Info(
                        'Group ID',
                        groupId,
                        Icons.key_outlined,
                      ),
                    if (chatId != '-')
                      _Info(
                        'Private Chat ID',
                        chatId,
                        Icons.chat_bubble_outline,
                      ),
                  ],
                ),
                if (gps != null) ...[
                  const SizedBox(height: 20),
                  const _Section('Shared One-Time Location'),
                  const SizedBox(height: 8),
                  _GpsCard(
                    latitude: gps.$1,
                    longitude: gps.$2,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// LIVE SHARING
// =============================================================================

class _LiveSharingTab extends StatefulWidget {
  const _LiveSharingTab();

  @override
  State<_LiveSharingTab> createState() => _LiveSharingTabState();
}

class _LiveSharingTabState extends State<_LiveSharingTab> {
  String filter = 'all';
  String search = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db.collectionGroup('locations').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _LoadError(
            title: 'Unable to load live location records',
            error: snapshot.error,
            hint:
            'Admin needs read permission for travel_groups/{groupId}/locations/{userId}.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final now = DateTime.now();

        final docs = snapshot.data!.docs.where((doc) {
          final groupDocument = doc.reference.parent.parent;
          return groupDocument != null &&
              groupDocument.parent.id == 'travel_groups';
        }).toList()
          ..sort((a, b) {
            final aTime =
                asDate(a.data()['updatedAt']) ?? DateTime(2000);
            final bTime =
                asDate(b.data()['updatedAt']) ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });

        int count(String state) => docs
            .where((doc) => _sharingState(doc.data(), now) == state)
            .length;

        final sosCount =
            docs.where((doc) => doc.data()['sosActive'] == true).length;

        final visible = docs.where((doc) {
          final data = doc.data();
          final state = _sharingState(data, now);

          if (filter == 'sos') {
            if (data['sosActive'] != true) return false;
          } else if (filter != 'all' && state != filter) {
            return false;
          }

          final q = search.trim().toLowerCase();
          if (q.isEmpty) return true;

          final groupId = _groupId(doc);

          return [
            doc.id,
            data['userId'],
            data['displayName'],
            data['role'],
            data['groupName'],
            data['groupId'],
            groupId,
          ].join(' ').toLowerCase().contains(q);
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const ExplorerAdminPageTitle(
              title: 'Live Location Sharing',
              subtitle:
              'Monitor consent-based group GPS sharing and location freshness.',
            ),
            const SizedBox(height: 22),
            _MetricRow(
              specs: [
                _Metric(
                  'Live',
                  '${count('live')}',
                  Icons.gps_fixed,
                ),
                _Metric(
                  'Recent',
                  '${count('recent')}',
                  Icons.schedule,
                ),
                _Metric(
                  'Stale / Offline',
                  '${count('stale') + count('offline')}',
                  Icons.location_off_outlined,
                ),
                _Metric(
                  'SOS Active',
                  '$sosCount',
                  Icons.sos_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ExplorerCard(
              backgroundColor: ExplorerColors.navySoft,
              child: const Text(
                'LIVE = updated within 2 min   •   RECENT = within 10 min   •   '
                    'STALE = older than 10 min   •   OFFLINE = sharing disabled',
                style: TextStyle(
                  color: ExplorerColors.navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 22),
            ExplorerCard(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;

                  final searchField = TextField(
                    onChanged: (value) {
                      setState(() => search = value);
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText:
                      'Search traveler, role, group or UID...',
                    ),
                  );

                  final dropdown = DropdownButtonFormField<String>(
                    initialValue: filter,
                    decoration: const InputDecoration(
                      labelText: 'Sharing State',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All'),
                      ),
                      DropdownMenuItem(
                        value: 'live',
                        child: Text('Live'),
                      ),
                      DropdownMenuItem(
                        value: 'recent',
                        child: Text('Recent'),
                      ),
                      DropdownMenuItem(
                        value: 'stale',
                        child: Text('Stale'),
                      ),
                      DropdownMenuItem(
                        value: 'offline',
                        child: Text('Offline'),
                      ),
                      DropdownMenuItem(
                        value: 'sos',
                        child: Text('SOS Active'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => filter = value);
                      }
                    },
                  );

                  if (compact) {
                    return Column(
                      children: [
                        searchField,
                        const SizedBox(height: 12),
                        dropdown,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      SizedBox(width: 190, child: dropdown),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            const ExplorerSectionTitle(
              'Group Location Records',
              subtitle:
              'Shows the latest stored GPS record for every sharing traveler.',
            ),
            const SizedBox(height: 10),
            if (visible.isEmpty)
              const ExplorerEmptyState(
                title: 'No live-sharing records',
                subtitle:
                'Group GPS records will appear after travelers enable location sharing.',
                icon: Icons.location_off_outlined,
              )
            else
              ...visible.map((doc) => _liveCard(doc, now)),
          ],
        );
      },
    );
  }

  Widget _liveCard(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      DateTime now,
      ) {
    final data = document.data();
    final state = _sharingState(data, now);
    final sos = data['sosActive'] == true;

    final userName = _text(
      data['displayName'],
      _text(data['userId'], 'Traveler'),
    );
    final userId = _text(
      data['userId'],
      document.id,
    );
    final role = _text(data['role'], 'member');
    final groupId = _groupId(document);
    final groupName = _text(
      data['groupName'],
      groupId,
    );
    final updated = asDate(data['updatedAt']);
    final gps = _gps(data);
    final viewers = _stringList(data['approvedViewerIds']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ExplorerCard(
        onTap: () => _showLiveDetails(document, now),
        borderColor: sos
            ? const Color(0xFFF0B8B3)
            : ExplorerColors.border,
        backgroundColor:
        sos ? const Color(0xFFFFFBFA) : Colors.white,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LiveCircle(
              state: state,
              sos: sos,
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
                          userName,
                          style: TextStyle(
                            color: sos
                                ? ExplorerColors.danger
                                : ExplorerColors.navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (sos) ...[
                        const ExplorerStatusBadge(
                          label: 'SOS',
                          tone: ExplorerStatusTone.danger,
                        ),
                        const SizedBox(width: 6),
                      ],
                      _stateBadge(state),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 18,
                    runSpacing: 7,
                    children: [
                      _SmallInfo(
                        Icons.person_outline,
                        _capitalise(role),
                      ),
                      _SmallInfo(
                        Icons.groups_outlined,
                        groupName,
                      ),
                      _SmallInfo(
                        Icons.access_time,
                        'Updated ${_relative(updated, now)}',
                      ),
                      _SmallInfo(
                        Icons.visibility_outlined,
                        '${viewers.length} approved viewer${viewers.length == 1 ? '' : 's'}',
                      ),
                      if (gps != null)
                        _SmallInfo(
                          Icons.location_on_outlined,
                          '${gps.$1.toStringAsFixed(5)}, '
                              '${gps.$2.toStringAsFixed(5)}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Traveler UID: $userId • Group ID: $groupId',
                    style: const TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: ExplorerColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLiveDetails(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      DateTime now,
      ) async {
    final data = document.data();
    final state = _sharingState(data, now);
    final sos = data['sosActive'] == true;
    final gps = _gps(data);

    final userName = _text(
      data['displayName'],
      _text(data['userId'], 'Traveler'),
    );
    final userId = _text(data['userId'], document.id);
    final role = _text(data['role'], 'member');
    final groupId = _groupId(document);
    final groupName = _text(data['groupName'], groupId);
    final updated = asDate(data['updatedAt']);
    final viewers = _stringList(data['approvedViewerIds']);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.all(24),
        title: Row(
          children: [
            _LiveCircle(state: state, sos: sos),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                userName,
                style: const TextStyle(
                  color: ExplorerColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (sos) ...[
              const ExplorerStatusBadge(
                label: 'SOS',
                tone: ExplorerStatusTone.danger,
              ),
              const SizedBox(width: 6),
            ],
            _stateBadge(state),
          ],
        ),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 14),
                _Grid(
                  children: [
                    _Info(
                      'Traveler',
                      userName,
                      Icons.person_outline,
                    ),
                    _Info(
                      'Traveler UID',
                      userId,
                      Icons.badge_outlined,
                    ),
                    _Info(
                      'Role',
                      _capitalise(role),
                      Icons.groups_outlined,
                    ),
                    _Info(
                      'Group',
                      groupName,
                      Icons.groups_outlined,
                    ),
                    _Info(
                      'Group ID',
                      groupId,
                      Icons.key_outlined,
                    ),
                    _Info(
                      'Sharing',
                      data['sharingEnabled'] == true
                          ? 'ENABLED'
                          : 'DISABLED',
                      Icons.privacy_tip_outlined,
                    ),
                    _Info(
                      'Freshness',
                      state.toUpperCase(),
                      Icons.schedule,
                    ),
                    _Info(
                      'Last Updated',
                      _dateTime(updated),
                      Icons.update,
                    ),
                    _Info(
                      'SOS Marker',
                      sos ? 'ACTIVE' : 'NONE',
                      Icons.sos_rounded,
                    ),
                    _Info(
                      'Approved Viewers',
                      '${viewers.length}',
                      Icons.visibility_outlined,
                    ),
                  ],
                ),
                if (viewers.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _Note(
                    title: 'Approved Viewer UIDs',
                    value: viewers.join('\n'),
                  ),
                ],
                const SizedBox(height: 20),
                const _Section('Latest GPS'),
                const SizedBox(height: 8),
                if (gps == null)
                  const _NoGps()
                else
                  _GpsCard(
                    latitude: gps.$1,
                    longitude: gps.$2,
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SHARED UI
// =============================================================================

class _Metric {
  const _Metric(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.specs});

  final List<_Metric> specs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: specs
                .map(
                  (item) => SizedBox(
                width: 250,
                child: ExplorerMetricCard(
                  label: item.label,
                  value: item.value,
                  icon: item.icon,
                ),
              ),
            )
                .toList(),
          );
        }

        return Row(
          children: [
            for (var i = 0; i < specs.length; i++) ...[
              Expanded(
                child: ExplorerMetricCard(
                  label: specs[i].label,
                  value: specs[i].value,
                  icon: specs[i].icon,
                ),
              ),
              if (i != specs.length - 1)
                const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }
}

class _SmallInfo extends StatelessWidget {
  const _SmallInfo(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: ExplorerColors.muted,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: ExplorerColors.muted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _StatusCircle extends StatelessWidget {
  const _StatusCircle({
    required this.state,
    required this.sos,
    this.private = false,
  });

  final String state;
  final bool sos;
  final bool private;

  @override
  Widget build(BuildContext context) {
    final tone = _tone(state);

    final background = switch (tone) {
      ExplorerStatusTone.success => ExplorerColors.successSoft,
      ExplorerStatusTone.warning => ExplorerColors.warningSoft,
      ExplorerStatusTone.danger => ExplorerColors.dangerSoft,
      ExplorerStatusTone.navy => ExplorerColors.navySoft,
      ExplorerStatusTone.neutral => ExplorerColors.subtle,
    };

    final color = switch (tone) {
      ExplorerStatusTone.success => ExplorerColors.success,
      ExplorerStatusTone.warning => ExplorerColors.goldDark,
      ExplorerStatusTone.danger => ExplorerColors.danger,
      ExplorerStatusTone.navy => ExplorerColors.navy,
      ExplorerStatusTone.neutral => ExplorerColors.muted,
    };

    IconData icon;

    if (sos) {
      icon = state == 'resolved'
          ? Icons.task_alt
          : state == 'responding'
          ? Icons.directions_run
          : Icons.sos_rounded;
    } else {
      icon = private
          ? Icons.lock_outline
          : state == 'approved'
          ? Icons.location_on_outlined
          : state == 'rejected'
          ? Icons.location_off_outlined
          : Icons.location_searching;
    }

    return CircleAvatar(
      radius: 23,
      backgroundColor: background,
      foregroundColor: color,
      child: Icon(icon),
    );
  }
}

class _LiveCircle extends StatelessWidget {
  const _LiveCircle({
    required this.state,
    required this.sos,
  });

  final String state;
  final bool sos;

  @override
  Widget build(BuildContext context) {
    if (sos) {
      return const CircleAvatar(
        radius: 23,
        backgroundColor: ExplorerColors.dangerSoft,
        foregroundColor: ExplorerColors.danger,
        child: Icon(Icons.sos_rounded),
      );
    }

    final tone = _tone(state);

    final background = switch (tone) {
      ExplorerStatusTone.success => ExplorerColors.successSoft,
      ExplorerStatusTone.warning => ExplorerColors.warningSoft,
      ExplorerStatusTone.danger => ExplorerColors.dangerSoft,
      ExplorerStatusTone.navy => ExplorerColors.navySoft,
      ExplorerStatusTone.neutral => ExplorerColors.subtle,
    };

    final color = switch (tone) {
      ExplorerStatusTone.success => ExplorerColors.success,
      ExplorerStatusTone.warning => ExplorerColors.goldDark,
      ExplorerStatusTone.danger => ExplorerColors.danger,
      ExplorerStatusTone.navy => ExplorerColors.navy,
      ExplorerStatusTone.neutral => ExplorerColors.muted,
    };

    final icon = state == 'live'
        ? Icons.gps_fixed
        : state == 'recent'
        ? Icons.location_on_outlined
        : state == 'stale'
        ? Icons.schedule
        : Icons.location_off_outlined;

    return CircleAvatar(
      radius: 23,
      backgroundColor: background,
      foregroundColor: color,
      child: Icon(icon),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: ExplorerColors.navy,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: children,
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 338,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: ExplorerColors.subtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ExplorerColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: ExplorerColors.navy,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _Note extends StatelessWidget {
  const _Note({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: ExplorerColors.navySoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ExplorerColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ExplorerColors.navy,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(
              color: ExplorerColors.text,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ExplorerStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      ExplorerStatusTone.success => ExplorerColors.success,
      ExplorerStatusTone.warning => ExplorerColors.goldDark,
      ExplorerStatusTone.danger => ExplorerColors.danger,
      ExplorerStatusTone.navy => ExplorerColors.navy,
      ExplorerStatusTone.neutral => ExplorerColors.muted,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color.withOpacity(.12),
            foregroundColor: color,
            child: Icon(icon, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 10,
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

class _GpsCard extends StatelessWidget {
  const _GpsCard({
    required this.latitude,
    required this.longitude,
    this.danger = false,
  });

  final double latitude;
  final double longitude;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger
            ? ExplorerColors.dangerSoft
            : ExplorerColors.navySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: danger
              ? const Color(0xFFF0B8B3)
              : ExplorerColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: danger
                ? ExplorerColors.danger
                : ExplorerColors.navy,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              'Latitude: ${latitude.toStringAsFixed(6)}\n'
                  'Longitude: ${longitude.toStringAsFixed(6)}',
              style: const TextStyle(
                color: ExplorerColors.navy,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _openMap(latitude, longitude),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open Map'),
          ),
        ],
      ),
    );
  }
}

class _NoGps extends StatelessWidget {
  const _NoGps();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ExplorerColors.subtle,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.location_off_outlined,
            color: ExplorerColors.muted,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No valid GPS location is stored for this record.',
              style: TextStyle(
                color: ExplorerColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.title,
    required this.error,
    this.hint,
  });

  final String title;
  final Object? error;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ExplorerCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: ExplorerColors.danger,
                  size: 50,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 12,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    hint!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ExplorerColors.goldDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// HELPERS
// =============================================================================

String _text(dynamic value, [String fallback = '-']) {
  final result = '${value ?? ''}'.trim();
  if (result.isEmpty || result.toLowerCase() == 'null') {
    return fallback;
  }
  return result;
}

DateTime? _triggeredAt(Map<String, dynamic> data) {
  return asDate(data['lastTriggeredAt']) ??
      asDate(data['timestamp']) ??
      asDate(data['createdAt']);
}

String _sosState(Map<String, dynamic> data) {
  final raw = '${data['status'] ?? 'active'}'.toLowerCase();

  if (raw == 'resolved') return 'resolved';

  if (raw == 'responding' ||
      asDate(data['acknowledgedAt']) != null ||
      asDate(data['routeStartedAt']) != null) {
    return 'responding';
  }

  return 'active';
}

String _consentState(dynamic value) {
  final raw = '$value'.trim().toLowerCase();

  if (raw == 'accepted' ||
      raw == 'approved' ||
      raw == 'granted') {
    return 'approved';
  }

  if (raw == 'rejected' ||
      raw == 'declined' ||
      raw == 'denied') {
    return 'rejected';
  }

  if (raw == 'cancelled' || raw == 'canceled') {
    return 'cancelled';
  }

  return 'pending';
}

String _requestType(Map<String, dynamic> data) {
  final raw = '${data['requestType'] ?? ''}'.toLowerCase();

  if (raw == 'private') return 'private';
  if (raw == 'group') return 'group';

  return '${data['chatId'] ?? ''}'.trim().isNotEmpty
      ? 'private'
      : 'group';
}

String _sharingState(
    Map<String, dynamic> data,
    DateTime now,
    ) {
  if (data['sharingEnabled'] != true) return 'offline';

  final updated = asDate(data['updatedAt']);
  if (updated == null) return 'stale';

  final age = now.difference(updated);

  if (age.isNegative || age <= const Duration(minutes: 2)) {
    return 'live';
  }

  if (age <= const Duration(minutes: 10)) {
    return 'recent';
  }

  return 'stale';
}

ExplorerStatusTone _tone(String state) {
  if (state == 'resolved' ||
      state == 'approved' ||
      state == 'live') {
    return ExplorerStatusTone.success;
  }

  if (state == 'responding' ||
      state == 'pending' ||
      state == 'stale') {
    return ExplorerStatusTone.warning;
  }

  if (state == 'active' || state == 'rejected') {
    return ExplorerStatusTone.danger;
  }

  if (state == 'recent') {
    return ExplorerStatusTone.navy;
  }

  return ExplorerStatusTone.neutral;
}

Widget _stateBadge(String state) {
  return ExplorerStatusBadge(
    label: state.toUpperCase(),
    tone: _tone(state),
  );
}

(double, double)? _gps(Map<String, dynamic> data) {
  final location = data['location'];

  if (location is GeoPoint) {
    return (location.latitude, location.longitude);
  }

  if (location is Map) {
    final lat = location['latitude'] ?? location['lat'];
    final lng =
        location['longitude'] ?? location['lng'] ?? location['lon'];

    if (lat is num && lng is num) {
      return (lat.toDouble(), lng.toDouble());
    }
  }

  final lat = data['latitude'];
  final lng = data['longitude'];

  if (lat is num && lng is num) {
    return (lat.toDouble(), lng.toDouble());
  }

  return null;
}

String _groupId(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) {
  final saved = '${doc.data()['groupId'] ?? ''}'.trim();
  if (saved.isNotEmpty) return saved;

  return doc.reference.parent.parent?.id ?? '-';
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const <String>[];

  return value
      .where((item) => item != null)
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _shortId(String value) {
  if (value.length <= 8) return value.toUpperCase();
  return value.substring(0, 8).toUpperCase();
}

String _dateTime(DateTime? date) {
  if (date == null) return 'Unavailable';
  return DateFormat('dd MMM yyyy, hh:mm a').format(date);
}

String _between(DateTime? start, DateTime? end) {
  if (start == null || end == null) return '-';

  final difference = end.difference(start);
  if (difference.isNegative) return '-';

  return _duration(difference);
}

String _duration(Duration duration) {
  if (duration.inSeconds < 60) {
    return '${duration.inSeconds}s';
  }

  if (duration.inMinutes < 60) {
    return '${duration.inMinutes}m';
  }

  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;

  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
}

String _relative(DateTime? date, DateTime now) {
  if (date == null) return 'unknown';

  final difference = now.difference(date);

  if (difference.isNegative || difference.inSeconds < 20) {
    return 'just now';
  }

  if (difference.inMinutes < 1) {
    return '${difference.inSeconds}s ago';
  }

  if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  }

  if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  }

  return '${difference.inDays}d ago';
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;
}

String _capitalise(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

Future<void> _openMap(
    double latitude,
    double longitude,
    ) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
  );

  await launchUrl(
    uri,
    mode: LaunchMode.platformDefault,
  );
}
