import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'services/localization_service.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart' show ThemeService, ThemeOption;
import 'services/voice_call_service.dart';
import 'services/call_navigation_service.dart';
import 'services/app_lifecycle_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_feed_screen.dart';
import 'theme/modern_ui_theme.dart';

void main() async {
  // Catch and log any errors during initialization
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    }
  };

  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase with duplicate app check
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    
    // Initialize App Lifecycle Service (LINE/WhatsApp style)
    AppLifecycleService().initialize();
    
    // Set up background message handler for push notifications
    // FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    runApp(const CallogApp());
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint('Error during app initialization: $e');
      debugPrint('Stack trace: $stackTrace');
    }
    // Run app with error screen if initialization fails
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('アプリの初期化に失敗しました'),
              const SizedBox(height: 8),
              Text('エラー: $e', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ));
  }
}

class CallogApp extends StatelessWidget {
  const CallogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocalizationService>(
          create: (_) => LocalizationService(),
        ),
        ChangeNotifierProvider<ThemeService>(
          create: (_) => ThemeService(),
        ),
        ChangeNotifierProvider<VoiceCallService>(
          create: (_) => VoiceCallService(),
        ),
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          // Determine which theme to use based on theme option
          ThemeData activeTheme;
          if (themeService.themeOption == ThemeOption.light) {
            activeTheme = ModernUITheme.lightTheme;
          } else if (themeService.themeOption == ThemeOption.dark) {
            activeTheme = ModernUITheme.darkTheme;
          } else {
            // Auto mode uses the mixed theme
            activeTheme = ModernUITheme.autoTheme;
          }
          
          return MaterialApp(
            title: 'Callog',
            debugShowCheckedModeBanner: false,
            navigatorKey: CallNavigationService.navigatorKey, // Enable global navigation
            theme: activeTheme,
            darkTheme: activeTheme, // Use same theme for both modes
            themeMode: ThemeMode.light, // Always use light mode since we're setting theme directly
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Future<void> _loadLanguageSettings(BuildContext context) async {
    try {
      final localService = Provider.of<LocalizationService>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;
      
      if (kDebugMode) {
        debugPrint('🌐 [AuthWrapper] Loading language settings...');
        debugPrint('🌐 [AuthWrapper] Current user: ${user?.uid}');
        debugPrint('🌐 [AuthWrapper] Current cached language: ${localService.currentLanguage}');
      }
      
      // CRITICAL: Reset cache to force fresh load from Firestore
      localService.resetCache();
      
      // Force reload language from Firestore
      await localService.loadLanguageFromFirestore(forceReload: true);
      
      if (kDebugMode) {
        debugPrint('✅ [AuthWrapper] Language settings loaded: ${localService.currentLanguage}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AuthWrapper] Failed to load language: $e');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Debug logging
        if (kDebugMode) {
          debugPrint('🔐 AuthWrapper State: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, User: ${snapshot.data?.uid}');
        }
        
        // Show loading indicator while waiting for auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // User is authenticated - load language first, then show home screen
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder(
            future: _loadLanguageSettings(context),
            builder: (context, languageSnapshot) {
              // Show loading while language is being loaded
              if (languageSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading...'),
                      ],
                    ),
                  ),
                );
              }
              
              // Language loaded - show home screen
              return const MainFeedScreen();
            },
          );
        }
        
        // User signed out - reset language cache and show login screen
        try {
          final localService = Provider.of<LocalizationService>(context, listen: false);
          localService.resetCache();
        } catch (e) {
          // Ignore reset errors
          if (kDebugMode) {
            debugPrint('⚠️ Language reset failed: $e');
          }
        }
        return const LoginScreen();
      },
    );
  }
}
