
part of '../traveler_pages.dart';

class TravelerProfilePage extends StatefulWidget {
  const TravelerProfilePage({
    super.key,
    required this.profile,
  });

  final Map<String, dynamic> profile;

  @override
  State<TravelerProfilePage> createState() => _TravelerProfilePageState();
}

class _TravelerProfilePageState extends State<TravelerProfilePage> {
  Future<void> deactivateAccount({required bool deletionRequested}) async {
    if (deletionRequested) {
      final keywordConfirmed = await confirmDeletionKeyword(context);
      if (!keywordConfirmed || !mounted) {
        if (mounted && !keywordConfirmed) {
          showMessage(
            context,
            'Deletion keyword was not confirmed.',
            error: true,
          );
        }
        return;
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Deactivate Account?'),
          content: const Text(
            'Deactivating your account is temporary. Your profile, itineraries and rewards will be hidden until an administrator reactivates your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep My Account'),
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
    final name =
        '${widget.profile['displayName'] ?? AppServices.auth.currentUser?.displayName ?? 'Traveler'}';
    final email =
        '${widget.profile['email'] ?? AppServices.auth.currentUser?.email ?? ''}';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const ExplorerBrand(compact: true),
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Menu',
            onPressed: () {},
            icon: const Icon(Icons.menu),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsPage(),
              ),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          ExplorerCard(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: ExplorerColors.navySoft,
                  foregroundColor: ExplorerColors.navy,
                  child: Text(
                    name.trim().isEmpty ? 'T' : name.trim()[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: const TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 19),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _profileStat(
                        'IMPACT',
                        '${widget.profile['localImpactScore'] ?? 0}',
                        'pts',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 42,
                      color: ExplorerColors.border,
                    ),
                    Expanded(
                      child: _profileStat(
                        'RANK',
                        '${widget.profile['rank'] ?? 'Bronze'}',
                        '',
                        valueColor: ExplorerColors.goldDark,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 42,
                      color: ExplorerColors.border,
                    ),
                    Expanded(
                      child: _profileStat(
                        'POINTS',
                        '${widget.profile['points'] ?? 0}',
                        'pts',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SETTINGS & PREFERENCES',
            style: TextStyle(
              color: ExplorerColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 8),
          ExplorerCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingsTile(
                  icon: Icons.person_outline,
                  title: 'Personal Information',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ProfileInformationPage(
                          profile: widget.profile,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Voucher Wallet',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VoucherWalletPage(),
                    ),
                  ),
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Safety & Hazard Reporting',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SafetyPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'ACCOUNT MAINTENANCE',
            style: TextStyle(
              color: ExplorerColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 8),
          ExplorerCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingsTile(
                  icon: Icons.password_outlined,
                  title: 'Change Password',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordPage(),
                    ),
                  ),
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: AppServices.auth.signOut,
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.pause_circle_outline,
                  title: 'Deactivate Account',
                  danger: true,
                  onTap: () =>
                      deactivateAccount(deletionRequested: false),
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete Account Permanently',
                  danger: true,
                  onTap: () => deactivateAccount(deletionRequested: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileStat(
    String label,
    String value,
    String suffix, {
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ExplorerColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? ExplorerColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (suffix.isNotEmpty)
          Text(
            suffix,
            style: const TextStyle(
              color: ExplorerColors.muted,
              fontSize: 9,
            ),
          ),
      ],
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color =
        danger ? ExplorerColors.danger : ExplorerColors.navy;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 2,
      ),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: danger
              ? ExplorerColors.dangerSoft
              : ExplorerColors.navySoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Icon(
        danger ? Icons.chevron_right : Icons.chevron_right,
        size: 19,
        color: ExplorerColors.muted,
      ),
      onTap: onTap,
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 64);
}

class _ProfileInformationPage extends StatefulWidget {
  const _ProfileInformationPage({
    required this.profile,
  });

  final Map<String, dynamic> profile;

  @override
  State<_ProfileInformationPage> createState() =>
      _ProfileInformationPageState();
}

class _ProfileInformationPageState
    extends State<_ProfileInformationPage> {
  late final TextEditingController name;
  late final Set<String> interests;
  late String budget;
  late String pace;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(
      text: '${widget.profile['displayName'] ?? ''}',
    );
    interests =
        Set<String>.from(widget.profile['travelInterests'] ?? const []);
    budget = '${widget.profile['budgetPreference'] ?? 'Medium'}';
    pace = '${widget.profile['travelPace'] ?? 'Balanced'}';
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      showMessage(context, 'Enter your full name.', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      final uid = AppServices.auth.currentUser!.uid;
      await AppServices.travelerRef(uid).update({
        'displayName': name.text.trim(),
        'travelInterests': interests.toList(),
        'budgetPreference': budget,
        'travelPace': pace,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await AppServices.auth.currentUser!
          .updateDisplayName(name.text.trim());
      widget.profile['displayName'] = name.text.trim();
      widget.profile['travelInterests'] = interests.toList();
      widget.profile['budgetPreference'] = budget;
      widget.profile['travelPace'] = pace;

      if (mounted) {
        showMessage(context, 'Profile updated.');
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
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email =
        '${widget.profile['email'] ?? AppServices.auth.currentUser?.email ?? ''}';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Text('Profile Information'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
        children: [
          ExplorerCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: ExplorerColors.navySoft,
                  foregroundColor: ExplorerColors.navy,
                  child: Text(
                    name.text.trim().isEmpty
                        ? 'T'
                        : name.text.trim()[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap to change profile picture',
                  style: TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: TextEditingController(text: email),
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                  ),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Travel Interests',
                    style: TextStyle(
                      color: ExplorerColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Heritage',
                    'Food',
                    'Nature',
                    'Culture',
                    'Local Business',
                  ]
                      .map(
                        (item) => FilterChip(
                          label: Text(item),
                          selected: interests.contains(item),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                interests.add(item);
                              } else {
                                interests.remove(item);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: budget,
                  decoration: const InputDecoration(
                    labelText: 'Budget Preference',
                  ),
                  items: const ['Low', 'Medium', 'High']
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => budget = value ?? budget),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: pace,
                  decoration: const InputDecoration(
                    labelText: 'Travel Pace',
                  ),
                  items: const ['Relaxed', 'Balanced', 'Fast']
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => pace = value ?? pace),
                ),
                const SizedBox(height: 18),
                ExplorerCard(
                  backgroundColor: ExplorerColors.successSoft,
                  borderColor: const Color(0xFFB9E3CF),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: ExplorerColors.success,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Verified Explorer Profile',
                          style: TextStyle(
                            color: ExplorerColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'Saving...' : 'Save Changes'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const Text('Discard Edits'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
