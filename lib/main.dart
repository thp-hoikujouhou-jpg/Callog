import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'services/localization_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_feed_screen.dart';

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
    
    // Initialize Firebase with error handling
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
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
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
      ],
      child: MaterialApp(
        title: 'Callog',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
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
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading indicator while waiting for auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // User is authenticated - load language then show home screen
        if (snapshot.hasData && snapshot.data != null) {
          final localService = Provider.of<LocalizationService>(context, listen: false);
          
          return FutureBuilder<void>(
            future: localService.loadLanguageFromFirestore(),
            builder: (context, langSnapshot) {
              // Show loading while language loads
              if (langSnapshot.connectionState == ConnectionState.waiting) {
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
        
        // User signed out - show login screen
        return const LoginScreen();
      },
    );
  }
}
