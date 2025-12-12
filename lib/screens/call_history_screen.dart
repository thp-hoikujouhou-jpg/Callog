import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';
import '../services/gemini_summary_service.dart';
import '../models/call_recording.dart';
import '../theme/modern_ui_theme.dart';
import '../models/sticky_note.dart';
import 'sticky_note_editor_screen.dart';

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
  
  // Cache for user display names
  final Map<String, String> _userDisplayNames = {};
  
  // Gemini summary service
  final GeminiSummaryService _summaryService = GeminiSummaryService();
  
  // Track which recordings are being summarized
  final Map<String, bool> _isSummarizing = {};
  
  // Cache for summaries
  final Map<String, String> _summaries = {};

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
  
  /// Show edit transcription dialog
  Future<void> _showEditDialog(CallRecording recording) async {
    final localService = Provider.of<LocalizationService>(context, listen: false);
    final controller = TextEditingController(text: recording.transcription ?? '');
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                localService.translate('edit_transcription'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(minWidth: 400, maxHeight: 400),
          child: TextField(
            controller: controller,
            maxLines: null,
            decoration: InputDecoration(
              hintText: localService.translate('enter_text'),
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localService.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(localService.translate('save')),
          ),
        ],
      ),
    );
    
    if (result != null && result != recording.transcription) {
      // Update transcription in Firestore
      try {
        await _firestore.collection('call_recordings').doc(recording.id).update({
          'transcription': result,
          'transcriptionEditedAt': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localService.translate('transcription_updated')),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${localService.translate('error')}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  /// Generate AI summary for transcription
  Future<void> _generateSummary(CallRecording recording) async {
    final localService = Provider.of<LocalizationService>(context, listen: false);
    
    if (recording.transcription == null || recording.transcription!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localService.translate('no_transcription_to_summarize')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _isSummarizing[recording.id] = true;
    });
    
    // Show processing message with retry hint
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🤖 AI要約を生成中... (最大5回まで自動リトライ)'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    try {
      final summary = await _summaryService.summarizeText(recording.transcription!);
      
      if (summary != null && summary.isNotEmpty) {
        // Check if summary is an error message
        if (summary.startsWith('ERROR')) {
          setState(() {
            _isSummarizing[recording.id] = false;
          });
          
          // Extract error message after colon
          final errorMessage = summary.contains(':') 
            ? summary.split(':')[1].trim() 
            : summary;
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: summary.contains('429') ? Colors.orange : Colors.red,
                duration: const Duration(seconds: 5),
                action: summary.contains('429') 
                  ? SnackBarAction(
                      label: '詳細',
                      textColor: Colors.white,
                      onPressed: () {
                        _showRateLimitDialog();
                      },
                    )
                  : null,
              ),
            );
          }
          return;
        }
        
        // Normal summary
        setState(() {
          _summaries[recording.id] = summary;
          _isSummarizing[recording.id] = false;
        });
        
        if (mounted) {
          _showSummaryDialog(summary, recording);
        }
      } else {
        setState(() {
          _isSummarizing[recording.id] = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localService.translate('summary_failed')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSummarizing[recording.id] = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localService.translate('error')}: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
  
  /// Show summary dialog with replace option
  void _showSummaryDialog(String summary, CallRecording recording) {
    final localService = Provider.of<LocalizationService>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                localService.translate('ai_summary'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 400, minWidth: 300),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  summary,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          localService.translate('replace_transcription_hint'),
                          style: const TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localService.translate('close')),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _replaceTranscriptionWithSummary(recording, summary);
            },
            icon: const Icon(Icons.swap_horiz),
            label: Text(localService.translate('replace_with_summary')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Replace transcription text with AI summary
  Future<void> _replaceTranscriptionWithSummary(CallRecording recording, String summary) async {
    final localService = Provider.of<LocalizationService>(context, listen: false);
    
    try {
      await _firestore.collection('call_recordings').doc(recording.id).update({
        'transcription': summary,
        'transcriptionEditedAt': FieldValue.serverTimestamp(),
        'replacedWithSummary': true,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localService.translate('transcription_replaced')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localService.translate('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Show rate limit information dialog
  void _showRateLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'API利用制限について',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Gemini APIの利用制限に達しました。',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 16),
              Text('🔄 自動リトライ機能 (強化版):', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• 最大5回まで自動的にリトライします (成功率向上)'),
              Text('• 待機時間: 2秒 → 4秒 → 8秒 → 16秒 (指数バックオフ)'),
              Text('• 合計最大40秒まで自動リトライを継続'),
              Text('• リトライ後も失敗した場合はこのエラーが表示されます'),
              SizedBox(height: 16),
              Text('📊 対処方法:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('1. 数分待ってから再度お試しください'),
              Text('2. 連続してリクエストを送信しないでください'),
              Text('3. Google AI Studioでクォータを確認してください'),
              Text('4. 無料プランの制限: 1分あたり15リクエスト'),
              SizedBox(height: 16),
              Text('🔗 詳細情報:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Google AI Studio: aistudio.google.com'),
              Text('• クォータ確認: API設定 > クォータ'),
              Text('• Googleの推奨対策: Exponential Backoff実装済み'),
              SizedBox(height: 16),
              Text(
                '💡 ヒント: トラフィックの平滑化が重要です。頻繁に429エラーが発生する場合は、リクエストの間隔を空けるか、有料プランへのアップグレードをご検討ください。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
  
  /// Get display name for a user ID
  Future<String> _getDisplayName(String userId) async {
    // Check cache first
    if (_userDisplayNames.containsKey(userId)) {
      return _userDisplayNames[userId]!;
    }
    
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final displayName = data?['username'] ?? data?['name'] ?? userId;
        _userDisplayNames[userId] = displayName;
        return displayName;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CallHistory] Error fetching display name: $e');
      }
    }
    
    // Fallback to user ID
    return userId;
  }
  
  /// Save transcription as sticky note to calendar
  Future<void> _saveToCalendar(CallRecording recording) async {
    final localService = Provider.of<LocalizationService>(context, listen: false);
    
    // Check if transcription exists
    if (recording.transcription == null || recording.transcription!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localService.translate('no_transcription_data')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      // Get contact name and photo URL
      final contactId = recording.callPartner ?? 'unknown';
      final contactName = await _getDisplayName(contactId);
      
      // Fetch contact photo URL from Firestore
      String? contactPhotoUrl;
      try {
        final userDoc = await _firestore.collection('users').doc(contactId).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          contactPhotoUrl = data?['photoUrl'] as String?;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [CallHistory] Could not fetch photo URL: $e');
        }
      }
      
      // Navigate to sticky note editor with pre-filled data
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StickyNoteEditorScreen(
            selectedDate: recording.timestamp, // Use call date
            contactId: contactId,
            contactName: contactName,
            contactPhotoUrl: contactPhotoUrl, // Fetched from Firestore
            callRecordings: [recording], // Pass recording for auto-import
          ),
        ),
      );
      
      if (kDebugMode) {
        debugPrint('📝 [CallHistory] Navigated to sticky note editor with photo: $contactPhotoUrl');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [CallHistory] Error saving to calendar: $e');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localService.translate('failed_to_save_note')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        .limit(100)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final recordings = snapshot.docs
            .map((doc) => CallRecording.fromMap(doc.data(), doc.id))
            .toList();
        
        // Sort in memory
        recordings.sort((a, b) => b.timestamp.compareTo(a.timestamp));

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
          _error = 'User not logged in';  // Will be shown in UI with localization
          _isLoading = false;
        });
        return;
      }

      if (kDebugMode) {
        debugPrint('📞 [CallHistory] Loading recordings for user: ${currentUser.uid}');
      }

      // Fetch recordings from Firestore (simple query without orderBy to avoid index requirement)
      final snapshot = await _firestore
          .collection('call_recordings')
          .where('userId', isEqualTo: currentUser.uid)
          .limit(100)
          .get();

      if (kDebugMode) {
        debugPrint('📞 [CallHistory] Found ${snapshot.docs.length} recordings');
      }

      final recordings = snapshot.docs
          .map((doc) => CallRecording.fromMap(doc.data(), doc.id))
          .toList();
      
      // Sort in memory instead of using Firestore orderBy (to avoid composite index requirement)
      recordings.sort((a, b) => b.timestamp.compareTo(a.timestamp));

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
        title: Text(
          localService.translate('call_history'),
          style: ModernUITheme.headingMedium.copyWith(color: ModernUITheme.textWhite),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(decoration: BoxDecoration(gradient: ModernUITheme.primaryGradient)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecordings,
            tooltip: localService.translate('reload'),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: ModernUITheme.backgroundGradient),
        child: SafeArea(
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
                          child: Text(localService.translate('retry')),
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
                            Text(
                              localService.translate('no_call_history'),
                              style: const TextStyle(fontSize: 16, color: Colors.grey),
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
        ),
    );
  }

  Widget _buildRecordingCard(CallRecording recording) {
    final localService = Provider.of<LocalizationService>(context, listen: false);
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    final dateStr = dateFormat.format(recording.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ModernUITheme.glassContainer(opacity: 0.15),
      child: ExpansionTile(
        leading: Icon(
          recording.callType == 'video' ? Icons.videocam : Icons.phone,
          color: Colors.blue.shade600,
        ),
        title: FutureBuilder<String>(
          future: _getDisplayName(recording.callPartner ?? ''),
          builder: (context, snapshot) {
            return Text(
              snapshot.data ?? recording.callPartner ?? localService.translate('unknown_contact'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            );
          },
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateStr),
            Text('${localService.translate('call_duration')}: ${recording.formattedDuration}'),
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
                        ? localService.translate('transcription_completed')
                        : recording.transcriptionStatus == 'processing'
                            ? localService.translate('transcription_processing')
                            : localService.translate('transcription_failed'),
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
                        Text(
                          localService.translate('processing_message'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localService.translate('auto_display_message'),
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
                            Expanded(
                              child: Text(
                                localService.translate('transcription_result'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                            // Edit button
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _showEditDialog(recording),
                              tooltip: localService.translate('edit'),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            // AI Summary button
                            if (_isSummarizing[recording.id] == true)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.auto_awesome, size: 18),
                                onPressed: () => _generateSummary(recording),
                                tooltip: localService.translate('ai_summary'),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                color: Colors.purple.shade700,
                              ),
                            const SizedBox(width: 8),
                            // Save to Calendar button (NEW!)
                            IconButton(
                              icon: const Icon(Icons.calendar_month, size: 18),
                              onPressed: () => _saveToCalendar(recording),
                              tooltip: localService.translate('save_to_calendar'),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: Colors.green.shade700,
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
                          localService.translate('copy_instruction'),
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
                    child: Text(
                      localService.translate('no_transcription_data'),
                      style: const TextStyle(color: Colors.grey),
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
