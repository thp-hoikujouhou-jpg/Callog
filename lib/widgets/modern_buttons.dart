import 'package:flutter/material.dart';
import 'package:callog_connect/theme/modern_ui_theme.dart';

/// Modern primary button with gradient
class ModernPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  
  const ModernPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: onPressed != null
            ? ModernUITheme.primaryGradient
            : const LinearGradient(colors: [Colors.grey, Colors.grey]),
        borderRadius: ModernUITheme.radiusMedium,
        boxShadow: onPressed != null ? ModernUITheme.softShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: ModernUITheme.radiusMedium,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: ModernUITheme.textWhite),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: ModernUITheme.bodyLarge.copyWith(
                          color: ModernUITheme.textWhite,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Modern secondary button (outline style)
class ModernSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  
  const ModernSecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(
          color: onPressed != null
              ? ModernUITheme.primaryCyan
              : ModernUITheme.textHint,
          width: 2,
        ),
        borderRadius: ModernUITheme.radiusMedium,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: ModernUITheme.radiusMedium,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: onPressed != null
                        ? ModernUITheme.primaryCyan
                        : ModernUITheme.textHint,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: ModernUITheme.bodyLarge.copyWith(
                    color: onPressed != null
                        ? ModernUITheme.primaryCyan
                        : ModernUITheme.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern icon button with neumorphism effect
class ModernIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  
  const ModernIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = 48,
  });
  
  @override
  State<ModernIconButton> createState() => _ModernIconButtonState();
}

class _ModernIconButtonState extends State<ModernIconButton> {
  bool _isPressed = false;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: ModernUITheme.animationFast,
        curve: ModernUITheme.animationCurve,
        width: widget.size,
        height: widget.size,
        decoration: _isPressed
            ? ModernUITheme.neumorphicPressed()
            : ModernUITheme.neumorphicElevated(),
        child: Icon(
          widget.icon,
          color: widget.color ?? ModernUITheme.primaryCyan,
          size: widget.size * 0.5,
        ),
      ),
    );
  }
}

/// Modern floating action button
class ModernFAB extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? heroTag;
  
  const ModernFAB({
    super.key,
    required this.icon,
    this.onPressed,
    this.heroTag,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: ModernUITheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ModernUITheme.mediumShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Icon(
            icon,
            color: ModernUITheme.textWhite,
            size: 28,
          ),
        ),
      ),
    );
  }
}

/// Modern segmented button (toggle style)
class ModernSegmentedButton extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  
  const ModernSegmentedButton({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: ModernUITheme.neumorphicPressed(),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(
          options.length,
          (index) => Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: ModernUITheme.animationMedium,
                curve: ModernUITheme.animationCurve,
                decoration: selectedIndex == index
                    ? BoxDecoration(
                        gradient: ModernUITheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: ModernUITheme.softShadow,
                      )
                    : null,
                child: Center(
                  child: Text(
                    options[index],
                    style: ModernUITheme.bodyMedium.copyWith(
                      color: selectedIndex == index
                          ? ModernUITheme.textWhite
                          : ModernUITheme.textSecondary,
                      fontWeight: selectedIndex == index
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
