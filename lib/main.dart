import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/localization_service.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CallogApp());
}

class CallogApp extends StatelessWidget {
  const CallogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<LocalizationService>(
      create: (_) => LocalizationService(),
      child: MaterialApp(
        title: 'Callog Connect',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
