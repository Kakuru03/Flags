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
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD7SCL47I6u62yOILbSTDZf9m6WBy64Dw4',
    authDomain: 'flags-1a8df.firebaseapp.com',
    projectId: 'flags-1a8df',
    storageBucket: 'flags-1a8df.firebasestorage.app',
    messagingSenderId: '967452533065',
    appId: '1:967452533065:web:f0e4cc2b2f49be5a077a98',
    measurementId: 'G-7SCGLWBQYK',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBP_ynG1O6-NIASzaTv4hki8xd2_L6-ohs',
    appId: '1:967452533065:android:1c59f5c9195d4fc9077a98',
    messagingSenderId: '967452533065',
    projectId: 'flags-1a8df',
    storageBucket: 'flags-1a8df.firebasestorage.app',
    authDomain: 'flags-1a8df.firebaseapp.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBvwVOGprKuyY4i4npqGu6OoUq_EtT0VRI',
    appId: '1:967452533065:ios:2cc43fb04d74e722077a98',
    messagingSenderId: '967452533065',
    projectId: 'flags-1a8df',
    storageBucket: 'flags-1a8df.firebasestorage.app',
    authDomain: 'flags-1a8df.firebaseapp.com',
    iosBundleId: 'com.example.flags',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBvwVOGprKuyY4i4npqGu6OoUq_EtT0VRI',
    appId: '1:967452533065:ios:2cc43fb04d74e722077a98',
    messagingSenderId: '967452533065',
    projectId: 'flags-1a8df',
    storageBucket: 'flags-1a8df.firebasestorage.app',
    authDomain: 'flags-1a8df.firebaseapp.com',
    iosBundleId: 'com.example.flags',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyD7SCL47I6u62yOILbSTDZf9m6WBy64Dw4',
    appId: '1:967452533065:web:29726b3d6349b1b7077a98',
    messagingSenderId: '967452533065',
    projectId: 'flags-1a8df',
    authDomain: 'flags-1a8df.firebaseapp.com',
    storageBucket: 'flags-1a8df.firebasestorage.app',
    measurementId: 'G-4STD5JKDBQ',
  );
}
