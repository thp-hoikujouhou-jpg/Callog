import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  // Callbacks
  Function(RemoteMessage)? onMessageReceived;
  Function(RemoteMessage)? onMessageOpenedApp;
  Function(String callerId, String callerName)? onIncomingCall;

  // Initialize notification service
  Future<void> initialize() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        debugPrint('Notification permission status: ${settings.authorizationStatus}');
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        String? token = await _firebaseMessaging.getToken();
        if (kDebugMode) {
          debugPrint('📱 FCM Token: $token');
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          if (kDebugMode) {
            debugPrint('📱 FCM Token refreshed: $newToken');
          }
          // TODO: Send token to server/Firestore
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (kDebugMode) {
            debugPrint('📨 Foreground message: ${message.notification?.title}');
          }
          
          if (onMessageReceived != null) {
            onMessageReceived!(message);
          }

          // Check if it's an incoming call notification
          if (message.data['type'] == 'incoming_call') {
            final callerId = message.data['callerId'] ?? '';
            final callerName = message.data['callerName'] ?? 'Unknown';
            
            if (onIncomingCall != null) {
              onIncomingCall!(callerId, callerName);
            }
          }
        });

        // Handle messages when app is opened from notification
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          if (kDebugMode) {
            debugPrint('📨 Message opened app: ${message.notification?.title}');
          }
          
          if (onMessageOpenedApp != null) {
            onMessageOpenedApp!(message);
          }
        });

        // Check for initial message (when app is launched from notification)
        RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          if (kDebugMode) {
            debugPrint('📨 App launched from notification: ${initialMessage.notification?.title}');
          }
          
          if (onMessageOpenedApp != null) {
            onMessageOpenedApp!(initialMessage);
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ Notification permission denied');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error initializing notifications: $e');
      }
    }
  }

  // Get FCM token
  Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting FCM token: $e');
      }
      return null;
    }
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      if (kDebugMode) {
        debugPrint('✅ Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error subscribing to topic: $e');
      }
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        debugPrint('✅ Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error unsubscribing from topic: $e');
      }
    }
  }

  // Show local notification (optional - for custom UI)
  void showIncomingCallNotification(BuildContext context, String callerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('着信'),
        content: Text('$callerNameから通話があります'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('拒否'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to incoming call screen
            },
            child: const Text('応答'),
          ),
        ],
      ),
    );
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('📨 Background message: ${message.messageId}');
  }
  
  // Handle incoming call notification in background
  if (message.data['type'] == 'incoming_call') {
    if (kDebugMode) {
      debugPrint('📞 Incoming call from: ${message.data['callerId']}');
    }
    // TODO: Show incoming call UI or notification
  }
}
