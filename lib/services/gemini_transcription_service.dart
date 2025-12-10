import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Gemini AI Transcription Service
/// 
/// Features:
/// - Transcribe audio files using Gemini AI
/// - Support for WebM and M4A audio formats
/// - Save transcription results to Firestore
/// - Process audio from Firebase Storage URLs
class GeminiTranscriptionService {
  // Singleton pattern
  static final GeminiTranscriptionService _instance = GeminiTranscriptionService._internal();
  factory GeminiTranscriptionService() => _instance;
  GeminiTranscriptionService._internal();

  // Note: Gemini API Key is now stored in Vercel environment variables
  // No need to include it in the Flutter app for better security
  
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  

  
  /// Transcribe audio file from Firebase Storage URL
  /// 
  /// [recordingId] - The ID of the call recording document
  /// [audioUrl] - Firebase Storage download URL of the audio file
  /// [audioFormat] - Format of the audio file (webm or m4a)
  /// 
  /// Returns the transcribed text
  Future<String?> transcribeAudio({
    required String recordingId,
    required String audioUrl,
    required String audioFormat,
  }) async {
    try {
      debugPrint('[GeminiTranscription] 🎙️ Starting transcription...');
      debugPrint('[GeminiTranscription]    Recording ID: $recordingId');
      debugPrint('[GeminiTranscription]    Audio URL: $audioUrl');
      debugPrint('[GeminiTranscription]    Format: $audioFormat');
      
      debugPrint('[GeminiTranscription] 📡 Using Vercel API proxy to bypass CORS');
      
      // Use Vercel API endpoint to transcribe (bypasses CORS)
      final vercelEndpoint = 'https://callog.vercel.app/api/transcribeAudio';
      
      debugPrint('[GeminiTranscription] 🚀 Calling Vercel API...');
      debugPrint('[GeminiTranscription]    Endpoint: $vercelEndpoint');
      
      // Call Vercel API (API key is stored in Vercel environment variables)
      final response = await http.post(
        Uri.parse(vercelEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'audioUrl': audioUrl,
          'audioFormat': audioFormat,
          // API key is now stored in Vercel environment (GEMINI_API_KEY)
        }),
      );
      
      debugPrint('[GeminiTranscription] 📬 Response status: ${response.statusCode}');
      debugPrint('[GeminiTranscription] 📄 Response body: ${response.body}');
      
      if (response.statusCode != 200) {
        debugPrint('[GeminiTranscription] ❌ Vercel API error: ${response.statusCode}');
        debugPrint('[GeminiTranscription]    Response: ${response.body}');
        
        // Try to parse error message
        try {
          final errorData = jsonDecode(response.body);
          debugPrint('[GeminiTranscription]    Error details: ${errorData['error']}');
          if (errorData['message'] != null) {
            debugPrint('[GeminiTranscription]    Message: ${errorData['message']}');
          }
        } catch (e) {
          // Ignore JSON parsing error
        }
        return null;
      }
      
      final responseData = jsonDecode(response.body);
      final transcription = responseData['transcription'] as String?;
      
      debugPrint('[GeminiTranscription] 📝 Raw transcription: $transcription');
      
      if (transcription == null || transcription.trim().isEmpty) {
        debugPrint('[GeminiTranscription] ⚠️ Empty transcription result from API');
        debugPrint('[GeminiTranscription]    This may indicate silent audio or speech recognition failure');
        return null;
      }
      
      debugPrint('[GeminiTranscription] ✅ Transcription completed via Vercel API');
      debugPrint('[GeminiTranscription]    Length: ${transcription.length} characters');
      
      // Save transcription to Firestore
      await _saveTranscription(recordingId, transcription);
      
      return transcription;
      
    } catch (e) {
      debugPrint('[GeminiTranscription] ❌ Transcription failed: $e');
      return null;
    }
  }
  
  /// Save transcription result to Firestore
  Future<void> _saveTranscription(String recordingId, String transcription) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('[GeminiTranscription] ⚠️ No authenticated user');
        return;
      }
      
      debugPrint('[GeminiTranscription] 💾 Saving transcription to Firestore...');
      
      await _firestore.collection('call_recordings').doc(recordingId).update({
        'transcription': transcription,
        'transcriptionStatus': 'completed',
        'transcriptionTimestamp': FieldValue.serverTimestamp(),
      });
      
      debugPrint('[GeminiTranscription] ✅ Transcription saved to Firestore');
      
    } catch (e) {
      debugPrint('[GeminiTranscription] ❌ Failed to save transcription: $e');
    }
  }
  
  /// Update transcription status (processing, completed, failed)
  Future<void> updateTranscriptionStatus(
    String recordingId,
    String status, {
    String? errorMessage,
  }) async {
    try {
      final updateData = {
        'transcriptionStatus': status,
        'transcriptionTimestamp': FieldValue.serverTimestamp(),
      };
      
      if (errorMessage != null) {
        updateData['transcriptionError'] = errorMessage;
      }
      
      await _firestore.collection('call_recordings').doc(recordingId).update(updateData);
      
      debugPrint('[GeminiTranscription] 📝 Status updated: $status');
      
    } catch (e) {
      debugPrint('[GeminiTranscription] ❌ Failed to update status: $e');
    }
  }
  
  /// Get transcription for a recording
  Future<String?> getTranscription(String recordingId) async {
    try {
      final doc = await _firestore.collection('call_recordings').doc(recordingId).get();
      
      if (!doc.exists) {
        return null;
      }
      
      final data = doc.data();
      return data?['transcription'] as String?;
      
    } catch (e) {
      debugPrint('[GeminiTranscription] ❌ Failed to get transcription: $e');
      return null;
    }
  }
  
  /// Check if transcription exists for a recording
  Future<bool> hasTranscription(String recordingId) async {
    try {
      final doc = await _firestore.collection('call_recordings').doc(recordingId).get();
      
      if (!doc.exists) {
        return false;
      }
      
      final data = doc.data();
      return data?['transcription'] != null && (data!['transcription'] as String).isNotEmpty;
      
    } catch (e) {
      debugPrint('[GeminiTranscription] ❌ Failed to check transcription: $e');
      return false;
    }
  }
  
  /// Get transcription status
  Future<String?> getTranscriptionStatus(String recordingId) async {
    try {
      final doc = await _firestore.collection('call_recordings').doc(recordingId).get();
      
      if (!doc.exists) {
        return null;
      }
      
      final data = doc.data();
      return data?['transcriptionStatus'] as String?;
      
    } catch (e) {
      debugPrint('[GeminiTranscription] ❌ Failed to get status: $e');
      return null;
    }
  }
}
