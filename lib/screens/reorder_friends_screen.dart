import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../services/localization_service.dart';
import '../utils/image_proxy.dart';
import '../theme/modern_ui_theme.dart';

class ReorderFriendsScreen extends StatefulWidget {
  const ReorderFriendsScreen({super.key});

  @override
  State<ReorderFriendsScreen> createState() => _ReorderFriendsScreenState();
}

class _ReorderFriendsScreenState extends State<ReorderFriendsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
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

      // If no custom order, use the friends list order
      final orderedIds = friendOrder.isEmpty ? friendIds : friendOrder;

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

  Future<void> _saveFriendOrder() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final friendOrder = _friends.map((f) => f['uid'] as String).toList();

      await _firestore.collection('users').doc(currentUser.uid).update({
        'friendOrder': friendOrder,
      });

      setState(() => _hasChanges = false);

      if (mounted) {
        final localService = Provider.of<LocalizationService>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localService.translate('friend_order_saved')),
            backgroundColor: Colors.green,
          ),
        );

        if (kDebugMode) {
          debugPrint('✅ Friend order saved: $friendOrder');
        }

        // Return true to indicate changes were saved
        Navigator.pop(context, true);
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

    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(localService.translate('discard_changes')),
              content: Text(localService.translate('unsaved_changes_message')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(localService.translate('cancel')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text(localService.translate('discard')),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            localService.translate('reorder_friends'),
            style: ModernUITheme.headingMedium.copyWith(color: ModernUITheme.textWhite),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          flexibleSpace: Container(decoration: BoxDecoration(gradient: ModernUITheme.primaryGradient)),
          elevation: 0,
          actions: [
            if (_hasChanges)
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveFriendOrder,
                tooltip: localService.translate('save'),
              ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(gradient: ModernUITheme.backgroundGradient),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
            : _friends.isEmpty
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
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.blue.shade50,
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                localService.translate('reorder_instruction'),
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ReorderableListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _friends.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              final friend = _friends.removeAt(oldIndex);
                              _friends.insert(newIndex, friend);
                              _hasChanges = true;
                            });
                          },
                          itemBuilder: (context, index) {
                            final friend = _friends[index];
                            final photoUrl = friend['photoUrl'] as String?;
                            final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

                            return Card(
                              key: ValueKey(friend['uid']),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade600,
                                  backgroundImage: hasPhoto ? ImageProxy.getImageProvider(photoUrl) : null,
                                  onBackgroundImageError: hasPhoto ? (exception, stackTrace) {} : null,
                                  child: hasPhoto
                                      ? null
                                      : Text(
                                          (friend['username'] ?? '?')[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                ),
                                title: Text(
                                  friend['username'] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(friend['location'] ?? ''),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_hasChanges)
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _saveFriendOrder,
                              icon: const Icon(Icons.save),
                              label: Text(localService.translate('save_changes')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
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
