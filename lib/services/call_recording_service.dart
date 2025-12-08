import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../models/call_recording.dart';

/// Call Recording Service - Handles recording of voice/video calls
/// 
/// Features:
/// - Records audio during voice/video calls
/// - Uploads recordings to Firebase Storage
/// - Saves recording metadata to Firestore
/// - Notifies remote user about recording
/// - Supports both Web and Android platforms
class CallRecordingService {
  // Singleton pattern
  static final CallRecordingService _instance = CallRecordingService._internal();
  factory CallRecordingService() => _instance;
  CallRecordingService._internal();

  // Audio recorder instance
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  // Recording state
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordingStartTime;
  String? _currentCallId;
  String? _remoteUserId;
  
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Getters
  bool get isRecording => _isRecording;
  String? get recordingPath => _recordingPath;
  
  /// Start recording the call
  /// 
  /// [callId] - The unique ID of the call
  /// [remoteUserId] - The ID of the remote user (to notify them)
  Future<bool> startRecording(String callId, String remoteUserId) async {
    if (_isRecording) {
      debugPrint('[CallRecording] ⚠️ Already recording');
      return false;
    }
    
    try {
      // Check microphone permission
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        debugPrint('[CallRecording] ❌ Microphone permission denied');
        return false;
      }
      
      // Get temporary directory for recording
      final String recordingDirectory = await _getRecordingDirectory();
      final String fileName = 'call_${callId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = '$recordingDirectory/$fileName';
      
      debugPrint('[CallRecording] 🎙️ Starting recording...');
      debugPrint('[CallRecording] Path: $_recordingPath');
      
      // Configure audio recording settings
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc, // AAC-LC for good quality and compression
        bitRate: 128000, // 128 kbps
        sampleRate: 44100, // 44.1 kHz
        numChannels: 1, // Mono for voice calls
      );
      
      // Start recording
      await _audioRecorder.start(config, path: _recordingPath!);
      
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _currentCallId = callId;
      _remoteUserId = remoteUserId;
      
      // Notify remote user about recording
      await _notifyRemoteUserRecording(callId, remoteUserId, isRecording: true);
      
