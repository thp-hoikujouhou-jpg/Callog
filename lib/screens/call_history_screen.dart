import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import '../models/call_recording.dart';

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  List<CallRecording> _recordings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _setupRealtimeListener();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  /// Setup realtime listener for transcription updates
  void _setupRealtimeListener() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    if (kDebugMode) {
      debugPrint('🔄 [CallHistory] Setting up realtime listener');
    }

    _firestore
        .collection('call_recordings')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final recordings = snapshot.docs
            .map((doc) => CallRecording.fromMap(doc.data(), doc.id))
            .toList();

        setState(() {
          _recordings = recordings;
        });

        if (kDebugMode) {
          debugPrint('🔄 [CallHistory] Updated ${recordings.length} recordings');
        }
      }
    }, onError: (error) {
      if (kDebugMode) {
        debugPrint('❌ [CallHistory] Listener error: $error');
      }
    });
  }

  Future<void> _loadRecordings() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'ユーザーがログインしていません';
          _isLoading = false;
        });
        return;
      }

      if (kDebugMode) {
        debugPrint('📞 [CallHistory] Loading recordings for user: ${currentUser.uid}');
      }

      // Fetch recordings from Firestore
      final snapshot = await _firestore
          .collection('call_recordings')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      if (kDebugMode) {
        debugPrint('📞 [CallHistory] Found ${snapshot.docs.length} recordings');
      }

      final recordings = snapshot.docs
          .map((doc) => CallRecording.fromMap(doc.data(), doc.id))
          .toList();

      setState(() {
        _recordings = recordings;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [CallHistory] Error loading recordings: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      
      setState(() {
        _error = 'エラー: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localService = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('通話履歴'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecordings,
            tooltip: '再読み込み',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadRecordings,
                          child: const Text('再試行'),
                        ),
                      ],
                    ),
                  )
                : _recordings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text(
                              '通話履歴がありません',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _recordings.length,
                        itemBuilder: (context, index) {
                          final recording = _recordings[index];
                          return _buildRecordingCard(recording);
                        },
                      ),
      ),
    );
  }

  Widget _buildRecordingCard(CallRecording recording) {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    final dateStr = dateFormat.format(recording.timestamp);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          recording.callType == 'video' ? Icons.videocam : Icons.phone,
          color: Colors.blue.shade600,
        ),
        title: Text(
          recording.callPartner ?? '不明',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateStr),
            Text('通話時間: ${recording.formattedDuration}'),
            if (recording.transcriptionStatus != null)
              Row(
                children: [
                  if (recording.transcriptionStatus == 'processing')
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                      ),
                    )
                  else
                    Icon(
                      recording.transcriptionStatus == 'completed'
                          ? Icons.check_circle
                          : Icons.error,
                      size: 16,
                      color: recording.transcriptionStatus == 'completed'
                          ? Colors.green
                          : Colors.red,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    recording.transcriptionStatus == 'completed'
                        ? '文字起こし完了'
                        : recording.transcriptionStatus == 'processing'
                            ? '文字起こし中...'
                            : '文字起こし失敗',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: recording.transcriptionStatus == 'processing'
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: recording.transcriptionStatus == 'completed'
                          ? Colors.green
                          : recording.transcriptionStatus == 'processing'
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ],
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transcription text
                if (recording.transcriptionStatus == 'processing')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '文字起こし処理中...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '完了すると自動的に表示されます',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (recording.transcription != null && recording.transcription!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Text(
                              '文字起こし結果',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        SelectableText(
                          recording.transcription!,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'テキストを選択してコピーできます',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '文字起こしデータがありません',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                // Recording URL (for debugging)
                if (kDebugMode && recording.recordingUrl.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '録音URL (Debug):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          recording.recordingUrl,
                          style: const TextStyle(fontSize: 10, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
