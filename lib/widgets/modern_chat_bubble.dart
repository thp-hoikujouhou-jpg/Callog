import 'package:flutter/material.dart';
import 'package:callog_connect/theme/modern_ui_theme.dart';

/// Modern chat bubble with glassmorphism effect
class ModernChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String time;
  final bool isRead;
  
  const ModernChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.time,
    this.isRead = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) const SizedBox(width: 40), // Space for profile picture
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                gradient: isMe
                    ? ModernUITheme.primaryGradient
                    : const LinearGradient(
                        colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F5)],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                ),
                boxShadow: ModernUITheme.softShadow,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: ModernUITheme.bodyLarge.copyWith(
                      color: isMe ? ModernUITheme.textWhite : ModernUITheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: ModernUITheme.caption.copyWith(
                          color: isMe
                              ? ModernUITheme.textWhite.withOpacity(0.8)
                              : ModernUITheme.textHint,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 14,
                          color: isRead
                              ? ModernUITheme.primaryCyanLight
                              : ModernUITheme.textWhite.withOpacity(0.8),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 40), // Space for profile picture
        ],
      ),
    );
  }
}

/// Modern call notification card
class ModernCallCard extends StatelessWidget {
  final String callType; // 'voice' or 'video'
  final String status; // 'missed', 'declined', 'failed', 'completed'
  final String direction; // 'incoming' or 'outgoing'
  final String? duration;
  final String time;
  
  const ModernCallCard({
    super.key,
    required this.callType,
    required this.status,
    required this.direction,
    this.duration,
    required this.time,
  });
  
  Color _getStatusColor() {
    switch (status) {
      case 'missed':
        return ModernUITheme.errorRed;
      case 'declined':
        return ModernUITheme.warningOrange;
      case 'failed':
        return ModernUITheme.textHint;
      case 'completed':
      default:
        return ModernUITheme.successGreen;
    }
  }
  
  IconData _getCallIcon() {
    return callType == 'video' ? Icons.videocam : Icons.call;
  }
  
  IconData _getDirectionIcon() {
    return direction == 'outgoing' ? Icons.call_made : Icons.call_received;
  }
  
  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: ModernUITheme.glassContainer(opacity: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Call icon with status color
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCallIcon(),
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            
            // Call details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getDirectionIcon(),
                        size: 16,
                        color: ModernUITheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getCallStatusText(),
                        style: ModernUITheme.bodyMedium.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (duration != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      duration!,
                      style: ModernUITheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            
            // Time
            Text(
              time,
              style: ModernUITheme.caption,
            ),
          ],
        ),
      ),
    );
  }
  
  String _getCallStatusText() {
    final callTypeText = callType == 'video' ? 'Video' : 'Voice';
    switch (status) {
      case 'missed':
        return 'Missed $callTypeText Call';
      case 'declined':
        return 'Declined $callTypeText Call';
      case 'failed':
        return 'Failed $callTypeText Call';
      case 'completed':
      default:
        return '$callTypeText Call';
    }
  }
}
