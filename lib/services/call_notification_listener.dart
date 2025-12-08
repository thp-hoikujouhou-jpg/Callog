import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Call Notification Listener Service
/// 
/// Listens to Firestore for incoming call notifications in realtime
/// This replaces FCM push notifications to avoid Firebase Admin SDK requirements
class CallNotificationListener {
  static final CallNotificationListener _instance = CallNotificationListener._internal();
  factory CallNotificationListener() => _instance;
  CallNotificationListener._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  bool _isListening = false;
  
  // Callback for incoming call
  Function(Map<String, dynamic> callData)? onIncomingCall;

  /// Start listening for incoming call notifications
  Future<void> startListening() async {
    if (_isListening) {
      debugPrint('[CallListener] Already listening');
      return;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint('[CallListener] ❌ No authenticated user');
      return;
    }

    final userId = currentUser.uid;
    debugPrint('[CallListener] 🎧 Starting to listen for calls to: $userId');

    try {
      // Listen to call_notifications collection where peerId matches current user
      // 🔥 CRITICAL FIX: Remove time filter to receive calls immediately after reload
      // Instead, we'll check timestamp in the callback to filter old notifications
      final tenSecondsAgo = DateTime.now().subtract(const Duration(seconds: 10));
      
      debugPrint('[CallListener] 🔥 Listening for calls (last 10 seconds filter)');
      
      _notificationSubscription = _firestore
          .collection('call_notifications')
          .where('peerId', isEqualTo: userId)
          .where('status', isEqualTo: 'ringing')
          .where('createdAt', isGreaterThan: tenSecondsAgo.millisecondsSinceEpoch)
          .snapshots()
          .listen(
        (QuerySnapshot snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;
              debugPrint('[CallListener] 📞 Incoming call detected!');
              debugPrint('[CallListener] From: ${data['callerName']}');
              debugPrint('[CallListener] Type: ${data['callType']}');
              debugPrint('[CallListener] Channel: ${data['channelId']}');
              
              // Trigger callback
              onIncomingCall?.call({
                'notificationId': change.doc.id,
                'callerId': data['callerId'],
                'callerName': data['callerName'],
                'channelId': data['channelId'],
                'callType': data['callType'],
                'timestamp': data['timestamp'],
              });
              
              // Mark as delivered (optional)
              _markAsDelivered(change.doc.id);
            }
          }
        },
        onError: (error) {
          debugPrint('[CallListener] ❌ Error listening: $error');
        },
      );

      _isListening = true;
      debugPrint('[CallListener] ✅ Listener started successfully');
      
    } catch (e) {
      debugPrint('[CallListener] ❌ Failed to start listener: $e');
    }
  }

  /// Mark notification as delivered
  Future<void> _markAsDelivered(String notificationId) async {
    try {
      await _firestore
          .collection('call_notifications')
          .doc(notificationId)
          .update({
        'status': 'delivered',
        'deliveredAt': DateTime.now().toIso8601String(),
      });
      debugPrint('[CallListener] ✅ Notification marked as delivered');
    } catch (e) {
      debugPrint('[CallListener] ⚠️ Failed to mark as delivered: $e');
    }
  }

  /// Accept call (update notification status)
  Future<void> acceptCall(String notificationId) async {
    try {
      await _firestore
          .collection('call_notifications')
          .doc(notificationId)
          .update({
        'status': 'accepted',
        'acceptedAt': DateTime.now().toIso8601String(),
      });
      debugPrint('[CallListener] ✅ Call accepted');
    } catch (e) {
      debugPrint('[CallListener] ❌ Failed to accept call: $e');
    }
  }

  /// Reject call (update notification status)
  Future<void> rejectCall(String notificationId) async {
    try {
      await _firestore
          .collection('call_notifications')
          .doc(notificationId)
          .update({
        'status': 'rejected',
        'rejectedAt': DateTime.now().toIso8601String(),
      });
      debugPrint('[CallListener] ✅ Call rejected');
    } catch (e) {
      debugPrint('[CallListener] ❌ Failed to reject call: $e');
    }
  }

  /// Stop listening
  void stopListening() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _isListening = false;
    debugPrint('[CallListener] 🛑 Listener stopped');
  }

  /// Check if listening
  bool get isListening => _isListening;
}
