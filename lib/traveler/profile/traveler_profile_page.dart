
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
  @override
  void initState() {
    super.initState();
    // Refresh user data (like changed email) whenever profile is opened.
    // Use a silent reload to avoid interrupting the session.
    _refreshUser();
  }

  Future<void> _refreshUser() async {
    try {
      final user = AppServices.auth.currentUser;
      if (user != null) {
        await user.reload();
        final updatedUser = AppServices.auth.currentUser;
        if (updatedUser != null &&
            updatedUser.emailVerified &&
            updatedUser.email != widget.profile['email']) {
          // Attempt to update Firestore. If user was force-logged out 
          // by Firebase, this update will fail, and we won't show the notice.
          await AppServices.travelerRef(updatedUser.uid).update({
            'email': updatedUser.email,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          showGlobalNotice(
            title: 'Session Expired',
            message: 'Your email address has been verified. Please sign in again with your new email.',
            buttonText: 'Login Now',
            onConfirm: () async {
              await AppServices.signOut();
            },
          );
        } else if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Profile refresh failed: $e');
    }
  }

  Future<void> deactivateAccount({required bool deletionRequested}) async {
    // Check 72-hour reactivation cooldown
    final rawReactivatedAt = widget.profile['lastReactivatedAt'];
    DateTime? reactivatedAt;
    if (rawReactivatedAt is Timestamp) {
      reactivatedAt = rawReactivatedAt.toDate();
    } else if (rawReactivatedAt is String) {
      reactivatedAt = DateTime.tryParse(rawReactivatedAt);
    }

    if (reactivatedAt != null) {
      final now = DateTime.now();
      final cooldownEnd = reactivatedAt.add(const Duration(hours: 72));
      if (now.isBefore(cooldownEnd)) {
        final remaining = cooldownEnd.difference(now);
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes.remainder(60);
        final timeStr = hours > 0
            ? '$hours hour${hours == 1 ? '' : 's'} and $minutes minute${minutes == 1 ? '' : 's'}'
            : '$minutes minute${minutes == 1 ? '' : 's'}';
        showMessage(
          context,
          'Account deactivation is on a 72-hour cooldown after reactivation. Remaining cooldown: $timeStr.',
          error: true,
        );
        return;
      }
    }

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
            'Deactivating your account is temporary. Your profile, itineraries and rewards will be hidden until you log back in and reactivate your account.',
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
        automaticallyImplyLeading: false,
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
          // SECTION 1: ACCOUNT & PRIVACY
          _sectionHeader('ACCOUNT & PRIVACY'),
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
                  icon: widget.profile['isProfileHidden'] == true
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  title: widget.profile['isProfileHidden'] == true
                      ? 'Profile Privacy (Hidden)'
                      : 'Profile Privacy (Visible)',
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
              ],
            ),
          ),

          // SECTION 2: EXPLORE & COMMUNITY
          _sectionHeader('EXPLORE & COMMUNITY'),
          ExplorerCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingsTile(
                  icon: Icons.person_search_outlined,
                  title: 'Search Users',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserSearchPage(),
                    ),
                  ),
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.storefront_outlined,
                  title: 'Search Vendors',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VendorSearchPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // SECTION 3: REWARDS & SAFETY
          _sectionHeader('REWARDS & SAFETY'),
          ExplorerCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
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

          // SECTION 4: SECURITY & LOGIN
          _sectionHeader('SECURITY & LOGIN'),
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
                FutureBuilder<bool>(
                  future: PinService.isPinSet(),
                  builder: (context, snapshot) {
                    final hasPin = snapshot.data == true;
                    return _settingsTile(
                      icon: hasPin ? Icons.lock_open_outlined : Icons.lock_outline,
                      title: hasPin ? 'Change or Disable PIN' : 'Setup Security PIN',
                      onTap: () async {
                        if (hasPin) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Security PIN'),
                              content: const Text('Would you like to change your PIN or disable it?'),
                              actions: [
                                TextButton(
                                  onPressed: () async {
                                    await PinService.disablePin();
                                    if (context.mounted) {
                                      Navigator.pop(context, true);
                                      showMessage(context, 'Security PIN disabled.');
                                    }
                                  },
                                  child: const Text('Disable PIN', style: TextStyle(color: ExplorerColors.danger)),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Change PIN'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == false && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PinSetupPage()),
                            ).then((_) => setState(() {}));
                          } else if (confirmed == true) {
                            setState(() {});
                          }
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PinSetupPage()),
                          ).then((_) => setState(() {}));
                        }
                      },
                    );
                  },
                ),
                _divider(),
                _settingsTile(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: AppServices.signOut,
                ),
              ],
            ),
          ),

          // SECTION 5: DANGER ZONE
          _sectionHeader('DANGER ZONE'),
          ExplorerCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
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

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: ExplorerColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .6,
        ),
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
  late bool isProfileHidden;
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
    isProfileHidden = widget.profile['isProfileHidden'] == true;
    
    // Reload user to get latest email if it was verified/changed
    AppServices.auth.currentUser?.reload().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> save() async {
    final cleanedName = cleanName(name.text);
    if (cleanedName.isEmpty) {
      showMessage(context, 'Enter your full name.', error: true);
      return;
    }
    if (!isValidName(name.text)) {
      showMessage(context, 'Name contains invalid characters.', error: true);
      return;
    }
    if (interests.isEmpty) {
      showMessage(context, 'Select at least one travel interest.', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      final uid = AppServices.auth.currentUser!.uid;
      await AppServices.travelerRef(uid).update({
        'displayName': cleanedName,
        'travelInterests': interests.toList(),
        'budgetPreference': budget,
        'travelPace': pace,
        'isProfileHidden': isProfileHidden,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await AppServices.auth.currentUser!.updateDisplayName(cleanedName);
      widget.profile['displayName'] = cleanedName;
      widget.profile['travelInterests'] = interests.toList();
      widget.profile['budgetPreference'] = budget;
      widget.profile['travelPace'] = pace;
      widget.profile['isProfileHidden'] = isProfileHidden;

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
    final email = AppServices.auth.currentUser?.email ??
        '${widget.profile['email'] ?? ''}';

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: email),
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangeEmailPage(),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Change'),
                      ),
                    ),
                  ],
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
                  initialValue: budget,
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
                  initialValue: pace,
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
                const SizedBox(height: 16),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Hide Profile from Search',
                    style: TextStyle(
                      color: ExplorerColors.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Turn off profile viewing by other people. When enabled, your profile will show as hidden when others search for your name.',
                    style: TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  value: isProfileHidden,
                  activeColor: ExplorerColors.navy,
                  onChanged: (val) =>
                      setState(() => isProfileHidden = val),
                ),
                const Divider(),
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
