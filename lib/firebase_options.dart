// lib/firebase_options.dart
// استبدل القيم ببيانات مشروعك من Firebase Console ← Project Settings
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'ضع_API_KEY_هنا',
    appId: 'ضع_APP_ID_هنا',
    messagingSenderId: 'ضع_SENDER_ID_هنا',
    projectId: 'ضع_PROJECT_ID_هنا',
    storageBucket: 'ضع_STORAGE_BUCKET_هنا',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'ضع_API_KEY_هنا',
    appId: 'ضع_APP_ID_هنا',
    messagingSenderId: 'ضع_SENDER_ID_هنا',
    projectId: 'ضع_PROJECT_ID_هنا',
    storageBucket: 'ضع_STORAGE_BUCKET_هنا',
    iosBundleId: 'ضع_BUNDLE_ID_هنا',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'ضع_API_KEY_هنا',
    appId: 'ضع_APP_ID_هنا',
    messagingSenderId: 'ضع_SENDER_ID_هنا',
    projectId: 'ضع_PROJECT_ID_هنا',
    storageBucket: 'ضع_STORAGE_BUCKET_هنا',
    authDomain: 'ضع_AUTH_DOMAIN_هنا',
  );
}
