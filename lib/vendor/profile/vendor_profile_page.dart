part of '../vendor_pages.dart';

class VendorProfilePage extends StatefulWidget {
  const VendorProfilePage({super.key, required this.profile});
  final Map<String, dynamic> profile;

  @override
  State<VendorProfilePage> createState() => _VendorProfilePageState();
}

class _VendorProfilePageState extends State<VendorProfilePage> {
  @override
  void initState() {
    super.initState();
    // Refresh user data whenever profile is opened.
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
          await AppServices.vendorRef(updatedUser.uid).update({
            'email': updatedUser.email,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          showGlobalNotice(
            title: 'Session Expired',
            message:
                'Your email address has been verified. Please sign in again with your new email.',
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
      debugPrint('Vendor profile refresh failed: $e');
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
              context, 'Deletion keyword was not confirmed.', error: true);
        }
        return;
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Deactivate vendor account?'),
          content: const Text(
              'The business profile and vouchers will become unavailable until you log back in and reactivate the account.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Deactivate')),
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
          deletionRequested: deletionRequested);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
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

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? ExplorerColors.danger : ExplorerColors.navy;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 2,
      ),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: danger ? ExplorerColors.dangerSoft : ExplorerColors.navySoft,
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
      trailing: const Icon(
        Icons.chevron_right,
        size: 19,
        color: ExplorerColors.muted,
      ),
      onTap: onTap,
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 64);

  @override
  Widget build(BuildContext context) {
    final businessName =
        '${widget.profile['businessName'] ?? widget.profile['displayName'] ?? 'Vendor Shop'}';
    final ownerName = '${widget.profile['ownerName'] ?? ''}';
    final email = AppServices.auth.currentUser?.email ??
        '${widget.profile['email'] ?? ''}';
    final category = '${widget.profile['category'] ?? 'Business'}';
    final shopLocation =
        '${widget.profile['shopLocation'] ?? 'No address set'}';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const ExplorerBrand(compact: true),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          // Header Card
          ExplorerCard(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: ExplorerColors.goldDark.withOpacity(0.15),
                  foregroundColor: ExplorerColors.goldDark,
                  child: const Icon(Icons.storefront, size: 44),
                ),
                const SizedBox(height: 12),
                Text(
                  businessName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (ownerName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Owner: $ownerName',
                    style: const TextStyle(
                      color: ExplorerColors.navy,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: ExplorerColors.navySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: ExplorerColors.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: ExplorerColors.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        shopLocation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ExplorerColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // SECTION 1: BUSINESS & PROFILE
          _sectionHeader('BUSINESS & PROFILE'),
          ExplorerCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingsTile(
                  icon: Icons.storefront_outlined,
                  title: 'Edit Business Profile',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _VendorBusinessInfoPage(
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
                      builder: (_) => UserSearchPage(),
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
                      builder: (_) => VendorSearchPage(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // SECTION 3: SECURITY & LOGIN
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
                      icon: hasPin
                          ? Icons.lock_open_outlined
                          : Icons.lock_outline,
                      title: hasPin
                          ? 'Change or Disable PIN'
                          : 'Setup Security PIN',
                      onTap: () async {
                        if (hasPin) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Security PIN'),
                              content: const Text(
                                  'Would you like to change your PIN or disable it?'),
                              actions: [
                                TextButton(
                                  onPressed: () async {
                                    await PinService.disablePin();
                                    if (context.mounted) {
                                      Navigator.pop(context, true);
                                      showMessage(
                                          context, 'Security PIN disabled.');
                                    }
                                  },
                                  child: const Text('Disable PIN',
                                      style: TextStyle(
                                          color: ExplorerColors.danger)),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Change PIN'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == false && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PinSetupPage()),
                            ).then((_) => setState(() {}));
                          } else if (confirmed == true) {
                            setState(() {});
                          }
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PinSetupPage()),
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

          // SECTION 4: DANGER ZONE
          _sectionHeader('DANGER ZONE'),
          ExplorerCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _settingsTile(
                  icon: Icons.pause_circle_outline,
                  title: 'Deactivate Account',
                  danger: true,
                  onTap: () => deactivateAccount(deletionRequested: false),
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
}

class _VendorBusinessInfoPage extends StatefulWidget {
  const _VendorBusinessInfoPage({required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<_VendorBusinessInfoPage> createState() =>
      _VendorBusinessInfoPageState();
}

class _VendorBusinessInfoPageState extends State<_VendorBusinessInfoPage> {
  late final TextEditingController business;
  late final TextEditingController owner;
  late final TextEditingController phone;
  late final TextEditingController location;
  late final TextEditingController description;
  final selectedDays = <String>{};
  TimeOfDay? openingTime;
  TimeOfDay? closingTime;
  LatLng? pinnedLocation;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    business =
        TextEditingController(text: widget.profile['businessName'] ?? '');
    owner = TextEditingController(text: widget.profile['ownerName'] ?? '');

    var rawPhone = '${widget.profile['contactNumber'] ?? ''}'.trim();
    if (rawPhone.startsWith('+60')) {
      rawPhone = rawPhone.substring(3).trim();
    } else if (rawPhone.startsWith('60')) {
      rawPhone = rawPhone.substring(2).trim();
    } else if (rawPhone.startsWith('0')) {
      rawPhone = rawPhone.substring(1).trim();
    }
    phone = TextEditingController(text: rawPhone);

    location =
        TextEditingController(text: widget.profile['shopLocation'] ?? '');
    description = TextEditingController(
        text: widget.profile['businessDescription'] ?? '');

    _parseBusinessHours(widget.profile['businessHours'] ?? '');

    final rawLocation = widget.profile['location'];
    if (rawLocation is GeoPoint) {
      pinnedLocation = LatLng(rawLocation.latitude, rawLocation.longitude);
    } else if (rawLocation is Map) {
      final map = Map<String, dynamic>.from(rawLocation);
      final latitude = map['latitude'] ?? map['lat'];
      final longitude = map['longitude'] ?? map['lng'] ?? map['lon'];
      if (latitude is num && longitude is num) {
        pinnedLocation = LatLng(latitude.toDouble(), longitude.toDouble());
      }
    }
  }

  void _parseBusinessHours(String raw) {
    if (raw.isEmpty) return;
    try {
      final parts = raw.split(' (');
      if (parts.length > 1) {
        final days = parts[1].replaceAll(')', '').split(', ');
        selectedDays.addAll(days.map((e) => e.trim()));
      }

      final times = parts[0].split(' - ');
      if (times.length > 1) {
        openingTime = _parseTimeOfDay(times[0]);
        closingTime = _parseTimeOfDay(times[1]);
      }
    } catch (_) {}
  }

  TimeOfDay? _parseTimeOfDay(String time) {
    try {
      final parts = time.split(' ');
      final hms = parts[0].split(':');
      var hour = int.parse(hms[0]);
      final minute = int.parse(hms[1]);
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour < 12) {
        hour += 12;
      } else if (parts.length > 1 &&
          parts[1].toUpperCase() == 'AM' &&
          hour == 12) {
        hour = 0;
      }
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    business.dispose();
    owner.dispose();
    phone.dispose();
    location.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final cleanedBusiness = cleanName(business.text);
    final cleanedOwner = cleanName(owner.text);

    if (cleanedBusiness.isEmpty || cleanedOwner.isEmpty) {
      showMessage(context, 'Business and owner names are required.',
          error: true);
      return;
    }
    if (!isValidName(business.text) || !isValidName(owner.text)) {
      showMessage(context, 'Names contains invalid characters.', error: true);
      return;
    }
    var rawInput = phone.text.trim();
    var cleanPhone = rawInput.replaceAll(' ', '').replaceAll('-', '').replaceAll('+', '');
    if (cleanPhone.startsWith('60')) {
      cleanPhone = cleanPhone.substring(2).trim();
    }
    if (cleanPhone.startsWith('0')) {
      cleanPhone = cleanPhone.substring(1).trim();
    }

    if (!isValidMalaysianPhone(cleanPhone)) {
      showMessage(context, 'Enter a valid Malaysian phone number.', error: true);
      return;
    }

    final formattedPhone = '+60 $cleanPhone';

    if (selectedDays.isEmpty) {
      showMessage(context, 'Select at least one operating day.', error: true);
      return;
    }
    if (openingTime == null || closingTime == null) {
      showMessage(context, 'Select business hours.', error: true);
      return;
    }

    final point = pinnedLocation;
    final hoursStr =
        '${openingTime!.format(context)} - ${closingTime!.format(context)} (${selectedDays.toList().join(', ')})';

    setState(() => busy = true);
    try {
      await AppServices.vendorRef(AppServices.auth.currentUser!.uid).update({
        'displayName': cleanedBusiness,
        'businessName': cleanedBusiness,
        'ownerName': cleanedOwner,
        'contactNumber': formattedPhone,
        'shopLocation': location.text.trim(),
        'businessHours': hoursStr,
        'businessDescription': description.text.trim(),
        if (point != null)
          'location': GeoPoint(point.latitude, point.longitude),
        if (point != null) 'latitude': point.latitude,
        if (point != null) 'longitude': point.longitude,
        if (point != null)
          'mapUrl': Uri.https(
            'www.google.com',
            '/maps/search/',
            {'api': '1', 'query': '${point.latitude},${point.longitude}'},
          ).toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      widget.profile['businessName'] = cleanedBusiness;
      widget.profile['displayName'] = cleanedBusiness;
      widget.profile['ownerName'] = cleanedOwner;
      widget.profile['contactNumber'] = formattedPhone;
      widget.profile['shopLocation'] = location.text.trim();
      widget.profile['businessHours'] = hoursStr;
      widget.profile['businessDescription'] = description.text.trim();
      if (point != null) {
        widget.profile['location'] = GeoPoint(point.latitude, point.longitude);
        widget.profile['latitude'] = point.latitude;
        widget.profile['longitude'] = point.longitude;
      }

      if (mounted) {
        showMessage(context, 'Business profile updated.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AppServices.auth.currentUser?.email ??
        '${widget.profile['email'] ?? ''}';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        title: const Text('Edit Business Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
        children: [
          ExplorerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: email),
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Account Email',
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
                const SizedBox(height: 14),
                TextField(
                  controller: business,
                  decoration:
                      const InputDecoration(labelText: 'Business Name'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: owner,
                  decoration: const InputDecoration(labelText: 'Owner Name'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number',
                    prefixText: '+60 ',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Operating Days',
                  style: TextStyle(
                    color: ExplorerColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ].map((day) {
                    final isSelected = selectedDays.contains(day);
                    return FilterChip(
                      label: Text(day),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedDays.add(day);
                          } else {
                            selectedDays.remove(day);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Business Hours',
                  style: TextStyle(
                    color: ExplorerColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: openingTime ??
                                const TimeOfDay(hour: 9, minute: 0),
                          );
                          if (time != null) {
                            setState(() => openingTime = time);
                          }
                        },
                        child: Text(
                          openingTime == null
                              ? 'Opening Time'
                              : 'Opens: ${openingTime!.format(context)}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: closingTime ??
                                const TimeOfDay(hour: 18, minute: 0),
                          );
                          if (time != null) {
                            setState(() => closingTime = time);
                          }
                        },
                        child: Text(
                          closingTime == null
                              ? 'Closing Time'
                              : 'Closes: ${closingTime!.format(context)}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: location,
                  decoration: const InputDecoration(labelText: 'Shop Address'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await Navigator.push<LatLng>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VendorLocationPickerPage(
                            initialLocation: pinnedLocation,
                          ),
                        ),
                      );
                      if (selected != null && mounted) {
                        setState(() => pinnedLocation = selected);
                      }
                    },
                    icon: const Icon(Icons.location_on_outlined),
                    label: Text(
                      pinnedLocation == null
                          ? 'Pin business coordinate on map'
                          : 'Coordinate: ${pinnedLocation!.latitude.toStringAsFixed(5)}, ${pinnedLocation!.longitude.toStringAsFixed(5)}',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Business Description'),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: busy ? null : save,
                  child: Text(busy ? 'Saving...' : 'Save Business Profile'),
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
