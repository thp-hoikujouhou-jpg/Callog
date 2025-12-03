/// Agora Configuration
/// 
/// IMPORTANT: Update this file with your Agora App ID from https://console.agora.io/
/// 
/// Error -17 (INVALID_APP_ID) Solutions:
/// 1. Go to Agora Console: https://console.agora.io/
/// 2. Create a new project or select existing one
/// 3. Get the App ID (32-character hexadecimal string)
/// 4. Replace the appId value below
/// 5. Ensure your App ID project status is "Active"
/// 
/// Common Issues:
/// - App ID is disabled or expired
/// - App ID format is incorrect (must be 32 hex characters)
/// - No internet connection when initializing
/// - App ID belongs to a different Agora account

class AgoraConfig {
  // Replace with your Agora App ID from https://console.agora.io/
  // Example: 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6'
  static const String appId = 'd1a8161eb70448d89eea1722bc169c92';
  
  // Optional: Agora Token (for production use)
  // Leave empty for testing without token
  static const String? token = null;
  
  // App Certificate (optional, for token generation)
  static const String? certificate = null;
  
  // Validate App ID format
  static bool isValidAppId() {
    if (appId.isEmpty || appId.length != 32) {
      return false;
    }
    // Check if it's hexadecimal
    final hexRegex = RegExp(r'^[a-f0-9]+$');
    return hexRegex.hasMatch(appId);
  }
  
  // Get error message for invalid App ID
  static String getAppIdErrorMessage() {
    return '''
🚨 Agora App ID Error (Error -17: INVALID_APP_ID)

Current App ID: $appId (${appId.length} characters)
Expected format: 32-character hexadecimal string

📋 How to fix:
1. Go to https://console.agora.io/
2. Sign in to your Agora account
3. Create a new project or select existing one
4. Copy the App ID
5. Open lib/config/agora_config.dart
6. Replace the appId value with your App ID
7. Rebuild the app

⚠️ Common Issues:
- App ID is disabled in Agora Console
- App ID project is inactive
- Wrong App ID format
- Internet connection issue

💡 Need help?
Visit: https://docs.agora.io/en/video-calling/get-started/get-started-sdk
''';
  }
}
