import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String _selectedBackground = 'default';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatSettings();
  }

  Future<void> _loadChatSettings() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          setState(() {
            _selectedBackground = data?['chatBackground'] ?? 'default';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChatBackground(String background) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'chatBackground': background,
        });
        
        setState(() {
          _selectedBackground = background;
        });
        
        if (mounted) {
          final localService = Provider.of<LocalizationService>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localService.translate('settings_saved')),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  LinearGradient _getBackgroundGradient(String background) {
    switch (background) {
      case 'blue_gradient':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade100, Colors.blue.shade50],
        );
      case 'purple_gradient':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple.shade100, Colors.purple.shade50],
        );
      case 'pink_gradient':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.pink.shade100, Colors.pink.shade50],
        );
      case 'green_gradient':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green.shade100, Colors.green.shade50],
        );
      case 'orange_gradient':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade100, Colors.orange.shade50],
        );
      case 'dark_blue':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade900, Colors.blue.shade800],
        );
      case 'dark_purple':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple.shade900, Colors.purple.shade800],
        );
      case 'sunset':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange.shade300, Colors.pink.shade300],
        );
      case 'ocean':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.cyan.shade300, Colors.blue.shade400],
        );
      default:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.white],
        );
    }
  }

  bool _isDarkBackground(String background) {
    return background == 'dark_blue' || background == 'dark_purple';
  }

  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localService.translate('chat_settings')),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final backgrounds = [
      {'key': 'default', 'name_key': 'default'},
      {'key': 'blue_gradient', 'name_key': 'bg_blue_gradient'},
      {'key': 'purple_gradient', 'name_key': 'bg_purple_gradient'},
      {'key': 'pink_gradient', 'name_key': 'bg_pink_gradient'},
      {'key': 'green_gradient', 'name_key': 'bg_green_gradient'},
      {'key': 'orange_gradient', 'name_key': 'bg_orange_gradient'},
      {'key': 'dark_blue', 'name_key': 'bg_dark_blue'},
      {'key': 'dark_purple', 'name_key': 'bg_dark_purple'},
      {'key': 'sunset', 'name_key': 'bg_sunset'},
      {'key': 'ocean', 'name_key': 'bg_ocean'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(localService.translate('chat_settings')),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localService.translate('chat_background'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                localService.translate('chat_background_description'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 24),
              
              // Background options grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.0,
                ),
                itemCount: backgrounds.length,
                itemBuilder: (context, index) {
                  final bg = backgrounds[index];
                  final bgKey = bg['key'] as String;
                  final isSelected = _selectedBackground == bgKey;
                  final isDark = _isDarkBackground(bgKey);
                  
                  return GestureDetector(
                    onTap: () => _saveChatBackground(bgKey),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _getBackgroundGradient(bgKey),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Preview area
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble,
                                  size: 48,
                                  color: isDark 
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    localService.translate(bg['name_key'] as String),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isDark 
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Selected checkmark
                          if (isSelected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.blue.shade600,
                                child: const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // Preview section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: _getBackgroundGradient(_selectedBackground),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localService.translate('preview'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isDarkBackground(_selectedBackground) 
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Sample sent message
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'Hello!',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Sample received message
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'Hi there!',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
