import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Agora Video Call Service - LINE/WhatsApp-level video calling
/// 
/// Features:
/// - High-quality video calls with audio
/// - Camera switching (front/back)
/// - Video enable/disable
/// - Audio mute/unmute
/// - Speaker on/off
/// - Real-time connection status monitoring
class AgoraVideoCallService {
  // Singleton pattern
  static final AgoraVideoCallService _instance = AgoraVideoCallService._internal();
  factory AgoraVideoCallService() => _instance;
  AgoraVideoCallService._internal();

  // Agora Configuration
  static const String appId = 'd1a8161eb70448d89eea1722bc169c92';
  
  // Agora Engine (public for video view controllers)
  RtcEngine? engine;
  
  // Call State
  bool _isInitialized = false;
  bool _isInCall = false;
  String? _currentChannelName;
  int? _remoteUid;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;
  
  // Event Callbacks
  Function(int userId)? onUserJoined;
  Function(int userId)? onUserLeft;
  Function(ConnectionStateType state)? onConnectionStateChanged;
  Function(String error)? onError;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isInCall => _isInCall;
  String? get currentChannelName => _currentChannelName;
  int? get remoteUid => _remoteUid;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isFrontCamera => _isFrontCamera;

  /// Initialize Agora RTC Engine
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[AgoraVideo] Already initialized');
      return;
    }

    // Web platform support
    if (kIsWeb) {
      debugPrint('[AgoraVideo] ✅ Web platform detected - using Agora Web SDK');
    }

    try {
      debugPrint('[AgoraVideo] Initializing with App ID: $appId');
      
      // Request permissions
      await _requestPermissions();

      // Create Agora RTC Engine
      debugPrint('[AgoraVideo] Creating RTC Engine...');
      try {
        engine = createAgoraRtcEngine();
        debugPrint('[AgoraVideo] RTC Engine created: ${engine != null}');
        
        if (engine == null) {
          debugPrint('[AgoraVideo] ❌ createAgoraRtcEngine returned null');
          debugPrint('[AgoraVideo] ℹ️ This may indicate missing Agora Web SDK');
          throw Exception('Agora Video Engine initialization failed: createAgoraRtcEngine returned null. Please ensure Agora Web SDK is properly loaded.');
        }
        debugPrint('[AgoraVideo] ✅ RTC Engine created successfully');
      } catch (e) {
        debugPrint('[AgoraVideo] Failed to create engine: $e');
        rethrow;
      }
      
      // Verify engine is not null before proceeding
      final currentEngine = engine;
      if (currentEngine == null) {
        throw Exception('Engine is null after creation');
      }
      
      // Now currentEngine is promoted to non-nullable type
      final localEngine = currentEngine;
      
      // Initialize the engine with proper error handling
      debugPrint('[AgoraVideo] Initializing engine with context...');
      try {
        debugPrint('[AgoraVideo] Creating context with appId=${appId.substring(0, 8)}...');
        
        final context = RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          // Web platform specific settings
          areaCode: AreaCode.areaCodeGlob.value(),
        );
        
        debugPrint('[AgoraVideo] Context created successfully');
        debugPrint('[AgoraVideo] Calling initialize on engine...');
        
        try {
          await localEngine.initialize(context);
          debugPrint('[AgoraVideo] ✅ Engine initialized successfully');
        } catch (initError) {
          debugPrint('[AgoraVideo] ❌ Initialize method failed: $initError');
          debugPrint('[AgoraVideo] ℹ️ Error details: ${initError.toString()}');
          rethrow;
        }
      } catch (e) {
        debugPrint('[AgoraVideo] ❌ Engine initialization failed: $e');
        debugPrint('[AgoraVideo] ℹ️ Error type: ${e.runtimeType}');
        rethrow;
      }

      // Register event handlers
      localEngine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('[AgoraVideo] Successfully joined channel: ${connection.channelId ?? "unknown"}');
          _isInCall = true;
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('[AgoraVideo] Remote user joined: $remoteUid');
          _remoteUid = remoteUid;
          onUserJoined?.call(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint('[AgoraVideo] Remote user left: $remoteUid, reason: $reason');
          _remoteUid = null;
          onUserLeft?.call(remoteUid);
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint('[AgoraVideo] Left channel');
          _isInCall = false;
          _currentChannelName = null;
          _remoteUid = null;
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          debugPrint('[AgoraVideo] Connection state changed: $state, reason: $reason');
          onConnectionStateChanged?.call(state);
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[AgoraVideo] Error: $err, message: $msg');
          onError?.call('Error $err: $msg');
        },
      ));

      // Enable video
      await localEngine.enableVideo();
      
      // Enable audio
      await localEngine.enableAudio();
      
      // Set video configuration for high quality
      await localEngine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 1280, height: 720),
          frameRate: 30,
          bitrate: 2000,
          orientationMode: OrientationMode.orientationModeAdaptive,
        ),
      );

      _isInitialized = true;
      debugPrint('[AgoraVideo] Initialization completed successfully');
    } catch (e) {
      debugPrint('[AgoraVideo] Initialization failed: $e');
      onError?.call('Initialization failed: $e');
      rethrow;
    }
  }

  /// Request camera and microphone permissions
  Future<void> _requestPermissions() async {
    if (kIsWeb) {
      // Web platform - browser handles permissions
      debugPrint('[AgoraVideo] Web platform - skipping permission request');
      return;
    }

    // Mobile platform - request camera and microphone permissions
    final cameraStatus = await Permission.camera.request();
    final microphoneStatus = await Permission.microphone.request();
    
    if (!cameraStatus.isGranted || !microphoneStatus.isGranted) {
      throw Exception('Camera or microphone permission denied');
    }
    
    debugPrint('[AgoraVideo] Camera and microphone permissions granted');
  }

  /// Join a video call channel
  Future<void> joinChannel(String channelName, {String? token, int uid = 0}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isInCall) {
      debugPrint('[AgoraVideo] Already in a call, leaving current channel first');
      await leaveChannel();
    }

    try {
      debugPrint('[AgoraVideo] Joining channel: $channelName with uid: $uid');
      
      final localEngine = engine;
      if (localEngine == null) {
        throw Exception('Agora video engine is not initialized');
      }
      
      _currentChannelName = channelName;

      // Enable local video preview
      await localEngine.startPreview();

      // Join the channel
      await localEngine.joinChannel(
        token: token ?? '',
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );

      debugPrint('[AgoraVideo] Join channel request sent');
    } catch (e) {
      debugPrint('[AgoraVideo] Failed to join channel: $e');
      onError?.call('Failed to join channel: $e');
      rethrow;
    }
  }

  /// Leave the current video call channel
  Future<void> leaveChannel() async {
    if (!_isInCall) {
      debugPrint('[AgoraVideo] Not in a call');
      return;
    }

    try {
      debugPrint('[AgoraVideo] Leaving channel: $_currentChannelName');
      
      await engine?.stopPreview();
      await engine?.leaveChannel();
      
      _isInCall = false;
      _currentChannelName = null;
      _remoteUid = null;
      
      debugPrint('[AgoraVideo] Successfully left channel');
    } catch (e) {
      debugPrint('[AgoraVideo] Failed to leave channel: $e');
      onError?.call('Failed to leave channel: $e');
    }
  }

  /// Toggle video on/off
  Future<void> toggleVideo() async {
    if (!_isInitialized) {
      debugPrint('[AgoraVideo] Not initialized');
      return;
    }

    try {
      _isVideoEnabled = !_isVideoEnabled;
      await engine?.enableLocalVideo(_isVideoEnabled);
      debugPrint('[AgoraVideo] Video ${_isVideoEnabled ? "enabled" : "disabled"}');
    } catch (e) {
      debugPrint('[AgoraVideo] Failed to toggle video: $e');
      onError?.call('Failed to toggle video: $e');
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (!_isInitialized) {
      debugPrint('[AgoraVideo] Not initialized');
      return;
    }

    try {
      await engine?.switchCamera();
      _isFrontCamera = !_isFrontCamera;
      debugPrint('[AgoraVideo] Switched to ${_isFrontCamera ? "front" : "back"} camera');
    } catch (e) {
      debugPrint('[AgoraVideo] Failed to switch camera: $e');
      onError?.call('Failed to switch camera: $e');
    }
  }

  /// Mute/Unmute local microphone
  Future<void> muteLocalAudio(bool muted) async {
    if (!_isInitialized) {
      debugPrint('[AgoraVideo] Not initialized');
      return;
    }

    try {
      await engine?.muteLocalAudioStream(muted);
      debugPrint('[AgoraVideo] Local audio ${muted ? "muted" : "unmuted"}');
    } catch (e) {
      debugPrint('[AgoraVideo] Failed to mute/unmute: $e');
      onError?.call('Failed to mute/unmute: $e');
    }
  }

  /// Enable/Disable local video
  Future<void> muteLocalVideo(bool muted) async {
    if (!_isInitialized) {
      debugPrint('[AgoraVideo] Not initialized');
      return;
    }

    try {
      await engine?.muteLocalVideoStream(muted);
      debugPrint('[AgoraVideo] Local video ${muted ? "disabled" : "enabled"}');
    } catch (e) {
      debugPrint('[AgoraVideo] Failed to toggle video: $e');
      onError?.call('Failed to toggle video: $e');
    }
  }

  /// Enable/Disable speaker
  Future<void> setEnableSpeakerphone(bool enabled) async {
    if (!_isInitialized) {
      debugPrint('[AgoraVideo] Not initialized');
      return;
    }

    try {
      await engine?.setEnableSpeakerphone(enabled);
      debugPrint('[AgoraVideo] Speakerphone ${enabled ? "enabled" : "disabled"}');
    } catch (e) {
      debugPrint('[AgoraVideo] Failed to toggle speakerphone: $e');
      onError?.call('Failed to toggle speakerphone: $e');
    }
  }

  /// Dispose and clean up resources
  Future<void> dispose() async {
    if (_isInCall) {
      await leaveChannel();
    }

    if (_isInitialized) {
      await engine?.release();
      engine = null;
      _isInitialized = false;
      debugPrint('[AgoraVideo] Resources released');
    }
  }
}
