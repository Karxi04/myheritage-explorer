// GENERATED PLACEHOLDER.
// Run: dart pub global activate flutterfire_cli
// Then: flutterfire configure
// The command will replace this file with your real Firebase configuration.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Run flutterfire configure for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDr8enmS5i42MSgfz26a6IM3iHJ8Cz7Z6o',
    appId: '1:83101076806:web:5665c75a161dc8c860a947',
    messagingSenderId: '83101076806',
    projectId: 'myheritage-4fe2f',
    authDomain: 'myheritage-4fe2f.firebaseapp.com',
    storageBucket: 'myheritage-4fe2f.firebasestorage.app',
    measurementId: 'G-JHGFW00PCL',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDj4Uofuuuqmj4vPh59--3EikWvK6KUxJY',
    appId: '1:83101076806:android:29f95de6243c444260a947',
    messagingSenderId: '83101076806',
    projectId: 'myheritage-4fe2f',
    storageBucket: 'myheritage-4fe2f.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME.firebasestorage.app',
    iosBundleId: 'com.example.myheritageExplorer',
  );
}
