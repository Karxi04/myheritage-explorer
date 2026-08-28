import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'auth/auth_gate.dart';
import 'core/app_theme.dart';
import 'core/notification_service.dart';
import 'core/services.dart';
import 'firebase_options.dart';
import 'shared/shared_itinerary_page.dart';
import 'traveler/traveler_pages.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemNotificationService.instance.onNotificationPayload =
      _handleNotificationPayload;
  SystemNotificationService.instance.init();
  MalaysianPlannerSync.syncAllCuratedPlacesToFirestore();
  runApp(const MyHeritageApp());
}

void _handleNotificationPayload(String? payload) {
  final value = (payload ?? '').trim();
  if (value.isEmpty) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    Widget? destination;
    if (AppServices.auth.currentUser != null) {
      destination = switch (value) {
        'rewards' => const RewardsPage(),
        'voucher_wallet' => const VoucherWalletPage(),
        _ => null,
      };
    }
    final itineraryId = _itineraryIdFromNotificationPayload(value);
    if (destination == null && itineraryId.isNotEmpty) {
      destination = ItineraryDetailPage(itineraryId: itineraryId);
    }
    if (destination == null) return;

    navigator.push(MaterialPageRoute(builder: (_) => destination!));
  });
}

String _itineraryIdFromNotificationPayload(String? payload) {
  final value = (payload ?? '').trim();
  if (value.isEmpty) return '';
  if (value == 'rewards' || value == 'voucher_wallet') return '';
  if (value.startsWith('itinerary:')) {
    return value.substring('itinerary:'.length).trim();
  }
  if (value.contains(':')) return '';
  return value;
}

class MyHeritageApp extends StatelessWidget {
  const MyHeritageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
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
    final shareId = Uri.base.queryParameters['share']?.trim();
    final encodedItinerary = Uri.base.queryParameters['itinerary']?.trim();

    if (shareId != null && shareId.isNotEmpty) {
      return SharedItineraryPage(shareId: shareId);
    }

    // Backward compatibility for the previous long itinerary links.
    if (encodedItinerary != null && encodedItinerary.isNotEmpty) {
      return SharedItineraryPage(encodedItinerary: encodedItinerary);
    }

    return const AuthGate();
  }
}
