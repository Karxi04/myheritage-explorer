import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';
import 'core/app_theme.dart';
import 'core/push_notification_service.dart';
import 'firebase_options.dart';
import 'shared/shared_itinerary_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );

    // ============================================================
    // REGISTER PHONE FOR PUSH NOTIFICATIONS
    // ============================================================

    await PushNotificationService.initialize();
  }

  runApp(
    const MyHeritageApp(),
  );
}

class MyHeritageApp extends StatelessWidget {
  const MyHeritageApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyHeritage Explorer',
      theme: AppTheme.light,
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends StatelessWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context) {
    final shareId =
    Uri.base.queryParameters['share']?.trim();

    final encodedItinerary =
    Uri.base
        .queryParameters['itinerary']
        ?.trim();

    if (shareId != null &&
        shareId.isNotEmpty) {
      return SharedItineraryPage(
        shareId: shareId,
      );
    }

    if (encodedItinerary != null &&
        encodedItinerary.isNotEmpty) {
      return SharedItineraryPage(
        encodedItinerary:
        encodedItinerary,
      );
    }

    return const AuthGate();
  }
}