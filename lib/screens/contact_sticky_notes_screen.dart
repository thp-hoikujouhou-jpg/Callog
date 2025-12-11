import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';
import '../models/sticky_note.dart';
import '../models/call_recording.dart';
import 'sticky_note_editor_screen.dart';

/// Screen to display all sticky notes for a specific contact on a specific date
class ContactStickyNotesScreen extends StatefulWidget {
  final String contactId;
  final String contactName;
  final String? contactPhotoUrl;
  final DateTime selectedDate;  // CRITICAL FIX: Add date filter
  
  const ContactStickyNotesScreen({
    super.key,
    required this.contactId,
    required this.contactName,
    this.contactPhotoUrl,
    required this.selectedDate,  // Required parameter
  });

  @override
  State<ContactStickyNotesScreen> createState() => _ContactStickyNotesScreenState();
}

class _ContactStickyNotesScreenState extends State<ContactStickyNotesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<StickyNote> _notes = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadStickyNotes();
  }
  
  /// Load sticky notes for this contact on the selected date only
  Future<void> _loadStickyNotes() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      // CRITICAL FIX: Add date filtering to show only notes for the selected date
      final startOfDay = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day);
      final endOfDay = DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, 23, 59, 59);
      
      print('📋 [ContactStickyNotes] Loading notes for ${widget.contactName} on ${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}');
      print('   Date range: $startOfDay to $endOfDay');
      
      final querySnapshot = await _firestore
          .collection('sticky_notes')
          .where('userId', isEqualTo: user.uid)
          .where('contactId', isEqualTo: widget.contactId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('date', descending: true)  // Newest first within the day
          .get();
      
      // CRITICAL DEBUG: Add detailed logging for sticky notes loading
      print('📋 [ContactStickyNotes] Query returned ${querySnapshot.docs.length} notes for ${widget.contactName} on selected date');
      
      final notes = querySnapshot.docs.map((doc) {
        print('  📄 [ContactStickyNotes] Processing note: ${doc.id}');
        print('    - contactId: ${doc.data()['contactId']}');
        print('    - date: ${doc.data()['date']}');
        print('    - keyPoints length: ${(doc.data()['keyPoints'] as String?)?.length ?? 0}');
        return StickyNote.fromFirestore(doc.data(), doc.id);
      }).toList();
      
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
      
      print('✅ [ContactStickyNotes] Successfully loaded ${notes.length} notes for ${widget.contactName}');
    } catch (e, stackTrace) {
      print('❌ [ContactStickyNotes] Error loading notes: $e');
      print('   Stack trace: $stackTrace');
      
      // Check for common Firestore issues
      if (e.toString().contains('requires an index')) {
        print('💡 [ContactStickyNotes] SOLUTION: Create composite index for sticky_notes collection:');
        print('   Fields: userId (Ascending), contactId (Ascending), date (Ascending), date (Descending)');
        print('   Firebase Console will provide the exact index creation link in the error message.');
      } else if (e.toString().contains('Missing or insufficient permissions')) {
        print('💡 [ContactStickyNotes] SOLUTION: Update Firestore Security Rules:');
        print('   allow read: if request.auth != null;');
      }
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Delete a sticky note
  Future<void> _deleteNote(StickyNote note) async {
    final localService = Provider.of<LocalizationService>(context, listen: false);
    try {
      await _firestore.collection('sticky_notes').doc(note.id).delete();
      
      setState(() {
        _notes.remove(note);
      });
      
      if (kDebugMode) {
        debugPrint('✅ [ContactStickyNotes] Deleted note: ${note.id}');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localService.translate('memo_deleted')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [ContactStickyNotes] Error deleting note: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(StickyNote note) async {
    final localService = Provider.of<LocalizationService>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localService.translate('delete_memo')),
        content: Text(localService.translate('delete_memo_confirmation')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localService.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(localService.translate('delete')),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _deleteNote(note);
    }
  }
  
  /// Navigate to create new sticky note
  Future<void> _createNewNote() async {
    // Get call recordings for this contact (for import functionality)
    List<CallRecording> recordings = [];
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final recordingsSnapshot = await _firestore
            .collection('call_recordings')
            .where('userId', isEqualTo: user.uid)
            .where('callPartner', isEqualTo: widget.contactId)
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get();
        
        recordings = recordingsSnapshot.docs
            .map((doc) => CallRecording.fromMap(doc.data(), doc.id))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ContactStickyNotes] Could not load recordings: $e');
      }
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StickyNoteEditorScreen(
          selectedDate: widget.selectedDate,  // Use the selected date from calendar
          contactId: widget.contactId,
          contactName: widget.contactName,
          contactPhotoUrl: widget.contactPhotoUrl,
          callRecordings: recordings,
        ),
      ),
    );
    
    // Reload notes after creating
    if (result == true && mounted) {
      _loadStickyNotes();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              backgroundImage: widget.contactPhotoUrl != null && widget.contactPhotoUrl!.isNotEmpty
                  ? NetworkImage(widget.contactPhotoUrl!)
                  : null,
              child: widget.contactPhotoUrl == null
                  ? Text(
                      widget.contactName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.contactName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? _buildEmptyState(localService)
              : _buildNotesList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewNote,
        backgroundColor: Colors.blue.shade600,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: localService.translate('create_new_memo'),
      ),
    );
  }
  
  /// Build empty state
  Widget _buildEmptyState(LocalizationService localService) {
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
  
  /// Build notes list
  Widget _buildNotesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return _buildNoteCard(note);
      },
    );
  }
  
  /// Build note card
  Widget _buildNoteCard(StickyNote note) {
    final localService = Provider.of<LocalizationService>(context, listen: false);
    final color = _parseColor(note.colorHex);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          // Navigate to edit
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StickyNoteEditorScreen(
                selectedDate: note.date,
                contactId: note.contactId,
                contactName: note.contactName,
                contactPhotoUrl: note.contactPhotoUrl,
                callRecordings: const [],
                existingNote: note,
              ),
            ),
          );
          
          // Reload after editing
          if (result == true && mounted) {
            _loadStickyNotes();
          }
        },
        onLongPress: () => _showDeleteConfirmation(note),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and imported badge
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(note.date, localService),
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (note.importedFromCallHistory) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone, size: 10, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            localService.translate('imported'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Key points
              Text(
                localService.translate('key_points_short'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                note.keyPoints,
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              // Results
              Text(
                localService.translate('results_short'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                note.results,
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Parse color from hex string
  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.substring(1, 7), radix: 16) + 0xFF000000);
    } catch (e) {
      return Colors.yellow;
    }
  }
  
  /// Format date
  String _formatDate(DateTime date, LocalizationService localService) {
    final languageCode = localService.currentLanguage;
    
    final monthNames = {
      'en': ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
      'ja': ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
      'ko': ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'],
      'zh': ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
      'es': ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'],
      'fr': ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'],
    };
    
    final months = monthNames[languageCode] ?? monthNames['en']!;
    final monthName = months[date.month - 1];
    
    if (languageCode == 'ja') {
      return '${date.year}年${date.month}月${date.day}日';
    } else if (languageCode == 'ko') {
      return '${date.year}년 ${date.month}월 ${date.day}일';
    } else if (languageCode == 'zh') {
      return '${date.year}年${date.month}月${date.day}日';
    } else {
      return '$monthName ${date.day}, ${date.year}';
    }
  }
}
