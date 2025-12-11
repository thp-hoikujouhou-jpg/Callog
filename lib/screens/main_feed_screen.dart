import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';
import '../services/push_notification_service.dart';
import '../services/call_notification_listener.dart';
import '../utils/image_proxy.dart';
import '../utils/web_notification_listener.dart';
import 'search_contacts_screen.dart';
import 'calendar_memo_screen.dart';
import 'call_history_screen.dart';
import 'profile_settings_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'agora_voice_call_screen.dart';
import 'agora_video_call_screen.dart';

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
    
    if (kDebugMode) {
      debugPrint('🏠 [MainFeed] Initializing main feed screen...');
    }
    
    // 🔥 CRITICAL FIX: Initialize Call Listener FIRST for immediate incoming call detection
    _initializeCallListener();
    
    // Load friends immediately with post-frame callback to ensure build context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        if (kDebugMode) {
          debugPrint('🏠 [MainFeed] Post-frame: Loading friends...');
        }
        await _loadFriends();
      }
    });
    
    _globalCleanupOldMessages(); // Clean up old messages on app start
    _initializePushNotifications(); // Initialize push notifications (FCM token, etc.)
    _handleUrlParameters(); // Handle URL parameters for incoming calls (Web)
    
    // Initialize Web notification listener for background notifications
    if (kIsWeb) {
      WebNotificationListener.startListening();
    }
  }
  
  /// Handle URL parameters for incoming calls (Web platform only)
  void _handleUrlParameters() {
    if (kIsWeb) {
      // Add a small delay to ensure navigation is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          // Import and use url_handler for web
          if (mounted) {
            // URL handling will be done by UrlHandler
            // This is a placeholder for future web-specific handling
          }
        } catch (e) {
          debugPrint('URL handler error: $e');
        }
      });
    }
  }
  
  Future<void> _initializePushNotifications() async {
    try {
      debugPrint('🔔 [Push] Starting push notification initialization...');
      
      // Initialize PushNotificationService
      final pushService = PushNotificationService();
      await pushService.initialize();
      
      debugPrint('✅ [Push] Push notification service initialized successfully');
      
      // Check if token was saved
      final token = pushService.fcmToken;
      if (token != null) {
        debugPrint('📱 [Push] FCM Token acquired: ${token.substring(0, 20)}...');
      } else {
        debugPrint('⚠️ [Push] FCM Token not available yet');
      }
      
      // Call listener is now initialized in initState() for immediate availability
    } catch (e, stackTrace) {
      debugPrint('❌ [Push] Push notification initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  Future<void> _initializeCallListener() async {
    try {
      debugPrint('📞 [CallListener] Initializing call notification listener...');
      
      final CallNotificationListener callListener = CallNotificationListener();
      
      // Set up incoming call callback
      callListener.onIncomingCall = (Map<String, dynamic> callData) {
        debugPrint('📞 [CallListener] Incoming call received!');
        _handleIncomingCall(callData);
      };
      
      // Start listening
      await callListener.startListening();
      
      debugPrint('✅ [CallListener] Call notification listener started');
    } catch (e) {
      debugPrint('❌ [CallListener] Failed to initialize: $e');
    }
  }
  
  void _handleIncomingCall(Map<String, dynamic> callData) {
    final callType = callData['callType'] as String;
    final callerName = callData['callerName'] as String;
    final callerId = callData['callerId'] as String;
    final notificationId = callData['notificationId'] as String;
    
    debugPrint('📞 [CallListener] Showing incoming call dialog');
    debugPrint('📞 From: $callerName, Type: $callType');
    
    // Show incoming call dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('${callType == 'voice_call' ? '音声' : 'ビデオ'}通話着信'),
        content: Text('$callerNameさんから${callType == 'voice_call' ? '音声' : 'ビデオ'}通話がかかってきています'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Reject call
              CallNotificationListener().rejectCall(notificationId);
              debugPrint('📞 [CallListener] Call rejected');
            },
            child: const Text('拒否', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Accept call
              CallNotificationListener().acceptCall(notificationId);
              debugPrint('📞 [CallListener] Call accepted - joining channel');
              
              // Navigate to appropriate call screen
              if (callType == 'voice_call') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AgoraVoiceCallScreen(
                      friendId: callerId,
                      friendName: callerName,
                      friendPhotoUrl: null,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AgoraVideoCallScreen(
                      friendId: callerId,
                      friendName: callerName,
                      friendPhotoUrl: null,
                    ),
                  ),
                );
              }
            },
            child: const Text('応答'),
          ),
        ],
      ),
    );
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
    if (kDebugMode) {
      debugPrint('🔄 [MainFeed] Starting to load friends...');
    }
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        if (kDebugMode) {
          debugPrint('❌ [MainFeed] No current user found');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('👤 [MainFeed] Current user: ${currentUser.uid}');
      }

      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      
      if (!userDoc.exists) {
        if (kDebugMode) {
          debugPrint('❌ [MainFeed] User document does not exist in Firestore');
        }
        setState(() => _isLoading = false);
        return;
      }

      if (kDebugMode) {
        debugPrint('✅ [MainFeed] User document found');
        debugPrint('📄 [MainFeed] User data: ${userDoc.data()}');
      }

      // Load friend order from Firestore
      final friendOrder = List<String>.from(userDoc.data()?['friendOrder'] ?? []);
      final friendIds = List<String>.from(userDoc.data()?['friends'] ?? []);
      
      if (kDebugMode) {
        debugPrint('📋 [MainFeed] Loading friends - friendIds: ${friendIds.length}, friendOrder: ${friendOrder.length}');
        debugPrint('   friendIds: $friendIds');
        debugPrint('   friendOrder: $friendOrder');
      }
      
      if (friendIds.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ [MainFeed] No friends found for this user');
        }
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
          final data = doc.data();
          if (data == null) continue;
          data['uid'] = doc.id;
          friends.add(data);
          
          // Debug log to check friend data
          if (kDebugMode) {
            debugPrint('👤 Friend loaded: ${data['username']}, photoUrl: ${data['photoUrl']}');
          }
          
          // Check for unread messages
          _checkUnreadMessages(currentUser.uid, doc.id);
        }
      }

      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoading = false;
        });
        
        if (kDebugMode) {
          debugPrint('✅ Friends loaded: ${friends.length} friends');
        }
      }
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

      final selectedFriendId = _selectedFriendId;
      if (selectedFriendId == null) return;
      final chatId = _getChatId(currentUser.uid, selectedFriendId);
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

  // WebRTC voice call method (updated to use existing UI)
  Future<void> _startVoiceCall() async {
    if (kDebugMode) {
      debugPrint('📞 [VOICE CALL] Button pressed');
    }
    
    // Store friend data early to prevent state changes during async operations
    final friendId = _selectedFriendId;
    final friendData = _selectedFriend;
    
    if (friendData == null || friendId == null) {
      if (kDebugMode) {
        debugPrint('❌ [VOICE CALL] No friend selected');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('友達を選択してください')),
      );
      return;
    }

    if (kDebugMode) {
      debugPrint('✅ [VOICE CALL] Friend selected: $friendId');
      debugPrint('📱 [VOICE CALL] Requesting microphone permission...');
    }

    // Request microphone permission
    final micStatus = await Permission.microphone.request();
    
    if (kDebugMode) {
      debugPrint('🎤 [VOICE CALL] Microphone permission: $micStatus');
    }
    
    if (!micStatus.isGranted) {
      if (kDebugMode) {
        debugPrint('❌ [VOICE CALL] Microphone permission denied');
      }
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('マイクの許可が必要です'),
          content: const Text('音声通話を行うには、マイクへのアクセスを許可してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('設定を開く'),
            ),
          ],
        ),
      );
      return;
    }

    if (kDebugMode) {
      debugPrint('✅ [VOICE CALL] Permission granted! Preparing to navigate...');
      debugPrint('   - Friend ID: $_selectedFriendId');
      debugPrint('   - Friend Name: ${_selectedFriend?['username'] ?? _selectedFriend?['name'] ?? 'Unknown'}');
      debugPrint('   - Friend Photo: ${_selectedFriend?['photoUrl']}');
    }

    try {
      if (!mounted) {
        if (kDebugMode) {
          debugPrint('❌ [VOICE CALL] Widget not mounted');
        }
        return;
      }
      
      // Extract friend data (already stored safely)
      final friendName = friendData['username'] as String? ?? 
                         friendData['name'] as String? ?? 
                         'Unknown';
      final friendPhotoUrl = friendData['photoUrl'] as String?;
      
      if (kDebugMode) {
        debugPrint('🚀 [VOICE CALL] Navigating to OutgoingVoiceCallScreen...');
        debugPrint('   - ID: $friendId');
        debugPrint('   - Name: $friendName');
        debugPrint('   - Photo: $friendPhotoUrl');
      }
      
      try {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              if (kDebugMode) {
                debugPrint('📱 Building AgoraVoiceCallScreen with Agora...');
                debugPrint('   - friendId: $friendId');
                debugPrint('   - friendName: $friendName');
              }
              return AgoraVoiceCallScreen(
                friendId: friendId,
                friendName: friendName,
                friendPhotoUrl: friendPhotoUrl,
              );
            },
          ),
        );
        
        if (kDebugMode) {
          debugPrint('📞 Returned from Agora call screen');
        }
      } catch (navError, navStackTrace) {
        if (kDebugMode) {
          debugPrint('❌ Navigation error: $navError');
          debugPrint('Navigation stack trace: $navStackTrace');
        }
        rethrow;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error starting voice call: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('通話開始エラー: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Video call method (similar to voice call)
  Future<void> _startVideoCall() async {
    if (kDebugMode) {
      debugPrint('📹 [VIDEO CALL] Button pressed');
    }
    
    // Store friend data early to prevent state changes during async operations
    final friendId = _selectedFriendId;
    final friendData = _selectedFriend;
    
    if (friendData == null || friendId == null) {
      if (kDebugMode) {
        debugPrint('❌ [VIDEO CALL] No friend selected');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('友達を選択してください')),
      );
      return;
    }

    if (kDebugMode) {
      debugPrint('✅ [VIDEO CALL] Friend selected: $friendId');
      debugPrint('📱 [VIDEO CALL] Requesting camera and microphone permissions...');
    }

    // Request camera and microphone permissions
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();
    
    if (kDebugMode) {
      debugPrint('📹 [VIDEO CALL] Camera permission: $cameraStatus');
      debugPrint('🎤 [VIDEO CALL] Microphone permission: $micStatus');
    }
    
    if (cameraStatus.isGranted == false || micStatus.isGranted == false) {
      if (kDebugMode) {
        debugPrint('❌ [VIDEO CALL] Permissions denied');
      }
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('カメラとマイクの許可が必要です'),
          content: const Text('ビデオ通話を行うには、カメラとマイクへのアクセスを許可してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('設定を開く'),
            ),
          ],
        ),
      );
      return;
    }

    if (kDebugMode) {
      debugPrint('✅ [VIDEO CALL] Permissions granted! Preparing to navigate...');
    }

    try {
      if (!mounted) return;
      
      // Extract friend data (already stored safely)
      final friendName = friendData['username'] as String? ?? 
                         friendData['name'] as String? ?? 
                         'Unknown';
      final friendPhotoUrl = _selectedFriend?['photoUrl'] as String?;
      
      if (kDebugMode) {
        debugPrint('🚀 [VIDEO CALL] Navigating to AgoraVideoCallScreen...');
      }
      
      // Navigate to Agora Video Call Screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            if (kDebugMode) {
              debugPrint('📱 Building AgoraVideoCallScreen...');
            }
            return AgoraVideoCallScreen(
              friendId: friendId,
              friendName: friendName,
              friendPhotoUrl: friendPhotoUrl,
            );
          },
        ),
      );
      
      if (kDebugMode) {
        debugPrint('📞 Returned from video call screen');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error starting video call: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ビデオ通話開始エラー: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationService>(
      builder: (context, localService, child) {
        return Scaffold(
      appBar: AppBar(
        title: Text(localService.translate('app_name')),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          // Only show call history button on larger screens (PC/tablet)
          if (MediaQuery.of(context).size.width > 600)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CallHistoryScreen()),
                );
              },
              tooltip: localService.translate('call_history'),
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalendarMemoScreen()),
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
                if (kDebugMode) {
                  debugPrint('🔄 Reloading friends list after returning from search screen (changed: $result)');
                }
                setState(() {
                  _isLoading = true;
                });
                await _loadFriends();
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
                                      ? ImageProxy.getImageProvider(friend['photoUrl'])
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
                                    setState(() {
                                      _isLoading = true;
                                    });
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
      },
    );
  }

  Widget _buildChatArea(LocalizationService localService) {
    final currentUser = _auth.currentUser;
    final selectedId = _selectedFriendId;
    
    if (currentUser == null || selectedId == null) {
      // Show friendly placeholder instead of blank gray area
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              localService.translate('select_friend_to_chat'),
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localService.translate('tap_friend_to_start_chat'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    final chatId = _getChatId(currentUser.uid, selectedId);

    return Column(
      children: [
        // Selected friend header
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              Builder(
                builder: (context) {
                  final photoUrl = _selectedFriend?['photoUrl'];
                  final hasPhoto = photoUrl != null && photoUrl.toString().isNotEmpty;
                  
                  return CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue.shade600,
                    backgroundImage: hasPhoto
                        ? ImageProxy.getImageProvider(photoUrl)
                        : null,
                    onBackgroundImageError: hasPhoto
                        ? (exception, stackTrace) {
                            if (kDebugMode) {
                              debugPrint('Failed to load profile image: $exception');
                            }
                          }
                        : null,
                    child: !hasPhoto
                        ? Text(
                            (_selectedFriend?['username'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedFriend?['username'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      _selectedFriend?['location'] ?? '',
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
                onPressed: _startVideoCall,
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
                final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                backgroundId = userData?['chatBackground'] ?? 'default';
              }

              // Define all background gradients
              final Map<String, List<Color>> backgroundColors = {
                'default': [Colors.white, Colors.white],  // Pure white background for clarity
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

                    if (!snapshot.hasData || snapshot.data?.docs.isEmpty == true) {
                      return Center(
                        child: Text(
                          localService.translate('no_messages_yet'),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      );
                    }

                    final messages = snapshot.data?.docs ?? [];

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index].data() as Map<String, dynamic>;
                        final isMe = message['senderId'] == currentUser.uid;
                        final isRead = message['read'] ?? false;
                        final messageType = message['type'] ?? 'text';
                        
                        // CRITICAL: Check if this is a call notification message
                        final isCallMessage = messageType.contains('call');
                        final isVideoCall = messageType.contains('video');
                        final isMissedCall = messageType.contains('missed');
                        
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              // Call notification (missed call) UI - WhatsApp/LINE style
                              if (isCallMessage)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMissedCall 
                                        ? Colors.red.shade50 
                                        : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isMissedCall 
                                          ? Colors.red.shade300 
                                          : Colors.green.shade300,
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Call type icon (video/voice) - Larger and more prominent
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isMissedCall ? Colors.red.shade100 : Colors.green.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isVideoCall ? Icons.videocam : Icons.phone,
                                          size: 24,
                                          color: isMissedCall ? Colors.red.shade700 : Colors.green.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Incoming arrow icon (WhatsApp/LINE style)
                                      Icon(
                                        Icons.call_received,
                                        size: 20,
                                        color: isMissedCall ? Colors.red.shade600 : Colors.green.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isMissedCall 
                                                ? (isVideoCall ? localService.translate('missed_video_call') : localService.translate('missed_voice_call'))
                                                : (isVideoCall ? localService.translate('video_call') : localService.translate('voice_call')),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: isMissedCall ? Colors.red.shade800 : Colors.green.shade800,
                                            ),
                                          ),
                                          if (message['duration'] != null)
                                            Text(
                                              message['duration'] as String,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              // Regular text message UI
                              else
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
