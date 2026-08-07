part of '../admin_pages.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    this.roleFilter,
    this.pageTitle,
  });

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
        if (widget.pageTitle != null &&
            widget.pageTitle!.trim().isNotEmpty)
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
                    labelText:
                        'Search administrator, traveler or vendor',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration:
                      const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('All roles'),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Administrators'),
                    ),
                    DropdownMenuItem(
                      value: 'traveler',
                      child: Text('Travelers'),
                    ),
                    DropdownMenuItem(
                      value: 'vendor',
                      child: Text('Vendors'),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => role = value ?? 'all',
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream:
                AppServices.db.collection('admins').snapshots(),
            builder: (context, adminSnapshot) {
              if (!adminSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              return StreamBuilder<
                  QuerySnapshot<Map<String, dynamic>>>(
                stream: AppServices.db
                    .collection('travelers')
                    .snapshots(),
                builder: (context, travelerSnapshot) {
                  if (!travelerSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  return StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream: AppServices.db
                        .collection('vendors')
                        .snapshots(),
                    builder: (context, vendorSnapshot) {
                      if (!vendorSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final query =
                          search.text.trim().toLowerCase();

                      final rows = _rows(
                        admins: adminSnapshot.data!,
                        travelers: travelerSnapshot.data!,
                        vendors: vendorSnapshot.data!,
                      ).where((row) {
                        final data = row.data;
                        final matchesRole =
                            role == 'all' || row.role == role;
                        final haystack =
                            '${data['displayName'] ?? ''} '
                                    '${data['email'] ?? ''} '
                                    '${data['businessName'] ?? ''} '
                                    '${data['ownerName'] ?? ''}'
                                .toLowerCase();

                        return matchesRole &&
                            haystack.contains(query);
                      }).toList()
                        ..sort(
                          (first, second) =>
                              '${first.data['displayName'] ?? first.data['businessName'] ?? ''}'
                                  .compareTo(
                            '${second.data['displayName'] ?? second.data['businessName'] ?? ''}',
                          ),
                        );

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          20,
                        ),
                        child: Card(
                          child: DataTable(
                            columns: const [
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
                            rows: rows.map((row) {
                              final data = row.data;
                              final isVendor =
                                  row.role == 'vendor';

                              return DataRow(
                                cells: [
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
                                    Text(
                                      '${data['status'] ?? '-'}',
                                    ),
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
                                            tooltip:
                                                'Approve vendor',
                                            onPressed: () async {
                                              await row.reference
                                                  .update({
                                                'vendorStatus':
                                                    'verified',
                                                'verifiedAt':
                                                    FieldValue
                                                        .serverTimestamp(),
                                                'updatedAt':
                                                    FieldValue
                                                        .serverTimestamp(),
                                              });
                                              await AppServices
                                                  .notify(
                                                userId: row.id,
                                                title:
                                                    'Vendor verified',
                                                message:
                                                    'Your business account has been approved.',
                                                type: 'vendor',
                                              );
                                            },
                                            icon: const Icon(
                                              Icons
                                                  .verified_outlined,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip:
                                                'Reject vendor',
                                            onPressed: () async {
                                              await row.reference
                                                  .update({
                                                'vendorStatus':
                                                    'rejected',
                                                'updatedAt':
                                                    FieldValue
                                                        .serverTimestamp(),
                                              });
                                              await AppServices
                                                  .notify(
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
                                              data['status'] ==
                                                      'active'
                                                  ? 'Suspend'
                                                  : 'Reactivate',
                                          onPressed: () =>
                                              row.reference.update({
                                            'status':
                                                data['status'] ==
                                                        'active'
                                                    ? 'suspended'
                                                    : 'active',
                                            'updatedAt': FieldValue
                                                .serverTimestamp(),
                                          }),
                                          icon: Icon(
                                            data['status'] ==
                                                    'active'
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
