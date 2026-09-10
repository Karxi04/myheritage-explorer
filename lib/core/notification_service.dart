import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class SystemNotificationService {
  SystemNotificationService._();
  static final SystemNotificationService instance =
      SystemNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  ValueChanged<String?>? onNotificationPayload;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Timezone init exception: $e');
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
          onNotificationPayload?.call(response.payload);
        },
      );

      final launchDetails = await _notificationsPlugin
          .getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        onNotificationPayload?.call(
          launchDetails?.notificationResponse?.payload,
        );
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidImplementation?.requestNotificationsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Local notifications init error: $e');
    }
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'myheritage_alerts',
      'Trip Alerts & Reminders',
      channelDescription:
          'Notifications for upcoming itineraries, weather reminders and cultural task rewards.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Show notification error: $e');
    }
  }

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    if (!_isInitialized) await init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidImplementation?.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  Future<bool> showNearbyRewardNotification({
    required int id,
    required String title,
    required String body,
    required String voucherId,
  }) async {
    // In the background, the Firestore notification is delivered by FCM. A
    // second local presentation here would produce a duplicate phone banner.
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return false;
    }
    if (!_isInitialized) await init();
    if (!await areNotificationsEnabled()) {
      debugPrint(
        'Nearby reward notification skipped: phone notifications are disabled.',
      );
      return false;
    }

    const androidDetails = AndroidNotificationDetails(
      'myheritage_nearby_rewards',
      'Nearby rewards',
      channelDescription:
          'Alerts when an active voucher is available within the nearby reward area.',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.recommendation,
      showWhen: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
          macOS: darwinDetails,
        ),
        payload: 'voucher:$voucherId',
      );
      return true;
    } catch (error) {
      debugPrint('Nearby reward notification display failed: $error');
      return false;
    }
  }

  Future<void> scheduleTripReminder({
    required int id,
    required String title,
    required String body,
    required DateTime reminderTime,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    // If reminder time is in the past or now, do not fire an immediate duplicate reminder
    if (!reminderTime.isAfter(DateTime.now())) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'myheritage_trip_reminders',
      'Trip Pre-Departure Reminders',
      channelDescription:
          'Reminders scheduled before your Malaysian heritage trips.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      final scheduledTz = tz.TZDateTime.from(reminderTime, tz.local);
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledTz,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Schedule trip notification error: $e');
    }
  }

  Future<void> scheduleRewardExpiryReminder({
    required int id,
    required String voucherTitle,
    required String claimId,
    required DateTime reminderTime,
    required int daysRemaining,
  }) async {
    if (!_isInitialized) await init();
    if (!reminderTime.isAfter(DateTime.now())) return;

    const androidDetails = AndroidNotificationDetails(
      'myheritage_reward_expiry',
      'Reward Expiry Reminders',
      channelDescription: 'Reminders before claimed reward vouchers expire.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: 'Voucher expiring soon',
        body: daysRemaining == 1
            ? '$voucherTitle expires tomorrow.'
            : '$voucherTitle expires in $daysRemaining days.',
        scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: claimId.isEmpty ? 'voucher_wallet' : 'claim:$claimId',
      );
    } catch (e) {
      debugPrint('Schedule reward expiry notification error: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (_) {}
  }
}
