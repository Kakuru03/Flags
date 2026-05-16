import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/chat_service.dart';
import '../../widgets/chat_bubble.dart';
import 'video_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String matchId;
  final String otherUserId;
  final String otherUserName;
  
  const ChatScreen({
    super.key,
    required this.matchId,
    required this.otherUserId,
    required this.otherUserName,
  });
  
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }
  
  void _markMessagesAsRead() {
    // Mark all unread messages as read
    _chatService.markMessagesAsRead(widget.matchId, FirebaseAuth.instance.currentUser!.uid);
  }
  
  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    await _chatService.sendMessage(
      widget.matchId,
      widget.otherUserId,
      _messageController.text.trim(),
    );
    
    _messageController.clear();
    _scrollToBottom();
  }
  
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  void _startVideoCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          roomId: widget.matchId,
          otherUserId: widget.otherUserId,
          otherUserName: widget.otherUserName,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              child: Icon(Icons.person),
            ),
            const SizedBox(width: 10),
            Text(widget.otherUserName),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _startVideoCall,
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              // Implement audio call
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showChatOptions();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _chatService.getMessages(widget.matchId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                var messages = snapshot.data!.docs;
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Send a message to start the conversation!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var messageData = messages[index].data() as Map<String, dynamic>;
                    bool isMe = messageData['senderId'] == FirebaseAuth.instance.currentUser!.uid;
                    
                    return ChatBubble(
                      message: messageData['text'],
                      isMe: isMe,
                      timestamp: (messageData['timestamp'] as Timestamp).toDate(),
                      isRead: messageData['readBy']?.contains(FirebaseAuth.instance.currentUser!.uid) ?? false,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () {
                    // Implement file/image sharing
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report, color: Colors.red),
              title: const Text('Report User'),
              onTap: () {
                Navigator.pop(context);
                _reportUser();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Block User'),
              onTap: () {
                Navigator.pop(context);
                _blockUser();
              },
            ),
          ],
        );
      },
    );
  }
  
  void _reportUser() {
    // Implement reporting functionality
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Why are you reporting this user?'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                hint: const Text('Select reason'),
                onChanged: (value) {},
                items: [
                  'Inappropriate behavior',
                  'Harassment',
                  'Fake profile',
                  'Spam',
                  'Other',
                ].map((reason) {
                  return DropdownMenuItem(value: reason, child: Text(reason));
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Submit report
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted. Thank you for helping keep Flags safe!')),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
  
  void _blockUser() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Block User'),
          content: const Text('Are you sure you want to block this user? You will no longer be able to chat or match with them.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                // Implement blocking
                Navigator.pop(context);
                Navigator.pop(context); // Go back to matches screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User has been blocked')),
                );
              },
              child: const Text('Block'),
            ),
          ],
        );
      },
    );
  }
}