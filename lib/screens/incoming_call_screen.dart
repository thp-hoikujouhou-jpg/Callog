import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/image_proxy.dart';
import '../services/ringtone_service.dart';
import 'agora_voice_call_screen.dart';
import 'agora_video_call_screen.dart';

/// Incoming Call Screen - Answer or Decline incoming calls
/// 
/// Features:
/// - Full-screen incoming call notification
/// - Accept/Decline buttons
/// - Caller information display
/// - Ringtone (optional)
/// - Auto-timeout after 30 seconds
class IncomingCallScreen extends StatefulWidget {
  final String callerId;
  final String callerName;
  final String? callerPhotoUrl;
  final String callType; // 'voice_call' or 'video_call'
  final String channelId;

  const IncomingCallScreen({
    super.key,
    required this.callerId,
    required this.callerName,
    this.callerPhotoUrl,
    required this.callType,
    required this.channelId,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Timer? _timeoutTimer;
  int _remainingSeconds = 30;

  @override
  void initState() {
    super.initState();
    
    // Animation for pulsing avatar
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Auto-decline after 30 seconds
    _startTimeout();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timeoutTimer?.cancel();
    
    // Stop ringtone when screen is closed
    RingtoneService().stopRingtone();
    
    super.dispose();
  }

  void _startTimeout() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _declineCall();
      }
    });
  }

  void _acceptCall() async {
    _timeoutTimer?.cancel();
    
    // Stop ringtone
    RingtoneService().stopRingtone();
    
    // Navigate to appropriate call screen
    if (!mounted) return;

    debugPrint('[IncomingCall] 📞 Accepting call - using ANSWER screen (no notification sent)');
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) {
          if (widget.callType == 'video_call') {
            return AgoraVideoCallScreen(
              friendId: widget.callerId,
              friendName: widget.callerName,
              friendPhotoUrl: widget.callerPhotoUrl,
              channelName: widget.channelId, // Use existing channel
              isIncoming: true, // Mark as incoming call
            );
          } else {
            // Use voice call screen with incoming flag (DOES NOT send push notification)
            return AgoraVoiceCallScreen(
              friendId: widget.callerId,
              friendName: widget.callerName,
              friendPhotoUrl: widget.callerPhotoUrl,
              channelName: widget.channelId, // Use existing channel
              isIncoming: true, // Mark as incoming call
            );
          }
        },
      ),
    );
  }

  void _declineCall() {
    _timeoutTimer?.cancel();
    
    // Stop ringtone
    RingtoneService().stopRingtone();
    
    if (!mounted) return;
    
    // Return to previous screen
    Navigator.of(context).pop();
    
    // Show declined message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.callerName} からの通話を拒否しました'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVideoCall = widget.callType == 'video_call';
    final callTypeText = isVideoCall ? 'ビデオ通話' : '音声通話';
    final callIcon = isVideoCall ? Icons.videocam : Icons.phone;
    final callColor = isVideoCall ? Colors.blue : Colors.green;

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with timeout indicator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$callTypeText 着信',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$_remainingSeconds 秒',
                    style: TextStyle(
                      color: _remainingSeconds <= 10 ? Colors.red : Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Caller avatar with pulsing animation
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: callColor,
                  boxShadow: [
                    BoxShadow(
                      color: callColor.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: widget.callerPhotoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          ImageProxy.getCorsProxyUrl(widget.callerPhotoUrl ?? ''),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 60,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : Center(
                        child: Text(
                          widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 60,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 32),

            // Caller name
            Text(
              widget.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // Call type indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  callIcon,
                  color: callColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '$callTypeText がかかってきています',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline button
                  _buildActionButton(
                    icon: Icons.call_end,
                    label: '拒否',
                    backgroundColor: Colors.red,
                    onPressed: _declineCall,
                  ),

                  // Accept button
                  _buildActionButton(
                    icon: callIcon,
                    label: '応答',
                    backgroundColor: callColor,
                    onPressed: _acceptCall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(40),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(40),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade300,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
