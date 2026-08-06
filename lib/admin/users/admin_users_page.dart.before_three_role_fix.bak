part of '../admin_pages.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    this.roleFilter,
    this.pageTitle = 'User Management',
  });

  final String? roleFilter;
  final String pageTitle;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final search = TextEditingController();
  String status = 'all';
  String role = 'all';

  @override
  void initState() {
    super.initState();
    role = widget.roleFilter ?? 'all';
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _setVendorStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String vendorStatus,
  ) async {
    await doc.reference.update({
      'vendorStatus': vendorStatus,
      'verifiedAt': vendorStatus == 'verified'
          ? FieldValue.serverTimestamp()
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AppServices.notify(
      userId: doc.id,
      title: vendorStatus == 'verified'
          ? 'Vendor verified'
          : 'Vendor verification rejected',
      message: vendorStatus == 'verified'
          ? 'Your business account has been approved.'
          : 'Your business verification was rejected. Please review your submitted details.',
      type: 'vendor',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVendorPage = widget.roleFilter == 'vendor';
    final subtitle = isVendorPage
        ? 'Review vendor registrations, business verification and account status.'
        : widget.roleFilter == 'traveler'
            ? 'Manage tourist accounts, activity status and community access.'
            : 'Manage all users registered in MyHeritage Explorer.';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.db.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data!.docs;
        final baseDocs = allDocs.where((doc) {
          final data = doc.data();
          return widget.roleFilter == null || data['role'] == widget.roleFilter;
        }).toList();
        final q = search.text.trim().toLowerCase();
        final docs = baseDocs.where((doc) {
          final data = doc.data();
          final matchesRole = role == 'all' || data['role'] == role;
          final accountStatus = '${data['status'] ?? 'active'}';
          final vendorStatus = '${data['vendorStatus'] ?? ''}';
          final matchesStatus = status == 'all' ||
              accountStatus == status ||
              vendorStatus == status;
          final haystack =
              '${data['displayName']} ${data['email']} ${data['businessName']} ${data['rank']}'
                  .toLowerCase();
          return matchesRole && matchesStatus && haystack.contains(q);
        }).toList();

        final active = baseDocs
            .where((doc) => '${doc.data()['status'] ?? 'active'}' == 'active')
            .length;
        final suspended = baseDocs
            .where((doc) => '${doc.data()['status']}' == 'suspended')
            .length;
        final pending = baseDocs
            .where((doc) => '${doc.data()['vendorStatus']}' == 'pending')
            .length;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ExplorerAdminPageTitle(
              title: widget.pageTitle,
              subtitle: subtitle,
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ExplorerMetricCard(
                    label: isVendorPage ? 'Total Vendors' : 'Total Tourists',
                    value: '${baseDocs.length}',
                    icon: isVendorPage
                        ? Icons.storefront_outlined
                        : Icons.explore_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ExplorerMetricCard(
                    label: 'Active Accounts',
                    value: '$active',
                    icon: Icons.verified_user_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ExplorerMetricCard(
                    label: isVendorPage ? 'Pending Verification' : 'Suspended',
                    value: isVendorPage ? '$pending' : '$suspended',
                    icon: isVendorPage
                        ? Icons.pending_actions_outlined
                        : Icons.block_outlined,
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
                    hintText: isVendorPage
                        ? 'Search vendor or business...'
                        : 'Search tourist name or email...',
                    width: 360,
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: 'Account status',
                        isDense: true,
                      ),
                      items: (isVendorPage
                              ? ['all', 'pending', 'verified', 'rejected', 'active', 'suspended']
                              : ['all', 'active', 'suspended', 'deactivated'])
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_pretty(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => status = value!),
                    ),
                  ),
                  if (widget.roleFilter == null)
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          isDense: true,
                        ),
                        items: ['all', 'traveler', 'vendor', 'admin']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_pretty(value)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => role = value!),
                      ),
                    ),
                  ExplorerStatusBadge(
                    label: '${docs.length} RECORDS',
                    tone: ExplorerStatusTone.navy,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ExplorerCard(
              padding: EdgeInsets.zero,
              child: docs.isEmpty
                  ? const ExplorerEmptyState(
                      title: 'No matching accounts',
                      subtitle: 'Try another search term or status filter.',
                      icon: Icons.manage_accounts_outlined,
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: const WidgetStatePropertyAll(
                          ExplorerColors.subtle,
                        ),
                        columns: [
                          DataColumn(
                            label: Text(isVendorPage ? 'Business / Owner' : 'Tourist'),
                          ),
                          const DataColumn(label: Text('Email')),
                          if (!isVendorPage)
                            const DataColumn(label: Text('Rank / Points')),
                          const DataColumn(label: Text('Account Status')),
                          if (isVendorPage)
                            const DataColumn(label: Text('Verification')),
                          const DataColumn(label: Text('Actions')),
                        ],
                        rows: docs.map((doc) {
                          final data = doc.data();
                          final accountStatus = '${data['status'] ?? 'active'}';
                          final vendorStatus = '${data['vendorStatus'] ?? 'pending'}';
                          final display = isVendorPage
                              ? '${data['businessName'] ?? data['displayName'] ?? '-'}'
                              : '${data['displayName'] ?? '-'}';
                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 17,
                                      backgroundColor: ExplorerColors.navySoft,
                                      foregroundColor: ExplorerColors.navy,
                                      child: Text(
                                        display.isEmpty ? '?' : display[0].toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    SizedBox(
                                      width: 180,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            display,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: ExplorerColors.navy,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (isVendorPage)
                                            Text(
                                              '${data['displayName'] ?? 'Business owner'}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                              ),
                              DataCell(
                                SizedBox(
                                  width: 200,
                                  child: Text(
                                    '${data['email'] ?? '-'}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              if (!isVendorPage)
                                DataCell(
                                  Text(
                                    '${data['rank'] ?? 'Bronze'} • ${data['points'] ?? 0} pts',
                                  ),
                                ),
                              DataCell(
                                ExplorerStatusBadge(
                                  label: accountStatus.toUpperCase(),
                                  tone: _tone(accountStatus),
                                ),
                              ),
                              if (isVendorPage)
                                DataCell(
                                  ExplorerStatusBadge(
                                    label: vendorStatus.toUpperCase(),
                                    tone: _tone(vendorStatus),
                                  ),
                                ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isVendorPage && vendorStatus == 'pending') ...[
                                      IconButton(
                                        tooltip: 'Approve vendor',
                                        onPressed: () => _setVendorStatus(doc, 'verified'),
                                        icon: const Icon(
                                          Icons.verified_outlined,
                                          color: ExplorerColors.success,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Reject vendor',
                                        onPressed: () => _setVendorStatus(doc, 'rejected'),
                                        icon: const Icon(
                                          Icons.cancel_outlined,
                                          color: ExplorerColors.danger,
                                        ),
                                      ),
                                    ],
                                    IconButton(
                                      tooltip: accountStatus == 'active'
                                          ? 'Suspend account'
                                          : 'Reactivate account',
                                      onPressed: () => doc.reference.update({
                                        'status': accountStatus == 'active'
                                            ? 'suspended'
                                            : 'active',
                                        'updatedAt': FieldValue.serverTimestamp(),
                                      }),
                                      icon: Icon(
                                        accountStatus == 'active'
                                            ? Icons.block_outlined
                                            : Icons.check_circle_outline,
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
          ],
        );
      },
    );
  }

  static String _pretty(String value) {
    if (value == 'all') return 'All';
    if (value == 'traveler') return 'Tourist';
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  static ExplorerStatusTone _tone(String status) => switch (status) {
        'active' || 'verified' => ExplorerStatusTone.success,
        'pending' => ExplorerStatusTone.warning,
        'rejected' || 'suspended' || 'deactivated' => ExplorerStatusTone.danger,
        _ => ExplorerStatusTone.neutral,
      };
}
