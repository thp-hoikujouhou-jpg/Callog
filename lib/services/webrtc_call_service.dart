import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

class WebRTCCallService {
  // Singleton pattern
  static final WebRTCCallService _instance = WebRTCCallService._internal();
  factory WebRTCCallService() => _instance;
  WebRTCCallService._internal();

  // WebRTC peer connection
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  // WebSocket for signaling
  WebSocketChannel? _signalChannel;
  String? _currentUserId;
  String? _targetUserId;
  
  // Callbacks
  Function(MediaStream)? onRemoteStream;
  Function(String)? onCallEnded;
  Function(Map<String, dynamic>)? onIncomingCall;
  Function(bool)? onConnectionStateChanged;
  
  // Configuration
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ]
      }
    ]
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  final Map<String, dynamic> _mediaConstraints = {
    'audio': true,
    'video': false, // Audio only for voice calls
  };

  // Signaling server URL
  static const String signalingServerUrl = 'wss://8765-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai';

  // Initialize WebRTC service
  Future<bool> initialize(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint('🔌 Connecting to signaling server: $signalingServerUrl');
      }
      
      _currentUserId = userId;
      
      // Connect to signaling server with timeout
      try {
        _signalChannel = WebSocketChannel.connect(
          Uri.parse(signalingServerUrl),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ WebSocket connection failed: $e');
        }
        return false;
      }

      // Listen for signaling messages
      _signalChannel!.stream.listen((message) {
        if (kDebugMode) {
          debugPrint('📨 Received signaling message: $message');
        }
        try {
          _handleSignalingMessage(jsonDecode(message));
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ Error parsing signaling message: $e');
          }
        }
      }, onError: (error) {
        if (kDebugMode) {
          debugPrint('❌ WebSocket error: $error');
        }
        onCallEnded?.call('Connection error');
      }, onDone: () {
        if (kDebugMode) {
          debugPrint('🔌 WebSocket connection closed');
        }
        onCallEnded?.call('Connection closed');
      });

      // Register user with signaling server
      _sendSignalingMessage({
        'type': 'register',
        'userId': userId,
      });

      // Wait a bit for connection to establish
      await Future.delayed(const Duration(milliseconds: 500));

      if (kDebugMode) {
        debugPrint('✅ WebRTC service initialized for user: $userId');
      }
      
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error initializing WebRTC: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      return false;
    }
  }

  // Make a call
  Future<bool> makeCall(String targetUserId) async {
    try {
      if (kDebugMode) {
        debugPrint('📞 Starting call to $targetUserId');
      }
      
      _targetUserId = targetUserId;
      
      // Get local media stream
      if (kDebugMode) {
        debugPrint('🎤 Requesting microphone access...');
      }
      
      try {
        _localStream = await navigator.mediaDevices.getUserMedia(_mediaConstraints);
        if (kDebugMode) {
          debugPrint('✅ Microphone access granted');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Failed to get microphone access: $e');
        }
        return false;
      }

      // Create peer connection
      if (kDebugMode) {
        debugPrint('🔗 Creating peer connection...');
      }
      
      _peerConnection = await createPeerConnection(_configuration, _constraints);

      // Add local stream to peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Listen for remote stream
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (kDebugMode) {
          debugPrint('📡 Received remote track');
        }
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          if (onRemoteStream != null) {
            if (kDebugMode) {
              debugPrint('✅ Calling onRemoteStream callback');
            }
            onRemoteStream!(_remoteStream!);
          }
          if (onConnectionStateChanged != null) {
            onConnectionStateChanged!(true);
          }
        }
      };

      // Listen for ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (kDebugMode) {
          debugPrint('🧊 Sending ICE candidate');
        }
        _sendSignalingMessage({
          'type': 'ice-candidate',
          'candidate': candidate.toMap(),
          'targetUserId': targetUserId,
        });
      };

      // Listen for connection state changes
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        if (kDebugMode) {
          debugPrint('🔌 Connection state: $state');
        }
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          if (onConnectionStateChanged != null) {
            onConnectionStateChanged!(false);
          }
        }
      };

      // Create offer
      if (kDebugMode) {
        debugPrint('📝 Creating offer...');
      }
      
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Send offer through signaling server
      if (kDebugMode) {
        debugPrint('📤 Sending offer to signaling server...');
      }
      
      _sendSignalingMessage({
        'type': 'offer',
        'offer': offer.toMap(),
        'targetUserId': targetUserId,
        'callerId': _currentUserId,
      });

      if (kDebugMode) {
        debugPrint('✅ Call initiated successfully to $targetUserId');
      }
      
      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error making call: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      return false;
    }
  }

  // Answer incoming call
  Future<bool> answerCall(Map<String, dynamic> offer, String callerId) async {
    try {
      _targetUserId = callerId;
      
      // Get local media stream
      _localStream = await navigator.mediaDevices.getUserMedia(_mediaConstraints);

      // Create peer connection
      _peerConnection = await createPeerConnection(_configuration, _constraints);

      // Add local stream to peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Listen for remote stream
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          if (onRemoteStream != null) {
            onRemoteStream!(_remoteStream!);
          }
          if (onConnectionStateChanged != null) {
            onConnectionStateChanged!(true);
          }
        }
      };

      // Listen for ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _sendSignalingMessage({
          'type': 'ice-candidate',
          'candidate': candidate.toMap(),
          'targetUserId': callerId,
        });
      };

      // Set remote description
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );

      // Create answer
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer through signaling server
      _sendSignalingMessage({
        'type': 'answer',
        'answer': answer.toMap(),
        'targetUserId': callerId,
      });

      if (kDebugMode) {
        debugPrint('Call answered from $callerId');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error answering call: $e');
      }
      return false;
    }
  }

  // End call
  Future<void> endCall() async {
    try {
      // Close peer connection
      await _peerConnection?.close();
      _peerConnection = null;

      // Stop local stream
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      _localStream?.dispose();
      _localStream = null;

      // Notify about call end
      if (_targetUserId != null) {
        _sendSignalingMessage({
          'type': 'end-call',
          'targetUserId': _targetUserId,
        });
      }

      if (onCallEnded != null) {
        onCallEnded!('Call ended');
      }

      _remoteStream = null;
      _targetUserId = null;

      if (kDebugMode) {
        debugPrint('Call ended');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error ending call: $e');
      }
    }
  }

  // Handle signaling messages
  void _handleSignalingMessage(Map<String, dynamic> message) {
    try {
      final type = message['type'];

      switch (type) {
        case 'registered':
          if (kDebugMode) {
            debugPrint('Successfully registered with signaling server');
          }
          break;

        case 'offer':
          // Incoming call offer
          if (onIncomingCall != null) {
            onIncomingCall!(message);
          }
          break;

        case 'answer':
          // Call answer received
          _handleAnswer(message['answer']);
          break;

        case 'ice-candidate':
          // ICE candidate received
          _handleIceCandidate(message['candidate']);
          break;

        case 'end-call':
          // Call ended by remote peer
          endCall();
          break;

        case 'offer-sent':
          if (kDebugMode) {
            debugPrint('Offer sent successfully: ${message['success']}');
          }
          break;

        default:
          if (kDebugMode) {
            debugPrint('Unknown signaling message type: $type');
          }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error handling signaling message: $e');
      }
    }
  }

  // Handle answer
  Future<void> _handleAnswer(Map<String, dynamic> answer) async {
    try {
      await _peerConnection?.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
      if (kDebugMode) {
        debugPrint('Remote description set');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error handling answer: $e');
      }
    }
  }

  // Handle ICE candidate
  Future<void> _handleIceCandidate(Map<String, dynamic> candidateMap) async {
    try {
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );
      await _peerConnection?.addCandidate(candidate);
      if (kDebugMode) {
        debugPrint('ICE candidate added');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error handling ICE candidate: $e');
      }
    }
  }

  // Send signaling message
  void _sendSignalingMessage(Map<String, dynamic> message) {
    try {
      _signalChannel?.sink.add(jsonEncode(message));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error sending signaling message: $e');
      }
    }
  }

  // Get local stream
  MediaStream? get localStream => _localStream;

  // Get remote stream
  MediaStream? get remoteStream => _remoteStream;

  // Dispose resources
  void dispose() {
    endCall();
    _signalChannel?.sink.close();
  }
}
