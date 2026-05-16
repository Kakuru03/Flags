import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MonitorChatsScreen extends StatefulWidget {
  const MonitorChatsScreen({super.key});

  @override
  _MonitorChatsScreenState createState() => _MonitorChatsScreenState();
}

class _MonitorChatsScreenState extends State<MonitorChatsScreen> {
  String _selectedMatchId = '';
  bool _autoRefresh = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _deleteMessage(String matchId, String messageId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('chats')
                  .doc(matchId)
                  .collection('messages')
                  .doc(messageId)
                  .delete();
              
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message deleted')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left side - List of chats
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search chats...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('matches')
                        .where('bothAgreed', isEqualTo: true)
                        .orderBy('lastInteraction', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final matches = snapshot.data!.docs;
                      
                      if (matches.isEmpty) {
                        return const Center(
                          child: Text('No active chats to monitor'),
                        );
                      }
                      
                      return ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final match = matches[index];
                          final matchData = match.data() as Map<String, dynamic>;
                          
                          return FutureBuilder(
                            future: Future.wait([
                              FirebaseFirestore.instance.collection('users').doc(matchData['user1Id']).get(),
                              FirebaseFirestore.instance.collection('users').doc(matchData['user2Id']).get(),
                            ]),
                            builder: (context, userSnapshots) {
                              if (!userSnapshots.hasData) {
                                return const ListTile(title: Text('Loading...'));
                              }
                              
                              final user1 = userSnapshots.data![0];
                              final user2 = userSnapshots.data![1];
                              final user1Data = user1.data() as Map<String, dynamic>;
                              final user2Data = user2.data() as Map<String, dynamic>;
                              
                              return ListTile(
                                selected: _selectedMatchId == match.id,
                                selectedTileColor: Colors.deepPurple.shade50,
                                leading: CircleAvatar(
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(
                                  '${user1Data['displayName'] ?? 'User'} & ${user2Data['displayName'] ?? 'User'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  matchData['lastMessage'] ?? 'No messages yet',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  _formatTime(matchData['lastInteraction'] as Timestamp?),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedMatchId = match.id;
                                  });
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Right side - Chat messages
        Expanded(
          flex: 2,
          child: _selectedMatchId.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Select a chat to monitor',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Chat header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.monitor_heart, color: Colors.deepPurple),
                          const SizedBox(width: 12),
                          Text(
                            'Monitoring Chat: $_selectedMatchId',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Switch(
                            value: _autoRefresh,
                            onChanged: (value) {
                              setState(() {
                                _autoRefresh = value;
                              });
                            },
                          ),
                          const Text('Auto-refresh'),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () {
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Messages
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _autoRefresh
                            ? FirebaseFirestore.instance
                                .collection('chats')
                                .doc(_selectedMatchId)
                                .collection('messages')
                                .orderBy('timestamp', descending: false)
                                .snapshots()
                            : FirebaseFirestore.instance
                                .collection('chats')
                                .doc(_selectedMatchId)
                                .collection('messages')
                                .orderBy('timestamp', descending: false)
                                .snapshots()
                                .take(1),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }
                          
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          final messages = snapshot.data!.docs;
                          
                          if (messages.isEmpty) {
                            return const Center(
                              child: Text('No messages in this chat yet'),
                            );
                          }
                          
                          // Auto-scroll to bottom
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              _scrollController.animateTo(
                                _scrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          });
                          
                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final messageData = message.data() as Map<String, dynamic>;
                              
                              return FutureBuilder(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(messageData['senderId'])
                                    .get(),
                                builder: (context, userSnapshot) {
                                  final senderName = userSnapshot.hasData
                                      ? (userSnapshot.data!.data() as Map<String, dynamic>)['displayName'] ?? 'Unknown'
                                      : 'Loading...';
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              senderName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: Colors.deepPurple,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatTime(messageData['timestamp'] as Timestamp?),
                                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                                            ),
                                            const Spacer(),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 16),
                                              onPressed: () => _deleteMessage(_selectedMatchId, message.id),
                                              tooltip: 'Delete message',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(messageData['text']),
                                              if (messageData['mediaUrl'] != null)
                                                Container(
                                                  margin: const EdgeInsets.only(top: 8),
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      _showMediaPreview(messageData['mediaUrl']);
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey.shade200,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.attach_file, size: 16),
                                                          SizedBox(width: 4),
                                                          Text('View Media'),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
  
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
  
  void _showMediaPreview(String? url) {
    if (url == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(url),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}