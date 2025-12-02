import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// Voice Call Service - Manages voice call functionality
/// Handles permissions, call state, and Firestore signaling
class VoiceCallService extends ChangeNotifier {
  static final VoiceCallService _instance = VoiceCallService._internal();
  factory VoiceCallService() => _instance;
  VoiceCallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Call state management
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  String? _currentCallId;
  String? _remoteFriendId;
  String? _remoteFriendName;
  String? _remoteFriendPhotoUrl;
  CallType _callType = CallType.voice;
  CallStatus _callStatus = CallStatus.idle;
  DateTime? _callStartTime;
  StreamSubscription<DocumentSnapshot>? _callSubscription;

  // Getters
  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  String? get currentCallId => _currentCallId;
  String? get remoteFriendId => _remoteFriendId;
  String? get remoteFriendName => _remoteFriendName;
  String? get remoteFriendPhotoUrl => _remoteFriendPhotoUrl;
  CallType get callType => _callType;
  CallStatus get callStatus => _callStatus;
  DateTime? get callStartTime => _callStartTime;

  /// Request necessary permissions for voice call
  Future<PermissionRequestResult> requestCallPermissions() async {
    try {
      if (kDebugMode) {
        debugPrint('🎤 Requesting call permissions...');
      }

      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (kDebugMode) {
        debugPrint('🎤 Microphone permission: $micStatus');
      }

      if (micStatus.isDenied || micStatus.isPermanentlyDenied) {
        return PermissionRequestResult(
          granted: false,
          message: 'マイクの権限が必要です',
          shouldOpenSettings: micStatus.isPermanentlyDenied,
        );
      }

      // Check if we need to request Bluetooth permission (Android 12+)
      if (await Permission.bluetooth.isRestricted == false) {
        final bluetoothStatus = await Permission.bluetooth.request();
        if (kDebugMode) {
          debugPrint('📶 Bluetooth permission: $bluetoothStatus');
        }
      }

      return PermissionRequestResult(
        granted: true,
        message: '権限が許可されました',
        shouldOpenSettings: false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Permission request error: $e');
      }
      return PermissionRequestResult(
        granted: false,
        message: '権限リクエストエラー: $e',
        shouldOpenSettings: false,
      );
    }
  }

  /// Check if call permissions are granted
  Future<bool> checkCallPermissions() async {
    final micStatus = await Permission.microphone.status;
    return micStatus.isGranted;
  }

