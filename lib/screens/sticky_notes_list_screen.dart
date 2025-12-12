import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';
import '../models/sticky_note.dart';
import '../theme/modern_ui_theme.dart';
import 'sticky_note_editor_screen.dart';
import 'daily_contacts_screen.dart';

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
        for (final note in notes) {
          debugPrint('  - Note: ${note.contactName}, photoUrl: ${note.contactPhotoUrl}');
        }
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
    final localService = Provider.of<LocalizationService>(context, listen: false);
    try {
      await _firestore.collection('sticky_notes').doc(note.id).delete();
      
      setState(() {
        _notes.remove(note);
      });
      
      if (kDebugMode) {
        debugPrint('✅ [StickyNotesList] Deleted note: ${note.id}');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localService.translate('memo_deleted')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StickyNotesList] Error deleting note: $e');
      }
      
      final localService = Provider.of<LocalizationService>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${localService.translate('error')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(StickyNote note) async {
    final localService = Provider.of<LocalizationService>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localService.translate('delete_memo')),
        content: Text(localService.translate('delete_memo_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localService.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(localService.translate('delete')),
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
        title: Text(
          _formatDate(localService),
          style: ModernUITheme.headingMedium.copyWith(color: ModernUITheme.textWhite),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(decoration: BoxDecoration(gradient: ModernUITheme.primaryGradient)),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: ModernUITheme.backgroundGradient),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notes.isEmpty
                ? _buildEmptyState()
                : _buildStickyNotesGrid(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showContactSelectionDialog,
        backgroundColor: Colors.blue.shade600,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: localService.translate('create_new_memo'),
      ),
    );
  }
  
  /// Show dialog to select contact for new memo
  Future<void> _showContactSelectionDialog() async {
    // Navigate to daily contacts screen to select a contact
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyContactsScreen(selectedDate: widget.selectedDate),
      ),
    );
    
    // Reload notes after returning (in case a new note was created)
    if (result == true || mounted) {
      _loadStickyNotes();
    }
  }
  
  /// Build empty state
  Widget _buildEmptyState() {
    final localService = Provider.of<LocalizationService>(context, listen: false);
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
            localService.translate('no_memos_yet'),
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localService.translate('tap_plus_to_create'),
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
    final localService = Provider.of<LocalizationService>(context, listen: false);
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
                        backgroundImage: note.contactPhotoUrl != null && note.contactPhotoUrl!.isNotEmpty
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
                  Text(
                    localService.translate('key_points_short'),
                    style: const TextStyle(
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
                  Text(
                    localService.translate('results_short'),
                    style: const TextStyle(
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.phone,
                        size: 10,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        localService.translate('imported'),
                        style: const TextStyle(
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
    final year = widget.selectedDate.year;
    final month = widget.selectedDate.month;
    final day = widget.selectedDate.day;
    
    // Language-specific date formatting
    switch (lang) {
      case 'ja':
        // Japanese: 2025年12月10日
        return '${year}年${month}月${day}日';
        
      case 'ko':
        // Korean: 2025년 12월 10일
        return '${year}년 ${month}월 ${day}일';
        
      case 'zh':
        // Chinese: 2025年12月10日
        return '${year}年${month}月${day}日';
        
      case 'es':
        // Spanish: 10 de diciembre de 2025
        final monthNames = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 
                           'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
        return '$day de ${monthNames[month - 1]} de $year';
        
      case 'fr':
        // French: 10 décembre 2025
        final monthNames = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin',
                           'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
        return '$day ${monthNames[month - 1]} $year';
        
      default:
        // English: December 10, 2025
        final monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                           'July', 'August', 'September', 'October', 'November', 'December'];
        return '${monthNames[month - 1]} $day, $year';
    }
  }
}
