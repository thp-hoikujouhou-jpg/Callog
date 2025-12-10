import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/calendar_note.dart';

/// Calendar Note Service
/// 
/// Manages CRUD operations for calendar notes in Firestore
class CalendarNoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get notes for a specific date
  Future<List<CalendarNote>> getNotesForDate(DateTime date) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Normalize date to start of day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection('calendar_notes')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      return querySnapshot.docs
          .map((doc) => CalendarNote.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CalendarNoteService] Error getting notes for date: $e');
      }
      return [];
    }
  }

  /// Get notes for a specific month
  Future<List<CalendarNote>> getNotesForMonth(int year, int month) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection('calendar_notes')
          .where('userId', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      return querySnapshot.docs
          .map((doc) => CalendarNote.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CalendarNoteService] Error getting notes for month: $e');
      }
      return [];
    }
  }

  /// Create a new note
  Future<String?> createNote(CalendarNote note) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final docRef = await _firestore.collection('calendar_notes').add(
        note.copyWith(userId: user.uid, createdAt: DateTime.now()).toFirestore(),
      );

      if (kDebugMode) {
        debugPrint('✅ [CalendarNoteService] Note created: ${docRef.id}');
      }

      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CalendarNoteService] Error creating note: $e');
      }
      return null;
    }
  }

  /// Update an existing note
  Future<bool> updateNote(CalendarNote note) async {
    try {
      await _firestore.collection('calendar_notes').doc(note.id).update(
        note.copyWith(updatedAt: DateTime.now()).toFirestore(),
      );

      if (kDebugMode) {
        debugPrint('✅ [CalendarNoteService] Note updated: ${note.id}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CalendarNoteService] Error updating note: $e');
      }
      return false;
    }
  }

  /// Delete a note
  Future<bool> deleteNote(String noteId) async {
    try {
      await _firestore.collection('calendar_notes').doc(noteId).delete();

      if (kDebugMode) {
        debugPrint('✅ [CalendarNoteService] Note deleted: $noteId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CalendarNoteService] Error deleting note: $e');
      }
      return false;
    }
  }

  /// Import note from call recording
  Future<String?> importFromCallRecording({
    required String callRecordingId,
    required DateTime date,
    required String participant,
    required String transcription,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Create note from call recording data
      final note = CalendarNote(
        id: '',
        userId: user.uid,
        date: date,
        participants: participant,
        keyPoints: transcription.length > 500 
          ? '${transcription.substring(0, 500)}...' 
          : transcription,
        results: '通話履歴からインポート',
        createdAt: DateTime.now(),
        callRecordingId: callRecordingId,
        importedFromCall: true,
      );

      return await createNote(note);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CalendarNoteService] Error importing from call: $e');
      }
      return null;
    }
  }

  /// Check if date has notes
  Future<bool> hasNotesForDate(DateTime date) async {
    final notes = await getNotesForDate(date);
    return notes.isNotEmpty;
  }

  /// Get dates with notes for a month (for calendar UI markers)
  Future<Set<DateTime>> getDatesWithNotes(int year, int month) async {
    final notes = await getNotesForMonth(year, month);
    return notes.map((note) {
      return DateTime(note.date.year, note.date.month, note.date.day);
    }).toSet();
  }
}
