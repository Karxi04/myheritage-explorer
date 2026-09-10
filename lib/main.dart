import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';

import 'auth/auth_gate.dart';
import 'core/app_theme.dart';
import 'core/notification_service.dart';
import 'core/push_notification_service.dart';
import 'core/services.dart';
import 'firebase_options.dart';
import 'services/background_alert_worker.dart';
import 'services/mobile_notification_service.dart';
import 'shared/shared_itinerary_page.dart';
import 'traveler/traveler_pages.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
String? _pendingNotificationPayload;
bool _openingNotificationDestination = false;

const _deepLinkMethodChannel = MethodChannel('myheritage_explorer/deep_links');
const _deepLinkEventChannel = EventChannel(
  'myheritage_explorer/deep_link_events',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );

    await PushNotificationService.initialize(
      onNotificationTap: (Map<String, dynamic> data) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navigator = appNavigatorKey.currentState;
          if (navigator == null) return;

          final destination = _notificationDestination(data);

          navigator.push(MaterialPageRoute(builder: (_) => destination));
        });
      },
    );
  }

  await MobileNotificationService.instance.initialize();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await Workmanager().initialize(backgroundAlertDispatcher);
      await registerBackgroundSafetyWorker();
    } catch (error) {
      debugPrint('Background safety worker initialization failed: $error');
    }
  }

  SystemNotificationService.instance.onNotificationPayload =
      _handleNotificationPayload;
  await SystemNotificationService.instance.init();

  // Curated Firestore data is seeded by an explicit admin/development action.
  // Re-syncing it on every app launch exhausts shared read and write quota.

  runApp(const MyHeritageApp());

  AppServices.auth.authStateChanges().listen((user) {
    if (user != null) _openPendingNotificationDestination();
  });

  if (!kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PushNotificationService.handlePendingInitialNotification();
    });
  }
}

Widget _notificationDestination(Map<String, dynamic> data) {
  final type = '${data['type'] ?? ''}'.trim().toLowerCase();
  final referenceId = '${data['referenceId'] ?? data['voucherId'] ?? ''}'
      .trim();

  return switch (type) {
    'voucher_nearby' ||
    'nearby_voucher' ||
    'nearby_reward' ||
    'voucher_nearby_digest' =>
      referenceId.isEmpty
          ? const NearbyRewardsPage()
          : VoucherDetailPage(voucherId: referenceId),
    'voucher_claimed' || 'voucher_redeemed' => VoucherWalletPage(
      focusClaimId: referenceId.isEmpty ? null : referenceId,
    ),
    _ => const NotificationsPage(),
  };
}

void _handleNotificationPayload(String? payload) {
  final value = (payload ?? '').trim();
  if (value.isEmpty) return;
  _pendingNotificationPayload = value;
  _openPendingNotificationDestination();
}

void _openPendingNotificationDestination() {
  if (_openingNotificationDestination) return;
  _openingNotificationDestination = true;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final navigator = appNavigatorKey.currentState;
    final value = (_pendingNotificationPayload ?? '').trim();
    if (navigator == null ||
        value.isEmpty ||
        AppServices.auth.currentUser == null) {
      _openingNotificationDestination = false;
      return;
    }

    try {
      final destination = await _notificationPayloadDestination(value);
      if (_pendingNotificationPayload == value) {
        _pendingNotificationPayload = null;
      }
      if (navigator.mounted) {
        navigator.push(MaterialPageRoute(builder: (_) => destination));
      }
    } finally {
      _openingNotificationDestination = false;
    }
  });
}

