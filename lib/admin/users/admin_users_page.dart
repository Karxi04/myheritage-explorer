part of '../admin_pages.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, this.roleFilter, this.pageTitle});

  final String? roleFilter;
  final String? pageTitle;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminAccountRow {
  const _AdminAccountRow({
    required this.id,
    required this.role,
    required this.reference,
    required this.data,
  });

  final String id;
  final String role;
  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic> data;
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final search = TextEditingController();
  late String role;
  bool checkingRoleData = false;

  @override
  void initState() {
    super.initState();

    final requestedRole = widget.roleFilter;
    role = const {'admin', 'traveler', 'vendor'}.contains(requestedRole)
        ? requestedRole!
        : 'all';
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String get _roleActionLabel {
    return switch (role) {
      'admin' => 'Check Administrator Data',
      'traveler' => 'View Traveler Records',
      'vendor' => 'Check Vendor Data',
      _ => 'View Platform Data',
    };
  }

  IconData get _roleActionIcon {
    return switch (role) {
      'admin' => Icons.admin_panel_settings_outlined,
      'traveler' => Icons.explore_outlined,
      'vendor' => Icons.fact_check_outlined,
      _ => Icons.dashboard_customize_outlined,
    };
  }

  Future<void> _runRoleAction() async {
    setState(() => checkingRoleData = true);
    try {
      final message = switch (role) {
        'admin' => await _administratorDataMessage(),
        'traveler' => await _travelerDataMessage(),
        'vendor' => await _vendorDataMessage(),
        _ => await _platformDataMessage(),
      };
      if (mounted) {
        showMessage(context, message);
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          'Unable to read ${_roleActionLabel.toLowerCase()}. Please refresh and sign in as administrator.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => checkingRoleData = false);
    }
  }

  Future<String> _administratorDataMessage() async {
    final snapshot = await AppServices.db.collection('admins').get();
    final admins = snapshot.docs.map((doc) => doc.data()).toList();
    final active = admins
        .where((data) => '${data['status'] ?? ''}' == 'active')
        .length;
    return 'Administrator data ready: $active active administrators from ${admins.length} records.';
  }

  Future<String> _travelerDataMessage() async {
    final snapshot = await AppServices.db.collection('travelers').get();
    final travelers = snapshot.docs.map((doc) => doc.data()).toList();
    final active = travelers
        .where((data) => '${data['status'] ?? ''}' == 'active')
        .length;
    return 'Traveler records ready: $active active travelers from ${travelers.length} records.';
  }

  Future<String> _vendorDataMessage() async {
    final snapshot = await AppServices.db.collection('vendors').get();
    final vendors = snapshot.docs.map((doc) => doc.data()).toList();
    final active = vendors
        .where((data) => '${data['status'] ?? ''}' == 'active')
        .length;
    final verified = vendors
        .where((data) => '${data['vendorStatus'] ?? ''}' == 'verified')
        .length;
    return 'Vendor data ready: $verified verified vendors and $active active vendors from ${vendors.length} records.';
  }

  Future<String> _platformDataMessage() async {
    final snapshots = await Future.wait([
      AppServices.db.collection('admins').get(),
      AppServices.db.collection('travelers').get(),
      AppServices.db.collection('vendors').get(),
    ]);
    return 'Platform data ready: ${snapshots[0].size} administrators, ${snapshots[1].size} travelers, and ${snapshots[2].size} vendors.';
  }

  List<_AdminAccountRow> _rows({
    required QuerySnapshot<Map<String, dynamic>> admins,
    required QuerySnapshot<Map<String, dynamic>> travelers,
    required QuerySnapshot<Map<String, dynamic>> vendors,
  }) {
    return [
      ...admins.docs.map(
        (doc) => _AdminAccountRow(
          id: doc.id,
          role: 'admin',
          reference: doc.reference,
          data: doc.data(),
        ),
      ),
      ...travelers.docs.map(
        (doc) => _AdminAccountRow(
          id: doc.id,
          role: 'traveler',
          reference: doc.reference,
          data: doc.data(),
        ),
      ),
      ...vendors.docs.map(
        (doc) => _AdminAccountRow(
          id: doc.id,
          role: 'vendor',
          reference: doc.reference,
          data: doc.data(),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.pageTitle != null && widget.pageTitle!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.pageTitle!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search administrator, traveler or vendor',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All roles')),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Administrators'),
                    ),
                    DropdownMenuItem(
                      value: 'traveler',
                      child: Text('Travelers'),
                    ),
                    DropdownMenuItem(value: 'vendor', child: Text('Vendors')),
                  ],
                  onChanged: (value) => setState(() => role = value ?? 'all'),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ExplorerColors.navy,
                ),
                onPressed: checkingRoleData ? null : _runRoleAction,
                icon: checkingRoleData
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(_roleActionIcon, size: 16),
                label: Text(
                  checkingRoleData ? 'Checking...' : _roleActionLabel,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: AppServices.db.collection('admins').snapshots(),
            builder: (context, adminSnapshot) {
              if (!adminSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppServices.db.collection('travelers').snapshots(),
                builder: (context, travelerSnapshot) {
                  if (!travelerSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: AppServices.db.collection('vendors').snapshots(),
                    builder: (context, vendorSnapshot) {
                      if (!vendorSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final query = search.text.trim().toLowerCase();

                      final allRows = _rows(
                        admins: adminSnapshot.data!,
                        travelers: travelerSnapshot.data!,
                        vendors: vendorSnapshot.data!,
                      );
                      final roleRows = allRows.where(
                        (row) => role == 'all' || row.role == role,
                      );
                      final totalForRole = roleRows.length;
                      final rows =
                          roleRows.where((row) {
                            final data = row.data;
                            final haystack =
                                '${data['displayName'] ?? ''} '
                                        '${data['email'] ?? ''} '
                                        '${data['businessName'] ?? ''} '
                                        '${data['ownerName'] ?? ''}'
                                    .toLowerCase();

                            return haystack.contains(query);
                          }).toList()..sort(
                            (
                              first,
                              second,
                            ) => '${first.data['displayName'] ?? first.data['businessName'] ?? ''}'
                                .compareTo(
                                  '${second.data['displayName'] ?? second.data['businessName'] ?? ''}',
                                ),
                          );
                      final roleLabel = switch (role) {
                        'admin' => 'administrators',
                        'traveler' => 'travelers',
                        'vendor' => 'vendors',
                        _ => 'accounts',
                      };
                      final countText = query.isEmpty
                          ? 'Total $roleLabel: $totalForRole'
                          : 'Showing ${rows.length} of $totalForRole $roleLabel';

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                countText,
                                style: const TextStyle(
                                  color: ExplorerColors.navy,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Card(
                              clipBehavior: Clip.antiAlias,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 1120,
                                  ),
                                  child: DataTable(
                                    columnSpacing: 34,
                                    horizontalMargin: 24,
                                    columns: const [
                                      DataColumn(
                                        numeric: true,
                                        label: Text('No.'),
                                      ),
                                      DataColumn(
                                        label: Text('Name / Business'),
                                      ),
                                      DataColumn(label: Text('Email')),
                                      DataColumn(label: Text('Role')),
                                      DataColumn(label: Text('Status')),
                                      DataColumn(
                                        label: Text('Vendor verification'),
                                      ),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: rows.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final row = entry.value;
                                      final data = row.data;
                                      final isVendor = row.role == 'vendor';

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              '${index + 1}',
                                              style: const TextStyle(
                                                color: ExplorerColors.navy,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${data['businessName'] ?? data['displayName'] ?? '-'}',
                                            ),
                                          ),
                                          DataCell(
                                            Text('${data['email'] ?? '-'}'),
                                          ),
                                          DataCell(Text(row.role)),
                                          DataCell(
                                            Text('${data['status'] ?? '-'}'),
                                          ),
                                          DataCell(
                                            Text(
                                              isVendor
                                                  ? '${data['vendorStatus'] ?? '-'}'
                                                  : '-',
                                            ),
                                          ),
                                          DataCell(
                                            Wrap(
                                              spacing: 6,
                                              children: [
                                                if (isVendor &&
                                                    data['vendorStatus'] ==
                                                        'pending') ...[
                                                  IconButton(
                                                    tooltip: 'Approve vendor',
                                                    onPressed: () async {
                                                      await row.reference.update({
                                                        'vendorStatus':
                                                            'verified',
                                                        'verifiedAt':
                                                            FieldValue.serverTimestamp(),
                                                        'updatedAt':
                                                            FieldValue.serverTimestamp(),
                                                      });
                                                      await AppServices.notify(
                                                        userId: row.id,
                                                        title:
                                                            'Vendor verified',
                                                        message:
                                                            'Your business account has been approved.',
                                                        type: 'vendor',
                                                      );
                                                    },
                                                    icon: const Icon(
                                                      Icons.verified_outlined,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Reject vendor',
                                                    onPressed: () async {
                                                      await row.reference.update({
                                                        'vendorStatus':
                                                            'rejected',
                                                        'updatedAt':
                                                            FieldValue.serverTimestamp(),
                                                      });
                                                      await AppServices.notify(
                                                        userId: row.id,
                                                        title:
                                                            'Vendor verification rejected',
                                                        message:
                                                            'Your business verification was rejected.',
                                                        type: 'vendor',
                                                      );
                                                    },
                                                    icon: const Icon(
                                                      Icons.cancel_outlined,
                                                    ),
                                                  ),
                                                ],
                                                IconButton(
                                                  tooltip:
                                                      data['status'] == 'active'
                                                      ? 'Suspend'
                                                      : 'Reactivate',
                                                  onPressed: () =>
                                                      row.reference.update({
                                                        'status':
                                                            data['status'] ==
                                                                'active'
                                                            ? 'suspended'
                                                            : 'active',
                                                        'updatedAt':
                                                            FieldValue.serverTimestamp(),
                                                      }),
                                                  icon: Icon(
                                                    data['status'] == 'active'
                                                        ? Icons.block
                                                        : Icons
                                                              .check_circle_outline,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
