class AppConfig {
  // ─────────────────────────────────────────────────────────────
  // ADMIN SETUP: change this to your email address.
  // Register with this email in the app and you become admin.
  // ─────────────────────────────────────────────────────────────
  static const String adminEmail = 'allan05@gmail.com';

  static const String firebaseApiKey = "AIzaSyD7SCL47I6u62yOILbSTDZf9m6WBy64Dw4";
  static const String firebaseAuthDomain = "flags-1a8df.firebaseapp.com";
  static const String firebaseProjectId = "flags-1a8df";
  static const String firebaseStorageBucket = "flags-1a8df.firebasestorage.app";
  static const String firebaseMessagingSenderId = "967452533065";
  static const String firebaseAppId = "1:967452533065:web:f0e4cc2b2f49be5a077a98";

  static const List<Map<String, dynamic>> turnServers = [
    {'url': 'stun:stun.l.google.com:19302'},
    {'url': 'stun:stun1.l.google.com:19302'},
    {'url': 'stun:stun2.l.google.com:19302'},
  ];

  static const int maxProfileImages = 6;
  static const int maxBioLength = 500;
  static const int maxDistanceKm = 100;
  static const int swipeLimitPerDay = 50;

  static const Duration cacheDuration = Duration(hours: 24);
  static const Duration offlineMessageSync = Duration(minutes: 5);
}
