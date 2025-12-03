import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';
import '../utils/image_proxy.dart';
import 'reorder_friends_screen.dart';

class SearchContactsScreen extends StatefulWidget {
  const SearchContactsScreen({super.key});

  @override
  State<SearchContactsScreen> createState() => _SearchContactsScreenState();
}

class _SearchContactsScreenState extends State<SearchContactsScreen> {
  final _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSearching = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _friendIds = [];
  bool _friendsChanged = false; // Track if friend list or order changed

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getChatId(String userId1, String userId2) {
    return userId1.compareTo(userId2) < 0 
        ? '${userId1}_$userId2' 
        : '${userId2}_$userId1';
  }

  Future<void> _loadFriends() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          final friendIds = List<String>.from(data?['friends'] ?? []);
          final friendOrder = List<String>.from(data?['friendOrder'] ?? []);
          
          // Use friendOrder if available, otherwise use friendIds order
          final orderedIds = friendOrder.isEmpty ? friendIds : friendOrder;
          
          // Add any new friends not in the order list
          for (var id in friendIds) {
            if (!orderedIds.contains(id)) {
              orderedIds.add(id);
            }
          }
          
          // Remove any friends that are no longer in the friends list
          orderedIds.removeWhere((id) => !friendIds.contains(id));
          
          setState(() {
            _friendIds = orderedIds;
          });
        }
      }
    } catch (e) {
      // エラーハンドリング
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // すべてのユーザーを取得してクライアント側でフィルタリング（インデックス不要）
      final querySnapshot = await _firestore
          .collection('users')
          .limit(100)
          .get();

      final results = <Map<String, dynamic>>[];
      final searchLower = query.toLowerCase();
      
      for (var doc in querySnapshot.docs) {
        // 自分自身は除外
        if (doc.id != currentUser.uid) {
          final data = doc.data();
          final username = (data['username'] ?? '').toString().toLowerCase();
          
          // クライアント側で部分一致検索
          if (username.contains(searchLower)) {
            data['uid'] = doc.id;
            results.add(data);
          }
        }
      }

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addFriend(String friendId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // 友達リストに追加
      await _firestore.collection('users').doc(currentUser.uid).update({
        'friends': FieldValue.arrayUnion([friendId])
      });

      setState(() {
        _friendIds.add(friendId);
        _friendsChanged = true; // Mark as changed
      });

      if (mounted) {
        final localService = Provider.of<LocalizationService>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localService.translate('friend_added')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final localService = Provider.of<LocalizationService>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localService.translate('error_occurred')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeFriend(String friendId) async {
    final localService = Provider.of<LocalizationService>(context, listen: false);
    
    if (kDebugMode) {
      debugPrint('🗑️ _removeFriend called for friendId: $friendId');
    }
    
    // 確認ダイアログを表示
    if (kDebugMode) {
      debugPrint('📋 Showing confirmation dialog...');
    }
    
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        if (kDebugMode) {
          debugPrint('🎨 Building AlertDialog...');
        }
        
        // レスポンシブ対応: 画面サイズを取得
        final screenWidth = MediaQuery.of(dialogContext).size.width;
        final isSmallScreen = screenWidth < 600; // スマホ・タブレット判定
        
        if (kDebugMode) {
          debugPrint('📱 Screen width: $screenWidth, isSmallScreen: $isSmallScreen');
        }
        
        return AlertDialog(
          title: Text(localService.translate('delete_friend')),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isSmallScreen ? screenWidth * 0.8 : 400,
            ),
            child: Text(
              localService.translate('delete_friend_confirmation'),
            ),
          ),
          contentPadding: EdgeInsets.fromLTRB(
            isSmallScreen ? 16 : 24,
            isSmallScreen ? 16 : 20,
            isSmallScreen ? 16 : 24,
            isSmallScreen ? 12 : 24,
          ),
          actionsPadding: EdgeInsets.fromLTRB(
            isSmallScreen ? 8 : 24,
            0,
            isSmallScreen ? 8 : 24,
            isSmallScreen ? 8 : 24,
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (kDebugMode) {
                  debugPrint('❌ User selected: No');
                }
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(
                localService.translate('no'),
                style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
              ),
            ),
            TextButton(
              onPressed: () {
                if (kDebugMode) {
                  debugPrint('✅ User selected: Yes');
                }
                Navigator.of(dialogContext).pop(true);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text(
                localService.translate('yes'),
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    
    if (kDebugMode) {
      debugPrint('💭 Dialog result: $shouldDelete');
    }
    
    // ユーザーが「No」を選択した場合は処理を中断
    if (shouldDelete != true) {
      if (kDebugMode) {
        debugPrint('🚫 Deletion cancelled by user');
      }
      return;
    }
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      if (kDebugMode) {
        debugPrint('🔄 Starting deletion process...');
        debugPrint('   Current User: ${currentUser.uid}');
        debugPrint('   Friend to remove: $friendId');
      }

      // チャットIDを計算
      final chatId = _getChatId(currentUser.uid, friendId);
      
      if (kDebugMode) {
        debugPrint('💬 Chat ID to delete: $chatId');
      }

      // 1. チャット履歴を削除
      try {
        // チャットドキュメント内のすべてのメッセージを取得
        final messagesSnapshot = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .get();
        
        if (kDebugMode) {
          debugPrint('📨 Found ${messagesSnapshot.docs.length} messages to delete');
        }

        // すべてのメッセージを削除
        if (messagesSnapshot.docs.isNotEmpty) {
          final batch = _firestore.batch();
          for (var doc in messagesSnapshot.docs) {
            if (kDebugMode) {
              debugPrint('   🗑️ Deleting message: ${doc.id}');
            }
            batch.delete(doc.reference);
          }
          
          // バッチコミット
          await batch.commit();
          
          if (kDebugMode) {
            debugPrint('✅ All messages deleted successfully');
          }
        } else {
          if (kDebugMode) {
            debugPrint('ℹ️ No messages to delete');
          }
        }
        
        // チャットドキュメント自体も削除
        if (kDebugMode) {
          debugPrint('🗑️ Deleting chat document: $chatId');
        }
        await _firestore.collection('chats').doc(chatId).delete();
        
        if (kDebugMode) {
          debugPrint('✅ Chat document deleted successfully');
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ ERROR deleting chat history: $e');
          debugPrint('📍 Stack trace: $stackTrace');
        }
        
        // エラーメッセージをユーザーに表示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('チャット履歴の削除に失敗しました: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        
        // チャット履歴の削除に失敗した場合は処理を中断
        return;
      }

      // 2. 友達リストとfriendOrderから削除
      await _firestore.collection('users').doc(currentUser.uid).update({
        'friends': FieldValue.arrayRemove([friendId]),
        'friendOrder': FieldValue.arrayRemove([friendId]),
      });
      
      if (kDebugMode) {
        debugPrint('✅ Friend removed from list and friendOrder');
      }

      setState(() {
        _friendIds.remove(friendId);
        _friendsChanged = true; // Mark as changed
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localService.translate('friend_removed')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localService.translate('error_occurred')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);

    return WillPopScope(
      onWillPop: () async {
        // Return true to indicate friends changed
        Navigator.pop(context, _friendsChanged);
        return false; // Prevent default pop
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(localService.translate('add_friend')),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_vert),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReorderFriendsScreen()),
              );
              
              // Reload friends if changes were saved
              if (result == true) {
                await _loadFriends();
                _friendsChanged = true; // Mark as changed
              }
            },
            tooltip: localService.translate('reorder_friends'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: localService.translate('search_by_username'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchUsers('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  _searchUsers(value);
                },
              ),
            ),
            Expanded(
              child: _isSearching
                  ? _buildSearchResults(localService)
                  : _buildFriendsList(localService),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSearchResults(LocalizationService localService) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            localService.translate('search_results'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            localService.translate('no_users_found'),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        final isFriend = _friendIds.contains(user['uid']);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Builder(
                              builder: (context) {
                                final photoUrl = user['photoUrl'] as String?;
                                final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
                                
                                return CircleAvatar(
                                  backgroundColor: Colors.blue.shade600,
                                  backgroundImage: hasPhoto ? ImageProxy.getImageProvider(photoUrl) : null,
                                  onBackgroundImageError: hasPhoto ? (exception, stackTrace) {} : null,
                                  child: hasPhoto
                                      ? null
                                      : Text(
                                          (user['username'] ?? '?')[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                );
                              },
                            ),
                            title: Text(
                              user['username'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(user['location'] ?? ''),
                            trailing: isFriend
                                ? TextButton(
                                    onPressed: () => _removeFriend(user['uid']),
                                    child: Text(localService.translate('remove_button')),
                                  )
                                : ElevatedButton(
                                    onPressed: () => _addFriend(user['uid']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(localService.translate('add_button')),
                                  ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFriendsList(LocalizationService localService) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            localService.translate('added_friends'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: _friendIds.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        localService.translate('no_friends'),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : FutureBuilder<List<DocumentSnapshot>>(
                  future: Future.wait(
                    _friendIds.map((id) => _firestore.collection('users').doc(id).get()),
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final data = snapshot.data;
                    if (!snapshot.hasData || data == null || data.isEmpty) {
                      return Center(
                        child: Text(
                          localService.translate('no_friends'),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      );
                    }

                    final friends = snapshot.data ?? [];
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        if (!friend.exists) return const SizedBox.shrink();

                        final data = friend.data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Builder(
                              builder: (context) {
                                final photoUrl = data['photoUrl'] as String?;
                                final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
                                
                                return CircleAvatar(
                                  backgroundColor: Colors.blue.shade600,
                                  backgroundImage: hasPhoto ? ImageProxy.getImageProvider(photoUrl) : null,
                                  onBackgroundImageError: hasPhoto ? (exception, stackTrace) {} : null,
                                  child: hasPhoto
                                      ? null
                                      : Text(
                                          (data['username'] ?? '?')[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                );
                              },
                            ),
                            title: Text(
                              data['username'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(data['location'] ?? ''),
                            trailing: TextButton(
                              onPressed: () => _removeFriend(friend.id),
                              child: Text(localService.translate('remove_button')),
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
