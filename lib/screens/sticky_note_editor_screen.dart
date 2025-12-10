import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/localization_service.dart';
import '../models/call_recording.dart';
import '../models/sticky_note.dart';
import 'sticky_notes_list_screen.dart';

class StickyNoteEditorScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String contactId;
  final String contactName;
  final String? contactPhotoUrl;
  final List<CallRecording> callRecordings;
  final StickyNote? existingNote;  // For editing existing note

  const StickyNoteEditorScreen({
    super.key,
    required this.selectedDate,
    required this.contactId,
    required this.contactName,
    this.contactPhotoUrl,
    required this.callRecordings,
    this.existingNote,
  });

  @override
  State<StickyNoteEditorScreen> createState() => _StickyNoteEditorScreenState();
}

class _StickyNoteEditorScreenState extends State<StickyNoteEditorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final TextEditingController _keyPointsController = TextEditingController();
  final TextEditingController _resultsController = TextEditingController();
  
  String _selectedColor = StickyNoteColors.colors[0]; // Default: Yellow
  bool _isImportedFromCallHistory = false;
  String? _callRecordingId;
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    
    // If editing existing note
    if (widget.existingNote != null) {
      _keyPointsController.text = widget.existingNote!.keyPoints;
      _resultsController.text = widget.existingNote!.results;
      _selectedColor = widget.existingNote!.colorHex;
      _isImportedFromCallHistory = widget.existingNote!.importedFromCallHistory;
      _callRecordingId = widget.existingNote!.callRecordingId;
    }
    // If creating from call history (auto-import)
    else if (widget.callRecordings.isNotEmpty) {
      _autoImportFromCallHistory();
    }
  }
  
  @override
  void dispose() {
    _keyPointsController.dispose();
    _resultsController.dispose();
    super.dispose();
  }
  
  /// Auto-import key points from call history
  void _autoImportFromCallHistory() {
    // Find first recording with transcription
    for (var recording in widget.callRecordings) {
      if (recording.transcription != null && recording.transcription!.isNotEmpty) {
        setState(() {
          _keyPointsController.text = recording.transcription!;
          _isImportedFromCallHistory = true;
          _callRecordingId = recording.id;
        });
        
        if (kDebugMode) {
          debugPrint('📋 [StickyNoteEditor] Auto-imported from call recording: ${recording.id}');
        }
        break;
      }
    }
  }
  
  /// Save sticky note to Firestore
  Future<void> _saveStickyNote() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    // Validate input
    final localService = Provider.of<LocalizationService>(context, listen: false);
    
    if (_keyPointsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localService.translate('please_enter_key_points')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (_resultsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localService.translate('please_enter_results')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      if (widget.existingNote != null) {
        // Update existing note
        await _firestore
            .collection('sticky_notes')
            .doc(widget.existingNote!.id)
            .update({
          'keyPoints': _keyPointsController.text.trim(),
          'results': _resultsController.text.trim(),
          'colorHex': _selectedColor,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        if (kDebugMode) {
          debugPrint('✅ [StickyNoteEditor] Updated note: ${widget.existingNote!.id}');
        }
      } else {
        // Get next position for this date
        final position = await _getNextPosition(user.uid, widget.selectedDate);
        
        // Create new note
        final note = StickyNote(
          id: '',  // Will be set by Firestore
          userId: user.uid,
          date: widget.selectedDate,
          contactId: widget.contactId,
          contactName: widget.contactName,
          contactPhotoUrl: widget.contactPhotoUrl,
          keyPoints: _keyPointsController.text.trim(),
          results: _resultsController.text.trim(),
          colorHex: _selectedColor,
          position: position,
          createdAt: DateTime.now(),
          importedFromCallHistory: _isImportedFromCallHistory,
          callRecordingId: _callRecordingId,
        );
        
        await _firestore.collection('sticky_notes').add(note.toFirestore());
        
        if (kDebugMode) {
          debugPrint('✅ [StickyNoteEditor] Created new note at position $position');
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localService.translate('memo_saved')),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to sticky notes list screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StickyNotesListScreen(selectedDate: widget.selectedDate),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StickyNoteEditor] Error saving note: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localService.translate('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  
  /// Get next position for sticky notes on this date
  Future<int> _getNextPosition(String userId, DateTime date) async {
    try {
      // Get all notes for this date
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      final querySnapshot = await _firestore
          .collection('sticky_notes')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      
      // Find max position
      int maxPosition = -1;
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final position = data['position'] as int? ?? 0;
        if (position > maxPosition) {
          maxPosition = position;
        }
      }
      
      return maxPosition + 1;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [StickyNoteEditor] Error getting next position: $e');
      }
      return 0;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingNote != null 
          ? localService.translate('edit_memo') 
          : localService.translate('create_new_memo')),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveStickyNote,
              tooltip: localService.translate('save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact info header
            _buildContactHeader(),
            
            const SizedBox(height: 24),
            
            // Import from call history button
            if (widget.callRecordings.isNotEmpty && !_isImportedFromCallHistory)
              _buildImportButton(),
            
            // Key points field
            _buildTextField(
              controller: _keyPointsController,
              label: localService.translate('key_points'),
              hint: localService.translate('key_points_hint'),
              maxLines: 5,
              icon: Icons.notes,
            ),
            
            const SizedBox(height: 16),
            
            // Results field
            _buildTextField(
              controller: _resultsController,
              label: localService.translate('discussion_results'),
              hint: localService.translate('results_hint'),
              maxLines: 5,
              icon: Icons.assignment_turned_in,
            ),
            
            const SizedBox(height: 24),
            
            // Color picker
            _buildColorPicker(localService),
            
            const SizedBox(height: 32),
            
            // Save button (large)
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }
  
  /// Build contact info header
  Widget _buildContactHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue.shade100,
            backgroundImage: widget.contactPhotoUrl != null
                ? NetworkImage(widget.contactPhotoUrl!)
                : null,
            child: widget.contactPhotoUrl == null
                ? Text(
                    widget.contactName[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Provider.of<LocalizationService>(context, listen: false).translate('todays_contact'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.contactName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build import from call history button
  Widget _buildImportButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton.icon(
        onPressed: () {
          _autoImportFromCallHistory();
          final localService = Provider.of<LocalizationService>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localService.translate('imported_from_call')),
              backgroundColor: Colors.blue,
            ),
          );
        },
        icon: const Icon(Icons.download),
        label: Text(Provider.of<LocalizationService>(context, listen: false).translate('import_from_call_history')),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }
  
  /// Build text field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int maxLines,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
      ],
    );
  }
  
  /// Build color picker
  Widget _buildColorPicker(LocalizationService localService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.palette, size: 20, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            Text(
              localService.translate('note_color'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: StickyNoteColors.colors.map((color) {
            final isSelected = color == _selectedColor;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColor = color;
                });
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Color(int.parse(color.substring(1), radix: 16) + 0xFF000000),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300,
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  /// Build save button
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveStickyNote,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving 
          ? Provider.of<LocalizationService>(context, listen: false).translate('saving')
          : Provider.of<LocalizationService>(context, listen: false).translate('save_memo')),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
