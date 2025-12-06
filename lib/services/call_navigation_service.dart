import 'package:flutter/material.dart';
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
  void handleCallNotification(Map<String, dynamic> data) {
    final callType = data['type'] as String?;
    
    if (callType != 'voice_call' && callType != 'video_call') {
      debugPrint('[CallNav] ⚠️ Not a call notification, ignoring');
      return;
    }

    final channelId = data['channelId'] as String?;
    final callerName = data['callerName'] as String?;
    final callerId = data['callerId'] as String?;
    final callerPhotoUrl = data['callerPhotoUrl'] as String?;

    if (channelId == null || channelId.isEmpty) {
      debugPrint('[CallNav] ❌ Invalid channelId, cannot show incoming call');
      return;
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
