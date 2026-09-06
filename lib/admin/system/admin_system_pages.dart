
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

// ================================================================
// ADMIN EMERGENCY / LOCATION & SOS MONITORING
// ================================================================

class AdminEmergencyPage extends StatelessWidget {
  const AdminEmergencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _EmergencyTabHeader(),
          Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _AdminSosAlertsTab(),
                _AdminLocationActivityTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// EMERGENCY TAB HEADER
// ================================================================

class _EmergencyTabHeader extends StatelessWidget {
  const _EmergencyTabHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
      ),
      alignment: Alignment.centerLeft,
      child: const TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: ExplorerColors.gold,
        indicatorWeight: 3,
        labelColor: ExplorerColors.navy,
        unselectedLabelColor: ExplorerColors.muted,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
        ),
        tabs: [
          Tab(
            icon: Icon(
              Icons.sos_rounded,
              size: 20,
            ),
            text: 'SOS Alerts',
          ),
          Tab(
            icon: Icon(
              Icons.location_searching,
              size: 20,
            ),
            text: 'Location Activity',
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SOS ALERTS TAB
// ================================================================

class _AdminSosAlertsTab extends StatefulWidget {
  const _AdminSosAlertsTab();

  @override
  State<_AdminSosAlertsTab> createState() =>
      _AdminSosAlertsTabState();
}

class _AdminSosAlertsTabState
    extends State<_AdminSosAlertsTab> {
  String _filter = 'all';
  String _search = '';

  // ==============================================================
  // RESOLVE SOS
  // ==============================================================

  Future<void> _resolve(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) async {
    final data = document.data();

    if ('${data['status'] ?? 'active'}'.toLowerCase() ==
        'resolved') {
      return;
    }

    final senderName =
        '${data['senderName'] ?? 'Traveler'}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.check_circle_outline,
            color: ExplorerColors.success,
            size: 42,
          ),
          title: const Text(
            'Resolve SOS Alert?',
          ),
          content: Text(
            'Confirm that the emergency involving '
                '$senderName has been handled before '
                'marking this SOS alert as resolved.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                ExplorerColors.success,
              ),
              icon: const Icon(
                Icons.check_circle_outline,
              ),
              label: const Text(
                'Mark Resolved',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final currentUser =
          AppServices.auth.currentUser;

      if (currentUser == null) {
        throw Exception(
          'Administrator session was not found.',
        );
      }

      await document.reference.update({
        'status': 'resolved',
        'resolvedBy': currentUser.uid,
        'resolvedAt':
        FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      showMessage(
        context,
        'SOS alert marked as resolved.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      showMessage(
        context,
        'Unable to resolve SOS alert: '
            '${error.toString().replaceFirst('Exception: ', '')}',
        error: true,
      );
    }
  }

  // ==============================================================
  // SOS DETAILS DIALOG
  // ==============================================================

  void _showDetails(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    final status =
    '${data['status'] ?? 'active'}'
        .toLowerCase();

    final senderName =
        '${data['senderName'] ?? 'Traveler'}';

    final senderId =
        '${data['senderId'] ?? '-'}';

    final groupName =
        '${data['groupName'] ?? 'Travel Group'}';

    final groupId =
        '${data['groupId'] ?? '-'}';

    final leaderId =
        '${data['leaderId'] ?? '-'}';

    final createdAt =
    _createdAt(data);

    final resolvedAt =
    asDate(data['resolvedAt']);

    final resolvedBy =
        '${data['resolvedBy'] ?? '-'}';

    final coordinates =
    _coordinates(data);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding:
          const EdgeInsets.all(32),
          contentPadding:
          const EdgeInsets.fromLTRB(
            24,
            12,
            24,
            24,
          ),
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                status == 'resolved'
                    ? ExplorerColors.successSoft
                    : ExplorerColors.dangerSoft,
                foregroundColor:
                status == 'resolved'
                    ? ExplorerColors.success
                    : ExplorerColors.danger,
                child: Icon(
                  status == 'resolved'
                      ? Icons.task_alt
                      : Icons.sos_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOS ${_shortId(document.id)}',
                      style: const TextStyle(
                        color: ExplorerColors.navy,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      senderName,
                      style: const TextStyle(
                        color:
                        ExplorerColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ExplorerStatusBadge(
                label:
                status.toUpperCase(),
                tone:
                status == 'resolved'
                    ? ExplorerStatusTone.success
                    : ExplorerStatusTone.danger,
              ),
            ],
          ),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Divider(),

                  const SizedBox(height: 16),

                  // ==============================================
                  // EMERGENCY INFORMATION
                  // ==============================================

                  const _EmergencyDetailTitle(
                    title:
                    'Emergency Information',
                  ),

                  const SizedBox(height: 10),

                  _EmergencyDetailGrid(
                    children: [
                      _EmergencyDetailItem(
                        label: 'SOS ID',
                        value: document.id,
                        icon:
                        Icons.fingerprint,
                      ),
                      _EmergencyDetailItem(
                        label: 'Status',
                        value:
                        status.toUpperCase(),
                        icon:
                        Icons.info_outline,
                      ),
                      _EmergencyDetailItem(
                        label:
                        'Triggered At',
                        value:
                        _formatDateTime(
                          createdAt,
                        ),
                        icon:
                        Icons.access_time,
                      ),
                      _EmergencyDetailItem(
                        label:
                        'Response Duration',
                        value:
                        _resolutionDuration(
                          createdAt,
                          resolvedAt,
                        ),
                        icon:
                        Icons.timer_outlined,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ==============================================
                  // TRAVELER INFORMATION
                  // ==============================================

                  const _EmergencyDetailTitle(
                    title:
                    'Traveler Information',
                  ),

                  const SizedBox(height: 10),

                  _EmergencyDetailGrid(
                    children: [
                      _EmergencyDetailItem(
                        label:
                        'Traveler Name',
                        value: senderName,
                        icon:
                        Icons.person_outline,
                      ),
                      _EmergencyDetailItem(
                        label:
                        'Traveler UID',
                        value: senderId,
                        icon:
                        Icons.badge_outlined,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ==============================================
                  // GROUP INFORMATION
                  // ==============================================

                  const _EmergencyDetailTitle(
                    title:
                    'Travel Group Information',
                  ),

                  const SizedBox(height: 10),

                  _EmergencyDetailGrid(
                    children: [
                      _EmergencyDetailItem(
                        label:
                        'Group Name',
                        value: groupName,
                        icon:
                        Icons.groups_outlined,
                      ),
                      _EmergencyDetailItem(
                        label: 'Group ID',
                        value: groupId,
                        icon:
                        Icons.key_outlined,
                      ),
                      _EmergencyDetailItem(
                        label:
                        'Group Leader UID',
                        value: leaderId,
                        icon: Icons
                            .supervisor_account_outlined,
                      ),
                      _EmergencyDetailItem(
                        label:
                        'Emergency Recipient',
                        value:
                        leaderId == '-'
                            ? 'Unavailable'
                            : 'Group Leader',
                        icon: Icons
                            .notifications_active_outlined,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ==============================================
                  // LOCATION
                  // ==============================================

                  const _EmergencyDetailTitle(
                    title:
                    'Emergency Location',
                  ),

                  const SizedBox(height: 10),

                  if (coordinates != null)
                    _EmergencyLocationCard(
                      latitude:
                      coordinates.$1,
                      longitude:
                      coordinates.$2,
                    )
                  else
                    const _EmergencyNoLocation(),

                  // ==============================================
                  // RESOLUTION
                  // ==============================================

                  if (status ==
                      'resolved') ...[
                    const SizedBox(
                      height: 24,
                    ),
                    const _EmergencyDetailTitle(
                      title:
                      'Resolution Information',
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    _EmergencyDetailGrid(
                      children: [
                        _EmergencyDetailItem(
                          label:
                          'Resolved At',
                          value:
                          _formatDateTime(
                            resolvedAt,
                          ),
                          icon: Icons
                              .event_available_outlined,
                        ),
                        _EmergencyDetailItem(
                          label:
                          'Resolved By',
                          value:
                          resolvedBy,
                          icon: Icons
                              .verified_user_outlined,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text('Close'),
            ),
            if (status != 'resolved')
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );

                  _resolve(
                    document,
                  );
                },
                style:
                FilledButton.styleFrom(
                  backgroundColor:
                  ExplorerColors.success,
                ),
                icon: const Icon(
                  Icons.check_circle_outline,
                ),
                label: const Text(
                  'Mark Resolved',
                ),
              ),
          ],
        );
      },
    );
  }

  // ==============================================================
  // MAIN BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db
          .collection('sos_alerts')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding:
              const EdgeInsets.all(24),
              child: Text(
                'Unable to load SOS alerts.\n'
                    '${snapshot.error}',
                textAlign:
                TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child:
            CircularProgressIndicator(),
          );
        }

        // ========================================================
        // SORT ALL SOS RECORDS
        // ========================================================

        final allDocs =
        snapshot.data!.docs.toList()
          ..sort(
                (
                first,
                second,
                ) {
              final firstDate =
                  _createdAt(
                    first.data(),
                  ) ??
                      DateTime(2000);

              final secondDate =
                  _createdAt(
                    second.data(),
                  ) ??
                      DateTime(2000);

              return secondDate
                  .compareTo(
                firstDate,
              );
            },
          );

        // ========================================================
        // REAL METRICS
        // ========================================================

        final activeCount =
            allDocs.where((document) {
              final status =
              '${document.data()['status'] ?? 'active'}'
                  .toLowerCase();

              return status !=
                  'resolved';
            }).length;

        final resolvedCount =
            allDocs.where((document) {
              return '${document.data()['status'] ?? ''}'
                  .toLowerCase() ==
                  'resolved';
            }).length;

        final now =
        DateTime.now();

        final alertsToday =
            allDocs.where((document) {
              final createdAt =
              _createdAt(
                document.data(),
              );

              if (createdAt == null) {
                return false;
              }

              return createdAt.year ==
                  now.year &&
                  createdAt.month ==
                      now.month &&
                  createdAt.day ==
                      now.day;
            }).length;

        // ========================================================
        // FILTER
        // ========================================================

        final displayedDocs =
        allDocs.where((document) {
          final data =
          document.data();

          final status =
          '${data['status'] ?? 'active'}'
              .toLowerCase();

          if (_filter == 'active' &&
              status == 'resolved') {
            return false;
          }

          if (_filter == 'resolved' &&
              status != 'resolved') {
            return false;
          }

          final query =
          _search
              .trim()
              .toLowerCase();

          if (query.isEmpty) {
            return true;
          }

          final searchable = [
            document.id,
            data['senderName'],
            data['senderId'],
            data['groupName'],
            data['groupId'],
            data['leaderId'],
            data['status'],
          ].join(' ').toLowerCase();

          return searchable.contains(
            query,
          );
        }).toList();

        return ListView(
          padding:
          const EdgeInsets.all(24),
          children: [
            // ====================================================
            // PAGE TITLE
            // ====================================================

            const ExplorerAdminPageTitle(
              title:
              'Location & SOS Monitoring',
              subtitle:
              'Real-time emergency oversight, GPS records and SOS resolution audit trail.',
            ),

            const SizedBox(height: 22),

            // ====================================================
            // METRIC CARDS
            // ====================================================

            LayoutBuilder(
              builder:
                  (context, constraints) {
                if (constraints.maxWidth <
                    900) {
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: 260,
                        child:
                        ExplorerMetricCard(
                          label:
                          'Active SOS Alerts',
                          value:
                          '$activeCount',
                          icon:
                          Icons.sos_rounded,
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child:
                        ExplorerMetricCard(
                          label:
                          'Resolved Alerts',
                          value:
                          '$resolvedCount',
                          icon:
                          Icons.task_alt,
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child:
                        ExplorerMetricCard(
                          label:
                          'Total SOS Records',
                          value:
                          '${allDocs.length}',
                          icon:
                          Icons.history,
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child:
                        ExplorerMetricCard(
                          label:
                          'Alerts Today',
                          value:
                          '$alertsToday',
                          icon: Icons
                              .today_outlined,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child:
                      ExplorerMetricCard(
                        label:
                        'Active SOS Alerts',
                        value:
                        '$activeCount',
                        icon:
                        Icons.sos_rounded,
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child:
                      ExplorerMetricCard(
                        label:
                        'Resolved Alerts',
                        value:
                        '$resolvedCount',
                        icon:
                        Icons.task_alt,
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child:
                      ExplorerMetricCard(
                        label:
                        'Total SOS Records',
                        value:
                        '${allDocs.length}',
                        icon:
                        Icons.history,
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child:
                      ExplorerMetricCard(
                        label:
                        'Alerts Today',
                        value:
                        '$alertsToday',
                        icon: Icons
                            .today_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 22),

            // ====================================================
            // SEARCH + FILTER
            // ====================================================

            ExplorerCard(
              child: LayoutBuilder(
                builder:
                    (context, constraints) {
                  final compact =
                      constraints.maxWidth <
                          760;

                  if (compact) {
                    return Column(
                      children: [
                        TextField(
                          onChanged:
                              (value) {
                            setState(() {
                              _search =
                                  value;
                            });
                          },
                          decoration:
                          const InputDecoration(
                            prefixIcon:
                            Icon(
                              Icons.search,
                            ),
                            hintText:
                            'Search SOS records...',
                          ),
                        ),
                        const SizedBox(
                          height: 12,
                        ),
                        SizedBox(
                          width:
                          double.infinity,
                          child:
                          SegmentedButton<
                              String>(
                            segments:
                            const [
                              ButtonSegment(
                                value:
                                'all',
                                label:
                                Text(
                                  'All',
                                ),
                              ),
                              ButtonSegment(
                                value:
                                'active',
                                label:
                                Text(
                                  'Active',
                                ),
                                icon:
                                Icon(
                                  Icons
                                      .warning_amber_rounded,
                                ),
                              ),
                              ButtonSegment(
                                value:
                                'resolved',
                                label:
                                Text(
                                  'Resolved',
                                ),
                                icon:
                                Icon(
                                  Icons
                                      .task_alt,
                                ),
                              ),
                            ],
                            selected: {
                              _filter,
                            },
                            onSelectionChanged:
                                (values) {
                              setState(() {
                                _filter =
                                    values
                                        .first;
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child:
                        TextField(
                          onChanged:
                              (value) {
                            setState(() {
                              _search =
                                  value;
                            });
                          },
                          decoration:
                          const InputDecoration(
                            prefixIcon:
                            Icon(
                              Icons.search,
                            ),
                            hintText:
                            'Search by SOS ID, traveler, group or leader...',
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 14,
                      ),
                      SegmentedButton<
                          String>(
                        segments:
                        const [
                          ButtonSegment(
                            value: 'all',
                            label:
                            Text('All'),
                          ),
                          ButtonSegment(
                            value:
                            'active',
                            label: Text(
                              'Active',
                            ),
                            icon: Icon(
                              Icons
                                  .warning_amber_rounded,
                            ),
                          ),
                          ButtonSegment(
                            value:
                            'resolved',
                            label: Text(
                              'Resolved',
                            ),
                            icon: Icon(
                              Icons
                                  .task_alt,
                            ),
                          ),
                        ],
                        selected: {
                          _filter,
                        },
                        onSelectionChanged:
                            (values) {
                          setState(() {
                            _filter =
                                values.first;
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 22),

            // ====================================================
            // RECORD TITLE
            // ====================================================

            Row(
              children: [
                const Expanded(
                  child:
                  ExplorerSectionTitle(
                    'SOS Alert Records',
                    subtitle:
                    'Select an emergency record to view complete details.',
                  ),
                ),
                Text(
                  '${displayedDocs.length} '
                      'record${displayedDocs.length == 1 ? '' : 's'}',
                  style:
                  const TextStyle(
                    color:
                    ExplorerColors.muted,
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (displayedDocs.isEmpty)
              const ExplorerEmptyState(
                title:
                'No matching SOS alerts',
                subtitle:
                'No SOS records match the selected search or filter.',
                icon: Icons
                    .health_and_safety_outlined,
              )
            else
              ...displayedDocs.map(
                _buildSosCard,
              ),
          ],
        );
      },
    );
  }

  // ==============================================================
  // SOS RECORD CARD
  // ==============================================================

  Widget _buildSosCard(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data =
    document.data();

    final status =
    '${data['status'] ?? 'active'}'
        .toLowerCase();

    final active =
        status != 'resolved';

    final sender =
        '${data['senderName'] ?? 'Traveler'}';

    final group =
        '${data['groupName'] ?? data['groupId'] ?? '-'}';

    final senderId =
        '${data['senderId'] ?? '-'}';

    final createdAt =
    _createdAt(data);

    final resolvedAt =
    asDate(data['resolvedAt']);

    final coordinates =
    _coordinates(data);

    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child: ExplorerCard(
        borderColor: active
            ? const Color(
          0xFFF0B8B3,
        )
            : ExplorerColors.border,
        backgroundColor: active
            ? const Color(
          0xFFFFFBFA,
        )
            : Colors.white,
        onTap: () {
          _showDetails(
            document,
          );
        },
        child: LayoutBuilder(
          builder:
              (context, constraints) {
            final narrow =
                constraints.maxWidth <
                    720;

            final information =
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          active
                              ? 'SOS Alert: $sender'
                              : 'Resolved SOS: $sender',
                          style:
                          TextStyle(
                            color: active
                                ? ExplorerColors
                                .danger
                                : ExplorerColors
                                .navy,
                            fontSize: 15,
                            fontWeight:
                            FontWeight
                                .w900,
                          ),
                        ),
                      ),
                      ExplorerStatusBadge(
                        label: active
                            ? 'ACTIVE'
                            : 'RESOLVED',
                        tone: active
                            ? ExplorerStatusTone
                            .danger
                            : ExplorerStatusTone
                            .success,
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _EmergencyInlineInfo(
                        icon:
                        Icons.fingerprint,
                        text:
                        'ID: ${_shortId(document.id)}',
                      ),
                      _EmergencyInlineInfo(
                        icon: Icons
                            .person_outline,
                        text:
                        'Traveler: $sender',
                      ),
                      _EmergencyInlineInfo(
                        icon: Icons
                            .groups_outlined,
                        text:
                        'Group: $group',
                      ),
                      if (coordinates !=
                          null)
                        _EmergencyInlineInfo(
                          icon: Icons
                              .location_on_outlined,
                          text:
                          '${coordinates.$1.toStringAsFixed(5)}, '
                              '${coordinates.$2.toStringAsFixed(5)}',
                        ),
                      _EmergencyInlineInfo(
                        icon:
                        Icons.access_time,
                        text:
                        _formatDateTime(
                          createdAt,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 7,
                  ),

                  Text(
                    'Traveler UID: '
                        '$senderId',
                    style:
                    const TextStyle(
                      color:
                      ExplorerColors.muted,
                      fontSize: 9,
                    ),
                  ),

                  if (!active &&
                      resolvedAt !=
                          null) ...[
                    const SizedBox(
                      height: 6,
                    ),
                    Text(
                      'Resolved: '
                          '${_formatDateTime(resolvedAt)}'
                          ' • Response duration: '
                          '${_resolutionDuration(createdAt, resolvedAt)}',
                      style:
                      const TextStyle(
                        color:
                        ExplorerColors
                            .muted,
                        fontSize: 10,
                      ),
                    ),
                  ],

                  if (active) ...[
                    const SizedBox(
                      height: 8,
                    ),
                    const Text(
                      'Emergency assistance may still be required.',
                      style:
                      TextStyle(
                        color:
                        ExplorerColors
                            .danger,
                        fontWeight:
                        FontWeight
                            .w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            );

            if (narrow) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      _SosStatusIcon(
                        active: active,
                      ),
                      const SizedBox(
                        width: 14,
                      ),
                      information,
                    ],
                  ),
                  const SizedBox(
                    height: 14,
                  ),
                  SizedBox(
                    width:
                    double.infinity,
                    child: active
                        ? FilledButton.icon(
                      onPressed: () {
                        _resolve(
                          document,
                        );
                      },
                      style:
                      FilledButton
                          .styleFrom(
                        backgroundColor:
                        ExplorerColors
                            .danger,
                      ),
                      icon:
                      const Icon(
                        Icons
                            .check_circle_outline,
                      ),
                      label:
                      const Text(
                        'Resolve SOS',
                      ),
                    )
                        : OutlinedButton.icon(
                      onPressed: () {
                        _showDetails(
                          document,
                        );
                      },
                      icon:
                      const Icon(
                        Icons
                            .visibility_outlined,
                      ),
                      label:
                      const Text(
                        'View Details',
                      ),
                    ),
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _SosStatusIcon(
                  active: active,
                ),
                const SizedBox(
                  width: 14,
                ),
                information,
                const SizedBox(
                  width: 16,
                ),
                if (active)
                  FilledButton.icon(
                    onPressed: () {
                      _resolve(
                        document,
                      );
                    },
                    style:
                    FilledButton
                        .styleFrom(
                      minimumSize:
                      const Size(
                        110,
                        42,
                      ),
                      backgroundColor:
                      ExplorerColors
                          .danger,
                    ),
                    icon: const Icon(
                      Icons
                          .check_circle_outline,
                      size: 17,
                    ),
                    label: const Text(
                      'Resolve',
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () {
                      _showDetails(
                        document,
                      );
                    },
                    icon: const Icon(
                      Icons
                          .visibility_outlined,
                      size: 17,
                    ),
                    label: const Text(
                      'Details',
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==============================================================
  // SOS HELPERS
  // ==============================================================

  static DateTime? _createdAt(
      Map<String, dynamic> data,
      ) {
    return asDate(
      data['createdAt'] ??
          data['timestamp'],
    );
  }

  static (double, double)? _coordinates(
      Map<String, dynamic> data,
      ) {
    final location =
    data['location'];

    if (location is GeoPoint) {
      return (
      location.latitude,
      location.longitude,
      );
    }

    final latitude =
    data['latitude'];

    final longitude =
    data['longitude'];

    if (latitude is num &&
        longitude is num) {
      return (
      latitude.toDouble(),
      longitude.toDouble(),
      );
    }

    return null;
  }

  static String _shortId(
      String id,
      ) {
    if (id.length <= 8) {
      return id.toUpperCase();
    }

    return id
        .substring(0, 8)
        .toUpperCase();
  }

  static String _formatDateTime(
      DateTime? date,
      ) {
    if (date == null) {
      return 'Unavailable';
    }

    return DateFormat
        .yMMMd()
        .add_jm()
        .format(date);
  }

  static String _resolutionDuration(
      DateTime? createdAt,
      DateTime? resolvedAt,
      ) {
    if (createdAt == null ||
        resolvedAt == null) {
      return '-';
    }

    final difference =
    resolvedAt.difference(
      createdAt,
    );

    if (difference.isNegative) {
      return '-';
    }

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} sec';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min';
    }

    final hours =
        difference.inHours;

    final minutes =
        difference.inMinutes % 60;

    if (minutes == 0) {
      return '$hours hr';
    }

    return '$hours hr $minutes min';
  }
}

// ================================================================
// SOS STATUS ICON
// ================================================================

class _SosStatusIcon extends StatelessWidget {
  const _SosStatusIcon({
    required this.active,
  });

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: active
            ? ExplorerColors.dangerSoft
            : ExplorerColors.successSoft,
        shape: BoxShape.circle,
      ),
      child: Icon(
        active
            ? Icons.sos_rounded
            : Icons.task_alt,
        color: active
            ? ExplorerColors.danger
            : ExplorerColors.success,
      ),
    );
  }
}

// ================================================================
// LOCATION ACTIVITY TAB
// ================================================================

class _AdminLocationActivityTab
    extends StatefulWidget {
  const _AdminLocationActivityTab();

  @override
  State<_AdminLocationActivityTab>
  createState() =>
      _AdminLocationActivityTabState();
}

class _AdminLocationActivityTabState
    extends State<_AdminLocationActivityTab> {
  String _filter = 'all';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db
          .collection(
        'location_requests',
      )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding:
              const EdgeInsets.all(24),
              child: Text(
                'Unable to load location activity.\n'
                    '${snapshot.error}',
                textAlign:
                TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child:
            CircularProgressIndicator(),
          );
        }

        final allDocs =
        snapshot.data!.docs.toList()
          ..sort(
                (
                first,
                second,
                ) {
              final firstDate =
                  asDate(
                    first.data()[
                    'createdAt'],
                  ) ??
                      DateTime(2000);

              final secondDate =
                  asDate(
                    second.data()[
                    'createdAt'],
                  ) ??
                      DateTime(2000);

              return secondDate
                  .compareTo(
                firstDate,
              );
            },
          );

        final pending =
            allDocs.where((document) {
              return '${document.data()['status'] ?? 'pending'}'
                  .toLowerCase() ==
                  'pending';
            }).length;

        final approved =
            allDocs.where((document) {
              final status =
              '${document.data()['status'] ?? ''}'
                  .toLowerCase();

              return status == 'approved' ||
                  status == 'accepted';
            }).length;

        final rejected =
            allDocs.where((document) {
              return '${document.data()['status'] ?? ''}'
                  .toLowerCase() ==
                  'rejected';
            }).length;

        final displayed =
        allDocs.where((document) {
          final data =
          document.data();

          final status =
          '${data['status'] ?? 'pending'}'
              .toLowerCase();

          if (_filter != 'all') {
            if (_filter ==
                'approved') {
              if (status !=
                  'approved' &&
                  status !=
                      'accepted') {
                return false;
              }
            } else if (status !=
                _filter) {
              return false;
            }
          }

          final query =
          _search
              .trim()
              .toLowerCase();

          if (query.isEmpty) {
            return true;
          }

          final searchable = [
            document.id,
            data['requesterName'],
            data['requesterId'],
            data['targetName'],
            data['targetId'],
            data['targetUserId'],
            data['groupId'],
            data['chatId'],
            data['requestType'],
            data['status'],
          ].join(' ').toLowerCase();

          return searchable.contains(
            query,
          );
        }).toList();

        return ListView(
          padding:
          const EdgeInsets.all(24),
          children: [
            const ExplorerAdminPageTitle(
              title:
              'Location Sharing Records',
              subtitle:
              'Audit location access requests, traveler consent and sharing activity.',
            ),

            const SizedBox(height: 22),

            // ====================================================
            // LOCATION METRICS
            // ====================================================

            LayoutBuilder(
              builder:
                  (context, constraints) {
                if (constraints.maxWidth <
                    900) {
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: 260,
                        child:
                        ExplorerMetricCard(
                          label:
                          'Total Requests',
                          value:
                          '${allDocs.length}',
                          icon: Icons
                              .location_searching,
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child:
                        ExplorerMetricCard(
                          label: 'Pending',
                          value:
                          '$pending',
                          icon: Icons
                              .pending_actions,
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child:
                        ExplorerMetricCard(
                          label:
                          'Approved',
                          value:
                          '$approved',
                          icon: Icons
                              .location_on_outlined,
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        child:
                        ExplorerMetricCard(
                          label:
                          'Rejected',
                          value:
                          '$rejected',
                          icon: Icons
                              .location_off_outlined,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child:
                      ExplorerMetricCard(
                        label:
                        'Total Requests',
                        value:
                        '${allDocs.length}',
                        icon: Icons
                            .location_searching,
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child:
                      ExplorerMetricCard(
                        label:
                        'Pending',
                        value:
                        '$pending',
                        icon: Icons
                            .pending_actions,
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child:
                      ExplorerMetricCard(
                        label:
                        'Approved',
                        value:
                        '$approved',
                        icon: Icons
                            .location_on_outlined,
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child:
                      ExplorerMetricCard(
                        label:
                        'Rejected',
                        value:
                        '$rejected',
                        icon: Icons
                            .location_off_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 22),

            // ====================================================
            // LOCATION SEARCH
            // ====================================================

            ExplorerCard(
              child: LayoutBuilder(
                builder:
                    (context, constraints) {
                  final compact =
                      constraints.maxWidth <
                          700;

                  final search =
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _search = value;
                      });
                    },
                    decoration:
                    const InputDecoration(
                      prefixIcon:
                      Icon(
                        Icons.search,
                      ),
                      hintText:
                      'Search requester, target, group, chat or request ID...',
                    ),
                  );

                  final filter =
                  DropdownButtonFormField<
                      String>(
                    value: _filter,
                    decoration:
                    const InputDecoration(
                      labelText:
                      'Status',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(
                          'All Statuses',
                        ),
                      ),
                      DropdownMenuItem(
                        value:
                        'pending',
                        child: Text(
                          'Pending',
                        ),
                      ),
                      DropdownMenuItem(
                        value:
                        'approved',
                        child: Text(
                          'Approved',
                        ),
                      ),
                      DropdownMenuItem(
                        value:
                        'rejected',
                        child: Text(
                          'Rejected',
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value ==
                          null) {
                        return;
                      }

                      setState(() {
                        _filter = value;
                      });
                    },
                  );

                  if (compact) {
                    return Column(
                      children: [
                        search,
                        const SizedBox(
                          height: 12,
                        ),
                        filter,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: search,
                      ),
                      const SizedBox(
                        width: 14,
                      ),
                      SizedBox(
                        width: 190,
                        child: filter,
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                const Expanded(
                  child:
                  ExplorerSectionTitle(
                    'Location Consent Audit Log',
                    subtitle:
                    'Records who requested location access and whether consent was granted.',
                  ),
                ),
                Text(
                  '${displayed.length} '
                      'record${displayed.length == 1 ? '' : 's'}',
                  style:
                  const TextStyle(
                    color:
                    ExplorerColors.muted,
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (displayed.isEmpty)
              const ExplorerEmptyState(
                title:
                'No location activity',
                subtitle:
                'Location access requests will appear here for monitoring.',
                icon: Icons.history,
              )
            else
              ...displayed.map(
                _buildLocationRecord,
              ),
          ],
        );
      },
    );
  }

  // ==============================================================
  // LOCATION REQUEST RECORD
  // ==============================================================

  Widget _buildLocationRecord(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data =
    document.data();

    final status =
    '${data['status'] ?? 'pending'}'
        .toLowerCase();

    final requestType =
    '${data['requestType'] ?? 'group'}'
        .toLowerCase();

    final requester =
        '${data['requesterName'] ?? data['requesterId'] ?? 'Traveler'}';

    final requesterId =
        '${data['requesterId'] ?? '-'}';

    final target =
        '${data['targetName'] ?? data['targetId'] ?? data['targetUserId'] ?? 'Traveler'}';

    final targetId =
        '${data['targetId'] ?? data['targetUserId'] ?? '-'}';

    final groupId =
        '${data['groupId'] ?? '-'}';

    final chatId =
        '${data['chatId'] ?? '-'}';

    final createdAt =
    asDate(
      data['createdAt'],
    );

    final respondedAt =
    asDate(
      data['respondedAt'],
    );

    final approved =
        status == 'approved' ||
            status == 'accepted';

    final rejected =
        status == 'rejected';

    final tone = approved
        ? ExplorerStatusTone.success
        : rejected
        ? ExplorerStatusTone.danger
        : ExplorerStatusTone.neutral;

    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 12,
      ),
      child: ExplorerCard(
        child: LayoutBuilder(
          builder:
              (context, constraints) {
            final narrow =
                constraints.maxWidth <
                    650;

            final details =
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          requestType ==
                              'private'
                              ? 'Private Location Request'
                              : 'Group Location Request',
                          style:
                          const TextStyle(
                            color:
                            ExplorerColors
                                .navy,
                            fontSize: 14,
                            fontWeight:
                            FontWeight
                                .w900,
                          ),
                        ),
                      ),
                      ExplorerStatusBadge(
                        label:
                        status.toUpperCase(),
                        tone: tone,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 20,
                    runSpacing: 7,
                    children: [
                      _EmergencyInlineInfo(
                        icon: Icons
                            .person_search_outlined,
                        text:
                        'From: $requester',
                      ),
                      _EmergencyInlineInfo(
                        icon:
                        Icons.person_outline,
                        text:
                        'To: $target',
                      ),
                      _EmergencyInlineInfo(
                        icon:
                        Icons.fingerprint,
                        text:
                        'ID: ${_AdminSosAlertsTabState._shortId(document.id)}',
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Requester UID: '
                        '$requesterId',
                    style:
                    const TextStyle(
                      color:
                      ExplorerColors.muted,
                      fontSize: 9,
                    ),
                  ),

                  Text(
                    'Target UID: '
                        '$targetId',
                    style:
                    const TextStyle(
                      color:
                      ExplorerColors.muted,
                      fontSize: 9,
                    ),
                  ),

                  if (groupId != '-')
                    Text(
                      'Group ID: '
                          '$groupId',
                      style:
                      const TextStyle(
                        color:
                        ExplorerColors
                            .muted,
                        fontSize: 9,
                      ),
                    ),

                  if (chatId != '-')
                    Text(
                      'Private Chat ID: '
                          '$chatId',
                      style:
                      const TextStyle(
                        color:
                        ExplorerColors
                            .muted,
                        fontSize: 9,
                      ),
                    ),

                  const SizedBox(height: 7),

                  Wrap(
                    spacing: 14,
                    runSpacing: 5,
                    children: [
                      Text(
                        'Requested: '
                            '${_AdminSosAlertsTabState._formatDateTime(createdAt)}',
                        style:
                        const TextStyle(
                          color:
                          ExplorerColors
                              .muted,
                          fontSize: 10,
                        ),
                      ),
                      if (respondedAt !=
                          null)
                        Text(
                          'Responded: '
                              '${_AdminSosAlertsTabState._formatDateTime(respondedAt)}',
                          style:
                          const TextStyle(
                            color:
                            ExplorerColors
                                .muted,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );

            final icon =
            _LocationStatusIcon(
              approved: approved,
              rejected: rejected,
            );

            if (narrow) {
              return Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  icon,
                  const SizedBox(
                    width: 14,
                  ),
                  details,
                ],
              );
            }

            return Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(
                  width: 14,
                ),
                details,
              ],
            );
          },
        ),
      ),
    );
  }
}

// ================================================================
// LOCATION STATUS ICON
// ================================================================

class _LocationStatusIcon extends StatelessWidget {
  const _LocationStatusIcon({
    required this.approved,
    required this.rejected,
  });

  final bool approved;
  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
    approved
        ? ExplorerColors.successSoft
        : rejected
        ? ExplorerColors.dangerSoft
        : ExplorerColors.navySoft;

    final foregroundColor =
    approved
        ? ExplorerColors.success
        : rejected
        ? ExplorerColors.danger
        : ExplorerColors.navy;

    final icon =
    approved
        ? Icons.location_on_outlined
        : rejected
        ? Icons.location_off_outlined
        : Icons.location_searching;

    return CircleAvatar(
      radius: 23,
      backgroundColor:
      backgroundColor,
      foregroundColor:
      foregroundColor,
      child: Icon(icon),
    );
  }
}

// ================================================================
// SHARED EMERGENCY INLINE INFORMATION
// ================================================================

class _EmergencyInlineInfo
    extends StatelessWidget {
  const _EmergencyInlineInfo({
    required this.icon,
    required this.text,
  });

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

// ================================================================
// EMERGENCY DETAIL SECTION TITLE
// ================================================================

class _EmergencyDetailTitle
    extends StatelessWidget {
  const _EmergencyDetailTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: ExplorerColors.navy,
        fontSize: 14,
        fontWeight:
        FontWeight.w900,
      ),
    );
  }
}

// ================================================================
// EMERGENCY DETAIL GRID
// ================================================================

class _EmergencyDetailGrid
    extends StatelessWidget {
  const _EmergencyDetailGrid({
    required this.children,
  });

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

// ================================================================
// EMERGENCY DETAIL ITEM
// ================================================================

class _EmergencyDetailItem
    extends StatelessWidget {
  const _EmergencyDetailItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 292,
      padding:
      const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
        ExplorerColors.subtle,
        borderRadius:
        BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color:
          ExplorerColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color:
            ExplorerColors.navy,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                  const TextStyle(
                    color:
                    ExplorerColors
                        .muted,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                SelectableText(
                  value,
                  style:
                  const TextStyle(
                    color:
                    ExplorerColors
                        .navy,
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w700,
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

// ================================================================
// EMERGENCY LOCATION CARD
// ================================================================

class _EmergencyLocationCard
    extends StatelessWidget {
  const _EmergencyLocationCard({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
        ExplorerColors.dangerSoft,
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color: const Color(
            0xFFF0B8B3,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
            const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              color:
              ExplorerColors.danger,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emergency GPS Location',
                  style:
                  TextStyle(
                    color:
                    ExplorerColors
                        .danger,
                    fontWeight:
                    FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  'Latitude: '
                      '${latitude.toStringAsFixed(6)}\n'
                      'Longitude: '
                      '${longitude.toStringAsFixed(6)}',
                  style:
                  const TextStyle(
                    color:
                    ExplorerColors
                        .navy,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.gps_fixed,
            color:
            ExplorerColors.danger,
          ),
        ],
      ),
    );
  }
}

// ================================================================
// NO LOCATION AVAILABLE
// ================================================================

class _EmergencyNoLocation
    extends StatelessWidget {
  const _EmergencyNoLocation();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
        ExplorerColors.dangerSoft,
        borderRadius:
        BorderRadius.circular(
          10,
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons
                .location_off_outlined,
            color:
            ExplorerColors.danger,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Emergency location is unavailable for this SOS record.',
              style: TextStyle(
                color:
                ExplorerColors
                    .danger,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
