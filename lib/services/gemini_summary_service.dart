import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Gemini AI Summary Service
/// 
/// Features:
/// - Summarize transcription text using Gemini AI
/// - Extract key points from call recordings
/// - Support for Japanese and other languages
class GeminiSummaryService {
  // Singleton pattern
  static final GeminiSummaryService _instance = GeminiSummaryService._internal();
  factory GeminiSummaryService() => _instance;
  GeminiSummaryService._internal();

  // Gemini API configuration
  static const String _apiKey = 'AIzaSyDCnU16tQHO_hxqDJFL-R01ure40QdzqLg';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash-lite:generateContent';
  
  /// Summarize transcription text into key points
  /// 
  /// [transcription] - The full transcription text
  /// Returns a list of key points or null if failed
  Future<String?> summarizeText(String transcription) async {
    try {
      if (kDebugMode) {
        debugPrint('🤖 [GeminiSummary] Starting summarization...');
        debugPrint('🤖 [GeminiSummary] Text length: ${transcription.length} characters');
      }
      
      // Prepare prompt for Gemini
      final prompt = '''
以下の通話文字起こしから、重要なポイントを箇条書き（3〜5項目）でまとめてください。
各項目は「・」で始め、簡潔に1行で記載してください。

文字起こしテキスト:
$transcription

要点まとめ:
''';

      // Call Gemini API
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 500,
          }
        }),
      );
      
      if (kDebugMode) {
        debugPrint('🤖 [GeminiSummary] Response status: ${response.statusCode}');
      }
      
      if (response.statusCode != 200) {
        debugPrint('❌ [GeminiSummary] API error: ${response.statusCode}');
        debugPrint('❌ [GeminiSummary] Response: ${response.body}');
        return null;
      }
      
      final responseData = jsonDecode(response.body);
      
      // Extract summary from response
      final candidates = responseData['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        debugPrint('⚠️ [GeminiSummary] No candidates in response');
        return null;
      }
      
      final content = candidates[0]['content'];
      final parts = content['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        debugPrint('⚠️ [GeminiSummary] No parts in content');
        return null;
      }
      
      final summary = parts[0]['text'] as String?;
      
      if (summary == null || summary.trim().isEmpty) {
        debugPrint('⚠️ [GeminiSummary] Empty summary result');
        return null;
      }
      
      if (kDebugMode) {
        debugPrint('✅ [GeminiSummary] Summary generated successfully');
        debugPrint('✅ [GeminiSummary] Summary length: ${summary.length} characters');
      }
      
      return summary.trim();
      
    } catch (e, stackTrace) {
      debugPrint('❌ [GeminiSummary] Error: $e');
      debugPrint('❌ [GeminiSummary] Stack trace: $stackTrace');
      return null;
    }
  }
}
