import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../services/webrtc_service.dart';
import '../../widgets/icebreaker_button.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomId;
  final String otherUserId;
  final String otherUserName;
  
  const VideoCallScreen({
    super.key,
    required this.roomId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  bool _isAudioMuted = false;
  bool _isVideoEnabled = true;
  bool _isOnSpeaker = true;

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  Future<void> _initCall() async {
    await _webrtcService.initializeRenderers();
    await _webrtcService.startLocalStream();
    
    // Determine if user is caller or receiver
    // For simplicity, assume caller creates offer
    await _webrtcService.createOffer(widget.roomId);
  }

  void _toggleAudio() {
    setState(() {
      _isAudioMuted = !_isAudioMuted;
      _webrtcService.toggleAudio(_isAudioMuted);
    });
  }

  void _toggleVideo() {
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
      _webrtcService.toggleVideo(_isVideoEnabled);
    });
  }

  void _toggleSpeaker() {
    setState(() {
      _isOnSpeaker = !_isOnSpeaker;
      _webrtcService.toggleSpeaker(_isOnSpeaker);
    });
  }

  void _endCall() {
    _webrtcService.hangUp();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple, Colors.purple.shade300],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with user info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _endCall,
                    ),
                    Text(
                      'Calling ${widget.otherUserName}...',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(width: 48), // Spacing
                  ],
                ),
              ),
              
              // Video streams
              Expanded(
                child: Stack(
                  children: [
                    // Remote video (full screen)
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: RTCVideoView(_webrtcService.remoteRenderer),
                    ),
                    
                    // Local video (small overlay)
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: Container(
                        width: 100,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: RTCVideoView(_webrtcService.localRenderer),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Icebreaker button
              IcebreakerButton(
                onTap: () {
                  final icebreaker = _webrtcService.getRandomIcebreaker();
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Conversation Starter'),
                      content: Text(icebreaker),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              // Call controls
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ControlButton(
                      icon: _isAudioMuted ? Icons.mic_off : Icons.mic,
                      color: _isAudioMuted ? Colors.red : Colors.white,
                      onPressed: _toggleAudio,
                    ),
                    _ControlButton(
                      icon: Icons.call_end,
                      color: Colors.red,
                      size: 56,
                      onPressed: _endCall,
                    ),
                    _ControlButton(
                      icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                      color: _isVideoEnabled ? Colors.white : Colors.red,
                      onPressed: _toggleVideo,
                    ),
                    _ControlButton(
                      icon: _isOnSpeaker ? Icons.volume_up : Icons.volume_down,
                      color: Colors.white,
                      onPressed: _toggleSpeaker,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onPressed;
  
  const _ControlButton({
    required this.icon,
    required this.color,
    this.size = 48,
    required this.onPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
      ),
    );
  }
}