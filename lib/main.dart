import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth/auth_gate.dart';
import 'core/app_theme.dart';
import 'core/notification_service.dart';
import 'firebase_options.dart';
import 'shared/shared_itinerary_page.dart';
import 'traveler/traveler_pages.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
const _deepLinkMethodChannel = MethodChannel('myheritage_explorer/deep_links');
const _deepLinkEventChannel = EventChannel('myheritage_explorer/deep_link_events');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemNotificationService.instance.onNotificationPayload =
      _handleNotificationPayload;
  SystemNotificationService.instance.init();
  MalaysianPlannerSync.syncAllCuratedPlacesToFirestore();
  runApp(const MyHeritageApp());
}

void _handleNotificationPayload(String? payload) {
  final itineraryId = _itineraryIdFromNotificationPayload(payload);
  if (itineraryId.isEmpty) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ItineraryDetailPage(itineraryId: itineraryId),
      ),
    );
  });
}

String _itineraryIdFromNotificationPayload(String? payload) {
  final value = (payload ?? '').trim();
  if (value.isEmpty) return '';
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
  final queryShare =
      (uri.queryParameters['share'] ?? uri.queryParameters['id'])?.trim();
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
    if (uri == null) return null;
    return _sharedLinkTargetFromUri(uri);
  }

  void _handleIncomingDeepLink(Object? value) {
    final target = _targetFromRawLink(value);
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_initialDeepLinkTarget != null) {
      return _initialDeepLinkTarget!.page();
    }

    return const AuthGate();
  }
}