Future<Widget> _notificationPayloadDestination(String value) async {
  if (value == 'rewards') return const RewardsPage();
  if (value == 'voucher_wallet') return const VoucherWalletPage();
  if (value == 'nearby_rewards') return const NearbyRewardsPage();

  for (final prefix in const [
    'reward:',
    'voucher:',
    'voucher_nearby:',
    'nearby_reward:',
  ]) {
    if (value.startsWith(prefix)) {
      final voucherId = value.substring(prefix.length).trim();
      return voucherId.isEmpty
          ? const NearbyRewardsPage()
          : VoucherDetailPage(voucherId: voucherId);
    }
  }

  if (value.startsWith('claim:')) {
    final claimId = value.substring('claim:'.length).trim();
    return VoucherWalletPage(focusClaimId: claimId.isEmpty ? null : claimId);
  }

  if (value.startsWith('itinerary:')) {
    final itineraryId = value.substring('itinerary:'.length).trim();
    return itineraryId.isEmpty
        ? const NotificationsPage()
        : ItineraryDetailPage(itineraryId: itineraryId);
  }

  // Older notification builds stored only a raw document ID. Resolve the
  // document type before navigating so a voucher can never be mistaken for an
  // itinerary.
  try {
    final voucher = await AppServices.db
        .collection('vouchers')
        .doc(value)
        .get();
    if (voucher.exists) return VoucherDetailPage(voucherId: value);

    final itinerary = await AppServices.db
        .collection('itineraries')
        .doc(value)
        .get();
    if (itinerary.exists) return ItineraryDetailPage(itineraryId: value);
  } catch (_) {
    // The notifications page is the safe fallback when the legacy ID cannot be
    // resolved, including while offline.
  }
  return const NotificationsPage();
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

class _SharedLinkTarget {
  const _SharedLinkTarget({this.shareId, this.encodedItinerary})
    : assert(shareId != null || encodedItinerary != null);

  final String? shareId;
  final String? encodedItinerary;

  Widget page() {
    final id = shareId?.trim();
    if (id != null && id.isNotEmpty) {
      return SharedItineraryPage(shareId: id);
    }
    return SharedItineraryPage(encodedItinerary: encodedItinerary!.trim());
  }
}

_SharedLinkTarget? _sharedLinkTargetFromUri(Uri uri) {
  final queryShare = (uri.queryParameters['share'] ?? uri.queryParameters['id'])
      ?.trim();
  if (queryShare != null && queryShare.isNotEmpty) {
    return _SharedLinkTarget(shareId: queryShare);
  }

  final encodedItinerary = uri.queryParameters['itinerary']?.trim();
  if (encodedItinerary != null && encodedItinerary.isNotEmpty) {
    return _SharedLinkTarget(encodedItinerary: encodedItinerary);
  }

  final segments = uri.pathSegments
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList();
  final shareIndex = segments.indexWhere(
    (segment) => segment == 'share' || segment == 'shared-itinerary',
  );
  if (shareIndex >= 0 && shareIndex + 1 < segments.length) {
    return _SharedLinkTarget(shareId: segments[shareIndex + 1]);
  }

  if (uri.scheme == 'myheritage' &&
      (uri.host == 'shared-itinerary' || uri.host == 'share') &&
      segments.isNotEmpty) {
    return _SharedLinkTarget(shareId: segments.first);
  }

  return null;
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  StreamSubscription<dynamic>? _deepLinkSubscription;
  _SharedLinkTarget? _initialDeepLinkTarget;
  bool _checkedInitialDeepLink = kIsWeb;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _loadInitialDeepLink();
      _deepLinkSubscription = _deepLinkEventChannel
          .receiveBroadcastStream()
          .listen(_handleIncomingDeepLink, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialDeepLink() async {
    try {
      final value = await _deepLinkMethodChannel.invokeMethod<String>(
        'initialLink',
      );
      final target = _targetFromRawLink(value);
      if (!mounted) return;
      setState(() {
        _initialDeepLinkTarget = target;
        _checkedInitialDeepLink = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkedInitialDeepLink = true);
    }
  }

  _SharedLinkTarget? _targetFromRawLink(Object? value) {
    final raw = '${value ?? ''}'.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    return uri == null ? null : _sharedLinkTargetFromUri(uri);
  }

  void _handleIncomingDeepLink(Object? value) {
    final raw = '${value ?? ''}'.trim();
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;

    // Handle Firebase Auth Action Links (e.g. recoverEmail)
    if (uri.path.contains('/__/auth/action') ||
        uri.queryParameters.containsKey('oobCode')) {
      AppServices.handleAuthActionLink(uri);
      return;
    }

    final target = _sharedLinkTargetFromUri(uri);
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;
      navigator.push(MaterialPageRoute(builder: (_) => target.page()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final browserTarget = _sharedLinkTargetFromUri(Uri.base);
    if (browserTarget != null) return browserTarget.page();

    if (!_checkedInitialDeepLink) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_initialDeepLinkTarget != null) {
      return _initialDeepLinkTarget!.page();
    }

    return const AuthGate();
  }
}
