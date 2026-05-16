// ACTION REQUIRED: Replace all placeholder values with your actual Firebase project configuration
// 
// To get these values:
// 1. Go to Firebase Console (https://console.firebase.google.com)
// 2. Select your project "Flags"
// 3. Go to Project Settings (gear icon)
// 4. Under "Your apps" section, register a new app or select existing
// 5. Copy the configuration values from there
//
// IMPORTANT: For Android, you also need to download google-services.json
// For iOS, download GoogleService-Info.plist
// For Web, copy the configuration object below

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

// Web app configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD7SCL47I6u62yOILbSTDZf9m6WBy64Dw4',
    authDomain: 'flags-1a8df.firebaseapp.com',
    projectId: 'flags-1a8df',
    storageBucket: 'flags-1a8df.firebasestorage.app',
    messagingSenderId: '967452533065',
    appId: '1:967452533065:web:f0e4cc2b2f49be5a077a98',
    measurementId: 'G-7SCGLWBQYK',
  );

// Android app configuration
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBP_ynG1O6-NIASzaTv4hki8xd2_L6-ohs',
    appId: '1:967452533065:android:1c59f5c9195d4fc9077a98',
    messagingSenderId: '967452533065',
    projectId: 'flags-1a8df',
    storageBucket: 'flags-1a8df.firebasestorage.app',
    authDomain: 'flags-1a8df.firebaseapp.com',
  );

// iOS app configuration
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBP_ynG1O6-NIASzaTv4hki8xd2_L6-ohs',
    appId: '1:967452533065:ios:2b785da40011000e077a98',
    messagingSenderId: '967452533065',
    projectId: 'flags-1a8df',
    storageBucket: 'flags-1a8df.firebasestorage.app',
    authDomain: 'flags-1a8df.firebaseapp.com',
    iosBundleId: 'com.clit.flags',
  );

  // For macOS (if needed)
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBP_ynG1O6-NIASzaTv4hki8xd2_L6-ohs',
    appId: '1:967452533065:macos:2b785da40011000e077a98',
    messagingSenderId: '967452533065',
    projectId: 'flags-1a8df',
    storageBucket: 'flags-1a8df.firebasestorage.app',
    authDomain: 'flags-1a8df.firebaseapp.com',
  );
}
