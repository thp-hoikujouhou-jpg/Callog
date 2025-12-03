import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'encryption_service.dart';
import 'dart:convert';

/// Call Type Enum
enum CallType {
  voice,
  video,
}

/// Call Status Enum
enum CallStatus {
  ringing,
  accepted,
  rejected,
  missed,
  ended,
  cancelled,
}

/// Call Manager Service
/// 
/// Manages call signaling, push notifications, and call state
/// - Voice and video call support
/// - Push notification integration
/// - E2E encrypted signaling
/// - Call history tracking
class CallManagerService {
  static final CallManagerService _instance = CallManagerService._internal();
  factory CallManagerService() => _instance;
  CallManagerService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final EncryptionService _encryption = EncryptionService();

  String? _fcmToken;
  bool _isInitialized = false;

  // Call state callbacks
  Function(String callId, String callerId, String callerName, CallType callType)? onIncomingCall;
  Function(String callId)? onCallAccepted;
  Function(String callId)? onCallRejected;
  Function(String callId)? onCallEnded;
  Function(String callId)? onCallCancelled;

  /// Initialize Call Manager
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[CallManager] Already initialized');
      return;
    }

    try {
      debugPrint('[CallManager] Initializing...');
      
      // Initialize encryption service
      await _encryption.initialize();
      
      // Initialize FCM
      await _initializeFCM();
      
      // Setup message handlers
      _setupMessageHandlers();
      
      _isInitialized = true;
      debugPrint('[CallManager] ✅ Initialized successfully');
    } catch (e) {
      debugPrint('[CallManager] ❌ Initialization failed: $e');
      rethrow;
    }
  }

  /// Initialize Firebase Cloud Messaging
  Future<void> _initializeFCM() async {
    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[CallManager] FCM permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        _fcmToken = await _messaging.getToken();
        debugPrint('[CallManager] FCM Token: $_fcmToken');

        // Upload token to Firestore
        await _uploadFCMToken();

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          _uploadFCMToken();
        });
      }
    } catch (e) {
      debugPrint('[CallManager] ⚠️ FCM initialization failed: $e');
    }
  }

  /// Upload FCM token to Firestore
  Future<void> _uploadFCMToken() async {
    final user = _auth.currentUser;
    if (user == null || _fcmToken == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': _fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[CallManager] ✅ FCM token uploaded');
    } catch (e) {
      debugPrint('[CallManager] ❌ FCM token upload failed: $e');
    }
  }

  /// Setup message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[CallManager] 📨 Foreground message received');
      _handleIncomingMessage(message);
    });

    // Handle background messages tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[CallManager] 📨 Background message tapped');
      _handleIncomingMessage(message);
    });
  }

  /// Handle incoming FCM message
  void _handleIncomingMessage(RemoteMessage message) {
    try {
      final data = message.data;
      final type = data['type'] as String?;

      debugPrint('[CallManager] Message type: $type');
      debugPrint('[CallManager] Message data: $data');

      switch (type) {
        case 'incoming_call':
          final callId = data['callId'] as String;
          final callerId = data['callerId'] as String;
          final callerName = data['callerName'] as String;
          final callTypeStr = data['callType'] as String;
          final callType = callTypeStr == 'video' ? CallType.video : CallType.voice;

          onIncomingCall?.call(callId, callerId, callerName, callType);
          break;

        case 'call_accepted':
          final callId = data['callId'] as String;
          onCallAccepted?.call(callId);
          break;

        case 'call_rejected':
          final callId = data['callId'] as String;
          onCallRejected?.call(callId);
          break;

        case 'call_ended':
          final callId = data['callId'] as String;
          onCallEnded?.call(callId);
          break;

        case 'call_cancelled':
          final callId = data['callId'] as String;
          onCallCancelled?.call(callId);
          break;
      }
    } catch (e) {
      debugPrint('[CallManager] ❌ Error handling message: $e');
    }
  }

  /// Start a call (voice or video)
  Future<String> startCall({
    required String friendId,
    required String friendName,
    required CallType callType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      debugPrint('[CallManager] Starting ${callType.name} call to $friendId...');

      // Generate call ID
      final callId = '${user.uid}_${friendId}_${DateTime.now().millisecondsSinceEpoch}';

      // Generate Agora channel name
      final channelName = 'call_$callId';

      // Create call document
      final callData = {
        'callId': callId,
        'callerId': user.uid,
        'callerName': user.displayName ?? 'Unknown',
        'calleeId': friendId,
        'calleeName': friendName,
        'callType': callType.name,
        'channelName': channelName,
        'status': CallStatus.ringing.name,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('calls').doc(callId).set(callData);

      // Send push notification to friend
      await _sendCallNotification(
        friendId: friendId,
        callId: callId,
        callType: callType,
        notificationType: 'incoming_call',
      );

      debugPrint('[CallManager] ✅ Call started: $callId');
      return callId;
    } catch (e) {
      debugPrint('[CallManager] ❌ Failed to start call: $e');
      rethrow;
    }
  }

  /// Accept a call
  Future<void> acceptCall(String callId) async {
    try {
      debugPrint('[CallManager] Accepting call: $callId');

      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.accepted.name,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Get call data to notify caller
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      final callData = callDoc.data();
      
      if (callData != null) {
        final callerId = callData['callerId'] as String;
        await _sendCallNotification(
          friendId: callerId,
          callId: callId,
          callType: CallType.voice, // Not used for accept notification
          notificationType: 'call_accepted',
        );
      }

      debugPrint('[CallManager] ✅ Call accepted');
    } catch (e) {
      debugPrint('[CallManager] ❌ Failed to accept call: $e');
      rethrow;
    }
  }

  /// Reject a call
  Future<void> rejectCall(String callId) async {
    try {
      debugPrint('[CallManager] Rejecting call: $callId');

      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.rejected.name,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Get call data to notify caller
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      final callData = callDoc.data();
      
      if (callData != null) {
        final callerId = callData['callerId'] as String;
        await _sendCallNotification(
          friendId: callerId,
          callId: callId,
          callType: CallType.voice,
          notificationType: 'call_rejected',
        );
      }

      debugPrint('[CallManager] ✅ Call rejected');
    } catch (e) {
      debugPrint('[CallManager] ❌ Failed to reject call: $e');
      rethrow;
    }
  }

  /// End a call
  Future<void> endCall(String callId) async {
    try {
      debugPrint('[CallManager] Ending call: $callId');

      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.ended.name,
        'endedAt': FieldValue.serverTimestamp(),
      });

      // Get call data to notify other party
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      final callData = callDoc.data();
      
      if (callData != null) {
        final user = _auth.currentUser;
        final otherUserId = callData['callerId'] == user?.uid 
            ? callData['calleeId'] 
            : callData['callerId'];
        
        await _sendCallNotification(
          friendId: otherUserId as String,
          callId: callId,
          callType: CallType.voice,
          notificationType: 'call_ended',
        );
      }

      debugPrint('[CallManager] ✅ Call ended');
    } catch (e) {
      debugPrint('[CallManager] ❌ Failed to end call: $e');
      rethrow;
    }
  }

  /// Cancel a call (before it's answered)
  Future<void> cancelCall(String callId) async {
    try {
      debugPrint('[CallManager] Cancelling call: $callId');

      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.cancelled.name,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Get call data to notify callee
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      final callData = callDoc.data();
      
      if (callData != null) {
        final calleeId = callData['calleeId'] as String;
        await _sendCallNotification(
          friendId: calleeId,
          callId: callId,
          callType: CallType.voice,
          notificationType: 'call_cancelled',
        );
      }

      debugPrint('[CallManager] ✅ Call cancelled');
    } catch (e) {
      debugPrint('[CallManager] ❌ Failed to cancel call: $e');
      rethrow;
    }
  }

  /// Send call notification via FCM
  Future<void> _sendCallNotification({
    required String friendId,
    required String callId,
    required CallType callType,
    required String notificationType,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get friend's FCM token
      final friendDoc = await _firestore.collection('users').doc(friendId).get();
      final fcmToken = friendDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        debugPrint('[CallManager] ⚠️ Friend has no FCM token');
        return;
      }

      // Create notification data
      final notificationData = {
        'type': notificationType,
        'callId': callId,
        'callerId': user.uid,
        'callerName': user.displayName ?? 'Unknown',
        'callType': callType.name,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      // Encrypt notification data
      final encryptedData = _encryption.encryptSignaling('notification', notificationData);

      // Store notification in Firestore (for Cloud Functions to process)
      await _firestore.collection('notifications').add({
        'recipientId': friendId,
        'recipientToken': fcmToken,
        'data': encryptedData,
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      debugPrint('[CallManager] ✅ Notification queued for Cloud Functions');
    } catch (e) {
      debugPrint('[CallManager] ❌ Failed to send notification: $e');
    }
  }

  /// Get call channel name
  Future<String?> getCallChannelName(String callId) async {
    try {
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      return callDoc.data()?['channelName'] as String?;
    } catch (e) {
      debugPrint('[CallManager] ❌ Failed to get channel name: $e');
      return null;
    }
  }

  /// Listen to call status changes
  Stream<DocumentSnapshot> listenToCallStatus(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots();
  }

  /// Get call history
  Stream<QuerySnapshot> getCallHistory() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('calls')
        .where('callerId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }
}
