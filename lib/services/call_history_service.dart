import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Call History Service
/// 
/// Features:
/// - Log voice and video calls to Firestore
/// - Store call history in chat messages
/// - Track call duration and status
class CallHistoryService {
  // Singleton pattern
  static final CallHistoryService _instance = CallHistoryService._internal();
  factory CallHistoryService() => _instance;
  CallHistoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Log call start in chat
  Future<void> logCallStart({
    required String friendId,
    required String callType, // 'voice' or 'video'
    required String direction, // 'outgoing' or 'incoming'
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get or create chat ID
      final chatId = _generateChatId(currentUser.uid, friendId);
      
      // Create call log message
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUser.uid,
        'receiverId': friendId,
        'type': 'call_log',
        'callType': callType,
        'direction': direction,
        'status': 'started',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      debugPrint('[CallHistory] Logged call start: $callType $direction');
    } catch (e) {
      debugPrint('[CallHistory] Error logging call start: $e');
    }
  }

  /// Log call end in chat with duration
  Future<void> logCallEnd({
    required String friendId,
    required String callType,
    required String direction,
    required int durationSeconds,
    required String status, // 'completed', 'missed', 'declined', 'failed'
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get or create chat ID
      final chatId = _generateChatId(currentUser.uid, friendId);
      
      // Create call log message
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUser.uid,
        'receiverId': friendId,
        'type': 'call_log',
        'callType': callType,
        'direction': direction,
        'status': status,
        'duration': durationSeconds,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      debugPrint('[CallHistory] Logged call end: $callType $direction, duration: ${durationSeconds}s, status: $status');
    } catch (e) {
      debugPrint('[CallHistory] Error logging call end: $e');
    }
  }

  /// Generate consistent chat ID for two users
  String _generateChatId(String userId1, String userId2) {
    final List<String> ids = [userId1, userId2];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Format call duration for display
  static String formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds秒';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '$minutes分${remainingSeconds}秒';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '$hours時間$minutes分';
    }
  }

  /// Get call type display text
  static String getCallTypeText(String callType) {
    return callType == 'video' ? 'ビデオ通話' : '音声通話';
  }

  /// Get call status display text
  static String getCallStatusText(String status) {
    switch (status) {
      case 'completed':
        return '通話終了';
      case 'missed':
        return '不在着信';
      case 'declined':
        return '拒否';
      case 'failed':
        return '失敗';
      default:
        return status;
    }
  }

  /// Get call direction icon
  static String getCallDirectionText(String direction) {
    return direction == 'outgoing' ? '発信' : '着信';
  }
}
