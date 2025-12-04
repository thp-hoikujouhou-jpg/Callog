import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Push Notification Service for Callog
/// 
/// Features:
/// - FCM token management and synchronization
/// - Incoming call notifications (voice & video)
/// - Background notification handling
/// - Local notification display
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  bool _isInitialized = false;

  /// Initialize push notification service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[Push] Already initialized');
      return;
    }

    try {
      // Request notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[Push] User granted permission');
      } else {
        debugPrint('[Push] User declined or has not accepted permission');
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token (Web requires vapidKey)
      debugPrint('[Push] 🔑 Requesting FCM token...');
      if (kIsWeb) {
        // For Web, use vapidKey (same as server key for legacy FCM)
        _fcmToken = await _messaging.getToken(
          vapidKey: 'BDk337DMgVNfm-PG-AWhZ7kKwPp_bdzFvzOiccCp3k999vwSc56ZFfVn3j-COgLnJoQ43ULmzxswUTDeg1pRRiA',
        );
      } else {
        // For mobile, no vapidKey needed
        _fcmToken = await _messaging.getToken();
      }
      
      final token = _fcmToken;
      if (token != null) {
        debugPrint('[Push] ✅ FCM Token acquired: ${token.substring(0, 20)}...');
        await _saveFCMToken(token);
      } else {
        debugPrint('[Push] ⚠️ Failed to get FCM token');
      }

      // Listen to token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[Push] Token refreshed: $newToken');
        _fcmToken = newToken;
        _saveFCMToken(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      _isInitialized = true;
      debugPrint('[Push] Initialization completed');
    } catch (e) {
      debugPrint('[Push] Initialization error: $e');
    }
  }

  /// Initialize local notifications (for displaying notifications)
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  /// Save FCM token to Firestore
  Future<void> _saveFCMToken(String token) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        debugPrint('[Push] ❌ No user logged in, skipping token save');
        return;
      }

      debugPrint('[Push] 💾 Saving FCM token for user: $userId');
      debugPrint('[Push] Token: ${token.substring(0, 20)}...');

      // Use set with merge to avoid errors if document doesn't exist
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[Push] ✅ FCM token saved to Firestore successfully');
      
      // Verify token was saved
      final doc = await _firestore.collection('users').doc(userId).get();
      final savedToken = doc.data()?['fcmToken'];
      if (savedToken == token) {
        debugPrint('[Push] ✅ Token verification successful');
      } else {
        debugPrint('[Push] ⚠️ Token verification failed - saved token does not match');
      }
    } catch (e, stackTrace) {
      debugPrint('[Push] ❌ Error saving FCM token: $e');
      debugPrint('[Push] Stack trace: $stackTrace');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[Push] Foreground message received: ${message.messageId}');
    debugPrint('[Push] Data: ${message.data}');

    final data = message.data;
    final type = data['type'] as String?;

    if (type == 'voice_call' || type == 'video_call') {
      _showIncomingCallNotification(message);
    } else if (message.notification != null) {
      _showLocalNotification(message);
    }
  }

  /// Show incoming call notification
  Future<void> _showIncomingCallNotification(RemoteMessage message) async {
    final data = message.data;
    final callerName = data['callerName'] ?? 'Unknown';
    final callType = data['type'] == 'video_call' ? 'ビデオ通話' : '音声通話';
    final channelId = data['channelId'] ?? '';

    const androidDetails = AndroidNotificationDetails(
      'incoming_calls',
      'Incoming Calls',
      channelDescription: 'Notifications for incoming voice and video calls',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('call_ringtone'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'call_ringtone.aiff',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      channelId.hashCode,
      '$callType着信',
      '$callerName さんから$callTypeがかかってきています',
      notificationDetails,
      payload: channelId,
    );

    debugPrint('[Push] Incoming call notification shown: $callType from $callerName');
  }

  /// Show general local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'general_notifications',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      notificationDetails,
      payload: message.data['payload'],
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[Push] Notification tapped: ${message.messageId}');
    debugPrint('[Push] Data: ${message.data}');
    
    // TODO: Navigate to appropriate screen based on notification type
  }

  /// Handle local notification tap
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[Push] Local notification tapped: ${response.payload}');
    
    // TODO: Navigate to appropriate screen based on payload
  }

  /// Send call notification to peer using Cloud Functions
  /// 
  /// This method calls the Cloud Functions endpoint to send push notifications.
  /// Advantages over direct FCM API:
  /// - No CORS issues (server-side execution)
  /// - Secure server key management
  /// - Better error handling
  /// - Easier to maintain and update
  Future<void> sendCallNotification({
    required String peerId,
    required String channelId,
    required String callType, // 'voice_call' or 'video_call'
    required String callerName,
  }) async {
    try {
      debugPrint('[Push] 📤 Sending notification via Cloud Functions');
      debugPrint('[Push] Peer: $peerId, Channel: $channelId, Type: $callType');

      // Call Cloud Function
      final callable = _functions.httpsCallable('sendPushNotification');
      final result = await callable.call({
        'peerId': peerId,
        'channelId': channelId,
        'callType': callType,
        'callerName': callerName,
      });

      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        debugPrint('[Push] ✅ Notification sent successfully!');
        debugPrint('[Push] Message ID: ${data['messageId']}');
      } else {
        debugPrint('[Push] ⚠️ Notification sent but success flag is false');
      }
    } catch (e, stackTrace) {
      debugPrint('[Push] ❌ Error sending call notification: $e');
      debugPrint('[Push] Stack trace: $stackTrace');
      
      // Rethrow to allow caller to handle the error
      rethrow;
    }
  }

  /// Get FCM token
  String? get fcmToken => _fcmToken;

  /// Check if initialized
  bool get isInitialized => _isInitialized;
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Push] Background message: ${message.messageId}');
  debugPrint('[Push] Data: ${message.data}');
  
  // Handle background notification logic here
}
