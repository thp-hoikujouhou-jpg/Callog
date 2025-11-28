import 'package:cloud_firestore/cloud_firestore.dart';

class CallRecording {
  final String id;
  final String userId;
  final String callId;
  final String recordingUrl;
  final int duration; // in seconds
  final DateTime timestamp;
  final String? callPartner;
  final String callType; // 'audio' or 'video'

  CallRecording({
    required this.id,
    required this.userId,
    required this.callId,
    required this.recordingUrl,
    required this.duration,
    required this.timestamp,
    this.callPartner,
    this.callType = 'audio',
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'callId': callId,
      'recordingUrl': recordingUrl,
      'duration': duration,
      'timestamp': Timestamp.fromDate(timestamp),
      'callPartner': callPartner,
      'callType': callType,
    };
  }

  // Create from Firestore document
  factory CallRecording.fromMap(Map<String, dynamic> map, String documentId) {
    return CallRecording(
      id: documentId,
      userId: map['userId'] ?? '',
      callId: map['callId'] ?? '',
      recordingUrl: map['recordingUrl'] ?? '',
      duration: map['duration'] ?? 0,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      callPartner: map['callPartner'],
      callType: map['callType'] ?? 'audio',
    );
  }

  // Create a copy with updated fields
  CallRecording copyWith({
    String? id,
    String? userId,
    String? callId,
    String? recordingUrl,
    int? duration,
    DateTime? timestamp,
    String? callPartner,
    String? callType,
  }) {
    return CallRecording(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      callId: callId ?? this.callId,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      callPartner: callPartner ?? this.callPartner,
      callType: callType ?? this.callType,
    );
  }

  // Format duration as MM:SS
  String get formattedDuration {
    int minutes = duration ~/ 60;
    int seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
