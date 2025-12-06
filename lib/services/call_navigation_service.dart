import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/incoming_call_screen.dart';

/// Call Navigation Service
/// 
/// Handles navigation to incoming call screens from push notifications.
/// This service manages global navigation context and ensures incoming
/// call screens can be displayed from anywhere in the app.
class CallNavigationService {
  static final CallNavigationService _instance = CallNavigationService._internal();
  factory CallNavigationService() => _instance;
  CallNavigationService._internal();

  /// Global navigator key for navigation without context
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Navigate to incoming call screen
  /// 
  /// Can be called from anywhere, including background message handlers
  void showIncomingCallScreen({
    required String callerId,
    required String callerName,
    String? callerPhotoUrl,
    required String callType,
    required String channelId,
  }) {
    final context = navigatorKey.currentContext;
    
    if (context == null) {
      debugPrint('[CallNav] ❌ No navigator context available');
      return;
    }

    debugPrint('[CallNav] 📱 Showing incoming call screen');
    debugPrint('[CallNav]    Caller: $callerName ($callerId)');
    debugPrint('[CallNav]    Type: $callType');
    debugPrint('[CallNav]    Channel: $channelId');

    // Navigate to incoming call screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(
          callerId: callerId,
          callerName: callerName,
          callerPhotoUrl: callerPhotoUrl,
          callType: callType,
          channelId: channelId,
        ),
        fullscreenDialog: true, // Display as full-screen dialog
      ),
    );
  }

  /// Parse notification data and show incoming call screen
  Future<void> handleCallNotification(Map<String, dynamic> data) async {
    final callType = data['type'] as String?;
    
    if (callType != 'voice_call' && callType != 'video_call') {
      debugPrint('[CallNav] ⚠️ Not a call notification, ignoring');
      return;
    }

    final channelId = data['channelId'] as String?;
    String? callerName = data['callerName'] as String?;
    final callerId = data['callerId'] as String?;
    String? callerPhotoUrl = data['callerPhotoUrl'] as String?;

    if (channelId == null || channelId.isEmpty) {
      debugPrint('[CallNav] ❌ Invalid channelId, cannot show incoming call');
      return;
    }

    // Fetch caller's info from Firestore (name and photo)
    if (callerId != null) {
      debugPrint('[CallNav] 📋 Fetching caller info from Firestore: $callerId');
      try {
        final firestore = FirebaseFirestore.instance;
        final userDoc = await firestore.collection('users').doc(callerId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          
          // Get caller's display name (priority: displayName > username > notification data)
          final firestoreDisplayName = userData?['displayName'] as String?;
          final firestoreUsername = userData?['username'] as String?;
          
          if (firestoreDisplayName != null && firestoreDisplayName.isNotEmpty) {
            callerName = firestoreDisplayName;
            debugPrint('[CallNav] ✅ Caller display name: $callerName');
          } else if (firestoreUsername != null && firestoreUsername.isNotEmpty) {
            callerName = firestoreUsername;
            debugPrint('[CallNav] ✅ Caller username: $callerName');
          } else {
            debugPrint('[CallNav] ⚠️ No display name or username, using notification data');
          }
          
          // Get caller's photo URL
          if (callerPhotoUrl == null || callerPhotoUrl.isEmpty) {
            callerPhotoUrl = userData?['photoUrl'] as String?;
            debugPrint('[CallNav] ✅ Caller photo URL: ${callerPhotoUrl ?? "No photo"}');
          }
        } else {
          debugPrint('[CallNav] ⚠️ User document not found for: $callerId');
        }
      } catch (e) {
        debugPrint('[CallNav] ⚠️ Failed to fetch caller info from Firestore: $e');
      }
    }

    showIncomingCallScreen(
      callerId: callerId ?? 'unknown',
      callerName: callerName ?? 'Unknown Caller',
      callerPhotoUrl: callerPhotoUrl,
      callType: callType!,
      channelId: channelId,
    );
  }
}
