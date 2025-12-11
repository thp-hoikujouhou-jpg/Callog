import 'package:flutter/material.dart';
import 'package:callog_connect/theme/modern_ui_theme.dart';
import 'package:callog_connect/widgets/modern_chat_bubble.dart';
import 'package:callog_connect/widgets/modern_card.dart';
import 'package:callog_connect/widgets/modern_buttons.dart';

/// Modern Chat Preview Screen - Demonstrates new UI design
/// This is a demo screen to showcase the new design before full integration
class ModernChatPreviewScreen extends StatefulWidget {
  const ModernChatPreviewScreen({super.key});

  @override
  State<ModernChatPreviewScreen> createState() => _ModernChatPreviewScreenState();
}

class _ModernChatPreviewScreenState extends State<ModernChatPreviewScreen> {
  final _messageController = TextEditingController();
  int _selectedTab = 0;
  
  // Demo data
  final List<Map<String, dynamic>> _demoContacts = [
    {
      'name': 'John Smith',
      'avatar': 'https://i.pravatar.cc/150?img=1',
      'lastMessage': 'See you tomorrow!',
      'time': '2:30 PM',
      'unreadCount': 3,
    },
    {
      'name': 'Emma Wilson',
      'avatar': 'https://i.pravatar.cc/150?img=2',
      'lastMessage': 'Thanks for your help',
      'time': '1:15 PM',
      'unreadCount': 0,
    },
    {
      'name': 'Mike Johnson',
      'avatar': 'https://i.pravatar.cc/150?img=3',
      'lastMessage': 'The meeting is at 3 PM',
      'time': '11:45 AM',
      'unreadCount': 1,
    },
  ];
  
  final List<Map<String, dynamic>> _demoMessages = [
    {
      'text': 'Hey! How are you doing today?',
      'isMe': false,
      'time': '2:25 PM',
      'isRead': true,
    },
    {
      'text': 'I\'m doing great! Thanks for asking. How about you?',
      'isMe': true,
      'time': '2:26 PM',
      'isRead': true,
    },
    {
      'text': 'Pretty good! I wanted to ask about tomorrow\'s meeting.',
      'isMe': false,
      'time': '2:27 PM',
      'isRead': true,
    },
    {
      'text': 'Sure! What would you like to know?',
      'isMe': true,
      'time': '2:28 PM',
      'isRead': true,
    },
    {
      'text': 'What time does it start?',
      'isMe': false,
      'time': '2:29 PM',
      'isRead': true,
    },
    {
      'text': 'The meeting starts at 3 PM. See you there!',
      'isMe': true,
      'time': '2:30 PM',
      'isRead': false,
    },
  ];
  
  final List<Map<String, dynamic>> _demoCallHistory = [
    {
      'callType': 'voice',
      'status': 'completed',
      'direction': 'outgoing',
      'duration': '5分30秒',
      'time': '2:15 PM',
    },
    {
      'callType': 'video',
      'status': 'missed',
      'direction': 'incoming',
      'duration': null,
      'time': '1:45 PM',
    },
    {
      'callType': 'voice',
      'status': 'declined',
      'direction': 'outgoing',
      'duration': null,
      'time': '12:30 PM',
    },
  ];
  
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ModernUITheme.lightTheme,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: ModernUITheme.backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildModernAppBar(),
                _buildTabBar(),
                Expanded(
                  child: _selectedTab == 0
                      ? _buildContactsList()
                      : _selectedTab == 1
                          ? _buildChatArea()
                          : _buildCallHistoryList(),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: _selectedTab == 1
            ? ModernFAB(
                icon: Icons.add_comment,
                onPressed: () {},
              )
            : null,
      ),
    );
  }
  
  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back button
          ModernIconButton(
            icon: Icons.arrow_back,
            onPressed: () => Navigator.pop(context),
            size: 48,
          ),
          const SizedBox(width: 12),
          
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Callog',
                  style: ModernUITheme.headingMedium,
                ),
                Text(
                  'Modern UI Preview',
                  style: ModernUITheme.bodySmall,
                ),
              ],
            ),
          ),
          
          // Action buttons
          ModernIconButton(
            icon: Icons.search,
            onPressed: () {},
            size: 48,
          ),
          const SizedBox(width: 8),
          ModernIconButton(
            icon: Icons.settings,
            onPressed: () {},
            size: 48,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
      child: ModernSegmentedButton(
        options: const ['Contacts', 'Chat', 'Calls'],
        selectedIndex: _selectedTab,
        onChanged: (index) {
          setState(() => _selectedTab = index);
        },
      ),
    );
  }
  
  Widget _buildContactsList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _demoContacts.length,
      itemBuilder: (context, index) {
        final contact = _demoContacts[index];
        return ModernContactItem(
          name: contact['name'],
          subtitle: contact['lastMessage'],
          avatarUrl: contact['avatar'],
          unreadCount: contact['unreadCount'],
          lastMessageTime: contact['time'],
          onTap: () {
            setState(() => _selectedTab = 1);
          },
          onCall: () {
            _showSnackBar('Voice call started');
          },
          onVideo: () {
            _showSnackBar('Video call started');
          },
        );
      },
    );
  }
  
  Widget _buildChatArea() {
    return Column(
      children: [
        // Chat header
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: ModernUITheme.glassContainer(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: ModernUITheme.primaryGradient,
                    image: const DecorationImage(
                      image: NetworkImage('https://i.pravatar.cc/150?img=1'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'John Smith',
                        style: ModernUITheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Online',
                        style: ModernUITheme.caption.copyWith(
                          color: ModernUITheme.successGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                ModernIconButton(
                  icon: Icons.call,
                  onPressed: () => _showSnackBar('Voice call started'),
                  color: ModernUITheme.successGreen,
                  size: 40,
                ),
                const SizedBox(width: 8),
                ModernIconButton(
                  icon: Icons.videocam,
                  onPressed: () => _showSnackBar('Video call started'),
                  color: ModernUITheme.primaryCyan,
                  size: 40,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Messages list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _demoMessages.length,
            itemBuilder: (context, index) {
              final message = _demoMessages[index];
              return ModernChatBubble(
                message: message['text'],
                isMe: message['isMe'],
                time: message['time'],
                isRead: message['isRead'],
              );
            },
          ),
        ),
        
        // Message input
        _buildMessageInput(),
      ],
    );
  }
  
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModernUITheme.surfaceWhite,
        boxShadow: ModernUITheme.softShadow,
      ),
      child: Row(
        children: [
          ModernIconButton(
            icon: Icons.add_circle_outline,
            onPressed: () => _showSnackBar('Attachment menu'),
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: ModernUITheme.glassContainer(opacity: 0.05),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: ModernUITheme.bodyMedium.copyWith(
                    color: ModernUITheme.textHint,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: ModernUITheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ModernIconButton(
            icon: Icons.send,
            onPressed: () {
              if (_messageController.text.isNotEmpty) {
                _showSnackBar('Message sent: ${_messageController.text}');
                _messageController.clear();
              }
            },
            color: ModernUITheme.primaryCyan,
            size: 40,
          ),
        ],
      ),
    );
  }
  
  Widget _buildCallHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _demoCallHistory.length,
      itemBuilder: (context, index) {
        final call = _demoCallHistory[index];
        return ModernCallCard(
          callType: call['callType'],
          status: call['status'],
          direction: call['direction'],
          duration: call['duration'],
          time: call['time'],
        );
      },
    );
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: ModernUITheme.radiusMedium,
        ),
        backgroundColor: ModernUITheme.primaryCyan,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
