import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

      // Get FCM token
      _fcmToken = await _messaging.getToken();
      final token = _fcmToken;
      if (token != null) {
        debugPrint('[Push] FCM Token: $token');
        await _saveFCMToken(token);
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
        debugPrint('[Push] No user logged in, skipping token save');
        return;
      }

      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

      debugPrint('[Push] FCM token saved to Firestore');
    } catch (e) {
      debugPrint('[Push] Error saving FCM token: $e');
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

  /// Send call notification to peer
  Future<void> sendCallNotification({
    required String peerId,
    required String channelId,
    required String callType, // 'voice_call' or 'video_call'
    required String callerName,
  }) async {
    try {
      // Get peer's FCM token
      final peerDoc = await _firestore.collection('users').doc(peerId).get();
      final peerToken = peerDoc.data()?['fcmToken'] as String?;

      if (peerToken == null) {
        debugPrint('[Push] Peer has no FCM token');
        return;
      }

      // Store call notification in Firestore (Cloud Function will send FCM)
      await _firestore.collection('call_notifications').add({
        'peerId': peerId,
        'peerToken': peerToken,
        'channelId': channelId,
        'callType': callType,
        'callerName': callerName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      debugPrint('[Push] Call notification sent to peer: $peerId');
    } catch (e) {
      debugPrint('[Push] Error sending call notification: $e');
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
