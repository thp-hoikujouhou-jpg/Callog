/// Stub for record package (used on web platform)
/// This file is a placeholder to allow conditional imports

class AudioRecorder {
  AudioRecorder();
  
  Future<bool> hasPermission() async {
    throw UnsupportedError('AudioRecorder is only supported on Mobile platform');
  }
  
  Future<void> start(dynamic config, {String? path}) async {
    throw UnsupportedError('AudioRecorder is only supported on Mobile platform');
  }
  
  Future<String?> stop() async {
    throw UnsupportedError('AudioRecorder is only supported on Mobile platform');
  }
  
  Future<void> dispose() async {}
}

class RecordConfig {
  final dynamic encoder;
  final int bitRate;
  final int sampleRate;
  final int numChannels;
  
  const RecordConfig({
    required this.encoder,
    required this.bitRate,
    required this.sampleRate,
    required this.numChannels,
  });
}

class AudioEncoder {
  static const aacLc = 'aacLc';
}
