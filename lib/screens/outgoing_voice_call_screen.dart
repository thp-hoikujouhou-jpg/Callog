import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/webrtc_call_service.dart';
import 'dart:async';

/// Outgoing Voice Call Screen with WebRTC
/// Callog-style interface for making voice calls
class OutgoingVoiceCallScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String? friendPhotoUrl;

  const OutgoingVoiceCallScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendPhotoUrl,
  }) : assert(friendId != '', 'friendId cannot be empty'),
       assert(friendName != '', 'friendName cannot be empty');

  @override
  State<OutgoingVoiceCallScreen> createState() => _OutgoingVoiceCallScreenState();
}

class _OutgoingVoiceCallScreenState extends State<OutgoingVoiceCallScreen> {
  final WebRTCCallService _webrtcService = WebRTCCallService();
  String _callDuration = '00:00';
  DateTime? _callStartTime;
  Timer? _durationTimer;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  String _callStatus = 'Calling...';
  bool _isInitializing = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('📱 OutgoingVoiceCallScreen.initState() called');
      debugPrint('   Target: ${widget.friendName} (${widget.friendId})');
      debugPrint('   Photo URL: ${widget.friendPhotoUrl}');
      debugPrint('   _isInitializing: $_isInitializing');
    }
    
    // Ensure initialization starts on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kDebugMode) {
        debugPrint('📱 Post-frame callback: Starting call initialization...');
      }
      _initializeCall();
    });
  }

  Future<void> _initializeCall() async {
    try {
      if (kDebugMode) {
        debugPrint('🔧 Initializing WebRTC call...');
      }
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('❌ User not authenticated');
        }
        setState(() {
          _initError = 'User not authenticated';
          _isInitializing = false;
        });
        return;
      }

      if (kDebugMode) {
        debugPrint('✅ Current user: ${currentUser.uid}');
        debugPrint('🔌 Initializing WebRTC service...');
      }

      // Initialize WebRTC service
      final initialized = await _webrtcService.initialize(currentUser.uid);
      
      if (kDebugMode) {
        debugPrint('WebRTC service initialized: $initialized');
      }

      if (!initialized) {
        setState(() {
          _initError = 'Failed to connect to signaling server';
          _isInitializing = false;
        });
        return;
      }

      // Set up callbacks
      _webrtcService.onRemoteStream = (stream) {
        if (kDebugMode) {
          debugPrint('📞 Remote stream received!');
        }
        setState(() {
          _isConnected = true;
          _callStatus = 'Connected';
          _callStartTime = DateTime.now();
        });
        _startDurationTimer();
      };

      _webrtcService.onCallEnded = (reason) {
        if (kDebugMode) {
          debugPrint('📞 Call ended: $reason');
        }
        _endCall();
      };

      _webrtcService.onConnectionStateChanged = (connected) {
        if (kDebugMode) {
          debugPrint('🔌 Connection state changed: $connected');
        }
        setState(() {
          _isConnected = connected;
          if (!connected) {
            _callStatus = 'Disconnected';
          }
        });
      };

      if (kDebugMode) {
        debugPrint('📞 Making call to ${widget.friendId}...');
      }

      // Make the call
      final success = await _webrtcService.makeCall(widget.friendId);
      
      if (kDebugMode) {
        debugPrint('📞 Call initiation result: $success');
      }
      
      setState(() {
        _isInitializing = false;
      });
      
      if (!success) {
        setState(() {
          _initError = 'Failed to initiate call';
        });
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error initializing call: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      setState(() {
        _initError = 'Error initializing call: $e';
        _isInitializing = false;
      });
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_callStartTime != null && mounted) {
        setState(() {
          final duration = DateTime.now().difference(_callStartTime!);
          _callDuration = _formatDuration(duration);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _endCall() async {
    _durationTimer?.cancel();
    await _webrtcService.endCall();
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('🎨 OutgoingVoiceCallScreen.build() called - _isInitializing: $_isInitializing, _initError: $_initError');
    }
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Show loading screen during initialization
    if (_isInitializing) {
      if (kDebugMode) {
        debugPrint('⏳ Showing loading screen...');
      }
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF1a1a2e) : Colors.white,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  'Connecting...',
                  style: TextStyle(
                    fontSize: 18,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Show error screen if initialization failed
    if (_initError != null) {
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF1a1a2e) : Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connection Failed',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _initError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1a1a2e) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Text(
                    'Voice Call',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    onPressed: _endCall,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Friend avatar
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade700,
              ),
              child: widget.friendPhotoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        widget.friendPhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.white,
                    ),
            ),

            const SizedBox(height: 24),

            // Friend name
            Text(
              widget.friendName,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),

            const SizedBox(height: 12),

            // Call status
            Text(
              _callStatus,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),

            // Call duration (shown when connected)
            if (_isConnected) ...[
              const SizedBox(height: 8),
              Text(
                _callDuration,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],

            const Spacer(),

            // Control buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Speaker button
                  _CallControlButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                    label: 'Speaker',
                    isActive: _isSpeakerOn,
                    onPressed: () {
                      setState(() {
                        _isSpeakerOn = !_isSpeakerOn;
                      });
                      // TODO: Implement speaker toggle in WebRTC service
                    },
                    isDarkMode: isDarkMode,
                  ),

                  // Mute button
                  _CallControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: 'Mute',
                    isActive: _isMuted,
                    onPressed: () {
                      setState(() {
                        _isMuted = !_isMuted;
                      });
                      // TODO: Implement mute toggle in WebRTC service
                    },
                    isDarkMode: isDarkMode,
                  ),

                  // End call button
                  _CallControlButton(
                    icon: Icons.call_end,
                    label: 'End',
                    isActive: false,
                    backgroundColor: Colors.red,
                    onPressed: _endCall,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// Call Control Button Widget
class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final bool isDarkMode;

  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
    this.backgroundColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ??
        (isActive
            ? (isDarkMode ? Colors.blue[700] : Colors.blue)
            : (isDarkMode ? Colors.grey[800] : Colors.grey[300]));
    
    final iconColor = backgroundColor != null || isActive
        ? Colors.white
        : (isDarkMode ? Colors.white : Colors.black87);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bgColor,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Icon(
                icon,
                size: 28,
                color: iconColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
