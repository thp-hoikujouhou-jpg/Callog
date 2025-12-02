import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../models/user_profile.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'chat_settings_screen.dart';
import 'settings_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  UserProfile? _userProfile;
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null) {
        final profile = await authService.getUserProfile(user.uid);
        if (mounted) {
          setState(() {
            _userProfile = profile;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editUsername() async {
    final controller = TextEditingController(text: _userProfile?.username ?? '');
    final localService = Provider.of<LocalizationService>(context, listen: false);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localService.translate('username')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: localService.translate('username'),
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localService.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(localService.translate('save')),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final user = authService.currentUser;
        if (user != null) {
          // Update both username and displayName together
          await authService.updateUserProfile(user.uid, {
            'username': result,
            'displayName': result,
          });
          await _loadUserProfile();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localService.translate('profile_updated')),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
    controller.dispose();
  }

  Future<void> _editEmail() async {
    final controller = TextEditingController(text: _userProfile?.email ?? '');
    final localService = Provider.of<LocalizationService>(context, listen: false);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localService.translate('email')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: localService.translate('email'),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localService.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(localService.translate('save')),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final user = authService.currentUser;
        if (user != null) {
          await authService.updateUserProfile(user.uid, {'email': result});
          await _loadUserProfile();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localService.translate('profile_updated')),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
    controller.dispose();
  }

  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final localService = Provider.of<LocalizationService>(context, listen: false);
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localService.translate('change_password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              decoration: InputDecoration(
                labelText: localService.translate('current_password'),
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: InputDecoration(
                labelText: localService.translate('new_password'),
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              decoration: InputDecoration(
                labelText: localService.translate('confirm_password'),
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localService.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              if (newPasswordController.text == confirmPasswordController.text) {
                Navigator.pop(context, {
                  'current': currentPasswordController.text,
                  'new': newPasswordController.text,
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localService.translate('passwords_not_match')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(localService.translate('save')),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.changePassword(result['current']!, result['new']!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localService.translate('password_changed')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> _editLocation() async {
    final controller = TextEditingController(text: _userProfile?.location ?? '');
    final localService = Provider.of<LocalizationService>(context, listen: false);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localService.translate('location')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: localService.translate('location'),
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localService.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(localService.translate('save')),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final user = authService.currentUser;
        if (user != null) {
          await authService.updateUserProfile(user.uid, {'location': result});
          await _loadUserProfile();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localService.translate('profile_updated')),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
    controller.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null && mounted) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        try {
          final authService = Provider.of<AuthService>(context, listen: false);
          final user = authService.currentUser;
          
          if (user != null) {
            // Upload image to Firebase Storage
            // For Web: pass XFile directly, For Mobile: convert to File
            final imageFile = kIsWeb ? image : File(image.path);
            final photoUrl = await authService.uploadProfileImage(user.uid, imageFile);
            
            if (photoUrl != null) {
              // Update Firestore with new photo URL
              await authService.updateProfilePhoto(user.uid, photoUrl);
              
              // Reload user profile
              await _loadUserProfile();
              
              if (mounted) {
                Navigator.pop(context); // Close loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile photo updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
          }
        } catch (e) {
          if (mounted) {
            Navigator.pop(context); // Close loading dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading image: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    final authService = Provider.of<AuthService>(context, listen: false);
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
        // Sign out - AuthWrapper will automatically navigate to LoginScreen
        await authService.signOut();
        
        // Close ProfileSettingsScreen to allow AuthWrapper to show LoginScreen
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localService.translate('profile_settings')),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
              Stack(
                children: [
                  Builder(
                    builder: (context) {
                      final photoUrl = _userProfile?.photoUrl;
                      final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
                      
                      return CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.blue.shade100,
                        backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                        onBackgroundImageError: hasPhoto
                            ? (exception, stackTrace) {
                                if (kDebugMode) {
                                  debugPrint('Failed to load profile image: $exception');
                                }
                              }
                            : null,
                        child: hasPhoto
                            ? null
                            : Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.blue.shade600,
                              ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue.shade600,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _userProfile?.displayName ?? 'User',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _userProfile?.email ?? 'No email',
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
                      subtitle: Text(_userProfile?.username ?? 'Not set'),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _editUsername(),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock),
                      title: Text(localService.translate('password')),
                      subtitle: const Text('••••••••'),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _changePassword(),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.email),
                      title: Text(localService.translate('email')),
                      subtitle: Text(_userProfile?.email ?? 'Not set'),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _editEmail(),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(localService.translate('location')),
                      subtitle: Text(_userProfile?.location ?? 'Not set'),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _editLocation(),
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
                                        onTap: () async {
                                          await localService.setLanguage(entry.key);
                                          if (mounted) {
                                            Navigator.pop(context);
                                            setState(() {});
                                          }
                                        },
                                      ))
                                  .toList(),
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    Consumer<ThemeService>(
                      builder: (context, themeService, child) {
                        IconData icon;
                        switch (themeService.themeOption) {
                          case ThemeOption.dark:
                            icon = Icons.dark_mode;
                            break;
                          case ThemeOption.auto:
                            icon = Icons.brightness_auto;
                            break;
                          default:
                            icon = Icons.light_mode;
                        }
                        
                        final localService = Provider.of<LocalizationService>(context, listen: false);
                        return ListTile(
                          leading: Icon(icon),
                          title: Text(localService.translate('theme')),
                          subtitle: Text(localService.translate(themeService.getThemeDisplayNameKey())),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await themeService.toggleTheme();
                          },
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.chat),
                      title: Text(localService.translate('chat_settings')),
                      subtitle: Text(localService.translate('chat_background')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChatSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.settings),
                  title: Text(localService.translate('settings')),
                  subtitle: Text(localService.translate('settings_coming_soon')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
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