      debugPrint('[CallRecording] ✅ Recording started successfully');
      return true;
    } catch (e) {
      debugPrint('[CallRecording] ❌ Failed to start recording: $e');
      return false;
    }
  }
  
  /// Stop recording and upload to Firebase Storage
  Future<CallRecording?> stopRecording() async {
    if (!_isRecording) {
      debugPrint('[CallRecording] ⚠️ Not currently recording');
      return null;
    }
    
    try {
      debugPrint('[CallRecording] 🛑 Stopping recording...');
      
      // Stop recording
      final path = await _audioRecorder.stop();
      _isRecording = false;
      
      if (path == null || _recordingPath == null) {
        debugPrint('[CallRecording] ❌ Recording path is null');
        return null;
      }
      
      // Calculate recording duration
      final duration = DateTime.now().difference(_recordingStartTime!).inSeconds;
      
      debugPrint('[CallRecording] 📊 Recording stopped');
      debugPrint('[CallRecording]    Duration: ${duration}s');
      debugPrint('[CallRecording]    Path: $path');
      
      // Notify remote user that recording stopped
      if (_currentCallId != null && _remoteUserId != null) {
        await _notifyRemoteUserRecording(_currentCallId!, _remoteUserId!, isRecording: false);
      }
      
      // Upload to Firebase Storage
      final recordingUrl = await _uploadRecording(path);
      
      if (recordingUrl == null) {
        debugPrint('[CallRecording] ❌ Failed to upload recording');
        return null;
      }
      
      // Save metadata to Firestore
      final recording = await _saveRecordingMetadata(
        callId: _currentCallId!,
        recordingUrl: recordingUrl,
        duration: duration,
      );
      
      // Clean up local file
      await _deleteLocalFile(path);
      
      // Reset state
      _recordingPath = null;
      _recordingStartTime = null;
      _currentCallId = null;
      _remoteUserId = null;
      
      debugPrint('[CallRecording] ✅ Recording saved successfully');
      return recording;
    } catch (e) {
      debugPrint('[CallRecording] ❌ Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }
  
  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    if (!_isRecording) {
      return;
    }
    
    try {
      debugPrint('[CallRecording] 🗑️ Canceling recording...');
      
      final path = await _audioRecorder.stop();
      _isRecording = false;
      
      // Notify remote user that recording stopped
      if (_currentCallId != null && _remoteUserId != null) {
        await _notifyRemoteUserRecording(_currentCallId!, _remoteUserId!, isRecording: false);
      }
      
      // Delete local file
      if (path != null) {
        await _deleteLocalFile(path);
      }
      
      // Reset state
      _recordingPath = null;
      _recordingStartTime = null;
      _currentCallId = null;
      _remoteUserId = null;
      
      debugPrint('[CallRecording] ✅ Recording canceled');
    } catch (e) {
      debugPrint('[CallRecording] ❌ Failed to cancel recording: $e');
    }
  }
  
  /// Get recording directory based on platform
  Future<String> _getRecordingDirectory() async {
    if (kIsWeb) {
      // Web platform - use temporary directory simulation
      return '/tmp/call_recordings';
    } else {
      // Mobile platform - use temporary directory
      final directory = await getTemporaryDirectory();
      final recordingDir = Directory('${directory.path}/call_recordings');
      
      // Create directory if it doesn't exist
      if (!await recordingDir.exists()) {
        await recordingDir.create(recursive: true);
      }
      
      return recordingDir.path;
    }
  }
  
  /// Upload recording to Firebase Storage
  Future<String?> _uploadRecording(String localPath) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('[CallRecording] ❌ No authenticated user');
        return null;
      }
      
      final userId = currentUser.uid;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final storageRef = _storage.ref().child('call_recordings/$userId/$fileName');
      
      debugPrint('[CallRecording] ☁️ Uploading to Firebase Storage...');
      debugPrint('[CallRecording]    Path: call_recordings/$userId/$fileName');
      
      // Upload file
      final file = File(localPath);
      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: 'audio/m4a',
          customMetadata: {
            'callId': _currentCallId ?? 'unknown',
            'recordedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('[CallRecording] ✅ Upload completed');
      debugPrint('[CallRecording]    URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      debugPrint('[CallRecording] ❌ Upload failed: $e');
      return null;
    }
  }
  
  /// Save recording metadata to Firestore
  Future<CallRecording?> _saveRecordingMetadata({
    required String callId,
    required String recordingUrl,
    required int duration,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('[CallRecording] ❌ No authenticated user');
        return null;
      }
      
      final userId = currentUser.uid;
      
      // Create recording document
      final docRef = _firestore.collection('call_recordings').doc();
      
      final recording = CallRecording(
        id: docRef.id,
        userId: userId,
        callId: callId,
        recordingUrl: recordingUrl,
        duration: duration,
        timestamp: DateTime.now(),
        callPartner: _remoteUserId,
        callType: 'audio',
      );
      
      await docRef.set(recording.toMap());
      
      debugPrint('[CallRecording] ✅ Metadata saved to Firestore');
      debugPrint('[CallRecording]    Document ID: ${docRef.id}');
      
      return recording;
    } catch (e) {
      debugPrint('[CallRecording] ❌ Failed to save metadata: $e');
      return null;
    }
  }
  
  /// Notify remote user about recording status
  Future<void> _notifyRemoteUserRecording(
    String callId,
    String remoteUserId,
    {required bool isRecording}
  ) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return;
      }
      
      debugPrint('[CallRecording] 📢 Notifying remote user: $remoteUserId');
      debugPrint('[CallRecording]    Recording: $isRecording');
      
      // Create notification in Firestore
      await _firestore.collection('call_recording_notifications').add({
        'callId': callId,
        'recordingUserId': currentUser.uid,
        'notifiedUserId': remoteUserId,
        'isRecording': isRecording,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      debugPrint('[CallRecording] ✅ Notification sent');
    } catch (e) {
      debugPrint('[CallRecording] ⚠️ Failed to notify remote user: $e');
      // Don't throw - notification failure shouldn't stop recording
    }
  }
  
  /// Delete local recording file
  Future<void> _deleteLocalFile(String path) async {
    try {
      if (!kIsWeb) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugPrint('[CallRecording] 🗑️ Local file deleted: $path');
        }
      }
    } catch (e) {
      debugPrint('[CallRecording] ⚠️ Failed to delete local file: $e');
    }
  }
  
  /// Listen for recording notifications from remote user
  Stream<Map<String, dynamic>> listenForRecordingNotifications(String callId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }
    
    return _firestore
        .collection('call_recording_notifications')
        .where('callId', isEqualTo: callId)
        .where('notifiedUserId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return {};
      }
      
      final doc = snapshot.docs.first;
      final data = doc.data();
      
      debugPrint('[CallRecording] 📩 Recording notification received');
      debugPrint('[CallRecording]    Recording: ${data['isRecording']}');
      
      return {
        'isRecording': data['isRecording'] ?? false,
        'recordingUserId': data['recordingUserId'] ?? '',
        'timestamp': data['timestamp'],
      };
    });
  }
  
  /// Get user's call recordings
  Future<List<CallRecording>> getUserRecordings() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return [];
      }
      
      final querySnapshot = await _firestore
          .collection('call_recordings')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => CallRecording.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('[CallRecording] ❌ Failed to get recordings: $e');
      return [];
    }
  }
  
  /// Delete a recording
  Future<bool> deleteRecording(CallRecording recording) async {
    try {
      // Delete from Firestore
      await _firestore.collection('call_recordings').doc(recording.id).delete();
      
      // Delete from Storage
      final storageRef = _storage.refFromURL(recording.recordingUrl);
      await storageRef.delete();
      
      debugPrint('[CallRecording] ✅ Recording deleted: ${recording.id}');
      return true;
    } catch (e) {
      debugPrint('[CallRecording] ❌ Failed to delete recording: $e');
      return false;
    }
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    if (_isRecording) {
      await cancelRecording();
    }
    await _audioRecorder.dispose();
  }
}
