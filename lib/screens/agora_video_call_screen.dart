import 'package:flutter/material.dart';
import 'dart:async';
import '../services/agora_video_call_service.dart';
import '../services/call_history_service.dart';
import '../services/push_notification_service.dart';
import '../services/auth_service.dart';
import '../utils/image_proxy.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

/// Agora Video Call Screen - LINE/WhatsApp-level video calling UI
/// 
/// Features:
/// - HD video calling interface
/// - Picture-in-picture local video
/// - Camera switching (front/back)
/// - Video mute/unmute
/// - Audio mute/unmute
/// - Call duration timer
class AgoraVideoCallScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String? friendPhotoUrl;
  final String? channelName; // Optional: Use existing channel for incoming calls
  final bool isIncoming; // true = incoming call (don't send notification)

  const AgoraVideoCallScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendPhotoUrl,
    this.channelName,
    this.isIncoming = false, // Default: outgoing call
  });

  @override
  State<AgoraVideoCallScreen> createState() => _AgoraVideoCallScreenState();
}

class _AgoraVideoCallScreenState extends State<AgoraVideoCallScreen> {
  final AgoraVideoCallService _callService = AgoraVideoCallService();
  final CallHistoryService _historyService = CallHistoryService();
  
  // Call State
  bool _isConnecting = true;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  int _callDuration = 0;
  Timer? _callTimer;
  String _connectionStatus = '接続中...';
  int? _remoteUid;
  DateTime? _callStartTime;
  
  @override
  void initState() {
    super.initState();
    debugPrint('🎬 [Agora Video] Initializing video call screen');
    _initializeCall();
  }

  @override
  void dispose() {
    debugPrint('🧹 [Agora Video] Disposing video call screen');
    _callTimer?.cancel();
    // Don't auto-end call on dispose - let user explicitly end it
    // _endCall();
    super.dispose();
  }

  /// Initialize Agora video call
  Future<void> _initializeCall() async {
    try {
      debugPrint('🚀 [Agora Video] Starting call initialization...');
      
      // Set up event handlers
      _callService.onUserJoined = (userId) {
        debugPrint('✅ [Agora Video] User joined: $userId');
        setState(() {
          _isConnecting = false;
          _isConnected = true;
          _connectionStatus = 'ビデオ通話中';
          _remoteUid = userId;
          _callStartTime = DateTime.now();
        });
        _startCallTimer();
        
        // Log call start
        _historyService.logCallStart(
          friendId: widget.friendId,
          callType: 'video',
          direction: 'outgoing',
        );
      };
      
      _callService.onUserLeft = (userId) {
        debugPrint('👋 [Agora Video] User left: $userId');
        if (mounted) {
          _endCallAndReturn();
        }
      };
      
      _callService.onConnectionStateChanged = (state) {
        debugPrint('📡 [Agora Video] Connection state: $state');
        if (mounted) {
          setState(() {
            switch (state) {
              case ConnectionStateType.connectionStateConnecting:
                _connectionStatus = '接続中...';
                break;
              case ConnectionStateType.connectionStateConnected:
                _connectionStatus = '接続完了';
                break;
              case ConnectionStateType.connectionStateReconnecting:
                _connectionStatus = '再接続中...';
                break;
              case ConnectionStateType.connectionStateFailed:
                _connectionStatus = '接続失敗';
                break;
              case ConnectionStateType.connectionStateDisconnected:
                _connectionStatus = '切断されました';
                break;
            }
          });
        }
      };
      
      _callService.onError = (error) {
        debugPrint('❌ [Agora Video] Error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('通話エラー: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      };

      // Initialize Agora engine
      await _callService.initialize();
      debugPrint('✅ [Agora Video] Agora engine initialized');
      
      // Use provided channel name or generate one
      final channelName = widget.channelName ?? _generateChannelName(widget.friendId);
      debugPrint('📞 [Agora Video] Joining channel: $channelName');
      debugPrint('📞 [Agora Video] Call type: ${widget.isIncoming ? "Incoming" : "Outgoing"}');
      
      // Join the channel
      await _callService.joinChannel(channelName);
      debugPrint('✅ [Agora Video] Join channel request sent');
      
      // Send push notification to peer (only for outgoing calls)
      if (!widget.isIncoming) {
        try {
          final pushService = PushNotificationService();
          final authService = AuthService();
          final currentUser = authService.currentUser;
          final callerName = currentUser?.displayName ?? 
                            currentUser?.email?.split('@')[0] ?? 
                            '不明なユーザー';
          
          await pushService.sendCallNotification(
            peerId: widget.friendId,
            channelId: channelName,
            callType: 'video_call',
            callerName: callerName,
          );
          debugPrint('📲 [Agora Video] Push notification sent to peer');
        } catch (e) {
          debugPrint('⚠️ [Agora Video] Failed to send push notification: $e');
        }
      } else {
        debugPrint('📲 [Agora Video] Incoming call - skipping notification');
      }
      
    } catch (e) {
      debugPrint('❌ [Agora Video] Initialization failed: $e');
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectionStatus = '接続失敗';
        });
        
        // Show user-friendly error message with details
        final errorMessage = e.toString();
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ ビデオ通話エラー'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ビデオ通話の開始に失敗しました。'),
                  const SizedBox(height: 12),
                  const Text('エラー詳細:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(errorMessage, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close call screen
                },
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Generate consistent channel name for both users
  String _generateChannelName(String friendId) {
    // Generate channel name that's the same regardless of who calls
    final authService = AuthService();
    final currentUserId = authService.currentUser?.uid ?? '';
    
    // Sort user IDs to ensure same channel name for both users
    final sortedIds = [currentUserId, friendId]..sort();
    return 'video_${sortedIds[0]}_${sortedIds[1]}';
  }

