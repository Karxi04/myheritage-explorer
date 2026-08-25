part of '../traveler_pages.dart';

class CreateHazardPage extends StatefulWidget {
  const CreateHazardPage({super.key});

  @override
  State<CreateHazardPage> createState() => _CreateHazardPageState();
}

class _CreateHazardPageState extends State<CreateHazardPage> {
  final _reportService = HazardReportService();
  final _locationService = const LocationService();
  final description = TextEditingController();
  String category = 'Unsafe walkway';
  String severity = 'Medium';
  XFile? image;
  bool busy = false;

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (description.text.trim().isEmpty) {
      showMessage(context, 'Enter a hazard description.', error: true);
      return;
    }
    if (image == null) {
      showMessage(
        context,
        'Add photo evidence before submitting.',
        error: true,
      );
      return;
    }

    setState(() => busy = true);
    try {
      final position = await _locationService.getCurrentPosition();
      final imageBytes = await image!.readAsBytes();

      await _reportService.createReport(
        category: category,
        severity: severity,
        description: description.text.trim(),
        latitude: position.latitude,
        longitude: position.longitude,
        imageBytes: imageBytes,
      );

      if (mounted) {
        showMessage(context, 'Hazard submitted with status Pending Review.');
        Navigator.pop(context);
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExplorerColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ExplorerPageHeader(
              title: 'Report a Safety Hazard',
              subtitle: 'Help other travelers avoid unsafe locations.',
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ExplorerColors.navy,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(0x26FFFFFF),
                          foregroundColor: Colors.white,
                          child: Icon(Icons.health_and_safety_outlined),
                        ),
                        SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Community Safety Report',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your current GPS location will be included when the report is submitted.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ExplorerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ExplorerSectionTitle('Hazard Details'),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Hazard category',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items:
                              const [
                                    'Unsafe walkway',
                                    'Poor lighting',
                                    'Road obstruction',
                                    'Flooding',
                                    'Suspicious activity',
                                    'Other',
                                  ]
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) =>
                              setState(() => category = value!),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Severity level',
                          style: TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: ['Low', 'Medium', 'High'].map((value) {
                            final selected = severity == value;
                            final selectedColor = switch (value) {
                              'High' => ExplorerColors.danger,
                              'Medium' => ExplorerColors.goldDark,
                              _ => ExplorerColors.success,
                            };
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: value == 'High' ? 0 : 8,
                                ),
                                child: ChoiceChip(
                                  label: SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      value,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  selected: selected,
                                  selectedColor: selectedColor,
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : ExplorerColors.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => severity = value),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: description,
                          maxLines: 5,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            labelText: 'Describe the safety concern',
                            hintText:
                                'Explain what happened, what travelers should avoid and any useful landmarks...',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ExplorerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ExplorerSectionTitle(
                          'Photo Evidence *',
                          subtitle:
                              'A clear photo helps administrators verify the report.',
                        ),
                        const SizedBox(height: 13),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            final picked = await ImagePicker().pickImage(
                              source: ImageSource.camera,
                              maxWidth: 1600,
                              maxHeight: 1600,
                              imageQuality: 85,
                            );
                            if (picked != null) setState(() => image = picked);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 24,
                            ),
                            decoration: BoxDecoration(
                              color: ExplorerColors.subtle,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: image == null
                                    ? ExplorerColors.border
                                    : ExplorerColors.success,
                              ),
                            ),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor: image == null
                                      ? ExplorerColors.navySoft
                                      : ExplorerColors.successSoft,
                                  foregroundColor: image == null
                                      ? ExplorerColors.navy
                                      : ExplorerColors.success,
                                  child: Icon(
                                    image == null
                                        ? Icons.camera_alt_outlined
                                        : Icons.check_rounded,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  image == null
                                      ? 'Tap to take a photo'
                                      : image!.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: ExplorerColors.navy,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: busy ? null : submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      busy ? 'Submitting Report...' : 'Submit Hazard Report',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
