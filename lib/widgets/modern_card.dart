import 'package:flutter/material.dart';
import 'package:callog_connect/theme/modern_ui_theme.dart';

/// Modern card with glassmorphism effect
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool useGlass;
  
  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.useGlass = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final cardWidget = Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: useGlass
          ? ModernUITheme.glassContainer()
          : ModernUITheme.neumorphicElevated(),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
    
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: ModernUITheme.radiusMedium,
        child: cardWidget,
      );
    }
    
    return cardWidget;
  }
}

/// Modern sticky note card
class ModernStickyNote extends StatelessWidget {
  final String title;
  final String content;
  final String date;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  
  const ModernStickyNote({
    super.key,
    required this.title,
    required this.content,
    required this.date,
    required this.color,
    this.onTap,
    this.onDelete,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: ModernUITheme.radiusMedium,
        boxShadow: ModernUITheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: ModernUITheme.radiusMedium,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: ModernUITheme.headingSmall.copyWith(
                          color: ModernUITheme.textWhite,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white70),
                        iconSize: 20,
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: ModernUITheme.bodyMedium.copyWith(
                    color: ModernUITheme.textWhite.withOpacity(0.9),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: ModernUITheme.textWhite.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: ModernUITheme.caption.copyWith(
                        color: ModernUITheme.textWhite.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern contact list item
class ModernContactItem extends StatelessWidget {
  final String name;
  final String? subtitle;
  final String avatarUrl;
  final int? unreadCount;
  final String? lastMessageTime;
  final VoidCallback? onTap;
  final VoidCallback? onCall;
  final VoidCallback? onVideo;
  
  const ModernContactItem({
    super.key,
    required this.name,
    this.subtitle,
    required this.avatarUrl,
    this.unreadCount,
    this.lastMessageTime,
    this.onTap,
    this.onCall,
    this.onVideo,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: ModernUITheme.glassContainer(opacity: 0.05),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: ModernUITheme.radiusMedium,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar with gradient border
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: ModernUITheme.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Name and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: ModernUITheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: ModernUITheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Right side content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (lastMessageTime != null)
                      Text(
                        lastMessageTime!,
                        style: ModernUITheme.caption,
                      ),
                    if (unreadCount != null && unreadCount! > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: ModernUITheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: ModernUITheme.caption.copyWith(
                            color: ModernUITheme.textWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                // Action buttons
                if (onCall != null || onVideo != null) ...[
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      if (onCall != null)
                        IconButton(
                          icon: const Icon(Icons.call),
                          onPressed: onCall,
                          color: ModernUITheme.successGreen,
                          iconSize: 20,
                        ),
                      if (onVideo != null)
                        IconButton(
                          icon: const Icon(Icons.videocam),
                          onPressed: onVideo,
                          color: ModernUITheme.primaryCyan,
                          iconSize: 20,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern calendar day cell
class ModernCalendarDay extends StatelessWidget {
  final int day;
  final bool isSelected;
  final bool isToday;
  final bool hasEvents;
  final VoidCallback? onTap;
  
  const ModernCalendarDay({
    super.key,
    required this.day,
    this.isSelected = false,
    this.isToday = false,
    this.hasEvents = false,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                gradient: ModernUITheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: ModernUITheme.softShadow,
              )
            : isToday
                ? BoxDecoration(
                    border: Border.all(
                      color: ModernUITheme.primaryCyan,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              day.toString(),
              style: ModernUITheme.bodyLarge.copyWith(
                color: isSelected
                    ? ModernUITheme.textWhite
                    : ModernUITheme.textPrimary,
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (hasEvents)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ModernUITheme.textWhite
                        : ModernUITheme.secondaryOrange,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