  /// Start call duration timer
  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  /// Format call duration
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Toggle mute/unmute
  Future<void> _toggleMute() async {
    await _callService.muteLocalAudio(!_isMuted);
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  /// Toggle video on/off
  Future<void> _toggleVideo() async {
    await _callService.muteLocalVideo(!_isVideoOff);
    setState(() {
      _isVideoOff = !_isVideoOff;
    });
  }

  /// Switch camera (front/back)
  Future<void> _switchCamera() async {
    await _callService.switchCamera();
  }

  /// Toggle speaker on/off
  Future<void> _toggleSpeaker() async {
    await _callService.setEnableSpeakerphone(!_isSpeakerOn);
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  /// End call
  Future<void> _endCall() async {
    debugPrint('🔴 [Agora Video] Ending call...');
    _callTimer?.cancel();
    
    // Log call end
    final callStartTime = _callStartTime;
    if (callStartTime != null) {
      final duration = DateTime.now().difference(callStartTime).inSeconds;
      await _historyService.logCallEnd(
        friendId: widget.friendId,
        callType: 'video',
        direction: 'outgoing',
        durationSeconds: duration,
        status: _isConnected ? 'completed' : 'failed',
      );
    }
    
    await _callService.leaveChannel();
  }

  /// End call and return
  void _endCallAndReturn() {
    _endCall();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video (full screen)
            if (_remoteUid != null)
              _buildRemoteVideo()
            else
              _buildWaitingView(),

            // Top bar (status and duration)
            _buildTopBar(),

            // Local video (picture-in-picture)
            if (!_isVideoOff)
              _buildLocalVideo(),

            // Control buttons
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  /// Remote video view
  Widget _buildRemoteVideo() {
    final engine = _callService.engine;
    if (engine == null) {
      return const Center(child: Text('エンジンが初期化されていません'));
    }
    
    final channelName = _callService.currentChannelName;
    if (channelName == null) {
      return const Center(child: Text('チャンネル名が不明です'));
    }
    
    return SizedBox.expand(
      child: AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: channelName),
        ),
      ),
    );
  }

  /// Waiting view (before remote user joins)
  Widget _buildWaitingView() {
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade700,
              ),
              child: widget.friendPhotoUrl != null && widget.friendPhotoUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        ImageProxy.getCorsProxyUrl(widget.friendPhotoUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              widget.friendName.isNotEmpty ? widget.friendName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Text(
                        widget.friendName.isNotEmpty ? widget.friendName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.friendName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_isConnecting)
              const CircularProgressIndicator(
                color: Colors.greenAccent,
              ),
          ],
        ),
      ),
    );
  }

  /// Local video (picture-in-picture)
  Widget _buildLocalVideo() {
    return Positioned(
      top: 80,
      right: 16,
      child: Container(
        width: 120,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: () {
            final engine = _callService.engine;
            if (engine != null) {
              return AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: engine,
                  canvas: const VideoCanvas(uid: 0),
                ),
              );
            }
            return const Center(
              child: Icon(Icons.videocam_off, color: Colors.white, size: 40),
            );
          }(),
        ),
      ),
    );
  }

  /// Top bar
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _connectionStatus,
              style: TextStyle(
                color: _isConnected ? Colors.greenAccent : Colors.white70,
                fontSize: 14,
              ),
            ),
            if (_isConnected)
              Text(
                _formatDuration(_callDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Control buttons
  Widget _buildControlButtons() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Camera switch button
            _buildControlButton(
              icon: Icons.cameraswitch,
              label: 'カメラ',
              onPressed: _switchCamera,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              iconColor: Colors.white,
            ),

            // Video toggle button
            _buildControlButton(
              icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
              label: 'ビデオ',
              onPressed: _toggleVideo,
              backgroundColor: _isVideoOff ? Colors.red : Colors.white.withValues(alpha: 0.3),
              iconColor: Colors.white,
            ),

            // Mute button
            _buildControlButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: 'ミュート',
              onPressed: _toggleMute,
              backgroundColor: _isMuted ? Colors.red : Colors.white.withValues(alpha: 0.3),
              iconColor: Colors.white,
            ),

            // End call button
            _buildControlButton(
              icon: Icons.call_end,
              label: '終了',
              onPressed: _endCallAndReturn,
              backgroundColor: Colors.red,
              iconColor: Colors.white,
              isLarge: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color iconColor,
    bool isLarge = false,
  }) {
    final size = isLarge ? 72.0 : 60.0;
    final iconSize = isLarge ? 36.0 : 28.0;

    return Column(
      children: [
        Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(size / 2),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(size / 2),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size / 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: iconSize,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade300,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
