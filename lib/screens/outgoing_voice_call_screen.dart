import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_call_service.dart';
import '../services/localization_service.dart';

/// Outgoing Voice Call Screen
/// LINE-style interface for making voice calls
class OutgoingVoiceCallScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String? friendPhotoUrl;

  const OutgoingVoiceCallScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendPhotoUrl,
  });

  @override
  State<OutgoingVoiceCallScreen> createState() => _OutgoingVoiceCallScreenState();
}

class _OutgoingVoiceCallScreenState extends State<OutgoingVoiceCallScreen> {
  String _callDuration = '00:00';
  DateTime? _callStartTime;

  @override
  void initState() {
    super.initState();
    _startCallDurationTimer();
  }

  void _startCallDurationTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        final callService = context.read<VoiceCallService>();
        if (callService.callStatus == CallStatus.active) {
          if (_callStartTime == null) {
            _callStartTime = callService.callStartTime ?? DateTime.now();
          }
          final duration = DateTime.now().difference(_callStartTime!);
          setState(() {
            _callDuration = _formatDuration(duration);
          });
        }
        _startCallDurationTimer();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final localization = LocalizationService();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Consumer<VoiceCallService>(
      builder: (context, callService, _) {
        // Auto-dismiss screen when call ends
        if (callService.callStatus == CallStatus.ended ||
            callService.callStatus == CallStatus.rejected ||
            !callService.isInCall) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }

        return Scaffold(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                // Header with close button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        onPressed: () => _endCall(context, callService),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Friend avatar
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: widget.friendPhotoUrl != null
                      ? NetworkImage(widget.friendPhotoUrl!)
                      : null,
                  child: widget.friendPhotoUrl == null
                      ? Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey[600],
                        )
                      : null,
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
                  _getCallStatusText(callService.callStatus, localization),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),

                // Call duration (shown when active)
                if (callService.callStatus == CallStatus.active) ...[
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
                        icon: callService.isSpeakerOn
                            ? Icons.volume_up
                            : Icons.volume_down,
                        label: localization.translate('speaker'),
                        isActive: callService.isSpeakerOn,
                        onPressed: () => callService.toggleSpeaker(),
                        isDarkMode: isDarkMode,
                      ),

                      // Mute button
                      _CallControlButton(
                        icon: callService.isMuted ? Icons.mic_off : Icons.mic,
                        label: localization.translate('mute'),
                        isActive: callService.isMuted,
                        onPressed: () => callService.toggleMute(),
                        isDarkMode: isDarkMode,
                      ),

                      // End call button
                      _CallControlButton(
                        icon: Icons.call_end,
                        label: localization.translate('end_call'),
                        isActive: false,
                        backgroundColor: Colors.red,
                        onPressed: () => _endCall(context, callService),
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
      },
    );
  }

  String _getCallStatusText(CallStatus status, LocalizationService localization) {
    switch (status) {
      case CallStatus.ringing:
        return localization.translate('calling');
      case CallStatus.active:
        return localization.translate('call_connected');
      case CallStatus.ended:
        return localization.translate('call_ended');
      case CallStatus.rejected:
        return localization.translate('call_rejected');
      default:
        return '';
    }
  }

  Future<void> _endCall(BuildContext context, VoiceCallService callService) async {
    await callService.endCall();
    if (context.mounted) {
      Navigator.of(context).pop();
    }
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
