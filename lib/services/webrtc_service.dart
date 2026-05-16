import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  
  void toggleAudio(bool muted) {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !muted;
    });
  }
  
  void toggleVideo(bool enabled) {
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = enabled;
    });
  }
  
  void toggleSpeaker(bool on) {
    // Platform-specific speaker toggle; stub for now
  }
  
  // ACTION REQUIRED:
  // WebRTC needs signaling server. For free tier, use Firebase Realtime Database
  // or Firestore as a signaling server (though not ideal for production)
  // You can also use WebSockets with a free tier like Heroku or Render
  
  Future<void> initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }
  
  Future<void> startLocalStream() async {
    Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      },
    };
    
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = _localStream;
  }
  
  Future<void> createOffer(String roomId) async {
    await startLocalStream();
    
    _peerConnection = await createPeerConnection({'iceServers': AppConfig.turnServers});
    
    // Add local stream
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });
    
    // Listen for remote stream
    _peerConnection?.onTrack = (event) {
      _remoteStream = event.streams[0];
      _remoteRenderer.srcObject = _remoteStream;
    };
    
    // Create offer
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    // Send offer to Firestore signaling
    await FirebaseFirestore.instance
        .collection('calls')
        .doc(roomId)
        .set({
      'offer': offer.toMap(),
      'callerId': FirebaseAuth.instance.currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
  
  Future<void> answerCall(String roomId) async {
    await startLocalStream();
    
    DocumentSnapshot callDoc = await FirebaseFirestore.instance
        .collection('calls')
        .doc(roomId)
        .get();
    
    if (callDoc.exists) {
      Map<String, dynamic> data = callDoc.data() as Map<String, dynamic>;
      
      _peerConnection = await createPeerConnection({'iceServers': AppConfig.turnServers});
      
      // Add local stream
      _localStream?.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });
      
      // Handle remote stream
      _peerConnection?.onTrack = (event) {
        _remoteStream = event.streams[0];
        _remoteRenderer.srcObject = _remoteStream;
      };
      
      // Set remote description
      RTCSessionDescription offer = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
      await _peerConnection!.setRemoteDescription(offer);
      
      // Create answer
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      // Send answer back
      await callDoc.reference.update({
        'answer': answer.toMap(),
      });
    }
  }
  
  void hangUp() {
    _peerConnection?.close();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    _peerConnection = null;
  }
  
  // Icebreakers for calls
  List<String> icebreakers = [
    "If you could travel anywhere right now, where would you go?",
    "What's the best book or movie you've experienced recently?",
    "What's something that made you smile today?",
    "What's a hidden talent you have?",
    "What's your favorite way to spend a weekend?",
    "What's a small thing that made your day better this week?",
    "What's something you're passionate about?",
    "What's the best advice you've ever received?",
    "What's a goal you're working towards?",
    "What's your comfort food?",
  ];
  
  String getRandomIcebreaker() {
    return icebreakers[DateTime.now().millisecondsSinceEpoch % icebreakers.length];
  }
}