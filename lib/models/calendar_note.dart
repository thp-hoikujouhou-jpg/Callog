import 'package:cloud_firestore/cloud_firestore.dart';

/// Calendar Note Model
/// 
/// Represents a note/memo attached to a specific date in the calendar
/// Can be created manually or imported from call recordings
class CalendarNote {
  final String id;
  final String userId;
  final DateTime date;
  final String participants; // 今日の話し相手
  final String keyPoints; // 話し合いの要点
  final String results; // 話し合いの結果
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? callRecordingId; // Optional: linked call recording
  final bool importedFromCall; // True if imported from call history

  CalendarNote({
    required this.id,
    required this.userId,
    required this.date,
    required this.participants,
    required this.keyPoints,
    required this.results,
    required this.createdAt,
    this.updatedAt,
    this.callRecordingId,
    this.importedFromCall = false,
  });

  /// Create CalendarNote from Firestore document
  factory CalendarNote.fromFirestore(Map<String, dynamic> data, String id) {
    return CalendarNote(
      id: id,
      userId: data['userId'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participants: data['participants'] as String? ?? '',
      keyPoints: data['keyPoints'] as String? ?? '',
      results: data['results'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      callRecordingId: data['callRecordingId'] as String?,
      importedFromCall: data['importedFromCall'] as bool? ?? false,
    );
  }

  /// Convert CalendarNote to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'participants': participants,
      'keyPoints': keyPoints,
      'results': results,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'callRecordingId': callRecordingId,
      'importedFromCall': importedFromCall,
    };
  }

  /// Create a copy with modified fields
  CalendarNote copyWith({
    String? id,
    String? userId,
    DateTime? date,
    String? participants,
    String? keyPoints,
    String? results,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? callRecordingId,
    bool? importedFromCall,
  }) {
    return CalendarNote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      participants: participants ?? this.participants,
      keyPoints: keyPoints ?? this.keyPoints,
      results: results ?? this.results,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      callRecordingId: callRecordingId ?? this.callRecordingId,
      importedFromCall: importedFromCall ?? this.importedFromCall,
    );
  }

  /// Check if note is empty
  bool get isEmpty {
    return participants.trim().isEmpty &&
        keyPoints.trim().isEmpty &&
        results.trim().isEmpty;
  }

  /// Get formatted date string
  String getFormattedDate(String format) {
    // Simple formatting for display
    switch (format) {
      case 'short':
        return '${date.year}/${date.month}/${date.day}';
      case 'long':
        return '${date.year}年${date.month}月${date.day}日';
      default:
        return date.toString();
    }
  }
}
