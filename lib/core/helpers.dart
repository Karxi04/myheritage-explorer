import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  // Matches 1x-xxxxxxx or 1x-xxxxxxxx
  return RegExp(r'^(1[0-46-9]-?[0-9]{7,8}|15-?[0-9]{7})$').hasMatch(phone.replaceAll(' ', '').replaceAll('-', ''));
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

