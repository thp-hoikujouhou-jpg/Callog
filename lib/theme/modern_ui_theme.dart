import 'package:flutter/material.dart';

/// Modern UI Theme with Glassmorphism & Neumorphism
class ModernUITheme {
  // ==================== COLOR PALETTE ====================
  
  // Primary Colors
  static const Color primaryCyan = Color(0xFF00B8D4);
  static const Color primaryCyanLight = Color(0xFF62EFFF);
  static const Color primaryCyanDark = Color(0xFF008BA3);
  
  // Secondary Colors
  static const Color secondaryOrange = Color(0xFFFF6E40);
  static const Color secondaryOrangeLight = Color(0xFFFF9E6E);
  static const Color secondaryOrangeDark = Color(0xFFC53D13);
  
  // Neutral Colors - Light Mode
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundGray = Color(0xFFF5F5F5);
  
  // Neutral Colors - Dark Mode
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color backgroundDarkGray = Color(0xFF2A2A2A);
  static const Color surfaceDarkElevated = Color(0xFF2C2C2C);
  
  // Status Colors
  static const Color successGreen = Color(0xFF00E676);
  static const Color warningOrange = Color(0xFFFFAB40);
  static const Color errorRed = Color(0xFFFF5252);
  static const Color infoBlue = Color(0xFF2979FF);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textWhite = Color(0xFFFFFFFF);
  
  // ==================== GRADIENTS ====================
  
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryCyan, primaryCyanLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFE3F2FD), Color(0xFFFAFAFA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [successGreen, Color(0xFF69F0AE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient warningGradient = LinearGradient(
    colors: [warningOrange, Color(0xFFFFD180)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Dark Mode Gradients
  static const LinearGradient backgroundGradientDark = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF2A2A2A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient cardGradientDark = LinearGradient(
    colors: [Color(0xFF2C2C2C), Color(0xFF1E1E1E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // ==================== GLASSMORPHISM ====================
  
  /// Glassmorphism container decoration (Light Mode)
  static BoxDecoration glassContainer({
    double blur = 10.0,
    double opacity = 0.15,
    Color color = Colors.white,
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: opacity),
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.3),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: blur,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
  
  /// Glassmorphism container decoration (Dark Mode)
  static BoxDecoration glassContainerDark({
    double blur = 10.0,
    double opacity = 0.2,
    Color color = const Color(0xFF2A2A2A),
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: opacity),
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.1),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: blur,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
  
  // ==================== NEUMORPHISM ====================
  
  /// Neumorphism elevated container
  static BoxDecoration neumorphicElevated({
    Color color = const Color(0xFFF5F5F5),
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.white,
          offset: const Offset(-6, -6),
          blurRadius: 12,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          offset: const Offset(6, 6),
          blurRadius: 12,
        ),
      ],
    );
  }
  
  /// Neumorphism pressed container (simulated inset shadow)
  static BoxDecoration neumorphicPressed({
    Color color = const Color(0xFFF5F5F5),
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      color: color.withOpacity(0.95),
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          offset: const Offset(2, 2),
          blurRadius: 4,
          spreadRadius: -2,
        ),
      ],
    );
  }
  
  // ==================== SHADOWS ====================
  
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> mediumShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> strongShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.16),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];
  
  // ==================== BORDER RADIUS ====================
  
  static const BorderRadius radiusSmall = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radiusMedium = BorderRadius.all(Radius.circular(16));
  static const BorderRadius radiusLarge = BorderRadius.all(Radius.circular(24));
  static const BorderRadius radiusXLarge = BorderRadius.all(Radius.circular(32));
  
  // ==================== TEXT STYLES ====================
  
  static const TextStyle headingLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );
  
  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
  );
  
  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.2,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textHint,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textHint,
    letterSpacing: 0.5,
  );
  
  // ==================== ANIMATIONS ====================
  
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  static const Curve animationCurve = Curves.easeInOutCubic;
  
  // ==================== THEME DATA ====================
  
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryCyan,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primaryCyan,
        secondary: secondaryOrange,
        surface: surfaceWhite,
        error: errorRed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false, // Left-aligned title (default)
        titleTextStyle: headingMedium.copyWith(color: textPrimary),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radiusMedium),
        color: surfaceWhite,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCyan,
          foregroundColor: textWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: radiusMedium),
          textStyle: bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryCyan,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryCyan,
        foregroundColor: textWhite,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: radiusMedium),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        border: OutlineInputBorder(
          borderRadius: radiusMedium,
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusMedium,
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusMedium,
          borderSide: const BorderSide(color: primaryCyan, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceWhite,
        selectedItemColor: primaryCyan,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
  
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryCyan,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A), // Very dark background
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: secondaryOrange,
        surface: Color(0xFF1A1A1A), // Slightly lighter surface
        error: errorRed,
        onPrimary: textWhite,
        onSecondary: textWhite,
        onSurface: Colors.white,
        onError: textWhite,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false, // Left-aligned title (default)
        titleTextStyle: headingMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 24),
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: radiusMedium),
        color: const Color(0xFF1A1A1A),
        shadowColor: Colors.black.withValues(alpha: 0.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCyan,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: radiusMedium),
          textStyle: bodyLarge.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryCyan,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryCyan,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: radiusMedium),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF252525),
        border: OutlineInputBorder(
          borderRadius: radiusMedium,
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusMedium,
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusMedium,
          borderSide: const BorderSide(color: primaryCyan, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIconColor: Colors.white.withValues(alpha: 0.7),
        suffixIconColor: Colors.white.withValues(alpha: 0.7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1A1A1A),
        selectedItemColor: primaryCyan,
        unselectedItemColor: Colors.white.withValues(alpha: 0.6),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      textTheme: TextTheme(
        headlineLarge: headingLarge.copyWith(color: Colors.white),
        headlineMedium: headingMedium.copyWith(color: Colors.white),
        headlineSmall: headingSmall.copyWith(color: Colors.white),
        bodyLarge: bodyLarge.copyWith(color: Colors.white.withValues(alpha: 0.95)),
        bodyMedium: bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.85)),
        bodySmall: bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.70)),
        labelLarge: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.1),
        thickness: 1,
      ),
      iconTheme: IconThemeData(
        color: Colors.white.withValues(alpha: 0.8),
        size: 24,
      ),
    );
  }
}
