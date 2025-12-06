import 'package:flutter/foundation.dart';

/// Stub implementation for non-Web platforms
/// This file is used on mobile platforms where Web Audio API is not available
class RingtoneServiceWeb {
  static final RingtoneServiceWeb _instance = RingtoneServiceWeb._internal();
  factory RingtoneServiceWeb() => _instance;
  RingtoneServiceWeb._internal();

  bool _isPlaying = false;

  Future<void> playRingtone() async {
    debugPrint('[Ringtone] Stub: playRingtone() - Not used on mobile');
  }

  Future<void> stopRingtone() async {
    debugPrint('[Ringtone] Stub: stopRingtone() - Not used on mobile');
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    debugPrint('[Ringtone] Stub: dispose() - Not used on mobile');
  }
}
