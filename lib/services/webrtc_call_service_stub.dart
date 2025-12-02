// Stub implementation for platforms without WebRTC support
import 'package:flutter/foundation.dart';

class WebRTCCallService {
  static final WebRTCCallService _instance = WebRTCCallService._internal();
  factory WebRTCCallService() => _instance;
  WebRTCCallService._internal();

  Function(dynamic)? onRemoteStream;
  Function(String)? onCallEnded;
  Function(Map<String, dynamic>)? onIncomingCall;
  Function(bool)? onConnectionStateChanged;

  Future<bool> initialize(String userId) async {
    if (kDebugMode) {
      debugPrint('⚠️ WebRTC not supported');
    }
    return false;
  }

  Future<bool> makeCall(String targetUserId) async {
    if (kDebugMode) {
      debugPrint('⚠️ WebRTC makeCall not supported');
    }
    return false;
  }

  Future<void> answerCall(Map<String, dynamic> offer) async {
    if (kDebugMode) {
      debugPrint('⚠️ WebRTC answerCall not supported');
    }
  }

  Future<void> endCall() async {
    if (kDebugMode) {
      debugPrint('⚠️ WebRTC endCall not supported');
    }
  }

  void toggleMute() {}
  void toggleSpeaker() {}

  bool get isMuted => false;
  bool get isSpeakerOn => false;
  dynamic get localStream => null;
  dynamic get remoteStream => null;
}
