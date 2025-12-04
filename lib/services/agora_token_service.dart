import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Agora Token Service
/// 
/// Generates secure RTC tokens using Cloud Functions
/// This ensures App Certificate security and prevents token manipulation
class AgoraTokenService {
  static final AgoraTokenService _instance = AgoraTokenService._internal();
  factory AgoraTokenService() => _instance;
  AgoraTokenService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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

      // Call Cloud Function
      final callable = _functions.httpsCallable('generateAgoraToken');
      final result = await callable.call({
        'channelName': channelName,
        'uid': uid,
        'role': role,
      });

      final data = result.data as Map<String, dynamic>;
      
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
