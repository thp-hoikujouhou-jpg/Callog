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

  final List<Map<String, dynamic>> _backgroundOptions = [
    {
      'id': 'default',
      'name_key': 'bg_default',
      'colors': [Color(0xFFE3F2FD), Color(0xFFFFFFFF)], // Light blue to white
      'isDark': false,
    },
    {
      'id': 'blue_gradient',
      'name_key': 'bg_blue_gradient',
      'colors': [Color(0xFFBBDEFB), Color(0xFFE3F2FD)], // Blue gradient
      'isDark': false,
    },
    {
      'id': 'purple_gradient',
      'name_key': 'bg_purple_gradient',
      'colors': [Color(0xFFE1BEE7), Color(0xFFF3E5F5)], // Purple gradient
      'isDark': false,
    },
    {
      'id': 'pink_gradient',
      'name_key': 'bg_pink_gradient',
      'colors': [Color(0xFFF8BBD0), Color(0xFFFCE4EC)], // Pink gradient
      'isDark': false,
    },
    {
      'id': 'green_gradient',
      'name_key': 'bg_green_gradient',
      'colors': [Color(0xFFC8E6C9), Color(0xFFE8F5E9)], // Green gradient
      'isDark': false,
    },
    {
      'id': 'orange_gradient',
      'name_key': 'bg_orange_gradient',
      'colors': [Color(0xFFFFE0B2), Color(0xFFFFF3E0)], // Orange gradient
      'isDark': false,
    },
    {
      'id': 'dark_blue',
      'name_key': 'bg_dark_blue',
      'colors': [Color(0xFF0D47A1), Color(0xFF1565C0)], // Dark blue
      'isDark': true,
    },
    {
      'id': 'dark_purple',
      'name_key': 'bg_dark_purple',
      'colors': [Color(0xFF4A148C), Color(0xFF6A1B9A)], // Dark purple
      'isDark': true,
    },
    {
      'id': 'sunset',
      'name_key': 'bg_sunset',
      'colors': [Color(0xFFFF9800), Color(0xFFE91E63)], // Orange to pink
      'isDark': false,
    },
    {
      'id': 'ocean',
      'name_key': 'bg_ocean',
      'colors': [Color(0xFF00BCD4), Color(0xFF2196F3)], // Cyan to blue
      'isDark': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentBackground();
  }

  Future<void> _loadCurrentBackground() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        
        if (doc.exists && mounted) {
          setState(() {
            _selectedBackground = doc.data()?['chatBackground'] ?? 'default';
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveBackground(String backgroundId) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'chatBackground': backgroundId,
        });
        
        if (mounted) {
          setState(() => _selectedBackground = backgroundId);
          
          final localService = Provider.of<LocalizationService>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localService.translate('background_saved'),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
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
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localService.translate('chat_settings')),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header section with description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localService.translate('select_chat_background'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localService.translate('background_description'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Background options grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: _backgroundOptions.length,
                itemBuilder: (context, index) {
                  final option = _backgroundOptions[index];
                  final isSelected = _selectedBackground == option['id'];
                  final isDark = option['isDark'] as bool;

                  return GestureDetector(
                    onTap: () => _saveBackground(option['id']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: option['colors'],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected 
                              ? Colors.blue.shade600 
                              : Colors.grey.shade300,
                          width: isSelected ? 3 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected 
                                ? Colors.blue.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.08),
                            blurRadius: isSelected ? 12 : 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Preview content
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 52,
                                  color: isDark 
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : Colors.grey.shade700,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : Colors.white.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    localService.translate(option['name_key']),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isDark 
                                          ? Colors.white
                                          : Colors.grey.shade800,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Selected indicator
                          if (isSelected)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade600,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
