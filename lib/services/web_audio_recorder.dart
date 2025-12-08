import 'dart:async';
import 'dart:js_interop' as js;
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Web Audio APIを使用した録音サービス (Web Platform専用)
class WebAudioRecorder {
  web.MediaRecorder? _mediaRecorder;
  StreamController<Uint8List>? _audioStreamController;
  final List<web.Blob> _recordedChunks = [];
  bool _isRecording = false;

  /// 録音中かどうか
  bool get isRecording => _isRecording;

  /// 録音を開始
  Future<void> start() async {
    if (_isRecording) {
      if (kDebugMode) {
        debugPrint('⚠️ WebAudioRecorder: 既に録音中です');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('🎤 WebAudioRecorder: 録音開始リクエスト');
      }

      // マイク権限をリクエスト (高品質設定)
      final audioConstraints = js.JSObject();
      audioConstraints.setProperty('echoCancellation'.toJS, true.toJS); // エコーキャンセル
      audioConstraints.setProperty('noiseSuppression'.toJS, true.toJS); // ノイズ除去
      audioConstraints.setProperty('autoGainControl'.toJS, true.toJS);  // 自動ゲイン調整
      audioConstraints.setProperty('sampleRate'.toJS, 48000.toJS);      // 48kHz (高品質)
      audioConstraints.setProperty('channelCount'.toJS, 1.toJS);        // モノラル (音声認識最適)
      
      final streamPromise = web.window.navigator.mediaDevices.getUserMedia(
        web.MediaStreamConstraints(
          audio: audioConstraints,
          video: false.toJS,
        ),
      );
      final stream = await streamPromise.toDart;

      if (kDebugMode) {
        debugPrint('✅ WebAudioRecorder: マイク権限取得成功');
        debugPrint('🎚️ 録音品質設定:');
        debugPrint('   - Sample Rate: 48000 Hz');
        debugPrint('   - Bit Rate: 128 kbps');
        debugPrint('   - Echo Cancellation: ON');
        debugPrint('   - Noise Suppression: ON');
        debugPrint('   - Auto Gain Control: ON');
        debugPrint('   - Channel: Mono');
      }

      // MediaRecorderを作成 (高品質設定)
      _mediaRecorder = web.MediaRecorder(
        stream,
        web.MediaRecorderOptions(
          mimeType: 'audio/webm;codecs=opus',
          audioBitsPerSecond: 128000, // 128kbps (高品質音声)
        ),
      );

      _recordedChunks.clear();

      // データが利用可能になったときのハンドラー
      _mediaRecorder!.ondataavailable = (web.BlobEvent event) {
        if (event.data.size > 0) {
          _recordedChunks.add(event.data);
          if (kDebugMode) {
            debugPrint('📦 WebAudioRecorder: データチャンク追加 (size: ${event.data.size})');
          }
        }
      }.toJS;

      // 録音開始
      _mediaRecorder!.start();
      _isRecording = true;

      if (kDebugMode) {
        debugPrint('✅ WebAudioRecorder: 録音開始成功');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ WebAudioRecorder: 録音開始エラー: $e');
      }
      rethrow;
    }
  }

  /// 録音を停止してBlobを返す
  Future<web.Blob?> stop() async {
    if (!_isRecording || _mediaRecorder == null) {
      if (kDebugMode) {
        debugPrint('⚠️ WebAudioRecorder: 録音中ではありません');
      }
      return null;
    }

    try {
      if (kDebugMode) {
        debugPrint('🛑 WebAudioRecorder: 録音停止リクエスト');
      }

      // MediaRecorderの停止を待つ
      final completer = Completer<void>();
      
      _mediaRecorder!.onstop = ((web.Event event) {
        if (kDebugMode) {
          debugPrint('✅ WebAudioRecorder: MediaRecorder停止完了');
        }
        completer.complete();
      }).toJS;

      _mediaRecorder!.stop();

      // すべてのトラックを停止
      final stream = _mediaRecorder!.stream;
      for (var track in stream.getTracks().toDart) {
        track.stop();
      }

      // 停止完了を待つ
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('⚠️ WebAudioRecorder: 停止タイムアウト');
          }
        },
      );

      _isRecording = false;

      // 録音データをBlobに結合
      if (_recordedChunks.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ WebAudioRecorder: 録音データがありません');
        }
        return null;
      }

      final blob = web.Blob(
        _recordedChunks.toJS,
        web.BlobPropertyBag(type: 'audio/webm;codecs=opus'),
      );

      if (kDebugMode) {
        debugPrint('✅ WebAudioRecorder: Blob作成成功 (size: ${blob.size} bytes)');
      }

      return blob;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ WebAudioRecorder: 録音停止エラー: $e');
      }
      _isRecording = false;
      return null;
    }
  }

  /// リソースをクリーンアップ
  void dispose() {
    if (_mediaRecorder != null) {
      final stream = _mediaRecorder!.stream;
      for (var track in stream.getTracks().toDart) {
        track.stop();
      }
    }
    _audioStreamController?.close();
    _recordedChunks.clear();
    _isRecording = false;
    
    if (kDebugMode) {
      debugPrint('🧹 WebAudioRecorder: リソースクリーンアップ完了');
    }
  }
}
