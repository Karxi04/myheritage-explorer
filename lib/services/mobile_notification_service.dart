import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/app_notification.dart';
import '../models/hazard_report.dart';

class MobileNotificationService {
  MobileNotificationService._();

  static final instance = MobileNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  ValueChanged<String>? onHazardOpened;
  String? pendingHazardPayload;

  void _handleTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null ||
        (!payload.startsWith('hazard:') && !payload.startsWith('review:'))) {
      return;
    }
    if (onHazardOpened == null) {
      pendingHazardPayload = payload;
    } else {
      onHazardOpened!(payload);
    }
  }

  void clearPendingPayload() {
    pendingHazardPayload = null;
  }

  Future<bool> areNotificationsEnabled() async {
    if (!_supportsMobileNotifications) return true;
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final enabled = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      return enabled ?? true;
    }
    return true;
  }

  bool _permissionRequested = false;
  int _nextId = DateTime.now().millisecondsSinceEpoch.remainder(1 << 30);

  bool get _supportsMobileNotifications =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (_initialized || !_supportsMobileNotifications) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_safety'),
      iOS: IOSInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _handleTap,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true &&
          launch?.notificationResponse != null) {
        _handleTap(launch!.notificationResponse!);
      }
      _initialized = true;
    } catch (error, stack) {
      debugPrint('Safety notifications unavailable: $error\n$stack');
    }
  }

  Future<void> requestPermissions() async {
    if (_permissionRequested || !_supportsMobileNotifications) return;
    _permissionRequested = true;
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> showStatusUpdate(AppNotification notification) async {
    if (!_supportsMobileNotifications) return;
    await initialize();
    final body = notification.message.trim().isEmpty
        ? 'Your hazard report status has changed.'
        : notification.message;
    final android = AndroidNotificationDetails(
      'hazard_status_updates',
      'Hazard status updates',
      channelDescription:
          'Notifications when an administrator updates a hazard report.',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
    );
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentSound: true,
      threadIdentifier: 'hazard_status_updates',
    );

    await _plugin.show(
      id: _notificationId(),
      title: notification.title,
      body: body,
      notificationDetails: NotificationDetails(android: android, iOS: darwin),
      payload: notification.hazardId == null
          ? null
          : 'hazard:${notification.hazardId}',
    );
  }

  Future<bool> showProximityAlert({
    required HazardReport report,
    required double distanceMeters,
  }) async {
    if (!_supportsMobileNotifications) return false;
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final enabled = await androidPlugin?.areNotificationsEnabled();
      if (enabled == false) {
        debugPrint(
          'Proximity alert skipped: notifications are disabled by user.',
        );
        return false;
      }
    }

    final distanceLabel = distanceMeters < 1000
        ? '${distanceMeters.round()} m'
        : '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    final body =
        '${report.category} (${report.severity}) is $distanceLabel '
        'away. Avoid the marked danger zone and review the safety details.';
    final android = AndroidNotificationDetails(
      'hazard_proximity_alerts',
      'Nearby danger-zone alerts',
      channelDescription:
          'Urgent alerts when a traveler approaches a verified hazard.',
      importance: Importance.max,
      priority: Priority.max,
      styleInformation: BigTextStyleInformation(body),
      visibility: NotificationVisibility.public,
    );
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentSound: true,
      threadIdentifier: 'hazard_proximity_alerts',
    );

    try {
      await _plugin.show(
        id: _notificationId(),
        title: 'Danger zone nearby',
        body: body,
        notificationDetails: NotificationDetails(android: android, iOS: darwin),
        payload: 'review:${report.id}',
      );
      return true;
    } catch (e) {
      debugPrint('Proximity alert notification display failed: $e');
      return false;
    }
  }

  int _notificationId() {
    _nextId = (_nextId + 1).remainder(1 << 30);
    return _nextId;
  }
}
