import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';
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

  Future<void> _loadFriends() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          setState(() {
            _friendIds = List<String>.from(data?['friends'] ?? []);
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
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // 友達リストから削除
      await _firestore.collection('users').doc(currentUser.uid).update({
        'friends': FieldValue.arrayRemove([friendId])
      });

      setState(() {
        _friendIds.remove(friendId);
      });

      if (mounted) {
        final localService = Provider.of<LocalizationService>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localService.translate('friend_removed')),
            backgroundColor: Colors.orange,
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

  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);

    return Scaffold(
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
                                  backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
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

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text(
                          localService.translate('no_friends'),
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      );
                    }

                    final friends = snapshot.data!;
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
                                  backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
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
