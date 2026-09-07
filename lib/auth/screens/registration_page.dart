part of '../auth_pages.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({
    super.key,
    required this.role,
    this.initialName,
    this.initialEmail,
    this.isGoogle = false,
  });

  final String role;
  final String? initialName;
  final String? initialEmail;
  final bool isGoogle;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;

  @override
  void initState() {
    super.initState();
    fields = <String, TextEditingController>{
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

    if (widget.initialName != null) {
      fields['name']?.text = widget.initialName!;
      fields['owner']?.text = widget.initialName!;
    }
    if (widget.initialEmail != null) {
      fields['email']?.text = widget.initialEmail!;
    }
  }
  final interests = <String>{};
  final selectedDays = <String>{};
  TimeOfDay? openingTime;
  TimeOfDay? closingTime;
  String budget = 'Medium';
  String pace = 'Balanced';
  String category = 'Food';
  XFile? verification;
  XFile? businessImage;
  LatLng? vendorLocation;
  bool busy = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  // Security Questions State
  bool _showSecurityQuestions = false;
  final securityQuestions = [
    'What was the name of your first pet?',
    'In what city were you born?',
    'What was your mother\'s maiden name?',
    'What was the make of your first car?',
    'What was the name of your elementary school?',
    'What is your favorite book?',
  ];
  String? q1;
  String? q2;
  final a1 = TextEditingController();
  final a2 = TextEditingController();

  String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String? validateNameInput(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (!isValidName(value)) return 'Use only letters and spaces';
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (!isValidEmail(value)) return 'Enter a valid email address';
    return null;
  }

  String? validatePasswordInput(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    return validatePassword(value);
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    if (!widget.isGoogle && fields['password']!.text != fields['confirm']!.text) {
      showMessage(context, 'Passwords do not match.', error: true);
      return;
    }
    if (widget.role == 'traveler' && interests.isEmpty) {
      showMessage(context, 'Select at least one travel interest.', error: true);
      return;
    }
    if (widget.role == 'vendor' && selectedDays.isEmpty) {
      showMessage(context, 'Select at least one operating day.', error: true);
      return;
    }
    if (widget.role == 'vendor' && (openingTime == null || closingTime == null)) {
      showMessage(context, 'Select business opening and closing hours.', error: true);
      return;
    }
    if (widget.role == 'vendor' && !isValidMalaysianPhone(fields['phone']!.text)) {
      showMessage(context, 'Enter a valid Malaysian phone number.', error: true);
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
    
    // Switch to security questions step
    setState(() => _showSecurityQuestions = true);
  }

  Future<void> _finalizeRegistration() async {
    final answer1 = a1.text.trim();
    final answer2 = a2.text.trim();

    if (q1 == null || q2 == null || answer1.isEmpty || answer2.isEmpty) {
      showMessage(context, 'Please answer both security questions.', error: true);
      return;
    }
    if (q1 == q2) {
      showMessage(context, 'Please select two different questions.', error: true);
      return;
    }
    if (answer1.length < 5 || answer2.length < 5) {
      showMessage(context, 'Each answer must be at least 5 characters long.', error: true);
      return;
    }

    final questionsData = [
      {'question': q1!, 'answer': answer1.toLowerCase()},
      {'question': q2!, 'answer': answer2.toLowerCase()},
    ];

    setState(() => busy = true);
    try {
      if (widget.isGoogle) {
        if (widget.role == 'traveler') {
          await AppServices.createTravelerProfileForCurrentUser(
            fullName: cleanName(fields['name']!.text),
            interests: interests.toList(),
            budgetPreference: budget,
            travelPace: pace,
            securityQuestions: questionsData,
          );
        } else {
          // Google sign-in for vendor (not requested but handled for safety)
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
            businessName: cleanName(fields['business']!.text),
            ownerName: cleanName(fields['owner']!.text),
            category: category,
            contactNumber: '+60 ${fields['phone']!.text.trim()}',
            shopLocation: fields['location']!.text.trim(),
            businessHours: '${openingTime!.format(context)} - ${closingTime!.format(context)} (${selectedDays.toList().join(', ')})',
            description: fields['description']!.text.trim(),
            latitude: vendorLocation!.latitude,
            longitude: vendorLocation!.longitude,
            verificationBytes: bytes,
            verificationExtension: extension,
            businessImageBytes: coverBytes,
            businessImageExtension: coverExtension,
            securityQuestions: questionsData,
          );
        }
      } else if (widget.role == 'traveler') {
        await AppServices.registerTraveler(
          email: fields['email']!.text.trim(),
          password: fields['password']!.text,
          fullName: cleanName(fields['name']!.text),
          interests: interests.toList(),
          budgetPreference: budget,
          travelPace: pace,
          securityQuestions: questionsData,
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

        final hours = '${openingTime!.format(context)} - ${closingTime!.format(context)}';
        final days = selectedDays.toList().join(', ');

        await AppServices.registerVendor(
          email: fields['email']!.text.trim(),
          password: fields['password']!.text,
          businessName: cleanName(fields['business']!.text),
          ownerName: cleanName(fields['owner']!.text),
          category: category,
          contactNumber: '+60 ${fields['phone']!.text.trim()}',
          shopLocation: fields['location']!.text.trim(),
          businessHours: '$hours ($days)',
          description: fields['description']!.text.trim(),
          latitude: vendorLocation!.latitude,
          longitude: vendorLocation!.longitude,
          verificationBytes: bytes,
          verificationExtension: extension,
          businessImageBytes: coverBytes,
          businessImageExtension: coverExtension,
          securityQuestions: questionsData,
        );
      }
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          await _completeExistingAuthRegistration(questionsData);
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

  Future<void> _completeExistingAuthRegistration(List<Map<String, String>> securityQuestions) async {
    final credential = await AppServices.auth.signInWithEmailAndPassword(
      email: fields['email']!.text.trim(),
      password: fields['password']!.text,
    );

    final account = await AppServices.currentAccountProfile();
    if (account != null) {
      if (account.role == widget.role) return;

      await AppServices.signOut();
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
        fullName: cleanName(fields['name']!.text),
        interests: interests.toList(),
        budgetPreference: budget,
        travelPace: pace,
        securityQuestions: securityQuestions,
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
      businessName: cleanName(fields['business']!.text),
      ownerName: cleanName(fields['owner']!.text),
      category: category,
      contactNumber: '+60 ${fields['phone']!.text.trim()}',
      shopLocation: fields['location']!.text.trim(),
      businessHours: '${openingTime!.format(context)} - ${closingTime!.format(context)} (${selectedDays.toList().join(', ')})',
      description: fields['description']!.text.trim(),
      latitude: vendorLocation!.latitude,
      longitude: vendorLocation!.longitude,
      verificationBytes: bytes,
      verificationExtension: extension,
      businessImageBytes: coverBytes,
      businessImageExtension: coverExtension,
      securityQuestions: securityQuestions,
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
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    a1.dispose();
    a2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final traveler = widget.role == 'traveler';
    return Scaffold(
      appBar: AppBar(
        title: Text(traveler ? 'Traveler registration' : 'Vendor registration'),
        leading: _showSecurityQuestions 
            ? IconButton(
                onPressed: () => setState(() => _showSecurityQuestions = false), 
                icon: const Icon(Icons.arrow_back),
              ) 
            : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: _showSecurityQuestions 
                ? _buildSecurityQuestionsForm() 
                : _buildRegistrationForm(traveler),
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm(bool traveler) {
    return Form(
      key: formKey,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              if (traveler) ...[
                TextFormField(
                  controller: fields['name'],
                  validator: validateNameInput,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                TextFormField(
                  controller: fields['business'],
                  validator: validateNameInput,
                  decoration: const InputDecoration(
                    labelText: 'Business name',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: fields['owner'],
                  validator: validateNameInput,
                  decoration: const InputDecoration(
                    labelText: 'Owner name',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: fields['email'],
                validator: validateEmail,
                keyboardType: TextInputType.emailAddress,
                enabled: !widget.isGoogle,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'example@email.com',
                ),
              ),
              if (!widget.isGoogle) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: fields['password'],
                  validator: validatePasswordInput,
                  obscureText: obscurePassword,
                  obscuringCharacter: '*',
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                          () => obscurePassword = !obscurePassword),
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: fields['confirm'],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v != fields['password']!.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  obscureText: obscureConfirm,
                  obscuringCharacter: '*',
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                          () => obscureConfirm = !obscureConfirm),
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
              ],
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
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!isValidMalaysianPhone(v)) {
                      return 'Invalid Malaysia phone format';
                    }
                    return null;
                  },
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact number',
                    prefixText: '+60 ',
                    helperText: 'e.g. 123456789',
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
                        ? 'Upload verification document (Required)'
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
                  busy ? 'Checking details...' : 'Continue to Security',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityQuestionsForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.security, size: 48, color: ExplorerColors.navy),
            const SizedBox(height: 12),
            const Text(
              'Security Questions',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'These questions will help you recover your account if you lose access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ExplorerColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: q1,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(
                labelText: 'Question 1',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: securityQuestions
                  .where((q) => q != q2)
                  .map((q) => DropdownMenuItem(
                      value: q,
                      child: Text(
                        q,
                        style: const TextStyle(fontSize: 14),
                      )))
                  .toList(),
              onChanged: (v) => setState(() => q1 = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: a1,
              decoration: const InputDecoration(
                labelText: 'Answer 1',
                hintText: 'At least 5 characters',
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: q2,
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(
                labelText: 'Question 2',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: securityQuestions
                  .where((q) => q != q1)
                  .map((q) => DropdownMenuItem(
                      value: q,
                      child: Text(
                        q,
                        style: const TextStyle(fontSize: 14),
                      )))
                  .toList(),
              onChanged: (v) => setState(() => q2 = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: a2,
              decoration: const InputDecoration(
                labelText: 'Answer 2',
                hintText: 'At least 5 characters',
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: busy ? null : _finalizeRegistration,
              child: Text(busy ? 'Creating account...' : 'Complete Registration'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: busy ? null : () => setState(() => _showSecurityQuestions = false),
              child: const Text('Back to details'),
            ),
          ],
        ),
      ),
    );
  }
}
