part of '../traveler_pages.dart';

class CreateHazardPage extends StatefulWidget {
  const CreateHazardPage({super.key, this.reportService, this.locationService});
  final HazardReportService? reportService;
  final LocationService? locationService;

  @override
  State<CreateHazardPage> createState() => _CreateHazardPageState();
}

class _CreateHazardPageState extends State<CreateHazardPage> {
  late final _reportService = widget.reportService ?? HazardReportService();
  late final _locationService =
      widget.locationService ?? const LocationService();
  final description = TextEditingController();
  String category = 'Unsafe walkway';
  String severity = 'Medium';
  XFile? image;
  Uint8List? _imageBytes;
  EvidenceValidationResult? _evidenceValidation;
  String? _evidenceCheckError;
  bool _validatingImage = false;
  Position? _capturedPosition;
  bool _capturingLocation = true;
  String? _locationError;
  bool busy = false;
  bool _pickingImage = false;
  String _evidenceSource = EvidenceSource.camera;
  String? _descriptionError;

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || _pickingImage || _validatingImage) return;
    if (description.text.trim().isEmpty) {
      setState(
        () => _descriptionError =
            'Describe the hazard so others know what to avoid.',
      );
      return;
    }
    if (image == null || _imageBytes == null) {
      showMessage(
        context,
        'Add photo evidence before submitting.',
        error: true,
      );
      return;
    }
    if (_evidenceCheckError != null) {
      showMessage(context, _evidenceCheckError!, error: true);
      return;
    }

    setState(() => busy = true);
    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      _capturedPosition = position;
      await _reportService.createReport(
        category: category,
        severity: severity,
        description: description.text.trim(),
        latitude: position.latitude,
        longitude: position.longitude,
        imageBytes: _imageBytes,
        evidenceSource: _evidenceSource,
        evidenceValidation: _evidenceValidation,
      );

      if (mounted) {
        showMessage(context, 'Hazard submitted with status Pending Review.');
        Navigator.pop(context);
      }
    } catch (e, stack) {
      debugPrint('Hazard submission failed: $e\n$stack');
      if (mounted) {
        showMessage(
          context,
          friendlySafetyActionError(
            e,
            fallback:
                'Your report could not be submitted. Check your connection and try again.',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _captureLocation() async {
    if (!_capturingLocation && mounted) {
      setState(() {
        _capturingLocation = true;
        _locationError = null;
      });
    }
    try {
      final position = await _locationService.getCurrentPosition();
      if (mounted) {
        setState(() {
          _capturedPosition = position;
          _locationError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _capturedPosition = null;
          _locationError = friendlySafetyActionError(
            error,
            fallback:
                'Location could not be captured. Check location access and retry.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _capturingLocation = false);
    }
  }

  Future<void> _takePhoto([ImageSource source = ImageSource.camera]) async {
    if (_validatingImage || busy || _pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        image = picked;
        _evidenceSource = source == ImageSource.camera
            ? EvidenceSource.camera
            : EvidenceSource.gallery;
        _imageBytes = bytes;
        _evidenceCheckError = null;
      });
      await _checkEvidence();
    } catch (error, stack) {
      debugPrint('Hazard photo capture failed: $error\n$stack');
      if (mounted) {
        showMessage(
          context,
          'Could not open or read the camera photo. Check camera access and try again.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _checkEvidence() async {
    final bytes = _imageBytes;
    if (bytes == null || _validatingImage || busy) return;
    setState(() {
      _validatingImage = true;
      _evidenceValidation = null;
      _evidenceCheckError = null;
    });
    try {
      final validation = await _reportService.validateEvidence(
        imageBytes: bytes,
        evidenceSource: _evidenceSource,
      );
      if (mounted) {
        if (!validation.isValid) {
          setState(() {
            _evidenceValidation = validation;
            _evidenceCheckError =
                'Unable to use this image. Please choose another photo.';
          });
        } else {
          setState(() {
            _evidenceValidation = validation;
            _evidenceCheckError = null;
          });
        }
      }
    } catch (error, stack) {
      debugPrint('Hazard evidence check failed: $error\n$stack');
      if (mounted) {
        setState(() {
          _evidenceCheckError =
              'Unable to use this image. Please choose another photo.';
        });
      }
    } finally {
      if (mounted) setState(() => _validatingImage = false);
    }
  }

  void _removeEvidence() {
    if (_validatingImage || busy) return;
    setState(() {
      image = null;
      _imageBytes = null;
      _evidenceValidation = null;
      _evidenceCheckError = null;
      _validatingImage = false;
    });
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
                  const Text(
                    'Share a current photo and describe what travelers should avoid.',
                    style: TextStyle(
                      color: ExplorerColors.muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _LocationCaptureStatus(
                    loading: _capturingLocation,
                    captured: _capturedPosition != null,
                    error: _locationError,
                    onRetry: _captureLocation,
                  ),
                  const SizedBox(height: 16),
                  EvidencePickerCard(
                    imageBytes: _imageBytes,
                    validation: _evidenceValidation,
                    validating: _validatingImage,
                    checkError: _evidenceCheckError,
                    onRetry: _checkEvidence,
                    requiredEvidence: true,
                    evidenceSource: _evidenceSource,
                    onCamera: _takePhoto,
                    onGallery: () => _takePhoto(ImageSource.gallery),
                    enabled: !busy && !_pickingImage,
                    onRemove: _removeEvidence,
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
                          isExpanded: true,
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
                                      child: Text(
                                        value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: busy
                              ? null
                              : (value) => setState(() => category = value!),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Severity level',
                          style: TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SeveritySelector(
                          selected: severity,
                          onChanged: (v) {
                            if (!busy) setState(() => severity = v);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: description,
                          enabled: !busy,
                          onChanged: (_) {
                            if (_descriptionError != null) {
                              setState(() => _descriptionError = null);
                            }
                          },
                          maxLines: 5,
                          maxLength: 500,
                          decoration: InputDecoration(
                            errorText: _descriptionError,
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
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed:
                        busy ||
                            _pickingImage ||
                            _capturedPosition == null ||
                            _validatingImage ||
                            _evidenceValidation?.canSubmit != true
                        ? null
                        : submit,
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

// ---------------------------------------------------------------------------
// Severity selector — replaces the buggy ChoiceChip row.
// ---------------------------------------------------------------------------

class _SeveritySelector extends StatelessWidget {
  const _SeveritySelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: ['Low', 'Medium', 'High'].asMap().entries.map((entry) {
          final value = entry.value;
          final isSelected = selected == value;
          final color = switch (value) {
            'High' => ExplorerColors.danger,
            'Medium' => ExplorerColors.goldDark,
            _ => ExplorerColors.success,
          };
          final icon = switch (value) {
            'High' => Icons.crisis_alert,
            'Medium' => Icons.warning_amber_rounded,
            _ => Icons.check_circle_outline,
          };
          final desc = switch (value) {
            'High' => 'Immediate danger',
            'Medium' => 'Moderate risk',
            _ => 'Minor issue',
          };
          return Expanded(
            child: Padding(
              padding: EdgeInsets.zero,
              child: Semantics(
                button: true,
                selected: isSelected,
                label: '$value severity',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? color : ExplorerColors.subtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : ExplorerColors.border,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          icon,
                          color: isSelected ? Colors.white : color,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : ExplorerColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white70
                                : ExplorerColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location capture status widget
// ---------------------------------------------------------------------------

class _LocationCaptureStatus extends StatelessWidget {
  const _LocationCaptureStatus({
    required this.loading,
    required this.captured,
    required this.error,
    required this.onRetry,
  });

  final bool loading;
  final bool captured;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final color = captured
        ? ExplorerColors.success
        : error != null
        ? ExplorerColors.danger
        : ExplorerColors.navy;
    final background = captured
        ? ExplorerColors.successSoft
        : error != null
        ? ExplorerColors.dangerSoft
        : ExplorerColors.navySoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              captured
                  ? Icons.location_on_outlined
                  : Icons.location_off_outlined,
              color: color,
              size: 19,
            ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              loading
                  ? 'Capturing current location…'
                  : captured
                  ? 'Current location captured'
                  : error ?? 'Location is required for this report.',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!loading && !captured)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
