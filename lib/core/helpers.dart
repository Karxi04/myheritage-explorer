import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

String randomCode([int length = 6]) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}

String randomToken([int length = 28]) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}

String randomNumericCode([int length = 6]) {
  final random = Random.secure();
  return List.generate(length, (_) => random.nextInt(10)).join();
}

String expiryCountdownLabel(DateTime? expiry, {DateTime? now}) {
  if (expiry == null) return 'No expiry date';
  final remaining = expiry.difference(now ?? DateTime.now());
  if (remaining <= Duration.zero) return 'Expired';
  if (remaining.inDays >= 2) return 'Expires in ${remaining.inDays} days';
  if (remaining.inDays == 1) return 'Expires tomorrow';
  if (remaining.inHours >= 1) return 'Expires in ${remaining.inHours} hours';
  final minutes = remaining.inMinutes.clamp(1, 59);
  return 'Expires in $minutes minutes';
}

int stableNotificationId(String value, int suffix) {
  var hash = 17;
  for (final unit in value.codeUnits) {
    hash = (hash * 37 + unit) & 0x3fffffff;
  }
  return ((hash * 10 + suffix) & 0x7fffffff);
}

DateTime? asDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Future<Position> determinePosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('Location services are disabled.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw Exception('Location permission was not granted.');
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );
}

String cleanDisplayText(Object? value) {
  var text = '${value ?? ''}';

  const replacements = <String, String>{
    'â€¢': ' - ',
    'â€˘': ' - ',
    'â€¯': ' ',
    'â€“': '-',
    'â€”': '-',
    'â€˜': "'",
    'â€™': "'",
    'â€œ': '"',
    'â€': '"',
    'Â': '',
    '�': '',
    '•': ' - ',
  };

  for (final entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }

  return text
      .replaceAll(RegExp(r'\s+-\s+'), ' - ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        maxLines: 5,
        overflow: TextOverflow.visible,
      ),
      backgroundColor: error ? Colors.red.shade700 : null,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showGlobalNotice({
  required String title,
  required String message,
  String buttonText = 'OK',
  VoidCallback? onConfirm,
}) {
  final context = appNavigatorKey.currentContext;
  if (context == null) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            if (onConfirm != null) onConfirm();
          },
          child: Text(buttonText),
        ),
      ],
    ),
  );
}

Widget emptyState(String title, [String? subtitle]) => Center(
  child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.inbox_outlined, size: 54),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ],
    ),
  ),
);

Future<String?> requestPassword(
  BuildContext context, {
  String title = 'Confirm your password',
}) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        obscureText: true,
        obscuringCharacter: '*',
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Current password'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

Future<bool> confirmDeletionKeyword(BuildContext context) async {
  final controller = TextEditingController();
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Request account deletion?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Type DELETE to deactivate the account and submit a deletion request.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Confirmation keyword',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim() == 'DELETE'),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;
}

bool isValidEmail(String email) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
}

String cleanName(String name) {
  return name.trim().replaceAll(RegExp(r'[^a-zA-Z\s]'), '').replaceAll(RegExp(r'\s+'), ' ');
}

bool isValidName(String name) {
  final cleaned = cleanName(name);
  return cleaned.isNotEmpty && RegExp(r'^[a-zA-Z\s]+$').hasMatch(cleaned);
}

bool isValidMalaysianPhone(String phone) {
  var clean = phone.replaceAll(' ', '').replaceAll('-', '').replaceAll('+', '');
  if (clean.startsWith('60')) {
    clean = clean.substring(2);
  } else if (clean.startsWith('0')) {
    clean = clean.substring(1);
  }
  return RegExp(r'^[0-9]{7,10}$').hasMatch(clean);
}

String? validatePassword(String password) {
  if (password.length < 8) {
    return 'Password must be at least 8 characters long.';
  }
  if (!password.contains(RegExp(r'[A-Z]'))) {
    return 'Password must contain at least one uppercase letter.';
  }
  if (!password.contains(RegExp(r'[a-z]'))) {
    return 'Password must contain at least one lowercase letter.';
  }
  if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>\-_+=~`[\]\\;/]'))) {
    return 'Password must contain at least one special character.';
  }
  return null;
}

Future<void> showReportDialog(
  BuildContext context, {
  required String targetId,
  required String targetName,
  required String targetType,
  bool popOnSuccess = true,
}) async {
  String selectedNature = 'Inappropriate Content / Behavior';
  final descriptionController = TextEditingController();
  bool submitting = false;

  final categories = [
    'Inappropriate Content / Behavior',
    'Spam or Fraudulent Activity',
    'Fake or Misleading Information',
    'Harassment or Abuse',
    'Other',
  ];

  final parentContext = context;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogStateContext, setDialogState) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.flag_outlined, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Report $targetType',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reporting: $targetName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nature of Report',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedNature,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: categories
                      .map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat, style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedNature = val);
                    }
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'Report Description',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Please provide details explaining the issue...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: submitting
                  ? null
                  : () async {
                      final desc = descriptionController.text.trim();
                      if (desc.isEmpty) {
                        showMessage(dialogStateContext, 'Please enter a description for the report.', error: true);
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        await FirebaseFirestore.instance.collection('user_reports').add({
                          'reporterId': user?.uid ?? '',
                          'reporterName': user?.displayName ?? user?.email ?? 'Traveler',
                          'reportedId': targetId,
                          'reportedName': targetName,
                          'reportedType': targetType,
                          'nature': selectedNature,
                          'description': desc,
                          'status': 'unresolved',
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (parentContext.mounted) {
                          showMessage(
                            parentContext,
                            'Report submitted successfully. Administrators will review this report.',
                          );
                          if (popOnSuccess && Navigator.canPop(parentContext)) {
                            Navigator.pop(parentContext);
                          }
                        }
                      } catch (e) {
                        if (dialogStateContext.mounted) {
                          showMessage(dialogStateContext, 'Failed to submit report: $e', error: true);
                          setDialogState(() => submitting = false);
                        }
                      }
                    },
              icon: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_outlined, size: 18),
              label: Text(submitting ? 'Submitting...' : 'Submit Report'),
            ),
          ],
        );
      },
    ),
  );
  descriptionController.dispose();
}

