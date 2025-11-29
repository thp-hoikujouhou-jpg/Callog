import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      if (_isSignUp) {
        // Sign up - user profile is automatically created in Firestore
        await authService.signUpWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        // AuthWrapper will handle navigation to MainFeed
      } else {
        // Sign in
        await authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
        // AuthWrapper will handle navigation
      }
    } catch (e) {
      if (mounted) {
        final localService = Provider.of<LocalizationService>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localService.translate('error')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      await authService.signInWithGoogle();
      // AuthWrapper will handle navigation
    } catch (e) {
      if (mounted) {
        final localService = Provider.of<LocalizationService>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localService.translate('error')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);

    return Scaffold(
      body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_in_talk,
                          size: 64,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          localService.translate('app_name'),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connect, Call, Chat',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: localService.translate('email'),
                            prefixIcon: const Icon(Icons.email),
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: localService.translate('password'),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        if (_isLoading)
                          const CircularProgressIndicator()
                        else
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _handleEmailAuth,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    _isSignUp
                                        ? localService.translate('sign_up')
                                        : localService.translate('login'),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() => _isSignUp = !_isSignUp);
                                },
                                child: Text(
                                  _isSignUp
                                      ? 'Already have an account? Login'
                                      : localService.translate('sign_up'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: Text('OR'),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _handleGoogleSignIn,
                                  icon: Image.network(
                                    'https://www.google.com/favicon.ico',
                                    height: 24,
                                    width: 24,
                                  ),
                                  label: Text(
                                    localService.translate('sign_in_with_google'),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        DropdownButton<String>(
                          value: localService.currentLanguage,
                          items: LocalizationService.supportedLanguages.entries
                              .map((entry) => DropdownMenuItem(
                                    value: entry.key,
                                    child: Row(
                                      children: [
                                        Text(
                                          LocalizationService.languageFlags[entry.key] ?? '',
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(entry.value),
                                      ],
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                localService.setLanguage(value);
                              });
                            }
                          },
                        ),
                      ],
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
