import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/agora_voice_call_service.dart';
import '../services/agora_token_service.dart';
import '../services/call_history_service.dart';
import '../services/push_notification_service.dart';
import '../services/auth_service.dart';
import '../utils/image_proxy.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

/// Agora Voice Call Screen - LINE/WhatsApp-level voice calling UI
/// 
/// Features:
/// - Clean, modern voice call interface
/// - Real-time connection status
/// - Mute/unmute microphone
/// - Speaker on/off toggle
/// - Call duration timer
class AgoraVoiceCallScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String? friendPhotoUrl;
  final String? channelName; // Optional: Use existing channel for incoming calls
  final bool isIncoming; // true = incoming call (don't send notification)

  const AgoraVoiceCallScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendPhotoUrl,
    this.channelName,
    this.isIncoming = false, // Default: outgoing call
  });

  @override
  State<AgoraVoiceCallScreen> createState() => _AgoraVoiceCallScreenState();
}

class _AgoraVoiceCallScreenState extends State<AgoraVoiceCallScreen> {
  final AgoraVoiceCallService _callService = AgoraVoiceCallService();
  final CallHistoryService _historyService = CallHistoryService();
  
  // Call State
  bool _isConnecting = true;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  int _callDuration = 0;
  Timer? _callTimer;
  String _connectionStatus = '接続中...';
  DateTime? _callStartTime;
  
  @override
  void initState() {
    super.initState();
    debugPrint('🎬 [Agora Screen] Initializing voice call screen');
    _initializeCall();
  }

  @override
  void dispose() {
    debugPrint('🧹 [Agora Screen] Disposing voice call screen');
    _callTimer?.cancel();
    // Don't auto-end call on dispose - let user explicitly end it
    // _endCall();
    super.dispose();
  }

