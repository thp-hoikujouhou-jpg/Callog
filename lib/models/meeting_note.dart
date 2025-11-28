import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingNote {
  final String id;
  final String userId;
  final String date; // Format: YYYY-MM-DD
  final String callPartner;
  final String userNotes;
  final String? aiSummary;
  final DateTime timestamp;
  final String? callId;
  final String? recordingUrl;

  MeetingNote({
    required this.id,
    required this.userId,
    required this.date,
    required this.callPartner,
    required this.userNotes,
    this.aiSummary,
    required this.timestamp,
    this.callId,
    this.recordingUrl,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date,
      'callPartner': callPartner,
      'userNotes': userNotes,
      'aiSummary': aiSummary,
      'timestamp': Timestamp.fromDate(timestamp),
      'callId': callId,
      'recordingUrl': recordingUrl,
    };
  }

  // Create from Firestore document
  factory MeetingNote.fromMap(Map<String, dynamic> map, String documentId) {
    return MeetingNote(
      id: documentId,
      userId: map['userId'] ?? '',
      date: map['date'] ?? '',
      callPartner: map['callPartner'] ?? 'Unknown',
      userNotes: map['userNotes'] ?? '',
      aiSummary: map['aiSummary'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      callId: map['callId'],
      recordingUrl: map['recordingUrl'],
    );
  }

  // Create a copy with updated fields
  MeetingNote copyWith({
    String? id,
    String? userId,
    String? date,
    String? callPartner,
    String? userNotes,
    String? aiSummary,
    DateTime? timestamp,
    String? callId,
    String? recordingUrl,
  }) {
    return MeetingNote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      callPartner: callPartner ?? this.callPartner,
      userNotes: userNotes ?? this.userNotes,
      aiSummary: aiSummary ?? this.aiSummary,
      timestamp: timestamp ?? this.timestamp,
      callId: callId ?? this.callId,
      recordingUrl: recordingUrl ?? this.recordingUrl,
    );
  }

  // Check if AI summary is available
  bool get hasAiSummary {
    return aiSummary != null && aiSummary!.isNotEmpty;
  }

  // Check if recording is available
  bool get hasRecording {
    return recordingUrl != null && recordingUrl!.isNotEmpty;
  }

  // Parse date string to DateTime
  DateTime get dateTime {
    try {
      return DateTime.parse(date);
    } catch (e) {
      return DateTime.now();
    }
  }

  // Format date for display (e.g., "Nov 28, 2025")
  String get formattedDate {
    final dt = dateTime;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
