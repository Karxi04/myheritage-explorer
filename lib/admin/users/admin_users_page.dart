part of '../admin_pages.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, this.roleFilter, this.pageTitle});

  final String? roleFilter;
  final String? pageTitle;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminAccountRow {
  _AdminAccountRow({
    required this.id,
    required this.role,
    required this.reference,
    required this.data,
  });

  final String id;
  final String role;
  final DocumentReference reference;
  Map<String, dynamic> data;
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final search = TextEditingController();
  late String role;
  bool checkingRoleData = false;

  bool _isLoading = false;
  List<_AdminAccountRow> _rows = [];
  int _currentPage = 1;
  final int _pageSize = 25;
  bool _hasMore = true;

  final Map<int, DocumentSnapshot> _pageStartDocs = {};
  DocumentSnapshot? _lastDoc;

  @override
  void initState() {
    super.initState();
    role = widget.roleFilter ?? 'traveler';
    if (role == 'all') role = 'traveler';
    _loadPage(1, refresh: true);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _loadPage(int page, {bool refresh = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    if (refresh) {
      _pageStartDocs.clear();
      _lastDoc = null;
      _hasMore = true;
      _currentPage = 1;
      page = 1;
    }

    try {
      final collection = role == 'vendor' ? 'vendors' : 'travelers';
      Query query = AppServices.db.collection(collection);

      final queryText = search.text.trim().toLowerCase();
      if (queryText.isNotEmpty) {
        query = query
            .where('email', isGreaterThanOrEqualTo: queryText)
            .where('email', isLessThan: '${queryText}z')
            .orderBy('email');
      } else {
        query = query.orderBy('createdAt', descending: true);
      }

      if (page > 1 && _pageStartDocs.containsKey(page)) {
        query = query.startAtDocument(_pageStartDocs[page]!);
      } else if (page > 1 && _lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      query = query.limit(_pageSize);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _pageStartDocs[page] = snapshot.docs.first;
        _lastDoc = snapshot.docs.last;
        _hasMore = snapshot.docs.length == _pageSize;
        _currentPage = page;

        _rows = snapshot.docs.map((doc) => _AdminAccountRow(
          id: doc.id,
          role: role,
          reference: doc.reference,
          data: Map<String, dynamic>.from(doc.data() as Map<String, dynamic>),
        )).toList();
      } else {
        _hasMore = false;
        if (page == 1) _rows = [];
      }
    } catch (e) {
      debugPrint('Error loading page: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _roleActionLabel {
    return switch (role) {
      'traveler' => 'View Traveler Records',
      'vendor' => 'Check Vendor Data',
      _ => 'View Platform Data',
    };
  }

  IconData get _roleActionIcon {
    return switch (role) {
      'traveler' => Icons.explore_outlined,
      'vendor' => Icons.fact_check_outlined,
      _ => Icons.dashboard_customize_outlined,
    };
  }

  Future<void> _runRoleAction() async {
    setState(() => checkingRoleData = true);
    try {
      final message = switch (role) {
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

  Future<String> _travelerDataMessage() async {
    final results = await Future.wait([
      AppServices.db.collection('travelers').count().get(),
      AppServices.db.collection('travelers').where('status', isEqualTo: 'active').count().get(),
    ]);
    final total = results[0].count ?? 0;
    final active = results[1].count ?? 0;
    return 'Traveler records ready: $active active travelers from $total records.';
  }

  Future<String> _vendorDataMessage() async {
    final results = await Future.wait([
      AppServices.db.collection('vendors').count().get(),
      AppServices.db.collection('vendors').where('status', isEqualTo: 'active').count().get(),
      AppServices.db.collection('vendors').where('vendorStatus', isEqualTo: 'verified').count().get(),
    ]);
    final total = results[0].count ?? 0;
    final active = results[1].count ?? 0;
    final verified = results[2].count ?? 0;
    return 'Vendor data ready: $verified verified vendors and $active active vendors from $total records.';
  }

  Future<String> _platformDataMessage() async {
    final results = await Future.wait([
      AppServices.db.collection('travelers').count().get(),
      AppServices.db.collection('vendors').count().get(),
    ]);
    final travelerCount = results[0].count ?? 0;
    final vendorCount = results[1].count ?? 0;
    return 'Platform data ready: $travelerCount travelers and $vendorCount vendors.';
  }

  void _confirmAndDeleteAccount(_AdminAccountRow row) {
    final isVendor = row.role == 'vendor';
    final name = '${row.data['businessName'] ?? row.data['displayName'] ?? 'Account'}';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: ExplorerColors.danger, size: 28),
            SizedBox(width: 10),
            Text(
              'Delete Account Permanently',
              style: TextStyle(
                color: ExplorerColors.navy,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete $name (${isVendor ? 'Vendor' : 'Tourist'})? '
          'This action will permanently remove their record from Cloud Firestore and cannot be undone.',
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ExplorerColors.danger,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                await row.reference.delete();
                setState(() {
                  _rows.removeWhere((r) => r.id == row.id);
                });
                if (mounted) {
                  showMessage(
                    context,
                    '$name has been permanently deleted.',
                  );
                }
              } catch (e) {
                if (mounted) {
                  showMessage(
                    context,
                    'Failed to delete account: $e',
                    error: true,
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(_AdminAccountRow row) {
    final isVendor = row.role == 'vendor';
    final data = row.data;

    final nameController = TextEditingController(
      text: isVendor ? '${data['businessName'] ?? ''}' : '${data['displayName'] ?? ''}',
    );
    final ownerController = TextEditingController(
      text: '${data['ownerName'] ?? ''}',
    );
    final emailController = TextEditingController(
      text: '${data['email'] ?? ''}',
    );
    final contactController = TextEditingController(
      text: '${data['contactNumber'] ?? ''}',
    );
    final locationController = TextEditingController(
      text: '${data['shopLocation'] ?? ''}',
    );
    final hoursController = TextEditingController(
      text: '${data['businessHours'] ?? ''}',
    );
    final descController = TextEditingController(
      text: '${data['businessDescription'] ?? ''}',
    );

    String vendorStatus = '${data['vendorStatus'] ?? 'verified'}';
    if (!['verified', 'pending', 'rejected'].contains(vendorStatus)) {
      vendorStatus = 'verified';
    }

    String category = '${data['category'] ?? 'General'}';
    final categoryOptions = [
      'General',
      'Culture & Heritage',
      'Food & Beverage',
      'Retail & Souvenirs',
      'Handicrafts',
      'Lodging',
      'Local Services',
    ];
    if (!categoryOptions.contains(category)) {
      categoryOptions.add(category);
    }

    bool saving = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    isVendor ? Icons.storefront : Icons.person_outline,
                    color: ExplorerColors.navy,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isVendor ? 'Edit Vendor Details' : 'Edit Tourist Details',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ExplorerColors.navy,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: isVendor ? 'Business Name' : 'Full Name',
                          prefixIcon: Icon(isVendor ? Icons.storefront : Icons.person),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (isVendor) ...[
                        TextField(
                          controller: ownerController,
                          decoration: const InputDecoration(
                            labelText: 'Owner Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),
                      if (isVendor) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Business Category',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: categoryOptions
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setDialogState(() => category = v);
                          },
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: contactController,
                          decoration: const InputDecoration(
                            labelText: 'Contact Number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            labelText: 'Shop Location',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: hoursController,
                          decoration: const InputDecoration(
                            labelText: 'Business Operating Hours',
                            prefixIcon: Icon(Icons.access_time_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: descController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Business Description',
                            prefixIcon: Icon(Icons.description_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          value: vendorStatus,
                          decoration: const InputDecoration(
                            labelText: 'Verification Status',
                            prefixIcon: Icon(Icons.verified_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'verified', child: Text('Verified')),
                            DropdownMenuItem(value: 'pending', child: Text('Pending Approval')),
                            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDialogState(() => vendorStatus = v);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ExplorerColors.navy,
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final isVendorRole = isVendor;
                          setDialogState(() => saving = true);
                          try {
                            final Map<String, dynamic> updates = {
                              'updatedAt': FieldValue.serverTimestamp(),
                            };

                            if (isVendor) {
                              updates['businessName'] = nameController.text.trim();
                              updates['ownerName'] = ownerController.text.trim();
                              updates['email'] = emailController.text.trim();
                              updates['category'] = category;
                              updates['contactNumber'] = contactController.text.trim();
                              updates['shopLocation'] = locationController.text.trim();
                              updates['businessHours'] = hoursController.text.trim();
                              updates['businessDescription'] = descController.text.trim();
                              updates['vendorStatus'] = vendorStatus;
                            } else {
                              updates['displayName'] = nameController.text.trim();
                              updates['email'] = emailController.text.trim();
                            }

                            await row.reference.update(updates);

                            setState(() {
                              row.data.addAll(updates);
                              row.data['updatedAt'] = DateTime.now();
                            });

                            if (!mounted) return;
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final rootCtx = appNavigatorKey.currentContext;
                              if (rootCtx != null) {
                                showMessage(
                                  rootCtx,
                                  isVendorRole
                                      ? 'Vendor business profile updated.'
                                      : 'Tourist profile updated.',
                                );
                              }
                            });
                          } catch (e) {
                            setDialogState(() => saving = false);
                            if (mounted) {
                              showMessage(
                                context,
                                'Failed to update profile: $e',
                                error: true,
                              );
                            }
                          }
                        },
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(saving ? 'Saving...' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = role == 'vendor' ? 'vendors' : 'travelers';
    
    return Column(
      children: [
        if (widget.pageTitle != null && widget.pageTitle!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Text(
                    widget.pageTitle!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
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
                  onSubmitted: (_) => _loadPage(1, refresh: true),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: 'Search $roleLabel by email...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => _loadPage(1, refresh: true),
                    ),
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
                    DropdownMenuItem(
                      value: 'traveler',
                      child: Text('Travelers'),
                    ),
                    DropdownMenuItem(value: 'vendor', child: Text('Vendors')),
                  ],
                  onChanged: (value) {
                    if (value != null && value != role) {
                      setState(() {
                        role = value;
                        search.clear();
                      });
                      _loadPage(1, refresh: true);
                    }
                  },
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        rows: _rows.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          final data = row.data;
                          final isVendor = row.role == 'vendor';

                          // Offset the row number based on the current page
                          final displayIndex = ((_currentPage - 1) * _pageSize) + index + 1;

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  '$displayIndex',
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
                                    IconButton(
                                      tooltip: 'Edit details',
                                      onPressed: () => _showEditDialog(row),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: ExplorerColors.navy,
                                      ),
                                    ),
                                    if (isVendor &&
                                        data['vendorStatus'] ==
                                            'pending') ...[
                                      IconButton(
                                        tooltip: 'Approve vendor',
                                        onPressed: () async {
                                          setState(() => data['vendorStatus'] = 'verified');
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
                                          setState(() => data['vendorStatus'] = 'rejected');
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
                                      onPressed: () async {
                                          final newStatus = data['status'] == 'active' ? 'suspended' : 'active';
                                          setState(() => data['status'] = newStatus);

                                          await row.reference.update({
                                            'status': newStatus,
                                            'updatedAt': FieldValue.serverTimestamp(),
                                          });
                                      },
                                      icon: Icon(
                                        data['status'] == 'active'
                                            ? Icons.block
                                            : Icons
                                                  .check_circle_outline,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete Account Permanently',
                                      onPressed: () => _confirmAndDeleteAccount(row),
                                      icon: const Icon(
                                        Icons.delete_forever_outlined,
                                        color: ExplorerColors.danger,
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
                if (_rows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _currentPage > 1
                              ? () => _loadPage(_currentPage - 1)
                              : null,
                        ),
                        Text(
                          'Page $_currentPage',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _hasMore
                              ? () => _loadPage(_currentPage + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                if (_rows.isEmpty && !_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('No results found.'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