  /// Initialize Agora call
  Future<void> _initializeCall() async {
    try {
      debugPrint('🚀 [Agora Screen] Starting call initialization...');
      
      // Initialize Agora engine FIRST
      await _callService.initialize();
      debugPrint('✅ [Agora Screen] Agora engine initialized');
      
      // Set up event handlers AFTER initialization
      _callService.onUserJoined = (userId) {
        debugPrint('✅ [Agora Screen] User joined: $userId');
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _isConnected = true;
            _connectionStatus = '通話中';
            _callStartTime = DateTime.now();
          });
          _startCallTimer();
          
          // Log call start
          _historyService.logCallStart(
            friendId: widget.friendId,
            callType: 'voice',
            direction: 'outgoing',
          );
        }
      };
      
      _callService.onUserLeft = (userId) {
        debugPrint('👋 [Agora Screen] User left: $userId');
        if (mounted) {
          _endCallAndReturn();
        }
      };
      
      _callService.onConnectionStateChanged = (state) {
        debugPrint('📡 [Agora Screen] Connection state: $state');
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
        debugPrint('❌ [Agora Screen] Error: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('通話エラー: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      };
      
      // Use provided channel name or generate one
      final channelName = widget.channelName ?? _generateChannelName(widget.friendId);
      debugPrint('📞 [Agora Screen] Joining channel: $channelName');
      debugPrint('📞 [Agora Screen] Call type: ${widget.isIncoming ? "Incoming" : "Outgoing"}');
      
      // Generate Agora token using Cloud Functions
      String? token;
      try {
        final tokenService = AgoraTokenService();
        final tokenData = await tokenService.generateToken(
          channelName: channelName,
          uid: 0, // 0 means Agora will auto-assign UID
          role: 'publisher',
        );
        token = tokenData['token'];
        debugPrint('✅ [Agora Screen] Token generated: ${token != null ? "Yes" : "No (using null token)"}');
      } catch (e) {
        debugPrint('⚠️ [Agora Screen] Failed to generate token: $e');
        debugPrint('⚠️ [Agora Screen] Continuing with null token...');
      }
      
      // Join the channel with token
      await _callService.joinChannel(channelName, token: token);
      debugPrint('✅ [Agora Screen] Join channel request sent');
      
      // Web SDK workaround: Force connection after timeout if onUserJoined doesn't fire
      if (kIsWeb) {
        debugPrint('🌐 [Agora Screen] Web: Setting up connection timeout (5 seconds)');
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _isConnecting && !_isConnected) {
            debugPrint('⏰ [Agora Screen] Timeout: Force-connecting to call (Web workaround)');
            debugPrint('💡 [Agora Screen] This is normal for Web - continuing to call state');
            setState(() {
              _isConnecting = false;
              _isConnected = true;
              _connectionStatus = '通話中';
              _callStartTime = DateTime.now();
            });
            _startCallTimer();
            
            // Log call start
            _historyService.logCallStart(
              friendId: widget.friendId,
              callType: 'voice',
              direction: widget.isIncoming ? 'incoming' : 'outgoing',
            );
          }
        });
      }
      
      // Send push notification to peer (only for outgoing calls)
      if (!widget.isIncoming) {
        try {
          final pushService = PushNotificationService();
          final authService = AuthService();
          final currentUser = authService.currentUser;
          
          // Get caller name from Firestore (prioritize displayName)
          String callerName = '不明なユーザー';
          if (currentUser != null) {
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .get();
              
              if (userDoc.exists) {
                final userData = userDoc.data();
                // Priority: displayName > username > email > fallback
                callerName = userData?['displayName'] as String? ?? 
                           userData?['username'] as String? ??
                           currentUser.email?.split('@')[0] ?? 
                           '不明なユーザー';
                debugPrint('📝 [Agora Screen] Caller display name from Firestore: $callerName');
              }
            } catch (e) {
              debugPrint('⚠️ [Agora Screen] Failed to fetch caller name from Firestore: $e');
              callerName = currentUser.displayName ?? 
                          currentUser.email?.split('@')[0] ?? 
                          '不明なユーザー';
            }
          }
          
          await pushService.sendCallNotification(
            peerId: widget.friendId,
            channelId: channelName,
            callType: 'voice_call',
            callerName: callerName,
          );
          debugPrint('📲 [Agora Screen] Push notification sent to peer');
        } catch (e) {
          debugPrint('⚠️ [Agora Screen] Failed to send push notification: $e');
        }
      } else {
        debugPrint('📲 [Agora Screen] Incoming call - skipping notification');
      }
      
    } catch (e) {
      debugPrint('❌ [Agora Screen] Initialization failed: $e');
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
            title: const Text('⚠️ 音声通話エラー'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('通話の開始に失敗しました。'),
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
    return 'call_${sortedIds[0]}_${sortedIds[1]}';
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

  /// Toggle speaker on/off
  Future<void> _toggleSpeaker() async {
    await _callService.setEnableSpeakerphone(!_isSpeakerOn);
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  /// End call
  Future<void> _endCall() async {
    debugPrint('🔴 [Agora Screen] Ending call...');
    _callTimer?.cancel();
    
    // Log call end
    final callStartTime = _callStartTime;
    if (callStartTime != null) {
      final duration = DateTime.now().difference(callStartTime).inSeconds;
      await _historyService.logCallEnd(
        friendId: widget.friendId,
        callType: 'voice',
        direction: 'outgoing',
        durationSeconds: duration,
        status: _isConnected ? 'completed' : 'failed',
      );
    }
    
    await _callService.leaveChannel();
  }

  /// End call and return to previous screen
  void _endCallAndReturn() {
    _endCall();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.all(16.0),
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

            const Spacer(),

            // User avatar and name
            Column(
              children: [
                // Avatar
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.shade700,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
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

                // Friend name
                Text(
                  widget.friendName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // Connection indicator
                if (_isConnecting)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.greenAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '接続中...',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                else if (_isConnected)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '通話中',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const Spacer(),

            // Control buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Speaker button
                  _buildControlButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                    label: 'スピーカー',
                    onPressed: _toggleSpeaker,
                    backgroundColor: _isSpeakerOn ? Colors.white : Colors.grey.shade700,
                    iconColor: _isSpeakerOn ? Colors.grey.shade900 : Colors.white,
                  ),

                  // Mute button
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: 'ミュート',
                    onPressed: _toggleMute,
                    backgroundColor: _isMuted ? Colors.red : Colors.white,
                    iconColor: _isMuted ? Colors.white : Colors.grey.shade900,
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
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
