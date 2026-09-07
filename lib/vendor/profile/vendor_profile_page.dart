part of '../vendor_pages.dart';

class VendorProfilePage extends StatefulWidget {
  const VendorProfilePage({super.key, required this.profile});
  final Map<String, dynamic> profile;
  @override
  State<VendorProfilePage> createState() => _VendorProfilePageState();
}

class _VendorProfilePageState extends State<VendorProfilePage> {
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
    business = TextEditingController(text: widget.profile['businessName'] ?? '');
    owner = TextEditingController(text: widget.profile['ownerName'] ?? '');

    final rawPhone = '${widget.profile['contactNumber'] ?? ''}';
    phone = TextEditingController(text: rawPhone.replaceFirst('+60 ', ''));

    location = TextEditingController(text: widget.profile['shopLocation'] ?? '');
    description =
        TextEditingController(text: widget.profile['businessDescription'] ?? '');

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
          await AppServices.vendorRef(updatedUser.uid).update({
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
      debugPrint('Vendor profile refresh failed: $e');
    }
  }

  void _parseBusinessHours(String raw) {
    if (raw.isEmpty) return;
    try {
      // Format: 9:00 AM - 6:00 PM (Mon, Tue, Wed)
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

  Future<void> save() async {
    final cleanedBusiness = cleanName(business.text);
    final cleanedOwner = cleanName(owner.text);

    if (cleanedBusiness.isEmpty || cleanedOwner.isEmpty) {
      showMessage(context, 'Business and owner names are required.', error: true);
      return;
    }
    if (!isValidName(business.text) || !isValidName(owner.text)) {
      showMessage(context, 'Names contains invalid characters.', error: true);
      return;
    }
    if (!isValidMalaysianPhone(phone.text)) {
      showMessage(context, 'Enter a valid Malaysian phone number.', error: true);
      return;
    }
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
        'contactNumber': '+60 ${phone.text.trim()}',
        'shopLocation': location.text.trim(),
        'businessHours': hoursStr,
        'businessDescription': description.text.trim(),
        if (point != null) 'location': GeoPoint(point.latitude, point.longitude),
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
      if (mounted) showMessage(context, 'Business profile updated.');
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deactivateAccount({required bool deletionRequested}) async {
    if (deletionRequested) {
      final keywordConfirmed = await confirmDeletionKeyword(context);
      if (!keywordConfirmed || !mounted) {
        if (mounted && !keywordConfirmed) {
          showMessage(context, 'Deletion keyword was not confirmed.', error: true);
        }
        return;
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Deactivate vendor account?'),
          content: const Text('The business profile and vouchers will become unavailable until an administrator reactivates the account.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Deactivate')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final password = await requestPassword(context);
    if (password == null || password.isEmpty) return;
    try {
      await AppServices.reauthenticate(password);
      await AppServices.deactivateOwnAccount(deletionRequested: deletionRequested);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Vendor Profile')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(
                        text: AppServices.auth.currentUser?.email ?? ''),
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
            const SizedBox(height: 12),
            TextField(
              controller: business,
              decoration: const InputDecoration(labelText: 'Business name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: owner,
              decoration: const InputDecoration(labelText: 'Owner name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact number',
                prefixText: '+60 ',
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Operating Days',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
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
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Business Hours',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
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
            const SizedBox(height: 12),
            TextField(
              controller: location,
              decoration: const InputDecoration(labelText: 'Shop address'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
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
                    : 'Coordinate: '
                        '${pinnedLocation!.latitude.toStringAsFixed(5)}, '
                        '${pinnedLocation!.longitude.toStringAsFixed(5)}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Business description'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Saving...' : 'Save business profile'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ChangePasswordPage())),
              icon: const Icon(Icons.password_outlined),
              label: const Text('Change password'),
            ),
            const SizedBox(height: 8),
            FutureBuilder<bool>(
              future: PinService.isPinSet(),
              builder: (context, snapshot) {
                final hasPin = snapshot.data == true;
                return OutlinedButton.icon(
                  onPressed: () async {
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
                                  showMessage(context, 'Security PIN disabled.');
                                }
                              },
                              child: const Text('Disable PIN',
                                  style: TextStyle(color: ExplorerColors.danger)),
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
                  icon: Icon(hasPin ? Icons.lock_open_outlined : Icons.lock_outline),
                  label: Text(hasPin ? 'Manage Security PIN' : 'Setup Security PIN'),
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: AppServices.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => deactivateAccount(deletionRequested: false),
              icon: const Icon(Icons.pause_circle_outline),
              label: const Text('Deactivate account'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => deactivateAccount(deletionRequested: true),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Delete account'),
            ),
          ],
        ),
      );
}

