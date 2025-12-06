import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Web-specific Ringtone Service using Web Audio API
/// 
/// This implementation uses browser's native Audio API for better compatibility
class RingtoneServiceWeb {
  static final RingtoneServiceWeb _instance = RingtoneServiceWeb._internal();
  factory RingtoneServiceWeb() => _instance;
  RingtoneServiceWeb._internal();

  html.AudioElement? _audioElement;
  bool _isPlaying = false;

  /// Play ringtone (loops until stopped)
  Future<void> playRingtone() async {
    if (_isPlaying) {
      debugPrint('[Ringtone] Already playing, skipping');
      return;
    }

    try {
      debugPrint('[Ringtone] 🔔 Starting ringtone playback (Web Audio API)');
      
      // Create audio element
      _audioElement = html.AudioElement();
      
      // Use a clear, pleasant ringtone
      _audioElement!.src = 'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3';
      _audioElement!.loop = true; // Loop continuously
      _audioElement!.volume = 1.0; // Full volume
      
      // Wait for audio to be loaded
      await _audioElement!.play();
      
      _isPlaying = true;
      debugPrint('[Ringtone] ✅ Ringtone playing (Web Audio API)');
    } catch (e) {
      debugPrint('[Ringtone] ❌ Error playing ringtone: $e');
      debugPrint('[Ringtone] 💡 Note: Browser may block autoplay. User interaction required.');
    }
  }

  /// Stop ringtone
  Future<void> stopRingtone() async {
    if (!_isPlaying) {
      debugPrint('[Ringtone] Not playing, skipping stop');
      return;
    }

    try {
      debugPrint('[Ringtone] 🔕 Stopping ringtone');
      
      if (_audioElement != null) {
        _audioElement!.pause();
        _audioElement!.currentTime = 0;
        _audioElement = null;
      }
      
      _isPlaying = false;
      debugPrint('[Ringtone] ✅ Ringtone stopped');
    } catch (e) {
      debugPrint('[Ringtone] ❌ Error stopping ringtone: $e');
    }
  }

  /// Check if ringtone is currently playing
  bool get isPlaying => _isPlaying;

  /// Dispose audio player
  void dispose() {
    if (_audioElement != null) {
      _audioElement!.pause();
      _audioElement = null;
    }
    _isPlaying = false;
  }
}
