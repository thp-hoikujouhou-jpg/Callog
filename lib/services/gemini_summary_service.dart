import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Gemini AI Summary Service
/// 
/// Features:
/// - Summarize transcription text using Gemini AI
/// - Extract key points from call recordings
/// - Support for Japanese and other languages
/// - Rate limit handling with user-friendly error messages
class GeminiSummaryService {
  // Singleton pattern
  static final GeminiSummaryService _instance = GeminiSummaryService._internal();
  factory GeminiSummaryService() => _instance;
  GeminiSummaryService._internal();

  // Gemini API configuration
  static const String _apiKey = 'AIzaSyCZEIJG-SMR-wSlqg820rBKveDe4rjWnfA';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash-lite:generateContent';
  
  /// Summarize transcription text into key points
  /// 
  /// [transcription] - The full transcription text
  /// Returns a list of key points or error message if failed
  Future<String?> summarizeText(String transcription) async {
    try {
      if (kDebugMode) {
        debugPrint('🤖 [GeminiSummary] Starting summarization...');
        debugPrint('🤖 [GeminiSummary] Text length: ${transcription.length} characters');
      }
      
      // Prepare prompt for Gemini
      final prompt = '''
以下の通話文字起こしから、重要なポイントを箇条書き(3〜5項目)でまとめてください。
各項目は「・」で始め、簡潔に1行で記載してください。

文字起こしテキスト:
$transcription

要点まとめ:
''';

      // Call Gemini API with timeout
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
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⏱️ [GeminiSummary] Request timeout');
          throw Exception('リクエストがタイムアウトしました');
        },
      );
      
      if (kDebugMode) {
        debugPrint('🤖 [GeminiSummary] Response status: ${response.statusCode}');
      }
      
      // Handle rate limit error (429)
      if (response.statusCode == 429) {
        debugPrint('⚠️ [GeminiSummary] Rate limit exceeded (429)');
        debugPrint('⚠️ [GeminiSummary] Response: ${response.body}');
        return 'ERROR_429:APIの利用制限に達しました。しばらく待ってから再度お試しください。\n\n💡 ヒント: Google AI Studioでクォータを確認できます。';
      }
      
      // Handle forbidden error (403)
      if (response.statusCode == 403) {
        debugPrint('❌ [GeminiSummary] Forbidden (403) - API key issue');
        debugPrint('❌ [GeminiSummary] Response: ${response.body}');
        return 'ERROR_403:APIキーに問題があります。管理者に連絡してください。';
      }
      
      // Handle other errors
      if (response.statusCode != 200) {
        debugPrint('❌ [GeminiSummary] API error: ${response.statusCode}');
        debugPrint('❌ [GeminiSummary] Response: ${response.body}');
        return 'ERROR_${response.statusCode}:API呼び出しに失敗しました。後でもう一度お試しください。';
      }
      
      final responseData = jsonDecode(response.body);
      
      // Extract summary from response
      final candidates = responseData['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        debugPrint('⚠️ [GeminiSummary] No candidates in response');
        return '⚠️ AI要約を生成できませんでした。テキストが短すぎる可能性があります。';
      }
      
      final content = candidates[0]['content'];
      final parts = content['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        debugPrint('⚠️ [GeminiSummary] No parts in content');
        return '⚠️ AI要約を生成できませんでした。';
      }
      
      final summary = parts[0]['text'] as String?;
      
      if (summary == null || summary.trim().isEmpty) {
        debugPrint('⚠️ [GeminiSummary] Empty summary result');
        return '⚠️ 要約結果が空でした。';
      }
      
      if (kDebugMode) {
        debugPrint('✅ [GeminiSummary] Summary generated successfully');
        debugPrint('✅ [GeminiSummary] Summary length: ${summary.length} characters');
      }
      
      return summary.trim();
      
    } catch (e, stackTrace) {
      debugPrint('❌ [GeminiSummary] Error: $e');
      debugPrint('❌ [GeminiSummary] Stack trace: $stackTrace');
      
      // Return user-friendly error message
      if (e.toString().contains('timeout')) {
        return 'ERROR_TIMEOUT:リクエストがタイムアウトしました。ネットワーク接続を確認してください。';
      }
      
      return 'ERROR:予期しないエラーが発生しました。後でもう一度お試しください。';
    }
  }
}
