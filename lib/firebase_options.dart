// ignore_for_file: lines_longer_than_80_chars

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase options used by [Firebase.initializeApp].
///
/// Replace these placeholder values by running:
/// dart pub global run flutterfire_cli:flutterfire configure --project your-project-id
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA9Q7eCH9jOl4pX3P-_HwH4x3jLL0NUtUM',
    appId: '1:331589496845:web:1e9c82f3d9fe0ebd0ee544',
    messagingSenderId: '331589496845',
    projectId: 'sales-erp-desktop-260715',
    authDomain: 'sales-erp-desktop-260715.firebaseapp.com',
    storageBucket: 'sales-erp-desktop-260715.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAtawkD7dAMqQUIhBtXsFrYTMabi_UsVZU',
    appId: '1:331589496845:android:fb7cad2db2060ae60ee544',
    messagingSenderId: '331589496845',
    projectId: 'sales-erp-desktop-260715',
    storageBucket: 'sales-erp-desktop-260715.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCbI2w9uSj3E4nIz90r2h9qYUk9dgu-Xyg',
    appId: '1:331589496845:ios:fd7e5d43cff7552d0ee544',
    messagingSenderId: '331589496845',
    projectId: 'sales-erp-desktop-260715',
    storageBucket: 'sales-erp-desktop-260715.firebasestorage.app',
    iosBundleId: 'com.example.desktop',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCbI2w9uSj3E4nIz90r2h9qYUk9dgu-Xyg',
    appId: '1:331589496845:ios:fd7e5d43cff7552d0ee544',
    messagingSenderId: '331589496845',
    projectId: 'sales-erp-desktop-260715',
    storageBucket: 'sales-erp-desktop-260715.firebasestorage.app',
    iosBundleId: 'com.example.desktop',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA9Q7eCH9jOl4pX3P-_HwH4x3jLL0NUtUM',
    appId: '1:331589496845:web:86927a694f4fc3500ee544',
    messagingSenderId: '331589496845',
    projectId: 'sales-erp-desktop-260715',
    authDomain: 'sales-erp-desktop-260715.firebaseapp.com',
    storageBucket: 'sales-erp-desktop-260715.firebasestorage.app',
  );
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_WITH_LINUX_API_KEY',
    appId: '1:000000000000:web:replace_me',
    messagingSenderId: '000000000000',
    projectId: 'replace-with-your-project-id',
    authDomain: 'replace-with-your-project-id.firebaseapp.com',
    storageBucket: 'replace-with-your-project-id.firebasestorage.app',
  );
}
