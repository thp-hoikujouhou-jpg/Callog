import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import '../services/call_navigation_service.dart';

/// Web Service Worker notification listener
/// 
/// Listens for incoming call notifications from the Service Worker
/// when the app is in the background and a notification is received
class WebNotificationListener {
  static bool _isListening = false;

  /// Start listening to Service Worker messages
  static void startListening() {
    if (!kIsWeb) {
      debugPrint('[WebNotificationListener] Not on Web platform, skipping');
      return;
    }

    if (_isListening) {
      debugPrint('[WebNotificationListener] Already listening');
      return;
    }

    try {
      debugPrint('[WebNotificationListener] 🎧 Setting up Service Worker message listener');
      
      // Listen to messages from Service Worker
      html.window.navigator.serviceWorker?.addEventListener('message', (event) {
        final messageEvent = event as html.MessageEvent;
        final data = messageEvent.data;
        
        debugPrint('[WebNotificationListener] 📬 Message received from Service Worker');
        debugPrint('[WebNotificationListener] Data: $data');
        
        if (data is Map) {
          final type = data['type'] as String?;
          final callData = data['data'] as Map?;
          
          if (type == 'incoming_call' && callData != null) {
            debugPrint('[WebNotificationListener] 📞 Incoming call detected');
            debugPrint('[WebNotificationListener] Call data: $callData');
            
            // Convert to Map<String, dynamic>
            final callDataMap = <String, dynamic>{};
            callData.forEach((key, value) {
              callDataMap[key.toString()] = value;
            });
            
            // Handle incoming call
            CallNavigationService().handleCallNotification(callDataMap);
          }
        }
      });
      
      _isListening = true;
      debugPrint('[WebNotificationListener] ✅ Service Worker listener activated');
    } catch (e) {
      debugPrint('[WebNotificationListener] ❌ Failed to set up listener: $e');
    }
  }

  /// Stop listening to Service Worker messages
  static void stopListening() {
    if (!kIsWeb || !_isListening) {
      return;
    }

    try {
      // Note: Cannot remove event listeners added via addEventListener
      // This is a limitation of the current implementation
      _isListening = false;
      debugPrint('[WebNotificationListener] 🔇 Service Worker listener deactivated');
    } catch (e) {
      debugPrint('[WebNotificationListener] ❌ Failed to stop listener: $e');
    }
  }
}
