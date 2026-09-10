import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
    'Background FCM received: ${message.messageId}',
  );
}
class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  static final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  static final FlutterLocalNotificationsPlugin
  _localNotifications =
  FlutterLocalNotificationsPlugin();

  static StreamSubscription<User?>?
  _authSubscription;

  static StreamSubscription<String>?
  _tokenSubscription;

  static StreamSubscription<RemoteMessage>?
  _foregroundFcmSubscription;

  static StreamSubscription<RemoteMessage>?
  _openedFcmSubscription;

  static StreamSubscription<
      QuerySnapshot<Map<String, dynamic>>>?
  _firestoreNotificationSubscription;

  static bool _initialized = false;

  static void Function(
      Map<String, dynamic> data,
      )? _tapHandler;

  static Map<String, dynamic>?
  _pendingLaunchNotification;

  // Prevent duplicate banners when Firestore and FCM
  // deliver the same notification while the app is open.
  static final Set<String>
  _shownNotificationIds = <String>{};

  // ============================================================
  // ANDROID CHANNELS
  // ============================================================

  static const AndroidNotificationChannel
  _chatChannel =
  AndroidNotificationChannel(
    'chat_heads_up_v6',
    'Chat Messages',
    description:
    'Group chat, private chat and location notifications.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel
  _sosChannel =
  AndroidNotificationChannel(
    'sos_heads_up_v6',
    'Emergency SOS Alerts',
    description:
    'Urgent emergency alerts from travel companions.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel
  _generalChannel =
  AndroidNotificationChannel(
    'general_heads_up_v6',
    'General Notifications',
    description:
    'General MyHeritage Explorer notifications.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static bool get _supportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform ==
        TargetPlatform.android ||
        defaultTargetPlatform ==
            TargetPlatform.iOS;
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  static Future<void> initialize({
    required void Function(
        Map<String, dynamic> data,
        )
    onNotificationTap,
  }) async {
    if (_initialized ||
        !_supportedPlatform) {
      return;
    }

    _initialized = true;
    _tapHandler = onNotificationTap;

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    // ==========================================================
    // LOCAL NOTIFICATIONS
    // ==========================================================

    const androidInitialization =
    AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosInitialization =
    DarwinInitializationSettings();

    const initializationSettings =
    InitializationSettings(
      android: androidInitialization,
      iOS: iosInitialization,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse:
          (
          NotificationResponse response,
          ) {
        final payload = response.payload;

        if (payload == null ||
            payload.trim().isEmpty) {
          return;
        }

        try {
          final decoded =
          jsonDecode(payload);

          if (decoded is Map) {
            _tapHandler?.call(
              Map<String, dynamic>.from(
                decoded,
              ),
            );
          }
        } catch (error) {
          debugPrint(
            'Notification payload error: $error',
          );
        }
      },
    );

    // If a local notification launched the app.
    final localLaunchDetails =
    await _localNotifications
        .getNotificationAppLaunchDetails();

    if (localLaunchDetails
        ?.didNotificationLaunchApp ==
        true &&
        localLaunchDetails
            ?.notificationResponse
            ?.payload !=
            null) {
      try {
        final decoded =
        jsonDecode(
          localLaunchDetails!
              .notificationResponse!
              .payload!,
        );

        if (decoded is Map) {
          _pendingLaunchNotification =
          Map<String, dynamic>.from(
            decoded,
          );
        }
      } catch (_) {}
    }

    // ==========================================================
    // CREATE ANDROID CHANNELS
    // ==========================================================

    final androidPlugin =
    _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin
          .createNotificationChannel(
        _chatChannel,
      );

      await androidPlugin
          .createNotificationChannel(
        _sosChannel,
      );

      await androidPlugin
          .createNotificationChannel(
        _generalChannel,
      );

      await androidPlugin
          .requestNotificationsPermission();
    }

    // ==========================================================
    // FCM PERMISSION
    // ==========================================================

    final permission =
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint(
      'FCM authorization: '
          '${permission.authorizationStatus}',
    );

    await _messaging
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // ==========================================================
    // FCM WHILE APP IS OPEN
    // ==========================================================

    _foregroundFcmSubscription =
        FirebaseMessaging.onMessage.listen(
              (RemoteMessage message) async {
            final notificationId =
                '${message.data['notificationId'] ?? message.messageId ?? ''}';

            if (!_rememberNotification(
              notificationId,
            )) {
              return;
            }

            await _showLocalNotification(
              notificationId:
              notificationId,
              data:
              message.data,
              remoteNotification:
              message.notification,
            );
          },
          onError: (error) {
            debugPrint(
              'Foreground FCM error: $error',
            );
          },
        );

    // ==========================================================
    // USER TAPS FCM WHILE APP IS IN BACKGROUND
    // ==========================================================

    _openedFcmSubscription =
        FirebaseMessaging
            .onMessageOpenedApp
            .listen(
              (message) {
            _tapHandler?.call(
              message.data,
            );
          },
        );

    // ==========================================================
    // USER TAPS FCM WHEN APP WAS TERMINATED
    // ==========================================================

    final initialRemoteMessage =
    await _messaging
        .getInitialMessage();

    if (initialRemoteMessage != null) {
      _pendingLaunchNotification =
          initialRemoteMessage.data;
    }

    // ==========================================================
    // LOGIN / LOGOUT
    // ==========================================================

    _authSubscription =
        FirebaseAuth.instance
            .authStateChanges()
            .listen(
              (User? user) async {
            if (user == null) {
              await _stopFirestoreListener();

              // Invalidate the token used by the previous
              // account on this device.
              try {
                await _messaging.deleteToken();
              } catch (_) {}

              return;
            }

            debugPrint(
              'Push service user: ${user.uid}',
            );

            await _registerCurrentToken(
              user.uid,
            );

            await _startFirestoreListener(
              user.uid,
            );
          },
          onError: (error) {
            debugPrint(
              'Push auth listener error: $error',
            );
          },
        );

    // ==========================================================
    // TOKEN REFRESH
    // ==========================================================

    _tokenSubscription =
        _messaging
            .onTokenRefresh
            .listen(
              (String token) async {
            final user =
                FirebaseAuth
                    .instance
                    .currentUser;

            if (user == null) {
              return;
            }

            await _saveToken(
              user.uid,
              token,
            );
          },
          onError: (error) {
            debugPrint(
              'FCM token refresh error: $error',
            );
          },
        );
  }

  // ============================================================
  // FCM TOKEN REGISTRATION
  // ============================================================

  static Future<void>
  _registerCurrentToken(
      String uid,
      ) async {
    try {
      final token =
      await _messaging.getToken();

      if (token == null ||
          token.trim().isEmpty) {
        debugPrint(
          'Firebase Messaging returned no FCM token.',
        );

        return;
      }

      debugPrint(
        'FCM token received for $uid',
      );

      await _saveToken(
        uid,
        token,
      );
    } catch (error) {
      debugPrint(
        'Unable to obtain FCM token: $error',
      );
    }
  }

  static Future<void> _saveToken(
      String uid,
      String token,
      ) async {
    try {
      final encodedToken =
      base64Url
          .encode(
        utf8.encode(token),
      )
          .replaceAll(
        '=',
        '',
      );

      final documentId =
          '${uid}_$encodedToken';

      await _db
          .collection(
        'push_tokens',
      )
          .doc(
        documentId,
      )
          .set(
        {
          'userId':
          uid,

          'token':
          token,

          'platform':
          defaultTargetPlatform.name,

          'enabled':
          true,

          'updatedAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      debugPrint(
        'PUSH TOKEN SAVED: $uid',
      );
    } catch (error) {
      debugPrint(
        'ERROR saving FCM token: $error',
      );
    }
  }

  static Future<void>
  registerCurrentDevice() async {
    final user =
        FirebaseAuth
            .instance
            .currentUser;

    if (user == null) {
      return;
    }

    await _registerCurrentToken(
      user.uid,
    );
  }

  // ============================================================
  // FIRESTORE FOREGROUND NOTIFICATION LISTENER
  //
  // This keeps phone notifications working while the application
  // is open, even if the local Spark notification server is not
  // running.
  // ============================================================

  static Future<void>
  _startFirestoreListener(
      String uid,
      ) async {
    await _firestoreNotificationSubscription
        ?.cancel();

    _shownNotificationIds.clear();

    var initialSnapshot = true;

    _firestoreNotificationSubscription =
        _db
            .collection(
          'notifications',
        )
            .where(
          'userId',
          isEqualTo: uid,
        )
            .limit(25)
            .snapshots()
            .listen(
              (snapshot) async {
            if (initialSnapshot) {
              // Existing notifications remain visible in the
              // in-app Notifications page, but do not show
              // hundreds of phone banners when the app launches.
              for (final document
              in snapshot.docs) {
                _rememberNotification(
                  document.id,
                );
              }

              initialSnapshot = false;
              return;
            }

            for (final change
            in snapshot.docChanges) {
              if (change.type !=
                  DocumentChangeType.added) {
                continue;
              }

              final document =
                  change.doc;

              final data =
              document.data();

              if (data == null) {
                continue;
              }

              if ('${data['userId'] ?? ''}' !=
                  uid) {
                continue;
              }

              // Firestore local banners are only used when
              // the app is actually visible.
              //
              // Background/terminated notifications are handled
              // by real FCM sent by our Spark local server.
              if (WidgetsBinding
                  .instance
                  .lifecycleState !=
                  AppLifecycleState.resumed) {
                continue;
              }

              if (!_rememberNotification(
                document.id,
              )) {
                continue;
              }

              await _showLocalNotification(
                notificationId:
                document.id,
                data:
                data,
              );
            }
          },
          onError: (error) {
            debugPrint(
              'Notification Firestore listener error: '
                  '$error',
            );
          },
        );
  }

  static Future<void>
  _stopFirestoreListener() async {
    await _firestoreNotificationSubscription
        ?.cancel();

    _firestoreNotificationSubscription =
    null;

    _shownNotificationIds.clear();
  }

  // ============================================================
  // DUPLICATE PROTECTION
  // ============================================================

  static bool _rememberNotification(
      String notificationId,
      ) {
    if (notificationId.isEmpty) {
      return true;
    }

    if (_shownNotificationIds
        .contains(
      notificationId,
    )) {
      return false;
    }

    _shownNotificationIds.add(
      notificationId,
    );

    if (_shownNotificationIds.length >
        500) {
      _shownNotificationIds.remove(
        _shownNotificationIds.first,
      );
    }

    return true;
  }

  /// Prevents a nearby reward alert that was already presented directly from
  /// being shown again when its Firestore document or foreground FCM arrives.
  static void markNotificationAsHandled(String notificationId) {
    _rememberNotification(notificationId);
  }

  // ============================================================
  // LOCAL HEADS-UP NOTIFICATION
  // ============================================================

  static Future<void>
  _showLocalNotification({
    required String notificationId,
    required Map<String, dynamic> data,
    RemoteNotification? remoteNotification,
  }) async {
    final type =
    '${data['type'] ?? 'general'}'
        .trim()
        .toLowerCase();

    final title =
        remoteNotification?.title ??
            '${data['title'] ?? 'MyHeritage Explorer'}';

    final body =
        remoteNotification?.body ??
            '${data['message'] ?? 'You have a new notification.'}';

    final isSos =
        type == 'sos';

    final isChat =
        type == 'group_message' ||
            type == 'private_message' ||
            type == 'private_chat' ||
            type ==
                'private_location_request' ||
            type ==
                'private_location_shared';

    final AndroidNotificationChannel channel;

    if (isSos) {
      channel = _sosChannel;
    } else if (isChat) {
      channel = _chatChannel;
    } else {
      channel = _generalChannel;
    }

    final androidDetails =
    AndroidNotificationDetails(
      channel.id,
      channel.name,

      channelDescription:
      channel.description,

      importance:
      isSos
          ? Importance.max
          : Importance.high,

      priority:
      isSos
          ? Priority.max
          : Priority.high,

      playSound:
      true,

      enableVibration:
      true,

      visibility:
      NotificationVisibility.public,

      category:
      isSos
          ? AndroidNotificationCategory
          .alarm
          : AndroidNotificationCategory
          .message,

      autoCancel:
      true,

      showWhen:
      true,
    );

    const iosDetails =
    DarwinNotificationDetails(
      presentAlert:
      true,
      presentBadge:
      true,
      presentSound:
      true,
    );

    final payload =
    jsonEncode({
      'notificationId':
      notificationId,

      'type':
      type,

      'referenceId':
      '${data['referenceId'] ?? ''}',

      'groupId':
      '${data['groupId'] ?? ''}',

      'chatId':
      '${data['chatId'] ?? ''}',
    });

    await _localNotifications.show(
      id: DateTime.now()
          .microsecondsSinceEpoch
          .remainder(
        2147483647,
      ),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android:
        androidDetails,
        iOS:
        iosDetails,
      ),
      payload:
      payload,
    );

    debugPrint(
      'Phone notification shown: '
          '$type / $title',
    );
  }

  // Opens a notification that launched the app after the navigator is ready.
  static Future<void> handlePendingInitialNotification() async {
    final pending = _pendingLaunchNotification;
    if (pending == null) return;

    _pendingLaunchNotification = null;
    _tapHandler?.call(pending);
  }

  static Future<void> dispose() async {
    await _authSubscription
        ?.cancel();

    await _tokenSubscription
        ?.cancel();

    await _foregroundFcmSubscription
        ?.cancel();

    await _openedFcmSubscription
        ?.cancel();

    await _firestoreNotificationSubscription
        ?.cancel();

    _initialized = false;

    _shownNotificationIds.clear();
  }
}
