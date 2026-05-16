import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Initialize local notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
await _localNotifications.initialize(settings);
    
    // Request permissions
    await _firebaseMessaging.requestPermission();
    
    // Get FCM token - Firebase Messaging Web will automatically look for
    // firebase-messaging-sw.js in the root of the web app
    String? token = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $token');
    
    // Save token to Firestore
    if (token != null && FirebaseAuth.instance.currentUser != null) {
      await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({
        'fcmToken': token,
      });
    }
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
    
    // Handle when notification is clicked
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint('Handling background message: ${message.messageId}');
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'flags_channel',
      'Flags Notifications',
      channelDescription: 'Notifications for matches, messages, and updates',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      message.notification?.title ?? 'Flags Notification',
      message.notification?.body ?? 'You have a new notification',
      details,
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Navigate to appropriate screen based on notification type
    debugPrint('Notification tapped: ${message.data}');
  }

  Future<void> showMatchNotification(String userName) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'match_channel',
      'New Match',
      channelDescription: 'When you get a new match',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'New Match! 🎉',
      'You matched with $userName! Start chatting now.',
      details,
    );
  }

  Future<void> showMessageNotification(String userName, String message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'message_channel',
      'New Message',
      channelDescription: 'When you receive a new message',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Message from $userName',
      message.length > 50 ? '${message.substring(0, 50)}...' : message,
      details,
    );
  }

  Future<void> showWarningNotification(String reason) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'warning_channel',
      'Account Warning',
      channelDescription: 'Important account notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Account Notice',
      reason,
      details,
    );
  }
}

