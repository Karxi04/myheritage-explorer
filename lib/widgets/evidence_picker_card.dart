import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/explorer_ui.dart';
import '../models/evidence_validation_result.dart';

/// Shared photo selection and validation feedback for Safety reports and votes.
class EvidencePickerCard extends StatelessWidget {
  const EvidencePickerCard({
    super.key,
    required this.imageBytes,
    required this.validation,
    required this.validating,
    required this.onCamera,
    required this.onRemove,
    this.checkError,
    this.onRetry,
    this.requiredEvidence = false,
    this.onGallery,
    this.enabled = true,
  });

  final Uint8List? imageBytes;
  final EvidenceValidationResult? validation;
  final bool validating;
  final VoidCallback onCamera;
  final VoidCallback onRemove;
  final String? checkError;
  final VoidCallback? onRetry;
  final bool requiredEvidence;
  final VoidCallback? onGallery;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExplorerSectionTitle(
            requiredEvidence ? 'Photo Evidence *' : 'Add Current Photo',
            subtitle: requiredEvidence
                ? 'Add a clear, current photo of the hazard.'
                : 'An optional current photo helps the administrator review your update.',
          ),
          const SizedBox(height: 14),
          if (imageBytes == null)
            _EmptyState(
              onCamera: enabled ? onCamera : null,
              onGallery: enabled ? onGallery : null,
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.memory(
                  imageBytes!,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Text('Photo preview unavailable')),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (validating)
              const _ValidationMessage.loading()
            else if (checkError != null)
              _ValidationMessage.error(checkError!)
            else if (validation != null)
              _ValidationMessage.result(validation!),
            if (!validating && checkError != null && onRetry != null)
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry Photo Check'),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: validating || !enabled ? null : onCamera,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Retake Photo'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: validating || !enabled ? null : onRemove,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCamera, this.onGallery});
  final VoidCallback? onCamera;
  final VoidCallback? onGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: ExplorerColors.subtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ExplorerColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: ExplorerColors.navySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: ExplorerColors.navy,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Take a photo of the current scene',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ExplorerColors.navy,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Show the hazard and enough of its surroundings to identify the scene.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ExplorerColors.muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCamera,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Take Photo'),
          ),
          if (onGallery != null)
            TextButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
            ),
        ],
      ),
    );
  }
}

class _ValidationMessage extends StatelessWidget {
  const _ValidationMessage.loading()
    : result = null,
      loading = true,
      errorMessage = null;

  const _ValidationMessage.result(this.result)
    : loading = false,
      errorMessage = null;

  const _ValidationMessage.error(this.errorMessage)
    : result = null,
      loading = false;

  final EvidenceValidationResult? result;
  final bool loading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final validation = result;
    final isProblem =
        errorMessage != null || (validation != null && !validation.canSubmit);
    final isWarning =
        validation != null &&
        validation.validationLevel == EvidenceValidationLevel.lowQuality;
    final color = isProblem
        ? ExplorerColors.danger
        : isWarning
        ? ExplorerColors.goldDark
        : ExplorerColors.success;
    final background = isProblem
        ? ExplorerColors.dangerSoft
        : isWarning
        ? ExplorerColors.warningSoft
        : ExplorerColors.successSoft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: loading ? ExplorerColors.navySoft : background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              isProblem
                  ? Icons.error_outline_rounded
                  : isWarning
                  ? Icons.info_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: color,
              size: 20,
            ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading
                      ? 'Checking photo quality…'
                      : errorMessage != null
                      ? 'Photo check could not finish'
                      : validation!.touristTitle,
                  style: TextStyle(
                    color: loading ? ExplorerColors.navy : color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!loading) ...[
                  const SizedBox(height: 3),
                  Text(
                    errorMessage ?? validation!.touristMessage,
                    style: const TextStyle(
                      color: ExplorerColors.text,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