  /// Initiate outgoing voice call
  Future<CallInitiationResult> initiateCall({
    required String friendId,
    required String friendName,
    String? friendPhotoUrl,
    CallType callType = CallType.voice,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return CallInitiationResult(
          success: false,
          message: 'ユーザーが認証されていません',
        );
      }

      // Check if already in a call
      if (_isInCall) {
        return CallInitiationResult(
          success: false,
          message: '通話中です',
        );
      }

      // Check permissions
      final hasPermissions = await checkCallPermissions();
      if (!hasPermissions) {
        return CallInitiationResult(
          success: false,
          message: '通話権限が必要です',
          needsPermission: true,
        );
      }

      if (kDebugMode) {
        debugPrint('📞 Initiating call to: $friendName');
      }

      // Create call document in Firestore
      final callDoc = _firestore.collection('calls').doc();
      _currentCallId = callDoc.id;

      final callData = {
        'callId': _currentCallId,
        'callerId': currentUser.uid,
        'callerName': currentUser.displayName ?? 'Unknown',
        'callerPhotoUrl': currentUser.photoURL,
        'receiverId': friendId,
        'receiverName': friendName,
        'receiverPhotoUrl': friendPhotoUrl,
        'callType': callType.toString(),
        'status': CallStatus.ringing.toString(),
        'createdAt': FieldValue.serverTimestamp(),
        'answeredAt': null,
        'endedAt': null,
      };

      await callDoc.set(callData);

      // Update local state
      _isInCall = true;
      _remoteFriendId = friendId;
      _remoteFriendName = friendName;
      _remoteFriendPhotoUrl = friendPhotoUrl;
      _callType = callType;
      _callStatus = CallStatus.ringing;
      notifyListeners();

      // Listen to call status changes
      _listenToCallStatus(_currentCallId!);

      return CallInitiationResult(
        success: true,
        message: '通話を開始しています...',
        callId: _currentCallId,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Call initiation error: $e');
      }
      return CallInitiationResult(
        success: false,
        message: '通話開始エラー: $e',
      );
    }
  }

  /// Listen to call status changes
  void _listenToCallStatus(String callId) {
    _callSubscription?.cancel();
    _callSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        if (kDebugMode) {
          debugPrint('⚠️ Call document deleted');
        }
        endCall();
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      final statusString = data['status'] as String?;
      if (statusString == null) return;

      final newStatus = CallStatus.values.firstWhere(
        (e) => e.toString() == statusString,
        orElse: () => CallStatus.idle,
      );

      if (_callStatus != newStatus) {
        _callStatus = newStatus;

        if (newStatus == CallStatus.active) {
          _callStartTime = DateTime.now();
          if (kDebugMode) {
            debugPrint('📞 Call connected!');
          }
        } else if (newStatus == CallStatus.ended || newStatus == CallStatus.rejected) {
          if (kDebugMode) {
            debugPrint('📞 Call ended or rejected');
          }
          endCall();
        }

        notifyListeners();
      }
    });
  }

  /// Answer incoming call
  Future<bool> answerCall(String callId) async {
    try {
      if (kDebugMode) {
        debugPrint('📞 Answering call: $callId');
      }

      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.active.toString(),
        'answeredAt': FieldValue.serverTimestamp(),
      });

      _currentCallId = callId;
      _isInCall = true;
      _callStatus = CallStatus.active;
      _callStartTime = DateTime.now();
      notifyListeners();

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Answer call error: $e');
      }
      return false;
    }
  }

  /// Reject incoming call
  Future<void> rejectCall(String callId) async {
    try {
      if (kDebugMode) {
        debugPrint('❌ Rejecting call: $callId');
      }

      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.rejected.toString(),
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Reject call error: $e');
      }
    }
  }

  /// End current call
  Future<void> endCall() async {
    try {
      if (_currentCallId != null) {
        await _firestore.collection('calls').doc(_currentCallId).update({
          'status': CallStatus.ended.toString(),
          'endedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ End call error: $e');
      }
    } finally {
      _cleanup();
    }
  }

  /// Toggle mute status
  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
    if (kDebugMode) {
      debugPrint('🔇 Mute toggled: $_isMuted');
    }
  }

  /// Toggle speaker status
  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    notifyListeners();
    if (kDebugMode) {
      debugPrint('🔊 Speaker toggled: $_isSpeakerOn');
    }
  }

  /// Cleanup call state
  void _cleanup() {
    _callSubscription?.cancel();
    _callSubscription = null;
    _isInCall = false;
    _isMuted = false;
    _isSpeakerOn = false;
    _currentCallId = null;
    _remoteFriendId = null;
    _remoteFriendName = null;
    _remoteFriendPhotoUrl = null;
    _callStatus = CallStatus.idle;
    _callStartTime = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }
}

// Enums
enum CallType { voice, video }

enum CallStatus {
  idle,
  ringing,
  active,
  ended,
  rejected,
}

// Result classes
class PermissionRequestResult {
  final bool granted;
  final String message;
  final bool shouldOpenSettings;

  PermissionRequestResult({
    required this.granted,
    required this.message,
    required this.shouldOpenSettings,
  });
}

class CallInitiationResult {
  final bool success;
  final String message;
  final String? callId;
  final bool needsPermission;

  CallInitiationResult({
    required this.success,
    required this.message,
    this.callId,
    this.needsPermission = false,
  });
}
