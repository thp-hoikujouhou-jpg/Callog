import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import 'login_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  Future<void> _handleSignOut() async {
    final localService = Provider.of<LocalizationService>(context, listen: false);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localService.translate('sign_out')),
        content: Text(localService.translate('confirm_sign_out')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localService.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(localService.translate('sign_out')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.signOut();
        
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(localService.translate('profile_settings')),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.blue.shade100,
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.blue.shade600,
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                user?.displayName ?? 'User',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? '',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 32),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(localService.translate('username')),
                      subtitle: Text(user?.displayName ?? 'Not set'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: Text(localService.translate('email')),
                      subtitle: Text(user?.email ?? 'Not set'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(localService.translate('location')),
                      subtitle: const Text('Not set'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: Text(localService.translate('language')),
                      subtitle: Text(
                        LocalizationService.supportedLanguages[
                                localService.currentLanguage] ??
                            'English',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(localService.translate('language')),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: LocalizationService.supportedLanguages.entries
                                  .map((entry) => ListTile(
                                        leading: Text(
                                          LocalizationService.languageFlags[entry.key] ?? '',
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                        title: Text(entry.value),
                                        onTap: () {
                                          localService.setLanguage(entry.key);
                                          Navigator.pop(context);
                                          setState(() {});
                                        },
                                      ))
                                  .toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _handleSignOut,
                  icon: const Icon(Icons.logout),
                  label: Text(localService.translate('sign_out')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
