import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Image Proxy Utility
/// 
/// Provides CORS-safe image URL proxying for web platform.
/// On mobile platforms, returns the original URL.
class ImageProxy {
  /// Get CORS-safe image URL
  /// 
  /// For web platform: Uses CORS proxy
  /// For mobile platforms: Returns original URL
  static String getCorsProxyUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '';
    }

    // On web platform, use CORS proxy for Firebase Storage images
    if (kIsWeb && imageUrl.contains('firebasestorage.googleapis.com')) {
      // Use CORS Anywhere proxy
      return 'https://corsproxy.io/?${Uri.encodeComponent(imageUrl)}';
    }

    // For mobile or non-Firebase URLs, return original
    return imageUrl;
  }

  /// Get image provider with CORS handling
  static NetworkImage getImageProvider(String? imageUrl) {
    return NetworkImage(getCorsProxyUrl(imageUrl));
  }
}
