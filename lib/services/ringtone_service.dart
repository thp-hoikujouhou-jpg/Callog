import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:audioplayers/audioplayers.dart';

/// Ringtone Service for Incoming Calls
/// 
/// Plays ringtone for incoming calls (LINE/WhatsApp style)
/// Only plays when app is in foreground/background (not closed)
class RingtoneService {
  static final RingtoneService _instance = RingtoneService._internal();
  factory RingtoneService() => _instance;
  RingtoneService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  /// Play ringtone (loops until stopped)
  Future<void> playRingtone() async {
    if (_isPlaying) {
      debugPrint('[Ringtone] Already playing, skipping');
      return;
    }

    try {
      debugPrint('[Ringtone] 🔔 Starting ringtone playback');
      
      // For Web platform, use network audio
      if (kIsWeb) {
        // Use a free ringtone audio file (you can replace with your own)
        const ringtoneUrl = 'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3';
        
        await _audioPlayer.setReleaseMode(ReleaseMode.loop); // Loop the ringtone
        await _audioPlayer.setVolume(1.0); // Full volume
        await _audioPlayer.play(UrlSource(ringtoneUrl));
        
        _isPlaying = true;
        debugPrint('[Ringtone] ✅ Ringtone playing (Web)');
      } else {
        // For mobile platforms, use asset audio
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.play(AssetSource('audio/ringtone.mp3'));
        
        _isPlaying = true;
        debugPrint('[Ringtone] ✅ Ringtone playing (Mobile)');
      }
    } catch (e) {
      debugPrint('[Ringtone] ❌ Error playing ringtone: $e');
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
      await _audioPlayer.stop();
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
    _audioPlayer.dispose();
  }
}
