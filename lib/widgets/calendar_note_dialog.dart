import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/calendar_note.dart';
import '../services/localization_service.dart';
import '../services/calendar_note_service.dart';

/// Calendar Note Dialog Widget
/// 
/// Sticky note style dialog for creating/editing calendar notes
class CalendarNoteDialog extends StatefulWidget {
  final DateTime selectedDate;
  final CalendarNote? existingNote;

  const CalendarNoteDialog({
    super.key,
    required this.selectedDate,
    this.existingNote,
  });

  @override
  State<CalendarNoteDialog> createState() => _CalendarNoteDialogState();
}

class _CalendarNoteDialogState extends State<CalendarNoteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _participantsController;
  late final TextEditingController _keyPointsController;
  late final TextEditingController _resultsController;
  late DateTime _selectedDate;

  final CalendarNoteService _noteService = CalendarNoteService();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _participantsController = TextEditingController(
      text: widget.existingNote?.participants ?? '',
    );
    _keyPointsController = TextEditingController(
      text: widget.existingNote?.keyPoints ?? '',
    );
    _resultsController = TextEditingController(
      text: widget.existingNote?.results ?? '',
    );
  }

  @override
  void dispose() {
    _participantsController.dispose();
    _keyPointsController.dispose();
    _resultsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final localService = Provider.of<LocalizationService>(context, listen: false);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: localService.translate('select_date'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    final localService = Provider.of<LocalizationService>(context, listen: false);

    final note = CalendarNote(
      id: widget.existingNote?.id ?? '',
      userId: '', // Will be set by service
      date: _selectedDate,
      participants: _participantsController.text.trim(),
      keyPoints: _keyPointsController.text.trim(),
      results: _resultsController.text.trim(),
      createdAt: widget.existingNote?.createdAt ?? DateTime.now(),
      callRecordingId: widget.existingNote?.callRecordingId,
      importedFromCall: widget.existingNote?.importedFromCall ?? false,
    );

    bool success;
    if (widget.existingNote != null) {
      success = await _noteService.updateNote(note);
    } else {
      final noteId = await _noteService.createNote(note);
      success = noteId != null;
    }

    if (mounted) {
      if (success) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localService.translate('note_saved')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localService.translate('error_occurred')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);
    final isEditing = widget.existingNote != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9C4), // Sticky note yellow
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with sticky note effect
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFFEB3B),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sticky_note_2,
                    color: Colors.brown.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing
                          ? localService.translate('edit_calendar_note')
                          : localService.translate('add_calendar_note'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.brown.shade700),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Date Picker
                      InkWell(
                        onTap: () => _pickDate(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.brown.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.brown.shade700),
                              const SizedBox(width: 12),
                              Text(
                                '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown.shade800,
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.edit, size: 20, color: Colors.brown.shade600),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Participants Field
                      _buildStickyField(
                        label: localService.translate('today_participants'),
                        icon: Icons.people,
                        controller: _participantsController,
                        hint: '例: 田中さん、鈴木さん',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      // Key Points Field
                      _buildStickyField(
                        label: localService.translate('discussion_points'),
                        icon: Icons.lightbulb_outline,
                        controller: _keyPointsController,
                        hint: '例: プロジェクトの進捗確認、次回の予定調整',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),

                      // Results Field
                      _buildStickyField(
                        label: localService.translate('discussion_results'),
                        icon: Icons.check_circle_outline,
                        controller: _resultsController,
                        hint: '例: 次回ミーティングは来週月曜日',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saveNote,
                          icon: const Icon(Icons.save),
                          label: Text(localService.translate('save')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.brown.shade700),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.brown.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.brown.shade200),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(color: Colors.brown.shade900),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.brown.shade400),
              contentPadding: const EdgeInsets.all(12),
              border: InputBorder.none,
            ),
            validator: (value) {
              // At least one field must be filled
              if (value == null || value.trim().isEmpty) {
                if (controller == _participantsController &&
                    _keyPointsController.text.trim().isEmpty &&
                    _resultsController.text.trim().isEmpty) {
                  return '少なくとも1つのフィールドを入力してください';
                }
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}
