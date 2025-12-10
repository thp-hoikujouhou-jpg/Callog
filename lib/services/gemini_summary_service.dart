import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Gemini AI Summary Service
/// 
/// Features:
/// - Summarize transcription text using Gemini AI
/// - Extract key points from call recordings
/// - Support for Japanese and other languages
/// - Rate limit handling with exponential backoff retry
/// - User-friendly error messages
class GeminiSummaryService {
  // Singleton pattern
  static final GeminiSummaryService _instance = GeminiSummaryService._internal();
  factory GeminiSummaryService() => _instance;
  GeminiSummaryService._internal();

  // Gemini API configuration
  static const String _apiKey = 'AIzaSyCZEIJG-SMR-wSlqg820rBKveDe4rjWnfA';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash-lite:generateContent';
  
  // Retry configuration (Exponential Backoff) - Enhanced for higher success rate
  static const int _maxRetries = 5; // Increased from 3 to 5 retries
  static const int _initialDelayMs = 2000; // Increased from 1s to 2s
  static const int _maxDelayMs = 16000; // Increased from 8s to 16s
  
  /// Summarize transcription text into key points with automatic retry
  /// 
  /// [transcription] - The full transcription text
  /// Returns a list of key points or error message if failed
  Future<String?> summarizeText(String transcription) async {
    return await _summarizeWithRetry(transcription, 0);
  }
  
  /// Internal method to handle API calls with exponential backoff retry
  Future<String?> _summarizeWithRetry(String transcription, int attemptNumber) async {
    try {
      if (kDebugMode) {
        debugPrint('🤖 [GeminiSummary] Starting summarization (Attempt ${attemptNumber + 1}/${_maxRetries + 1})...');
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
      
      // Handle rate limit error (429) with retry
      if (response.statusCode == 429) {
        debugPrint('⚠️ [GeminiSummary] Rate limit exceeded (429) - Attempt ${attemptNumber + 1}');
        
        // If we haven't exceeded max retries, retry with exponential backoff
        if (attemptNumber < _maxRetries - 1) {
          final delayMs = _calculateBackoffDelay(attemptNumber);
          debugPrint('🔄 [GeminiSummary] Retrying after ${delayMs}ms...');
          
          // Wait before retrying
          await Future.delayed(Duration(milliseconds: delayMs));
          
          // Retry the request
          return await _summarizeWithRetry(transcription, attemptNumber + 1);
        }
        
        // Max retries exceeded
        debugPrint('❌ [GeminiSummary] Max retries exceeded for 429 error');
        return 'ERROR_429:APIの利用制限に達しました。${_formatRetryMessage(attemptNumber)}';
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
        if (attemptNumber > 0) {
          debugPrint('✅ [GeminiSummary] Succeeded after ${attemptNumber + 1} attempts');
        }
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
  
  /// Calculate exponential backoff delay with jitter
  /// 
  /// Formula: min(maxDelay, initialDelay * 2^attempt) + random jitter
  int _calculateBackoffDelay(int attemptNumber) {
    // Exponential backoff: 1s, 2s, 4s, 8s...
    final exponentialDelay = _initialDelayMs * pow(2, attemptNumber);
    
    // Cap at maximum delay
    final cappedDelay = min(exponentialDelay.toInt(), _maxDelayMs);
    
    // Add random jitter (0-1000ms) to prevent thundering herd
    final random = Random();
    final jitter = random.nextInt(1000);
    
    return cappedDelay + jitter;
  }
  
  /// Format retry message for user
  String _formatRetryMessage(int attemptNumber) {
    return '${attemptNumber + 1}回試行しましたが、利用制限が続いています。\n\n💡 対処方法:\n• 2〜3分待ってから再度お試しください\n• Google AI Studioでクォータを確認\n• 連続してリクエストを送信しないでください\n• 無料プランの制限: 1分あたり15リクエスト';
  }
}
