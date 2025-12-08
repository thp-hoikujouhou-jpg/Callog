import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/call_recording.dart';

// Conditional imports for platform-specific recording
import 'web_audio_recorder.dart' if (dart.library.io) 'web_audio_recorder_stub.dart';
import 'package:record/record.dart' if (dart.library.html) 'record_stub.dart';

/// Call Recording Service - Handles recording of voice/video calls
/// 
/// Features:
/// - Records audio during voice/video calls (Web & Mobile)
/// - Uploads recordings to Firebase Storage
/// - Saves recording metadata to Firestore
/// - Notifies remote user about recording
/// - Supports both Web and Android platforms
class CallRecordingService {
  // Singleton pattern
  static final CallRecordingService _instance = CallRecordingService._internal();
  factory CallRecordingService() => _instance;
  CallRecordingService._internal();

  // Platform-specific recorder instances
  AudioRecorder? _mobileRecorder; // For mobile
  WebAudioRecorder? _webRecorder; // For web
  
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
  
  /// Initialize platform-specific recorder
  void _initRecorder() {
    if (kIsWeb) {
      _webRecorder ??= WebAudioRecorder();
      debugPrint('[CallRecording] 🌐 Web Audio Recorder initialized');
    } else {
      _mobileRecorder ??= AudioRecorder();
      debugPrint('[CallRecording] 📱 Mobile Audio Recorder initialized');
    }
  }
  
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
      _initRecorder();
      
      debugPrint('[CallRecording] 🎙️ Starting recording...');
      debugPrint('[CallRecording] Platform: ${kIsWeb ? "Web" : "Mobile"}');
      
      if (kIsWeb) {
        // Web platform recording
        await _webRecorder!.start();
      } else {
        // Mobile platform recording
        final hasPermission = await _mobileRecorder!.hasPermission();
        if (!hasPermission) {
          debugPrint('[CallRecording] ❌ Microphone permission denied');
          return false;
        }
        
        final String recordingDirectory = await _getRecordingDirectory();
        final String fileName = 'call_${callId}_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _recordingPath = '$recordingDirectory/$fileName';
        
        debugPrint('[CallRecording] Path: $_recordingPath');
        
        const config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        );
        
