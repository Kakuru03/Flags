import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../user/chat_screen.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Matches'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('matches')
            .where('bothAgreed', isEqualTo: true)
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final matches = snapshot.data!.docs.where((doc) {
            final data = doc.data();
            return data['user1Id'] == currentUserId || data['user2Id'] == currentUserId;
          }).toList();
          
          if (matches.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'No matches yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Keep swiping to find your perfect match!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          
          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              final matchData = match.data();
              
              final otherUserId = matchData['user1Id'] == currentUserId
                  ? matchData['user2Id']
                  : matchData['user1Id'];
              
              return FutureBuilder(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const Card(child: Center(child: CircularProgressIndicator()));
                  }
                  
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final user = UserModel.fromMap(otherUserId, userData);
                  
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            matchId: match.id,
                            otherUserId: otherUserId,
                            otherUserName: user.displayName ?? 'User',
                          ),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                              child: user.photos.isNotEmpty
                                  ? Image.network(
                                      user.photos.first,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.person, size: 80),
                                    )
                                  : const Icon(Icons.person, size: 80),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    user.displayName ?? 'User',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  StreamBuilder(
                                    stream: FirebaseFirestore.instance
                                        .collection('chats')
                                        .doc(match.id)
                                        .collection('messages')
.where('receiverId', isEqualTo: currentUserId)
                                        .orderBy('timestamp', descending: true)
                                        .limit(20)
                                        .snapshots(),
                                    builder: (context, msgSnapshot) {
                                      int unreadCount = msgSnapshot.hasData
                                          ? msgSnapshot.data!.docs.length
                                          : 0;
                                      
                                      if (unreadCount > 0) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '$unreadCount new',
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                        );
                                      }
                                      return Container();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}