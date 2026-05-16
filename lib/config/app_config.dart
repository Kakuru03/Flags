class AppConfig {
  // ACTION REQUIRED: 
  // Replace these with your actual Firebase project credentials
  static const String firebaseApiKey = "YOUR_FIREBASE_API_KEY";
  static const String firebaseAuthDomain = "YOUR_PROJECT.firebaseapp.com";
  static const String firebaseProjectId = "YOUR_PROJECT_ID";
  static const String firebaseStorageBucket = "YOUR_PROJECT.appspot.com";
  static const String firebaseMessagingSenderId = "YOUR_SENDER_ID";
  static const String firebaseAppId = "YOUR_APP_ID";
  
  // WebRTC STUN/TURN servers (Free public STUN servers)
  // ACTION REQUIRED: For production, consider free TURN servers like:
  // - OpenRelay (free tier available)
  // - Metered.ca (free tier with TURN)
  // - Xirsys (free tier available)
  static const List<Map<String, dynamic>> turnServers = [
    {'url': 'stun:stun.l.google.com:19302'},
    {'url': 'stun:stun1.l.google.com:19302'},
    {'url': 'stun:stun2.l.google.com:19302'},
    // Add free TURN servers if needed:
    // {'url': 'turn:openrelay.metered.ca:80', 'username': 'openrelayproject', 'credential': 'openrelayproject'},
  ];
  
  // App limits
  static const int maxProfileImages = 6;
  static const int maxBioLength = 500;
  static const int maxDistanceKm = 100;
  static const int swipeLimitPerDay = 50; // Free tier limit
  
  // Cache durations
  static const Duration cacheDuration = Duration(hours: 24);
  static const Duration offlineMessageSync = Duration(minutes: 5);
}