        await _mobileRecorder!.start(config, path: _recordingPath!);
      }
      
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
      
      String? uploadUrl;
      
      if (kIsWeb) {
        // Web platform - get Blob and upload directly
        final blob = await _webRecorder!.stop();
        _isRecording = false;
        
        if (blob == null) {
          debugPrint('[CallRecording] ❌ Web recording blob is null');
          return null;
        }
        
        final duration = DateTime.now().difference(_recordingStartTime!).inSeconds;
        
        debugPrint('[CallRecording] 📊 Web recording stopped');
        debugPrint('[CallRecording]    Duration: ${duration}s');
        debugPrint('[CallRecording]    Blob size: ${blob.size} bytes');
        
        // Notify remote user that recording stopped
        if (_currentCallId != null && _remoteUserId != null) {
          await _notifyRemoteUserRecording(_currentCallId!, _remoteUserId!, isRecording: false);
        }
        
        // Upload blob to Firebase Storage
        uploadUrl = await _uploadWebBlob(blob);
        
        if (uploadUrl == null) {
          debugPrint('[CallRecording] ❌ Failed to upload web recording');
          return null;
        }
        
        // Save metadata to Firestore
        final recording = await _saveRecordingMetadata(
          callId: _currentCallId!,
          recordingUrl: uploadUrl,
          duration: duration,
        );
        
        // Reset state
        _recordingPath = null;
        _recordingStartTime = null;
        _currentCallId = null;
        _remoteUserId = null;
        
        debugPrint('[CallRecording] ✅ Web recording saved successfully');
        return recording;
        
      } else {
        // Mobile platform - stop recorder and get file path
        final path = await _mobileRecorder!.stop();
        _isRecording = false;
        
        if (path == null || _recordingPath == null) {
          debugPrint('[CallRecording] ❌ Recording path is null');
          return null;
        }
        
        final duration = DateTime.now().difference(_recordingStartTime!).inSeconds;
        
        debugPrint('[CallRecording] 📊 Mobile recording stopped');
        debugPrint('[CallRecording]    Duration: ${duration}s');
        debugPrint('[CallRecording]    Path: $path');
        
        // Notify remote user that recording stopped
        if (_currentCallId != null && _remoteUserId != null) {
          await _notifyRemoteUserRecording(_currentCallId!, _remoteUserId!, isRecording: false);
        }
        
        // Upload to Firebase Storage
        uploadUrl = await _uploadMobileFile(path);
        
        if (uploadUrl == null) {
          debugPrint('[CallRecording] ❌ Failed to upload mobile recording');
          return null;
        }
        
        // Save metadata to Firestore
        final recording = await _saveRecordingMetadata(
          callId: _currentCallId!,
          recordingUrl: uploadUrl,
          duration: duration,
        );
        
        // Clean up local file
        await _deleteLocalFile(path);
        
        // Reset state
        _recordingPath = null;
        _recordingStartTime = null;
        _currentCallId = null;
        _remoteUserId = null;
        
        debugPrint('[CallRecording] ✅ Mobile recording saved successfully');
        return recording;
      }
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
      
      if (kIsWeb) {
        await _webRecorder!.stop();
      } else {
        final path = await _mobileRecorder!.stop();
        if (path != null) {
          await _deleteLocalFile(path);
        }
      }
      
      _isRecording = false;
      
      // Notify remote user that recording stopped
      if (_currentCallId != null && _remoteUserId != null) {
        await _notifyRemoteUserRecording(_currentCallId!, _remoteUserId!, isRecording: false);
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
  
  /// Get recording directory based on platform (Mobile only)
  Future<String> _getRecordingDirectory() async {
    final directory = await getTemporaryDirectory();
    final recordingDir = Directory('${directory.path}/call_recordings');
    
    if (!await recordingDir.exists()) {
      await recordingDir.create(recursive: true);
    }
    
    return recordingDir.path;
  }
  
  /// Upload Web Blob to Firebase Storage
  Future<String?> _uploadWebBlob(dynamic blob) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('[CallRecording] ❌ No authenticated user');
        return null;
      }
      
      final userId = currentUser.uid;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.webm';
      final storageRef = _storage.ref().child('call_recordings/$userId/$fileName');
      
      debugPrint('[CallRecording] ☁️ Uploading web blob to Firebase Storage...');
      debugPrint('[CallRecording]    Path: call_recordings/$userId/$fileName');
      
      // Upload blob using putBlob (Web-specific)
      final uploadTask = storageRef.putBlob(
        blob,
        SettableMetadata(
          contentType: 'audio/webm',
          customMetadata: {
            'callId': _currentCallId ?? 'unknown',
            'recordedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('[CallRecording] ✅ Web upload completed');
      debugPrint('[CallRecording]    URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      debugPrint('[CallRecording] ❌ Web upload failed: $e');
      return null;
    }
  }
  
  /// Upload Mobile file to Firebase Storage
  Future<String?> _uploadMobileFile(String localPath) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('[CallRecording] ❌ No authenticated user');
        return null;
      }
      
      final userId = currentUser.uid;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final storageRef = _storage.ref().child('call_recordings/$userId/$fileName');
      
      debugPrint('[CallRecording] ☁️ Uploading mobile file to Firebase Storage...');
      debugPrint('[CallRecording]    Path: call_recordings/$userId/$fileName');
      
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
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('[CallRecording] ✅ Mobile upload completed');
      debugPrint('[CallRecording]    URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      debugPrint('[CallRecording] ❌ Mobile upload failed: $e');
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
    }
  }
  
  /// Delete local recording file (Mobile only)
  Future<void> _deleteLocalFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[CallRecording] 🗑️ Local file deleted: $path');
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
      await _firestore.collection('call_recordings').doc(recording.id).delete();
      
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
    
    if (kIsWeb) {
      _webRecorder?.dispose();
    } else {
      await _mobileRecorder?.dispose();
    }
  }
}
