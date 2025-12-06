import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import '../services/call_navigation_service.dart';

/// URL Parameter Handler for Web Platform
/// 
/// Handles deep linking and URL parameters for incoming calls
/// triggered from Service Worker notification clicks
class UrlHandler {
  static void handleInitialUrl() {
    if (!kIsWeb) return;
    
    try {
      final uri = Uri.parse(html.window.location.href);
      final queryParams = uri.queryParameters;
      
      debugPrint('[UrlHandler] Checking URL parameters: ${html.window.location.href}');
      
      // Check for incoming call parameters
      final callType = queryParams['call'];
      if (callType == 'incoming') {
        final channelId = queryParams['channelId'];
        final type = queryParams['type'];
        final callerName = queryParams['callerName'];
        final callerId = queryParams['callerId'];
        
        if (channelId != null && channelId.isNotEmpty) {
          debugPrint('[UrlHandler] 📱 Incoming call detected from URL');
          debugPrint('[UrlHandler]    Channel: $channelId');
          debugPrint('[UrlHandler]    Type: $type');
          debugPrint('[UrlHandler]    Caller: $callerName');
          
          // Navigate to incoming call screen
          Future.delayed(const Duration(milliseconds: 500), () {
            CallNavigationService().showIncomingCallScreen(
              callerId: callerId ?? 'unknown',
              callerName: callerName ?? 'Unknown Caller',
              callType: type ?? 'voice_call',
              channelId: channelId,
            );
          });
          
          // Clean URL after handling
          html.window.history.replaceState(null, '', '/');
        }
      }
    } catch (e) {
      debugPrint('[UrlHandler] Error handling URL: $e');
    }
  }
  
  /// Listen for Service Worker messages
  static void listenForServiceWorkerMessages() {
    if (!kIsWeb) return;
    
    try {
      html.window.addEventListener('message', (event) {
        final messageEvent = event as html.MessageEvent;
        final data = messageEvent.data;
        
        if (data is Map && data['type'] == 'incoming_call') {
          debugPrint('[UrlHandler] 📨 Received incoming call message from Service Worker');
          final callData = data['data'] as Map<String, dynamic>?;
          
          if (callData != null) {
            CallNavigationService().handleCallNotification(callData);
          }
        }
      });
      
      debugPrint('[UrlHandler] ✅ Service Worker message listener registered');
    } catch (e) {
      debugPrint('[UrlHandler] Error setting up message listener: $e');
    }
  }
}
