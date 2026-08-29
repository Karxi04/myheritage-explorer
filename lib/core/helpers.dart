import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : null,
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
