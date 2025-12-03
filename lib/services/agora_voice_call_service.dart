import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Agora Voice Call Service - LINE/WhatsApp-level voice calling
/// 
/// Features:
/// - Audio-only voice calls with high quality
/// - Automatic echo cancellation and noise suppression
/// - Support for Web and Android platforms
/// - Real-time connection status monitoring
class AgoraVoiceCallService {
  // Singleton pattern
  static final AgoraVoiceCallService _instance = AgoraVoiceCallService._internal();
  factory AgoraVoiceCallService() => _instance;
  AgoraVoiceCallService._internal();

  // Agora Configuration
  static const String appId = 'd1a8161eb70448d89eea1722bc169c92';
  
  // Agora Engine
  RtcEngine? _engine;
  
  // Call State
  bool _isInitialized = false;
  bool _isInCall = false;
  String? _currentChannelName;
  int? _remoteUid;
  
  // Event Callbacks
  Function(String userId)? onUserJoined;
  Function(String userId)? onUserLeft;
  Function(ConnectionStateType state)? onConnectionStateChanged;
  Function(String error)? onError;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isInCall => _isInCall;
  String? get currentChannelName => _currentChannelName;
  int? get remoteUid => _remoteUid;

  /// Initialize Agora RTC Engine
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[Agora] Already initialized');
      return;
    }

    try {
      debugPrint('[Agora] Initializing with App ID: $appId');
      
      // Request microphone permission
      await _requestPermission();

      // Create Agora RTC Engine
      _engine = createAgoraRtcEngine();
      
      // Initialize the engine
      await _engine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // Register event handlers
      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('[Agora] Successfully joined channel: ${connection.channelId}');
          _isInCall = true;
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('[Agora] Remote user joined: $remoteUid');
          _remoteUid = remoteUid;
          onUserJoined?.call(remoteUid.toString());
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint('[Agora] Remote user left: $remoteUid, reason: $reason');
          _remoteUid = null;
          onUserLeft?.call(remoteUid.toString());
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint('[Agora] Left channel');
          _isInCall = false;
          _currentChannelName = null;
          _remoteUid = null;
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          debugPrint('[Agora] Connection state changed: $state, reason: $reason');
          onConnectionStateChanged?.call(state);
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[Agora] Error: $err, message: $msg');
          onError?.call('Error $err: $msg');
        },
      ));

      // Enable audio
      await _engine!.enableAudio();
      
      // Set audio profile for voice call
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: AudioScenarioType.audioScenarioGameStreaming,
      );

      _isInitialized = true;
      debugPrint('[Agora] Initialization completed successfully');
    } catch (e) {
      debugPrint('[Agora] Initialization failed: $e');
      onError?.call('Initialization failed: $e');
      rethrow;
    }
  }

  /// Request microphone permission
  Future<void> _requestPermission() async {
    if (kIsWeb) {
      // Web platform - browser handles permissions
      debugPrint('[Agora] Web platform - skipping permission request');
      return;
    }

    // Mobile platform - request microphone permission
    final status = await Permission.microphone.request();
    
    if (!status.isGranted) {
      throw Exception('Microphone permission denied');
    }
    
    debugPrint('[Agora] Microphone permission granted');
  }

  /// Join a voice call channel
  Future<void> joinChannel(String channelName, {String? token, int uid = 0}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isInCall) {
      debugPrint('[Agora] Already in a call, leaving current channel first');
      await leaveChannel();
    }

    try {
      debugPrint('[Agora] Joining channel: $channelName with uid: $uid');
      
      _currentChannelName = channelName;

      // Join the channel
      await _engine!.joinChannel(
        token: token ?? '', // Use empty string if no token provided
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
        ),
      );

      debugPrint('[Agora] Join channel request sent');
    } catch (e) {
      debugPrint('[Agora] Failed to join channel: $e');
      onError?.call('Failed to join channel: $e');
      rethrow;
    }
  }

  /// Leave the current voice call channel
  Future<void> leaveChannel() async {
    if (!_isInCall) {
      debugPrint('[Agora] Not in a call');
      return;
    }

    try {
      debugPrint('[Agora] Leaving channel: $_currentChannelName');
      
      await _engine?.leaveChannel();
      
      _isInCall = false;
      _currentChannelName = null;
      _remoteUid = null;
      
      debugPrint('[Agora] Successfully left channel');
    } catch (e) {
      debugPrint('[Agora] Failed to leave channel: $e');
      onError?.call('Failed to leave channel: $e');
    }
  }

  /// Mute/Unmute local microphone
  Future<void> muteLocalAudio(bool muted) async {
    if (!_isInitialized) {
      debugPrint('[Agora] Not initialized');
      return;
    }

    try {
      await _engine?.muteLocalAudioStream(muted);
      debugPrint('[Agora] Local audio ${muted ? "muted" : "unmuted"}');
    } catch (e) {
      debugPrint('[Agora] Failed to mute/unmute: $e');
      onError?.call('Failed to mute/unmute: $e');
    }
  }

  /// Enable/Disable speaker
  Future<void> setEnableSpeakerphone(bool enabled) async {
    if (!_isInitialized) {
      debugPrint('[Agora] Not initialized');
      return;
    }

    try {
      await _engine?.setEnableSpeakerphone(enabled);
      debugPrint('[Agora] Speakerphone ${enabled ? "enabled" : "disabled"}');
    } catch (e) {
      debugPrint('[Agora] Failed to toggle speakerphone: $e');
      onError?.call('Failed to toggle speakerphone: $e');
    }
  }

  /// Dispose and clean up resources
  Future<void> dispose() async {
    if (_isInCall) {
      await leaveChannel();
    }

    if (_isInitialized) {
      await _engine?.release();
      _engine = null;
      _isInitialized = false;
      debugPrint('[Agora] Resources released');
    }
  }
}
