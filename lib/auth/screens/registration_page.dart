
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
  bool busy = false;
  bool passwordVisible = false;
  bool confirmVisible = false;

  static const travelerInterests = [
    'Historical Sites',
    'Traditional Food',
    'Local Businesses',
    'Cultural Landmarks',
    'Craft Workshops',
    'Nature',
  ];

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
        'Upload a business verification document image.',
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
          verificationBytes: bytes,
          verificationExtension: extension,
        );
      }

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
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

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final traveler = widget.role == 'traveler';

    return Scaffold(
      backgroundColor: ExplorerColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(traveler ? 'Tourist Registration' : 'Vendor Registration'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 36),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: formKey,
              child: ExplorerCard(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
                child: traveler
                    ? _buildTravelerForm(context)
                    : _buildVendorForm(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTravelerForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create Tourist\nAccount',
          style: TextStyle(
            color: ExplorerColors.navy,
            fontSize: 30,
            height: 1.06,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Join us to explore cultural landmarks and plan your heritage journey.',
          style: TextStyle(
            color: ExplorerColors.muted,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 25),
        _label('Full Name'),
        TextFormField(
          controller: fields['name'],
          validator: requiredText,
          decoration: const InputDecoration(hintText: 'John Doe'),
        ),
        const SizedBox(height: 14),
        _label('Email Address'),
        TextFormField(
          controller: fields['email'],
          validator: requiredText,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'john@example.com'),
        ),
        const SizedBox(height: 14),
        _label('Password'),
        TextFormField(
          controller: fields['password'],
          validator: (value) =>
              (value?.length ?? 0) < 8 ? 'Use at least 8 characters' : null,
          obscureText: !passwordVisible,
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => passwordVisible = !passwordVisible),
              icon: Icon(
                passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _label('Confirm Password'),
        TextFormField(
          controller: fields['confirm'],
          validator: requiredText,
          obscureText: !confirmVisible,
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => confirmVisible = !confirmVisible),
              icon: Icon(
                confirmVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _label('Travel Interests (Select all that apply)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: travelerInterests
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
        const SizedBox(height: 22),
        _label('Budget Preference'),
        const SizedBox(height: 8),
        _choiceRow(
          values: const ['Low', 'Medium', 'High'],
          selected: budget,
          onSelected: (value) => setState(() => budget = value),
        ),
        const SizedBox(height: 20),
        _label('Travel Pace'),
        const SizedBox(height: 8),
        _choiceRow(
          values: const ['Relaxed', 'Balanced', 'Fast'],
          selected: pace,
          onSelected: (value) => setState(() => pace = value),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: busy ? null : submit,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(busy ? 'Creating account...' : 'Create Tourist Account'),
              if (!busy) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 17),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const LoginPage(role: 'traveler'),
              ),
            ),
            child: const Text('Already have an account? Log in here'),
          ),
        ),
      ],
    );
  }

  Widget _buildVendorForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vendor Registration',
          style: TextStyle(
            color: ExplorerColors.navy,
            fontSize: 29,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Become a verified steward of cultural experiences.',
          style: TextStyle(
            color: ExplorerColors.muted,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 26),
        _sectionHeading('Business Information'),
        const SizedBox(height: 14),
        _label('Business Name'),
        TextFormField(
          controller: fields['business'],
          validator: requiredText,
          decoration: const InputDecoration(
            hintText: 'e.g. The Heritage Cafe',
          ),
        ),
        const SizedBox(height: 14),
        _label('Owner Name'),
        TextFormField(
          controller: fields['owner'],
          validator: requiredText,
          decoration: const InputDecoration(hintText: 'Full Name'),
        ),
        const SizedBox(height: 14),
        _label('Email Address'),
        TextFormField(
          controller: fields['email'],
          validator: requiredText,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'contact@business.com',
          ),
        ),
        const SizedBox(height: 14),
        _label('Password'),
        TextFormField(
          controller: fields['password'],
          validator: (value) =>
              (value?.length ?? 0) < 8 ? 'Use at least 8 characters' : null,
          obscureText: !passwordVisible,
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => passwordVisible = !passwordVisible),
              icon: Icon(
                passwordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _label('Confirm Password'),
        TextFormField(
          controller: fields['confirm'],
          validator: requiredText,
          obscureText: !confirmVisible,
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => confirmVisible = !confirmVisible),
              icon: Icon(
                confirmVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        _sectionHeading('Operational Details'),
        const SizedBox(height: 14),
        _label('Business Category'),
        DropdownButtonFormField<String>(
          value: category,
          items: const [
            'Food',
            'Craft',
            'Workshop',
            'Heritage',
            'Retail',
            'Other',
          ]
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => category = value ?? category),
        ),
        const SizedBox(height: 14),
        _label('Contact Number'),
        TextFormField(
          controller: fields['phone'],
          validator: requiredText,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: '+60 12-345 6789',
          ),
        ),
        const SizedBox(height: 14),
        _label('Shop Location'),
        TextFormField(
          controller: fields['location'],
          validator: requiredText,
          decoration: const InputDecoration(
            hintText: 'Full street address',
          ),
        ),
        const SizedBox(height: 14),
        _label('Opening Hours'),
        TextFormField(
          controller: fields['hours'],
          validator: requiredText,
          decoration: const InputDecoration(
            hintText: 'e.g. Mon-Fri: 9AM - 5PM',
          ),
        ),
        const SizedBox(height: 14),
        _label('Business Description'),
        TextFormField(
          controller: fields['description'],
          validator: requiredText,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Briefly describe your cultural offering...',
          ),
        ),
        const SizedBox(height: 26),
        _sectionHeading('Verification'),
        const SizedBox(height: 8),
        const Text(
          'Provide context for your heritage claim, such as family lineage, cultural significance, or business history.',
          style: TextStyle(
            color: ExplorerColors.muted,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: () async {
            verification =
                await ImagePicker().pickImage(source: ImageSource.gallery);
            if (mounted) setState(() {});
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            decoration: BoxDecoration(
              color: ExplorerColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ExplorerColors.border,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  color: ExplorerColors.navy,
                  size: 30,
                ),
                const SizedBox(height: 8),
                Text(
                  verification == null
                      ? 'Upload Business Verification Document'
                      : verification!.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ExplorerColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Tap to browse or upload an image file',
                  style: TextStyle(
                    color: ExplorerColors.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Supported image formats: JPG, PNG',
                  style: TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: busy ? null : submit,
          child: Text(busy ? 'Submitting...' : 'Submit Registration'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: ExplorerColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _sectionHeading(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: ExplorerColors.navy,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _choiceRow({
    required List<String> values,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Row(
      children: values
          .map(
            (item) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: item == values.last ? 0 : 8,
                ),
                child: ChoiceChip(
                  label: SizedBox(
                    width: double.infinity,
                    child: Text(item, textAlign: TextAlign.center),
                  ),
                  selected: selected == item,
                  onSelected: (_) => onSelected(item),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
