import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';
import 'search_contacts_screen.dart';
import 'calendar_notes_screen.dart';
import 'profile_settings_screen.dart';

class MainFeedScreen extends StatefulWidget {
  const MainFeedScreen({super.key});

  @override
  State<MainFeedScreen> createState() => _MainFeedScreenState();
}

class _MainFeedScreenState extends State<MainFeedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _messageController = TextEditingController();
  
  List<Map<String, dynamic>> _friends = [];
  String? _selectedFriendId;
  Map<String, dynamic>? _selectedFriend;
  bool _isLoading = true;
  Map<String, bool> _hasUnreadMessages = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _globalCleanupOldMessages(); // Clean up old messages on app start
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _cleanupOldMessages(String chatId) async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      // Query old messages
      final oldMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('timestamp', isLessThan: Timestamp.fromDate(sevenDaysAgo))
          .limit(100)
          .get();
      
      // Delete old messages in batch
      final batch = _firestore.batch();
      for (var doc in oldMessages.docs) {
        batch.delete(doc.reference);
      }
      
      if (oldMessages.docs.isNotEmpty) {
        await batch.commit();
      }
    } catch (e) {
      // Silently fail - cleanup is not critical
    }
  }

  Future<void> _globalCleanupOldMessages() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get all chats for current user
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('user1Id', isEqualTo: currentUser.uid)
          .get();
      
      final chatsSnapshot2 = await _firestore
          .collection('chats')
          .where('user2Id', isEqualTo: currentUser.uid)
          .get();
      
      // Combine chat IDs
      final allChatIds = <String>{};
      for (var doc in chatsSnapshot.docs) {
        allChatIds.add(doc.id);
      }
      for (var doc in chatsSnapshot2.docs) {
        allChatIds.add(doc.id);
      }
      
      // Clean up old messages from all chats
      for (var chatId in allChatIds) {
        await _cleanupOldMessages(chatId);
      }
    } catch (e) {
      // Silently fail - cleanup is not critical
    }
  }

  Future<void> _loadFriends() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final friendIds = List<String>.from(userDoc.data()?['friends'] ?? []);
      
      if (friendIds.isEmpty) {
        setState(() {
          _friends = [];
          _isLoading = false;
        });
        return;
      }

      // Load friend details
      final friendDocs = await Future.wait(
        friendIds.map((id) => _firestore.collection('users').doc(id).get()),
      );

      final friends = <Map<String, dynamic>>[];
      for (var doc in friendDocs) {
        if (doc.exists) {
          final data = doc.data()!;
          data['uid'] = doc.id;
          friends.add(data);
          
          // Check for unread messages
          _checkUnreadMessages(currentUser.uid, doc.id);
        }
      }

      setState(() {
        _friends = friends;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkUnreadMessages(String currentUserId, String friendId) async {
    try {
      // Create a consistent chat ID
      final chatId = _getChatId(currentUserId, friendId);
      
      // Check for unread messages
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: friendId)
          .where('read', isEqualTo: false)
          .limit(1)
          .get();

      setState(() {
        _hasUnreadMessages[friendId] = messagesSnapshot.docs.isNotEmpty;
      });
    } catch (e) {
      // Ignore errors
    }
  }

  String _getChatId(String userId1, String userId2) {
    return userId1.compareTo(userId2) < 0 
        ? '${userId1}_$userId2' 
        : '${userId2}_$userId1';
  }

  void _selectFriend(Map<String, dynamic> friend) {
    setState(() {
      if (_selectedFriendId == friend['uid']) {
        _selectedFriendId = null;
        _selectedFriend = null;
      } else {
        _selectedFriendId = friend['uid'];
        _selectedFriend = friend;
        _hasUnreadMessages[friend['uid']] = false; // Mark as read when opened
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedFriendId == null) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final chatId = _getChatId(currentUser.uid, _selectedFriendId!);
      final messageText = _messageController.text.trim();
      final now = DateTime.now();
      
      // Create chat document if it doesn't exist
      await _firestore.collection('chats').doc(chatId).set({
        'user1Id': currentUser.uid,
        'user2Id': _selectedFriendId,
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Add message with current timestamp
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': currentUser.uid,
        'receiverId': _selectedFriendId,
        'text': messageText,
        'timestamp': Timestamp.fromDate(now),
        'read': false,
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 7))),
      });
      
      // Clean up old messages (older than 7 days)
      _cleanupOldMessages(chatId);

      _messageController.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('メッセージを送信しました'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localService.translate('app_name')),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalendarNotesScreen()),
              );
            },
            tooltip: localService.translate('calendar'),
          ),
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchContactsScreen()),
              );
            },
            tooltip: localService.translate('add_friend'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()),
              );
            },
            tooltip: localService.translate('profile_settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Friends story-style row
            if (_friends.isNotEmpty)
              Container(
                height: 90,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _friends.length,
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
                    final isSelected = _selectedFriendId == friend['uid'];
                    final hasUnread = _hasUnreadMessages[friend['uid']] ?? false;
                    
                    return GestureDetector(
                      onTap: () => _selectFriend(friend),
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        child: Stack(
                          children: [
                            Container(
                              width: isSelected ? 70 : 64,
                              height: isSelected ? 70 : 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: hasUnread 
                                      ? Colors.green 
                                      : (isSelected ? Colors.blue : Colors.grey.shade300),
                                  width: hasUnread ? 3 : (isSelected ? 3 : 2),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: CircleAvatar(
                                  radius: isSelected ? 32 : 28,
                                  backgroundColor: Colors.blue.shade600,
                                  backgroundImage: friend['photoUrl'] != null
                                      ? NetworkImage(friend['photoUrl'])
                                      : null,
                                  child: friend['photoUrl'] == null
                                      ? Text(
                                          (friend['username'] ?? '?')[0].toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isSelected ? 24 : 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            if (hasUnread && !isSelected)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
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
            
            const Divider(height: 1),
            
            // Chat area or empty state
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _friends.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                localService.translate('no_friends'),
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Colors.grey.shade700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                localService.translate('add_friends'),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SearchContactsScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.person_add),
                                label: Text(localService.translate('add_friend')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _selectedFriend == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    localService.translate('start_conversation'),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildChatArea(localService),
            ),
            
            // Message input (only show when friend is selected)
            if (_selectedFriend != null) ...[
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: localService.translate('type_message'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          prefixIcon: const Icon(Icons.message),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea(LocalizationService localService) {
    final currentUser = _auth.currentUser;
    if (currentUser == null || _selectedFriendId == null) {
      return const SizedBox.shrink();
    }

    final chatId = _getChatId(currentUser.uid, _selectedFriendId!);

    return Column(
      children: [
        // Selected friend header
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue.shade600,
                backgroundImage: _selectedFriend!['photoUrl'] != null
                    ? NetworkImage(_selectedFriend!['photoUrl'])
                    : null,
                child: _selectedFriend!['photoUrl'] == null
                    ? Text(
                        (_selectedFriend!['username'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedFriend!['username'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _selectedFriend!['location'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone),
                onPressed: () {
                  // Voice call functionality (placeholder)
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.videocam),
                onPressed: () {
                  // Video call functionality (placeholder)
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        // Messages
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('chats')
                .doc(chatId)
                .collection('messages')
                .where('timestamp', isGreaterThan: DateTime.now().subtract(const Duration(days: 7)))
                .orderBy('timestamp', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    localService.translate('no_messages_yet'),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }

              final messages = snapshot.data!.docs;

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index].data() as Map<String, dynamic>;
                  final isMe = message['senderId'] == currentUser.uid;
                  
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue.shade600 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        message['text'] ?? '',
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
