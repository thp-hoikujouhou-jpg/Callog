/// Stub for Web Audio Recorder (used on mobile platforms)
/// This file is a placeholder to allow conditional imports

class WebAudioRecorder {
  WebAudioRecorder();
  
  bool get isRecording => false;
  
  Future<void> start() async {
    throw UnsupportedError('WebAudioRecorder is only supported on Web platform');
  }
  
  Future<dynamic> stop() async {
    throw UnsupportedError('WebAudioRecorder is only supported on Web platform');
  }
  
  void dispose() {}
}
