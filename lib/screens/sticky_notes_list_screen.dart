import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';
import '../models/sticky_note.dart';
import 'sticky_note_editor_screen.dart';

class StickyNotesListScreen extends StatefulWidget {
  final DateTime selectedDate;
  
  const StickyNotesListScreen({
    super.key,
    required this.selectedDate,
  });

  @override
  State<StickyNotesListScreen> createState() => _StickyNotesListScreenState();
}

class _StickyNotesListScreenState extends State<StickyNotesListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<StickyNote> _notes = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadStickyNotes();
  }
  
  /// Load sticky notes for selected date
  Future<void> _loadStickyNotes() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Get start and end of selected date
      final startOfDay = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
      );
      final endOfDay = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        23,
        59,
        59,
      );
      
      // Query sticky notes for selected date
      final querySnapshot = await _firestore
          .collection('sticky_notes')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      
      // Convert to StickyNote objects and sort by position
      final notes = querySnapshot.docs
          .map((doc) => StickyNote.fromFirestore(doc.data(), doc.id))
          .toList();
      
      notes.sort((a, b) => a.position.compareTo(b.position));
      
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
      
      if (kDebugMode) {
        debugPrint('📋 [StickyNotesList] Loaded ${notes.length} notes for ${widget.selectedDate}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StickyNotesList] Error loading notes: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Delete sticky note
  Future<void> _deleteNote(StickyNote note) async {
    try {
      await _firestore.collection('sticky_notes').doc(note.id).delete();
      
      setState(() {
        _notes.remove(note);
      });
      
      if (kDebugMode) {
        debugPrint('✅ [StickyNotesList] Deleted note: ${note.id}');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メモを削除しました'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StickyNotesList] Error deleting note: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(StickyNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メモを削除'),
        content: const Text('このメモを削除してもよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _deleteNote(note);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_formatDate(localService)),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? _buildEmptyState()
              : _buildStickyNotesGrid(),
    );
  }
  
  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'まだメモがありません',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '下の + ボタンでメモを作成',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build sticky notes grid (masonry-style layout)
  Widget _buildStickyNotesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,  // 2 columns
        childAspectRatio: 0.8,  // Slightly taller than wide
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        return _buildStickyNoteCard(_notes[index]);
      },
    );
  }
  
  /// Build sticky note card
  Widget _buildStickyNoteCard(StickyNote note) {
    final color = Color(int.parse(note.colorHex.substring(1), radix: 16) + 0xFF000000);
    
    return GestureDetector(
      onTap: () async {
        // Navigate to editor for editing
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StickyNoteEditorScreen(
              selectedDate: widget.selectedDate,
              contactId: note.contactId,
              contactName: note.contactName,
              contactPhotoUrl: note.contactPhotoUrl,
              callRecordings: const [],  // Not needed for editing
              existingNote: note,
            ),
          ),
        );
        
        // Reload notes after editing
        if (result == true || mounted) {
          _loadStickyNotes();
        }
      },
      onLongPress: () => _showDeleteConfirmation(note),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contact name header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white.withValues(alpha: 0.5),
                        backgroundImage: note.contactPhotoUrl != null
                            ? NetworkImage(note.contactPhotoUrl!)
                            : null,
                        child: note.contactPhotoUrl == null
                            ? Text(
                                note.contactName[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note.contactName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Key points (preview)
                  const Text(
                    '📝 要点:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note.keyPoints,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Results (preview)
                  const Text(
                    '✅ 結果:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note.results,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Imported indicator
            if (note.importedFromCallHistory)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phone,
                        size: 10,
                        color: Colors.white,
                      ),
                      SizedBox(width: 2),
                      Text(
                        'インポート',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  /// Format date based on locale
  String _formatDate(LocalizationService localService) {
    final monthNames = {
      'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
      'ja': ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
      'ko': ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12月'],
      'zh': ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
      'es': ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'],
      'fr': ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'],
    };
    
    final lang = localService.currentLanguage;
    final months = monthNames[lang] ?? monthNames['en']!;
    
    if (lang == 'ja' || lang == 'ko' || lang == 'zh') {
      return '${widget.selectedDate.year}年${months[widget.selectedDate.month - 1]}${widget.selectedDate.day}日';
    } else {
      return '${months[widget.selectedDate.month - 1]} ${widget.selectedDate.day}, ${widget.selectedDate.year}';
    }
  }
}
