import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

/// Agora Token Service
/// 
/// Generates secure RTC tokens using Cloud Functions
/// This ensures App Certificate security and prevents token manipulation
class AgoraTokenService {
  static final AgoraTokenService _instance = AgoraTokenService._internal();
  factory AgoraTokenService() => _instance;
  AgoraTokenService._internal();

  // Vercel Functions endpoint
  static const String _generateTokenUrl = 
      'https://callog-api-v2.vercel.app/api/generateAgoraToken';

  /// Generate Agora RTC Token
  /// 
  /// Parameters:
  /// - channelName: The name of the channel to join
  /// - uid: User ID (0 for auto-assignment by Agora)
  /// - role: 'publisher' (can send/receive) or 'audience' (can only receive)
  /// 
  /// Returns:
  /// - Map containing token, appId, channelName, uid, and expiration time
  /// 
  /// Example:
  /// ```dart
  /// final tokenData = await AgoraTokenService().generateToken(
  ///   channelName: 'my_channel',
  ///   uid: 12345,
  ///   role: 'publisher',
  /// );
  /// 
  /// final token = tokenData['token'];
  /// final appId = tokenData['appId'];
  /// ```
  Future<Map<String, dynamic>> generateToken({
    required String channelName,
    int uid = 0,
    String role = 'publisher',
  }) async {
    try {
      debugPrint('[AgoraToken] 🎫 Generating token for channel: $channelName');
      debugPrint('[AgoraToken] UID: $uid, Role: $role');

      // Get Firebase Auth token for authentication
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      
      // Call Cloud Function using HTTP POST (2nd Gen URL)
      final url = Uri.parse(_generateTokenUrl);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          'data': {
            'channelName': channelName,
            'uid': uid,
            'role': role,
          }
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate token: ${response.body}');
      }

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      final data = responseData['data'] as Map<String, dynamic>;
      
      debugPrint('[AgoraToken] ✅ Token generated successfully');
      debugPrint('[AgoraToken] Expires at: ${data['expiresAt'] ?? 'N/A'}');
      
      if (data['token'] == null) {
        debugPrint('[AgoraToken] ⚠️ Warning: ${data['message']}');
        debugPrint('[AgoraToken] 💡 App Certificate not configured - using null token');
      }
      
      return {
        'token': data['token'] as String?,
        'appId': data['appId'] as String,
        'channelName': data['channelName'] as String,
        'uid': data['uid'] as int,
        'expiresAt': data['expiresAt'] as int?,
      };
      
    } catch (e, stackTrace) {
      debugPrint('[AgoraToken] ❌ Error generating token: $e');
      debugPrint('[AgoraToken] Stack trace: $stackTrace');
      
      // Rethrow to allow caller to handle the error
      rethrow;
    }
  }

  /// Refresh Agora RTC Token
  /// 
  /// Should be called before token expiration (ideally when 30 seconds remaining)
  /// 
  /// Parameters:
  /// - channelName: The name of the channel
  /// - uid: User ID (must match the current UID)
  /// - role: 'publisher' or 'audience'
  /// 
  /// Returns:
  /// - New token data
  Future<Map<String, dynamic>> refreshToken({
    required String channelName,
    required int uid,
    String role = 'publisher',
  }) async {
    debugPrint('[AgoraToken] 🔄 Refreshing token for channel: $channelName');
    
    // Token refresh is the same as generating a new token
    return generateToken(
      channelName: channelName,
      uid: uid,
      role: role,
    );
  }

  /// Get token expiration status
  /// 
  /// Parameters:
  /// - expiresAt: Unix timestamp of token expiration
  /// 
  /// Returns:
  /// - Map with expiration status information
  Map<String, dynamic> getExpirationStatus(int expiresAt) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final secondsRemaining = expiresAt - now;
    
    return {
      'isExpired': secondsRemaining <= 0,
      'shouldRefresh': secondsRemaining <= 300, // Refresh when 5 minutes remaining
      'secondsRemaining': secondsRemaining,
      'expiresAt': DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
    };
  }
}
