import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// App Lifecycle Service
/// 
/// Tracks whether the app is in foreground, background, or closed.
/// This determines whether to show:
/// - Foreground: Incoming call screen + ringtone (LINE/WhatsApp style)
/// - Background/Closed: Push notification only (silent)
class AppLifecycleService with WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  AppLifecycleState _currentState = AppLifecycleState.resumed;
  bool _isInitialized = false;

  /// Initialize lifecycle observer
  void initialize() {
    if (_isInitialized) return;
    
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    debugPrint('[AppLifecycle] ✅ Lifecycle observer initialized');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _currentState = state;
    debugPrint('[AppLifecycle] State changed: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('[AppLifecycle] 🟢 App is in FOREGROUND');
        break;
      case AppLifecycleState.inactive:
        debugPrint('[AppLifecycle] 🟡 App is INACTIVE (transitioning)');
        break;
      case AppLifecycleState.paused:
        debugPrint('[AppLifecycle] 🔴 App is in BACKGROUND');
        break;
      case AppLifecycleState.detached:
        debugPrint('[AppLifecycle] ⚫ App is DETACHED (closing)');
        break;
      case AppLifecycleState.hidden:
        debugPrint('[AppLifecycle] 🔵 App is HIDDEN');
        break;
    }
  }

  /// Check if app is in foreground (user can see the app)
  bool get isAppInForeground {
    return _currentState == AppLifecycleState.resumed;
  }

  /// Check if app is in background (app is running but not visible)
  bool get isAppInBackground {
    return _currentState == AppLifecycleState.paused ||
           _currentState == AppLifecycleState.inactive ||
           _currentState == AppLifecycleState.hidden;
  }

  /// Get current app state
  AppLifecycleState get currentState => _currentState;

  /// Dispose lifecycle observer
  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
      debugPrint('[AppLifecycle] Lifecycle observer disposed');
    }
  }
}
