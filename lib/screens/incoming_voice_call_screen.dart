import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_call_service.dart';
import '../services/localization_service.dart';

/// Incoming Voice Call Screen
/// Displays incoming call with slide-to-answer interface
class IncomingVoiceCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String? callerPhotoUrl;

  const IncomingVoiceCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    this.callerPhotoUrl,
  });

  @override
  State<IncomingVoiceCallScreen> createState() => _IncomingVoiceCallScreenState();
}

class _IncomingVoiceCallScreenState extends State<IncomingVoiceCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localization = LocalizationService();
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.pink.withValues(alpha: 0.3),
              Colors.purple.withValues(alpha: 0.2),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),

              // Caller avatar with pulse animation
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pink.withValues(alpha: 0.3 * _pulseController.value),
                          blurRadius: 30,
                          spreadRadius: 20 * _pulseController.value,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: widget.callerPhotoUrl != null
                      ? NetworkImage(widget.callerPhotoUrl!)
                      : null,
                  child: widget.callerPhotoUrl == null
                      ? Icon(
                          Icons.person,
                          size: 80,
                          color: Colors.grey[600],
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 32),

              // Caller name
              Text(
                widget.callerName,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 12),

              // Call type indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    localization.translate('voice_call'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Action buttons row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Send message button
                    _ActionButton(
                      icon: Icons.message,
                      label: localization.translate('send_message'),
                      onTap: () {
                        // TODO: Implement send message
                      },
                    ),

                    // Remind later button
                    _ActionButton(
                      icon: Icons.access_time,
                      label: localization.translate('remind_later'),
                      onTap: () {
                        // TODO: Implement remind later
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              // Slide to answer
              _SlideToAnswerWidget(
                screenWidth: screenSize.width,
                onSlideComplete: () => _answerCall(context),
                localization: localization,
              ),

              const SizedBox(height: 40),

              // Decline button
              TextButton(
                onPressed: () => _declineCall(context),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _answerCall(BuildContext context) async {
    final callService = context.read<VoiceCallService>();
    final success = await callService.answerCall(widget.callId);
    
    if (success && context.mounted) {
      // Navigate to active call screen
      Navigator.of(context).pushReplacementNamed(
        '/outgoing_voice_call',
        arguments: {
          'friendId': callService.remoteFriendId,
          'friendName': callService.remoteFriendName,
          'friendPhotoUrl': callService.remoteFriendPhotoUrl,
        },
      );
    }
  }

  Future<void> _declineCall(BuildContext context) async {
    final callService = context.read<VoiceCallService>();
    await callService.rejectCall(widget.callId);
    
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

/// Action Button Widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: Colors.black87),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slide to Answer Widget
class _SlideToAnswerWidget extends StatefulWidget {
  final double screenWidth;
  final VoidCallback onSlideComplete;
  final LocalizationService localization;

  const _SlideToAnswerWidget({
    required this.screenWidth,
    required this.onSlideComplete,
    required this.localization,
  });

  @override
  State<_SlideToAnswerWidget> createState() => _SlideToAnswerWidgetState();
}

class _SlideToAnswerWidgetState extends State<_SlideToAnswerWidget> {
  double _slidePosition = 0.0;
  static const double _slideThreshold = 0.75;

  @override
  Widget build(BuildContext context) {
    final maxSlide = widget.screenWidth - 160;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.pink.withValues(alpha: 0.8),
              Colors.pink.withValues(alpha: 0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background text
            Center(
              child: Text(
                widget.localization.translate('slide_to_answer'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),

            // Sliding button
            Positioned(
              left: _slidePosition,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _slidePosition = (_slidePosition + details.delta.dx)
                        .clamp(0.0, maxSlide);
                  });

                  // Check if slide is complete
                  if (_slidePosition / maxSlide >= _slideThreshold) {
                    widget.onSlideComplete();
                  }
                },
                onHorizontalDragEnd: (details) {
                  // Reset if not completed
                  if (_slidePosition / maxSlide < _slideThreshold) {
                    setState(() {
                      _slidePosition = 0.0;
                    });
                  }
                },
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone,
                    color: Colors.pink[400],
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
