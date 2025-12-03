import 'package:cloud_firestore/cloud_firestore.dart';

class IncomingCall {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerPhotoUrl;
  final String calleeId;
  final String callType; // 'audio' or 'video'
  final String status; // 'pending', 'accepted', 'rejected', 'missed', 'ended'
  final DateTime startTime;
  final DateTime? endTime;

  IncomingCall({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerPhotoUrl,
    required this.calleeId,
    required this.callType,
    required this.status,
    required this.startTime,
    this.endTime,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'callerId': callerId,
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
      'calleeId': calleeId,
      'callType': callType,
      'status': status,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
    };
  }

  // Create from Firestore document
  factory IncomingCall.fromMap(Map<String, dynamic> map) {
    return IncomingCall(
      callId: map['callId'] ?? '',
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? 'Unknown',
      callerPhotoUrl: map['callerPhotoUrl'],
      calleeId: map['calleeId'] ?? '',
      callType: map['callType'] ?? 'audio',
      status: map['status'] ?? 'pending',
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: map['endTime'] != null 
          ? (map['endTime'] as Timestamp).toDate() 
          : null,
    );
  }

  // Create a copy with updated fields
  IncomingCall copyWith({
    String? callId,
    String? callerId,
    String? callerName,
    String? callerPhotoUrl,
    String? calleeId,
    String? callType,
    String? status,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return IncomingCall(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerPhotoUrl: callerPhotoUrl ?? this.callerPhotoUrl,
      calleeId: calleeId ?? this.calleeId,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  // Calculate call duration if ended
  Duration? get callDuration {
    final end = endTime;
    if (end != null) {
      return end.difference(startTime);
    }
    return null;
  }

  // Format call duration as MM:SS
  String get formattedDuration {
    final duration = callDuration;
    if (duration == null) return '00:00';
    
    int minutes = duration.inMinutes;
    int seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Check if call is active
  bool get isActive {
    return status == 'pending' || status == 'accepted';
  }
}
