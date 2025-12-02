import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';
import '../services/voice_call_service.dart';
import 'search_contacts_screen.dart';
import 'calendar_notes_screen.dart';
import 'profile_settings_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'outgoing_voice_call_screen.dart';

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
  Map<String, int> _unreadMessageCounts = {}; // Track unread message count per friend
  Map<String, dynamic> _messageListeners = {}; // Store listeners for cleanup

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _globalCleanupOldMessages(); // Clean up old messages on app start
    _initializePushNotifications(); // Initialize push notifications
  }
  
  Future<void> _initializePushNotifications() async {
    try {
      // This will be initialized in CallogApp, but we can get the instance here
      // No need to do anything special - notifications are handled globally
      if (kDebugMode) {
        debugPrint('✅ Push notifications ready');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Push notification initialization error: $e');
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    // Cancel all message listeners
    _messageListeners.forEach((key, listener) {
      listener?.cancel();
    });
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

      // Load friend order from Firestore
      final friendOrder = List<String>.from(userDoc.data()?['friendOrder'] ?? []);
      final friendIds = List<String>.from(userDoc.data()?['friends'] ?? []);
      
      if (kDebugMode) {
        debugPrint('📋 Loading friends - friendIds: ${friendIds.length}, friendOrder: ${friendOrder.length}');
        debugPrint('   friendOrder: $friendOrder');
      }
      
      if (friendIds.isEmpty) {
        setState(() {
          _friends = [];
          _isLoading = false;
        });
        return;
      }

      // If no custom order, use the friends list order
      final orderedIds = friendOrder.isEmpty ? friendIds : friendOrder;
      
      if (kDebugMode) {
        debugPrint('   Using order: $orderedIds');
      }

      // Add any new friends not in the order list
      for (var id in friendIds) {
        if (!orderedIds.contains(id)) {
          orderedIds.add(id);
        }
      }

      // Remove any friends that are no longer in the friends list
      orderedIds.removeWhere((id) => !friendIds.contains(id));

      // Load friend details
      final friendDocs = await Future.wait(
        orderedIds.map((id) => _firestore.collection('users').doc(id).get()),
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

  void _setupUnreadMessageListener(String currentUserId, String friendId) {
    try {
      // Cancel existing listener if any
      _messageListeners[friendId]?.cancel();
      
      final chatId = _getChatId(currentUserId, friendId);
      
      if (kDebugMode) {
        debugPrint('🔍 ================================');
        debugPrint('🔍 Setting up listener:');
        debugPrint('   Current User: $currentUserId');
        debugPrint('   Friend ID: $friendId');
        debugPrint('   Chat ID: $chatId');
        debugPrint('   Collection: chats/$chatId/messages');
        debugPrint('   Query: senderId == $friendId AND read == false');
        debugPrint('🔍 ================================');
      }
      
      // Set up real-time listener for unread messages
      final listener = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: friendId)
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          final hasUnread = snapshot.docs.isNotEmpty;
          final unreadCount = snapshot.docs.length;
          
          if (kDebugMode) {
            debugPrint('📩 ================================');
            debugPrint('📩 Listener update:');
            debugPrint('   Friend ID: $friendId');
            debugPrint('   Chat ID: $chatId');
            debugPrint('   Has Unread: $hasUnread');
            debugPrint('   Unread Count: $unreadCount');
            debugPrint('   Total Docs: ${snapshot.docs.length}');
            if (snapshot.docs.isNotEmpty) {
              debugPrint('   Messages:');
              for (var doc in snapshot.docs) {
                final data = doc.data();
                debugPrint('     • ID: ${doc.id}');
                debugPrint('       From: ${data['senderId']}');
                debugPrint('       To: ${data['receiverId']}');
                debugPrint('       Text: "${data['text']}"');
                debugPrint('       Read: ${data['read']}');
              }
            } else {
              debugPrint('   No unread messages found');
            }
            debugPrint('📩 ================================');
          }
          
          // Update state for this specific friend
          final oldUnreadCount = _unreadMessageCounts[friendId] ?? 0;
          
          if (kDebugMode) {
            debugPrint('🔄 Updating state: friend=$friendId, oldCount=$oldUnreadCount, newCount=$unreadCount');
          }
          
          setState(() {
            _hasUnreadMessages[friendId] = hasUnread;
            _unreadMessageCounts[friendId] = unreadCount;
            
            // Sort friends by unread message count (descending)
            _sortFriendsByUnreadCount();
          });
          
          if (kDebugMode) {
            debugPrint('✅ State updated and sorted for friend: $friendId');
          }
        }
      }, onError: (error) {
        if (kDebugMode) {
          debugPrint('❌ Listener error for friend $friendId: $error');
        }
      });
      
      _messageListeners[friendId] = listener;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error setting up unread listener: $e');
      }
    }
  }
  
  Future<void> _checkUnreadMessages(String currentUserId, String friendId) async {
    // Now just set up the listener instead of one-time check
    _setupUnreadMessageListener(currentUserId, friendId);
  }
  
  void _sortFriendsByUnreadCount() {
    // Create a map to store original order indices
    final Map<String, int> originalOrder = {};
    for (int i = 0; i < _friends.length; i++) {
      originalOrder[_friends[i]['uid']] = i;
    }
    
    // Sort friends: most unread messages first
    _friends.sort((a, b) {
      final aCount = _unreadMessageCounts[a['uid']] ?? 0;
      final bCount = _unreadMessageCounts[b['uid']] ?? 0;
      
      // Sort by unread count (descending)
      if (aCount != bCount) {
        return bCount.compareTo(aCount);
      }
      
      // If same unread count (including 0), maintain friendOrder (original order)
      final aIndex = originalOrder[a['uid']] ?? 0;
      final bIndex = originalOrder[b['uid']] ?? 0;
      return aIndex.compareTo(bIndex);
    });
    
    if (kDebugMode) {
      debugPrint('🔄 Friends sorted by unread count:');
      for (var friend in _friends) {
        final count = _unreadMessageCounts[friend['uid']] ?? 0;
        debugPrint('   - ${friend['username']}: $count unread messages');
      }
    }
  }

  String _getChatId(String userId1, String userId2) {
    return userId1.compareTo(userId2) < 0 
        ? '${userId1}_$userId2' 
        : '${userId2}_$userId1';
  }

  void _selectFriend(Map<String, dynamic> friend) {
    final friendId = friend['uid'] as String?;
    if (friendId == null) return;
    
    final wasSelected = _selectedFriendId == friendId;
    
    setState(() {
      if (wasSelected) {
        // Deselecting friend
        _selectedFriendId = null;
        _selectedFriend = null;
        // Keep hasUnreadMessages[friendId] = false (already marked as read)
      } else {
        // Selecting new friend
        _selectedFriendId = friendId;
        _selectedFriend = friend;
        // Immediately mark as read in UI for instant feedback
        _hasUnreadMessages[friendId] = false;
      }
    });
    
    // Mark as read in Firestore when selecting (not deselecting)
    if (!wasSelected) {
      _markMessagesAsRead(friendId).then((_) {
        // Double-check UI stays updated after Firestore sync
        if (mounted) {
          setState(() {
            _hasUnreadMessages[friendId] = false;
          });
        }
      });
    }
  }

  Future<void> _markMessagesAsRead(String friendId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('❌ Cannot mark as read: No current user');
        }
        return;
      }

      final chatId = _getChatId(currentUser.uid, friendId);
      
      if (kDebugMode) {
        debugPrint('🔄 Marking messages as read: friendId=$friendId, chatId=$chatId, currentUser=${currentUser.uid}');
      }
      
      // Get all unread messages from this friend
      final unreadMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isEqualTo: friendId)
          .where('read', isEqualTo: false)
          .get();
      
      if (kDebugMode) {
        debugPrint('📬 Found ${unreadMessages.docs.length} unread messages to mark as read');
      }
      
      // Mark all as read using batch
      if (unreadMessages.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in unreadMessages.docs) {
          if (kDebugMode) {
            final data = doc.data();
            debugPrint('   - Marking as read: ${doc.id} from ${data['senderId']} to ${data['receiverId']}');
          }
          batch.update(doc.reference, {
            'read': true,
            'readAt': FieldValue.serverTimestamp(), // Add timestamp for tracking
          });
        }
        await batch.commit();
        
        if (kDebugMode) {
          debugPrint('✅ Successfully marked ${unreadMessages.docs.length} messages as read for friend: $friendId');
        }
        
        // Force update UI state after successful Firestore update
        if (mounted) {
          setState(() {
            _hasUnreadMessages[friendId] = false;
            _unreadMessageCounts[friendId] = 0;
            
            // Re-sort friends after marking as read
            _sortFriendsByUnreadCount();
          });
        }
      } else {
        if (kDebugMode) {
          debugPrint('ℹ️ No unread messages found for friend: $friendId');
        }
      }
    } catch (e) {
      // Silently fail - not critical
      if (kDebugMode) {
        debugPrint('❌ Error marking messages as read: $e');
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedFriendId == null) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final chatId = _getChatId(currentUser.uid, _selectedFriendId!);
      final messageText = _messageController.text.trim();
      final now = DateTime.now();
      
      if (kDebugMode) {
        debugPrint('📤 ================================');
        debugPrint('📤 Sending message:');
        debugPrint('   From (senderId): ${currentUser.uid}');
        debugPrint('   To (receiverId): $_selectedFriendId');
        debugPrint('   Chat ID: $chatId');
        debugPrint('   Collection: chats/$chatId/messages');
        debugPrint('   Text: "$messageText"');
        debugPrint('   Read: false');
        debugPrint('📤 ================================');
      }
      
      // Create chat document if it doesn't exist
      await _firestore.collection('chats').doc(chatId).set({
        'user1Id': currentUser.uid,
        'user2Id': _selectedFriendId,
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Add message with current timestamp
      final messageDoc = await _firestore
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
      
      if (kDebugMode) {
        debugPrint('✅ ================================');
        debugPrint('✅ Message sent successfully!');
        debugPrint('   Message ID: ${messageDoc.id}');
        debugPrint('   Path: chats/$chatId/messages/${messageDoc.id}');
        debugPrint('   Timestamp: ${Timestamp.fromDate(now)}');
        debugPrint('✅ ================================');
      }
      
      _messageController.clear();
      
      // Clean up old messages asynchronously (don't block UI)
      _cleanupOldMessages(chatId).catchError((e) {
        if (kDebugMode) {
          debugPrint('⚠️ Background cleanup error: $e');
        }
      });
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

  // New WebRTC voice call method
  Future<void> _initiateVoiceCall() async {
    if (kDebugMode) {
      debugPrint('📞 Voice call button pressed');
    }
    
    if (_selectedFriend == null || _selectedFriendId == null) {
      if (kDebugMode) {
        debugPrint('❌ No friend selected');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('📞 Requesting microphone permission...');
    }

    try {
      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      
      if (kDebugMode) {
        debugPrint('🎤 Microphone permission status: $micStatus');
      }

      if (!micStatus.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('マイクの権限が必要です'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (kDebugMode) {
        debugPrint('✅ Permission granted, navigating to call screen...');
        debugPrint('   Friend ID: $_selectedFriendId');
        debugPrint('   Friend Name: ${_selectedFriend!['name']}');
      }

      // Navigate to outgoing call screen with WebRTC
      if (!mounted) return;
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OutgoingVoiceCallScreen(
            friendId: _selectedFriendId!,
            friendName: _selectedFriend!['name'] ?? 'Unknown',
            friendPhotoUrl: _selectedFriend!['photoUrl'],
          ),
        ),
      );
      
      if (kDebugMode) {
        debugPrint('📞 Returned from call screen');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error initiating voice call: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('通話開始エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startVoiceCall() async {
    if (_selectedFriend == null || _selectedFriendId == null) return;

    final localService = Provider.of<LocalizationService>(context, listen: false);
    final callService = Provider.of<VoiceCallService>(context, listen: false);

    // Request call permissions
    final permissionResult = await callService.requestCallPermissions();
    
    if (!permissionResult.granted) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(localService.translate('permission_required')),
          content: Text(localService.translate('microphone_permission')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localService.translate('cancel')),
            ),
            if (permissionResult.shouldOpenSettings)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: Text(localService.translate('open_settings')),
              )
            else
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Request again
                  await callService.requestCallPermissions();
                },
                child: Text(localService.translate('grant_permission')),
              ),
          ],
        ),
      );
      return;
    }

    // Initiate call
    final result = await callService.initiateCall(
      friendId: _selectedFriendId!,
      friendName: _selectedFriend!['username'] ?? 'Unknown',
      friendPhotoUrl: _selectedFriend!['photoUrl'],
      callType: CallType.voice,
    );

    if (!result.success) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }

    // Navigate to outgoing call screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OutgoingVoiceCallScreen(
            friendId: _selectedFriendId!,
            friendName: _selectedFriend!['username'] ?? 'Unknown',
            friendPhotoUrl: _selectedFriend!['photoUrl'],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use listen: false to avoid rebuild issues during login
    final localService = Provider.of<LocalizationService>(context, listen: false);

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
            onPressed: () async {
              // Navigate to search contacts screen
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchContactsScreen()),
              );
              
              // Always reload friends list when returning from search screen
              if (mounted) {
                await _loadFriends();
                
                if (kDebugMode) {
                  debugPrint('🔄 Reloading friends list after returning from search screen (changed: $result)');
                }
              }
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
                                  color: isSelected
                                      ? Colors.blue  // Selected: always blue
                                      : (hasUnread ? Colors.green : Colors.grey.shade300),
                                  width: isSelected || hasUnread ? 3 : 2,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: CircleAvatar(
                                  radius: isSelected ? 32 : 28,
                                  backgroundColor: Colors.blue.shade600,
                                  backgroundImage: (friend['photoUrl'] != null && 
                                                    friend['photoUrl'].toString().isNotEmpty)
                                      ? NetworkImage(friend['photoUrl'])
                                      : null,
                                  onBackgroundImageError: (friend['photoUrl'] != null && 
                                                          friend['photoUrl'].toString().isNotEmpty)
                                      ? (exception, stackTrace) {
                                          // Silently handle image loading errors
                                          if (kDebugMode) {
                                            debugPrint('Failed to load profile image: $exception');
                                          }
                                        }
                                      : null,
                                  child: (friend['photoUrl'] == null || 
                                         friend['photoUrl'].toString().isEmpty)
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
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SearchContactsScreen(),
                                    ),
                                  );
                                  
                                  // Reload friends list when returning
                                  if (mounted) {
                                    await _loadFriends();
                                  }
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
                    // Voice call button
                    IconButton(
                      onPressed: _initiateVoiceCall,
                      icon: const Icon(Icons.phone),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'Voice Call',
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
                backgroundImage: (_selectedFriend!['photoUrl'] != null && 
                                  _selectedFriend!['photoUrl'].toString().isNotEmpty)
                    ? NetworkImage(_selectedFriend!['photoUrl'])
                    : null,
                onBackgroundImageError: (_selectedFriend!['photoUrl'] != null && 
                                        _selectedFriend!['photoUrl'].toString().isNotEmpty)
                    ? (exception, stackTrace) {
                        if (kDebugMode) {
                          debugPrint('Failed to load profile image: $exception');
                        }
                      }
                    : null,
                child: (_selectedFriend!['photoUrl'] == null || 
                       _selectedFriend!['photoUrl'].toString().isEmpty)
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
                        color: Colors.black,
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
                onPressed: _startVoiceCall,
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
        
        // Messages with dynamic background
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('users').doc(currentUser.uid).snapshots(),
            builder: (context, userSnapshot) {
              // Get user's background preference
              String backgroundId = 'default';
              if (userSnapshot.hasData && userSnapshot.data != null) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                backgroundId = userData?['chatBackground'] ?? 'default';
              }

              // Define all background gradients
              final Map<String, List<Color>> backgroundColors = {
                'default': [const Color(0xFFE3F2FD), const Color(0xFFFFFFFF)],
                'blue_gradient': [const Color(0xFFBBDEFB), const Color(0xFFE3F2FD)],
                'purple_gradient': [const Color(0xFFE1BEE7), const Color(0xFFF3E5F5)],
                'pink_gradient': [const Color(0xFFF8BBD0), const Color(0xFFFCE4EC)],
                'green_gradient': [const Color(0xFFC8E6C9), const Color(0xFFE8F5E9)],
                'orange_gradient': [const Color(0xFFFFE0B2), const Color(0xFFFFF3E0)],
                'dark_blue': [const Color(0xFF0D47A1), const Color(0xFF1565C0)],
                'dark_purple': [const Color(0xFF4A148C), const Color(0xFF6A1B9A)],
                'sunset': [const Color(0xFFFF9800), const Color(0xFFE91E63)],
                'ocean': [const Color(0xFF00BCD4), const Color(0xFF2196F3)],
              };

              final colors = backgroundColors[backgroundId] ?? backgroundColors['default']!;

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
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
                        final isRead = message['read'] ?? false;
                        
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
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
                              // 既読/未読表示（自分のメッセージのみ）
                            if (isMe)
                              Padding(
                                padding: const EdgeInsets.only(right: 8, bottom: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isRead ? Icons.done_all : Icons.done,
                                      size: 16,
                                      color: isRead ? Colors.blue.shade600 : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isRead ? localService.translate('read') : localService.translate('unread'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isRead ? Colors.blue.shade600 : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        );
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
      ],
    );
  }
}
