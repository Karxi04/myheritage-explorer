import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/explorer_ui.dart';
import '../models/evidence_validation_result.dart';
import 'safety_image_viewer.dart';

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
    this.evidenceSource,
    this.title,
    this.subtitle,
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
  final String? evidenceSource;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ExplorerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExplorerSectionTitle(
            title ??
                (requiredEvidence
                    ? 'Photo Evidence *'
                    : 'Optional Evidence Photo'),
            subtitle:
                subtitle ??
                (requiredEvidence
                    ? 'Add a clear, current photo of the hazard.'
                    : 'An optional current photo helps the administrator review your update.'),
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
                child: ExpandableEvidenceImage(
                  imageProvider: MemoryImage(imageBytes!),
                  title: 'Captured Photo Evidence',
                  subtitle: 'Preview of selected photo',
                  tooltip: 'Tap to enlarge photo preview',
                  child: Image.memory(
                    imageBytes!,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Text('Photo preview unavailable')),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final source =
                    evidenceSource ??
                    validation?.evidenceSource ??
                    EvidenceSource.camera;
                final isCamera = source == EvidenceSource.camera;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ExplorerColors.navySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCamera
                            ? Icons.camera_alt_outlined
                            : Icons.photo_library_outlined,
                        size: 15,
                        color: ExplorerColors.navy,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isCamera
                              ? 'Captured in App'
                              : 'Selected from Gallery',
                          style: const TextStyle(
                            color: ExplorerColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (checkError != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ExplorerColors.dangerSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: ExplorerColors.danger,
                      size: 20,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        checkError!,
                        style: const TextStyle(
                          color: ExplorerColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onRetry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry Photo Check'),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: validating || !enabled ? null : onCamera,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Retake Photo'),
                ),
                if (onGallery != null)
                  OutlinedButton.icon(
                    onPressed: validating || !enabled ? null : onGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Choose from Gallery'),
                  ),
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
