
part of '../vendor_pages.dart';

class VendorProfilePage extends StatefulWidget {
  const VendorProfilePage({
    super.key,
    required this.profile,
  });

  final Map<String, dynamic> profile;

  @override
  State<VendorProfilePage> createState() => _VendorProfilePageState();
}

class _VendorProfilePageState extends State<VendorProfilePage> {
  Future<void> deactivateAccount({required bool deletionRequested}) async {
    if (deletionRequested) {
      final keywordConfirmed = await confirmDeletionKeyword(context);
      if (!keywordConfirmed || !mounted) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Deactivate Vendor Account?'),
          content: const Text(
            'The business profile and vouchers will become unavailable until an administrator reactivates the account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: ExplorerColors.danger,
              ),
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final password = await requestPassword(context);
    if (password == null || password.isEmpty) return;

    try {
      await AppServices.reauthenticate(password);
      await AppServices.deactivateOwnAccount(
        deletionRequested: deletionRequested,
      );
    } catch (e) {
      if (mounted) {
        showMessage(context, e.toString(), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppServices.auth.currentUser!.uid;
    final business =
        '${widget.profile['businessName'] ?? widget.profile['displayName'] ?? 'Vendor'}';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Text('Heritage Steward Console'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AppServices.db
            .collection('redemptions')
            .where('vendorId', isEqualTo: uid)
            .snapshots(),
        builder: (context, redemptionSnapshot) {
          final redemptions = redemptionSnapshot.data?.docs.length ?? 0;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: AppServices.db
                .collection('vouchers')
                .where('vendorId', isEqualTo: uid)
                .snapshots(),
            builder: (context, voucherSnapshot) {
              final vouchers = voucherSnapshot.data?.docs ?? const [];
              final active = vouchers
                  .where((doc) => doc.data()['status'] == 'active')
                  .length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  ExplorerCard(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: ExplorerColors.goldSoft,
                          foregroundColor: ExplorerColors.goldDark,
                          child: Text(
                            business.trim().isEmpty
                                ? 'V'
                                : business.trim()[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const ExplorerStatusBadge(
                          label: 'VERIFIED STEWARD',
                          tone: ExplorerStatusTone.success,
                          icon: Icons.verified,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          business,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.profile['shopLocation'] ?? 'Heritage Partner'}',
                          style: const TextStyle(
                            color: ExplorerColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _vendorProfileStat(
                                '$redemptions',
                                'Total Redemptions',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 42,
                              color: ExplorerColors.border,
                            ),
                            Expanded(
                              child: _vendorProfileStat(
                                '4.8/5',
                                'Current Rating',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 42,
                              color: ExplorerColors.border,
                            ),
                            Expanded(
                              child: _vendorProfileStat(
                                '$active',
                                'Active Vouchers',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const ExplorerSectionTitle('Business Information'),
                  const SizedBox(height: 10),
                  ExplorerCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _infoRow(
                          'Business Category',
                          '${widget.profile['businessCategory'] ?? '-'}',
                        ),
                        _infoRow(
                          'Location',
                          '${widget.profile['shopLocation'] ?? '-'}',
                        ),
                        _infoRow(
                          'Contact Person',
                          '${widget.profile['ownerName'] ?? '-'}',
                        ),
                        _infoRow(
                          'Business Hours',
                          '${widget.profile['businessHours'] ?? '-'}',
                          last: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const ExplorerSectionTitle('Settings & Management'),
                  const SizedBox(height: 10),
                  ExplorerCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _profileTile(
                          Icons.edit_outlined,
                          'Edit Business Profile',
                          () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _VendorEditProfilePage(
                                  profile: widget.profile,
                                ),
                              ),
                            );
                            if (mounted) setState(() {});
                          },
                        ),
                        _line(),
                        _profileTile(
                          Icons.password_outlined,
                          'Change Password',
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ChangePasswordPage(),
                            ),
                          ),
                        ),
                        _line(),
                        _profileTile(
                          Icons.notifications_outlined,
                          'Notification Preferences',
                          () {},
                        ),
                        _line(),
                        _profileTile(
                          Icons.help_outline,
                          'Help Center',
                          () {},
                        ),
                        _line(),
                        _profileTile(
                          Icons.logout,
                          'Logout',
                          AppServices.auth.signOut,
                        ),
                        _line(),
                        _profileTile(
                          Icons.pause_circle_outline,
                          'Deactivate Account',
                          () => deactivateAccount(
                            deletionRequested: false,
                          ),
                          danger: true,
                        ),
                        _line(),
                        _profileTile(
                          Icons.delete_forever_outlined,
                          'Delete Account',
                          () => deactivateAccount(
                            deletionRequested: true,
                          ),
                          danger: true,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _vendorProfileStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: ExplorerColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: ExplorerColors.muted,
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: ExplorerColors.border),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: ExplorerColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: ExplorerColors.navy,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color =
        danger ? ExplorerColors.danger : ExplorerColors.navy;
    return ListTile(
      leading: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          color: danger
              ? ExplorerColors.dangerSoft
              : ExplorerColors.navySoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 19,
        color: ExplorerColors.muted,
      ),
      onTap: onTap,
    );
  }

  Widget _line() => const Divider(height: 1, indent: 63);
}

class _VendorEditProfilePage extends StatefulWidget {
  const _VendorEditProfilePage({
    required this.profile,
  });

  final Map<String, dynamic> profile;

  @override
  State<_VendorEditProfilePage> createState() =>
      _VendorEditProfilePageState();
}

class _VendorEditProfilePageState
    extends State<_VendorEditProfilePage> {
  late final TextEditingController business;
  late final TextEditingController owner;
  late final TextEditingController phone;
  late final TextEditingController location;
  late final TextEditingController hours;
  late final TextEditingController description;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    business = TextEditingController(
      text: widget.profile['businessName'] ?? '',
    );
    owner = TextEditingController(
      text: widget.profile['ownerName'] ?? '',
    );
    phone = TextEditingController(
      text: widget.profile['contactNumber'] ?? '',
    );
    location = TextEditingController(
      text: widget.profile['shopLocation'] ?? '',
    );
    hours = TextEditingController(
      text: widget.profile['businessHours'] ?? '',
    );
    description = TextEditingController(
      text: widget.profile['businessDescription'] ?? '',
    );
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final data = {
        'displayName': business.text.trim(),
        'businessName': business.text.trim(),
        'ownerName': owner.text.trim(),
        'contactNumber': phone.text.trim(),
        'shopLocation': location.text.trim(),
        'businessHours': hours.text.trim(),
        'businessDescription': description.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await AppServices.userRef(
        AppServices.auth.currentUser!.uid,
      ).update(data);

      widget.profile.addAll(data);
      if (mounted) {
        showMessage(context, 'Business profile updated.');
        Navigator.pop(context);
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
    business.dispose();
    owner.dispose();
    phone.dispose();
    location.dispose();
    hours.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(title: const Text('Edit Business Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
        children: [
          ExplorerCard(
            child: Column(
              children: [
                TextField(
                  controller: business,
                  decoration: const InputDecoration(
                    labelText: 'Business Name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: owner,
                  decoration: const InputDecoration(
                    labelText: 'Owner Name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: location,
                  decoration: const InputDecoration(
                    labelText: 'Shop Location',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hours,
                  decoration: const InputDecoration(
                    labelText: 'Business Hours',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Business Description',
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: busy ? null : save,
                  child: Text(
                    busy ? 'Saving...' : 'Save Business Profile',
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
