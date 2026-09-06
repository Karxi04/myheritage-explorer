import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  static final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  static StreamSubscription<User?>? _authSubscription;
  static StreamSubscription<String>? _tokenSubscription;

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (kIsWeb) {
      return;
    }

    _initialized = true;

    // ============================================================
    // ASK FOR NOTIFICATION PERMISSION
    // ============================================================

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'Notification permission: '
          '${settings.authorizationStatus}',
    );

    // ============================================================
    // USER LOGIN LISTENER
    // ============================================================

    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(
              (user) async {
            if (user == null) {
              debugPrint(
                'No user signed in. FCM token not registered.',
              );

              return;
            }

            debugPrint(
              'User signed in: ${user.uid}',
            );

            await _registerToken(
              user.uid,
            );
          },
          onError: (error) {
            debugPrint(
              'Auth listener error: $error',
            );
          },
        );

    // ============================================================
    // TOKEN REFRESH
    // ============================================================

    _tokenSubscription =
        _messaging.onTokenRefresh.listen(
              (token) async {
            final user =
                FirebaseAuth.instance.currentUser;

            if (user == null) {
              return;
            }

            debugPrint(
              'FCM token refreshed.',
            );

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

  // ==============================================================
  // REGISTER CURRENT DEVICE TOKEN
  // ==============================================================

  static Future<void> _registerToken(
      String uid,
      ) async {
    try {
      final token =
      await _messaging.getToken();

      if (token == null ||
          token.trim().isEmpty) {
        debugPrint(
          'ERROR: Firebase Messaging returned no token.',
        );

        return;
      }

      debugPrint(
        '==========================================',
      );

      debugPrint(
        'FCM TOKEN RECEIVED',
      );

      debugPrint(
        'UID: $uid',
      );

      debugPrint(
        'TOKEN: $token',
      );

      debugPrint(
        '==========================================',
      );

      await _saveToken(
        uid,
        token,
      );
    } catch (error) {
      debugPrint(
        'Unable to get FCM token: $error',
      );
    }
  }

  // ==============================================================
  // SAVE TOKEN TO FIRESTORE
  // ==============================================================

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
          .collection('push_tokens')
          .doc(documentId)
          .set(
        {
          'userId': uid,

          'token': token,

          'platform':
          defaultTargetPlatform.name,

          'enabled': true,

          'createdAt':
          FieldValue.serverTimestamp(),

          'updatedAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      debugPrint(
        '==========================================',
      );

      debugPrint(
        'PUSH TOKEN SAVED TO FIRESTORE',
      );

      debugPrint(
        'User: $uid',
      );

      debugPrint(
        'Collection: push_tokens',
      );

      debugPrint(
        '==========================================',
      );
    } catch (error) {
      debugPrint(
        'ERROR saving push token: $error',
      );
    }
  }

  static Future<void> registerCurrentDevice() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint(
        'Cannot register device: no signed-in user.',
      );

      return;
    }

    await _registerToken(
      user.uid,
    );
  }

  static Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();

    _authSubscription = null;
    _tokenSubscription = null;

    _initialized = false;
  }
}