part of '../auth_pages.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, required this.role});
  final String role;
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final formKey = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{
    for (final key in [
      'email',
      'password',
      'confirm',
      'name',
      'business',
      'owner',
      'phone',
      'location',
      'hours',
      'description',
    ])
      key: TextEditingController(),
  };
  final interests = <String>{};
  String budget = 'Medium';
  String pace = 'Balanced';
  String category = 'Food';
  XFile? verification;
  XFile? businessImage;
  LatLng? vendorLocation;
  bool busy = false;

  String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    if (fields['password']!.text != fields['confirm']!.text) {
      showMessage(context, 'Passwords do not match.', error: true);
      return;
    }
    if (widget.role == 'traveler' && interests.isEmpty) {
      showMessage(context, 'Select at least one travel interest.', error: true);
      return;
    }
    if (widget.role == 'vendor' && verification == null) {
      showMessage(
        context,
        'Upload a business verification document.',
        error: true,
      );
      return;
    }
    if (widget.role == 'vendor' && vendorLocation == null) {
      showMessage(
        context,
        'Pin the business location on the map.',
        error: true,
      );
      return;
    }
    setState(() => busy = true);
    try {
      if (widget.role == 'traveler') {
        await AppServices.registerTraveler(
          email: fields['email']!.text,
          password: fields['password']!.text,
          fullName: fields['name']!.text,
          interests: interests.toList(),
          budgetPreference: budget,
          travelPace: pace,
        );
      } else {
        Uint8List? bytes;
        String? extension;
        if (verification != null) {
          bytes = await verification!.readAsBytes();
          extension = verification!.name.split('.').last;
        }
        Uint8List? coverBytes;
        String? coverExtension;
        if (businessImage != null) {
          coverBytes = await businessImage!.readAsBytes();
          coverExtension = businessImage!.name.split('.').last;
        }
        await AppServices.registerVendor(
          email: fields['email']!.text,
          password: fields['password']!.text,
          businessName: fields['business']!.text,
          ownerName: fields['owner']!.text,
          category: category,
          contactNumber: fields['phone']!.text,
          shopLocation: fields['location']!.text,
          businessHours: fields['hours']!.text,
          description: fields['description']!.text,
          latitude: vendorLocation!.latitude,
          longitude: vendorLocation!.longitude,
          verificationBytes: bytes,
          verificationExtension: extension,
          businessImageBytes: coverBytes,
          businessImageExtension: coverExtension,
        );
      }
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          await _completeExistingAuthRegistration();
          if (!mounted) return;
          showMessage(context, 'Account profile completed. You are signed in.');
          Navigator.popUntil(context, (route) => route.isFirst);
          return;
        } on FirebaseAuthException catch (signInError) {
          if (!mounted) return;
          showMessage(
            context,
            _existingAuthSignInMessage(signInError),
            error: true,
          );
          return;
        } catch (error) {
          if (!mounted) return;
          showMessage(
            context,
            error.toString().replaceFirst('Exception: ', ''),
            error: true,
          );
          return;
        }
      }

      if (mounted) {
        showMessage(context, _registrationAuthMessage(e), error: true);
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e.toString().replaceFirst('Exception: ', ''),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _completeExistingAuthRegistration() async {
    final credential = await AppServices.auth.signInWithEmailAndPassword(
      email: fields['email']!.text.trim(),
      password: fields['password']!.text,
    );

    final account = await AppServices.currentAccountProfile();
    if (account != null) {
      if (account.role == widget.role) return;

      await AppServices.auth.signOut();
      throw Exception(
        'This email is already registered as ${AppServices.labelForRole(account.role)}. '
        'Open the ${AppServices.labelForRole(account.role)} login screen.',
      );
    }

    final profile = await AppServices.profileForRole(
      credential.user!.uid,
      widget.role,
    );
    if (profile != null && profile['role'] == widget.role) return;

    if (widget.role == 'traveler') {
      await AppServices.createTravelerProfileForCurrentUser(
        fullName: fields['name']!.text,
        interests: interests.toList(),
        budgetPreference: budget,
        travelPace: pace,
      );
      return;
    }

    Uint8List? bytes;
    String? extension;
    if (verification != null) {
      bytes = await verification!.readAsBytes();
      extension = verification!.name.split('.').last;
    }

    Uint8List? coverBytes;
    String? coverExtension;
    if (businessImage != null) {
      coverBytes = await businessImage!.readAsBytes();
      coverExtension = businessImage!.name.split('.').last;
    }

    await AppServices.createVendorProfileForCurrentUser(
      businessName: fields['business']!.text,
      ownerName: fields['owner']!.text,
      category: category,
      contactNumber: fields['phone']!.text,
      shopLocation: fields['location']!.text,
      businessHours: fields['hours']!.text,
      description: fields['description']!.text,
      latitude: vendorLocation!.latitude,
      longitude: vendorLocation!.longitude,
      verificationBytes: bytes,
      verificationExtension: extension,
      businessImageBytes: coverBytes,
      businessImageExtension: coverExtension,
    );
  }

  String _existingAuthSignInMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'wrong-password' || 'invalid-credential' =>
        'This email already has a Firebase login, but the password entered here is incorrect. Use Login or Forgot Password.',
      'user-disabled' => 'This login account has been disabled.',
      'invalid-email' => 'Enter a valid email address.',
      _ =>
        e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : 'Unable to complete this existing account.',
    };
  }

  String _registrationAuthMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'email-already-in-use' =>
        'This email already has a Firebase login. Use Login or Forgot Password. If login says the role profile is missing, run the Auth/profile repair script.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Use a stronger password.',
      'operation-not-allowed' =>
        'Email/password sign-up is not enabled in Firebase Authentication.',
      _ =>
        e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : 'Unable to create the account.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final traveler = widget.role == 'traveler';
    return Scaffold(
      appBar: AppBar(
        title: Text(traveler ? 'Traveler registration' : 'Vendor registration'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
              key: formKey,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      if (traveler) ...[
                        TextFormField(
                          controller: fields['name'],
                          validator: requiredText,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        TextFormField(
                          controller: fields['business'],
                          validator: requiredText,
                          decoration: const InputDecoration(
                            labelText: 'Business name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: fields['owner'],
                          validator: requiredText,
                          decoration: const InputDecoration(
                            labelText: 'Owner name',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: fields['email'],
                        validator: requiredText,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: fields['password'],
                        validator: (v) => (v?.length ?? 0) < 8
                            ? 'Use at least 8 characters'
                            : null,
                        obscureText: true,
                        obscuringCharacter: '*',
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: fields['confirm'],
                        validator: requiredText,
                        obscureText: true,
                        obscuringCharacter: '*',
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (traveler) ...[
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Travel interests',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children:
                              [
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
                                      onSelected: (selected) => setState(
                                        () => selected
                                            ? interests.add(item)
                                            : interests.remove(item),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField(
                          initialValue: budget,
                          decoration: const InputDecoration(
                            labelText: 'Budget preference',
                          ),
                          items: ['Low', 'Medium', 'High']
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => budget = v!),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField(
                          initialValue: pace,
                          decoration: const InputDecoration(
                            labelText: 'Travel pace',
                          ),
                          items: ['Relaxed', 'Balanced', 'Fast']
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => pace = v!),
                        ),
                      ] else ...[
                        DropdownButtonFormField(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Business category',
                          ),
                          items:
                              [
                                    'Food',
                                    'Craft',
                                    'Workshop',
                                    'Heritage',
                                    'Retail',
                                    'Other',
                                  ]
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() => category = v!),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: fields['phone'],
                          validator: requiredText,
                          decoration: const InputDecoration(
                            labelText: 'Contact number',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: fields['location'],
                          validator: requiredText,
                          decoration: const InputDecoration(
                            labelText: 'Shop address',
                            prefixIcon: Icon(
                              Icons.store_mall_directory_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final selected = await Navigator.push<LatLng>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VendorLocationPickerPage(
                                  initialLocation: vendorLocation,
                                ),
                              ),
                            );
                            if (selected != null && mounted) {
                              setState(() => vendorLocation = selected);
                            }
                          },
                          icon: const Icon(Icons.location_on_outlined),
                          label: Text(
                            vendorLocation == null
                                ? 'Pin business coordinate on map'
                                : 'Location pinned: '
                                      '${vendorLocation!.latitude.toStringAsFixed(5)}, '
                                      '${vendorLocation!.longitude.toStringAsFixed(5)}',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: fields['hours'],
                          validator: requiredText,
                          decoration: const InputDecoration(
                            labelText: 'Business hours',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: fields['description'],
                          validator: requiredText,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Business description',
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            verification = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                            );
                            setState(() {});
                          },
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            verification == null
                                ? 'Upload verification document'
                                : verification!.name,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            businessImage = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 82,
                            );
                            if (mounted) setState(() {});
                          },
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            businessImage == null
                                ? 'Upload business cover photo (optional)'
                                : businessImage!.name,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: busy ? null : submit,
                        child: Text(
                          busy ? 'Creating account...' : 'Create account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
