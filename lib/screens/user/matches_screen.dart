import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../widgets/match_card.dart';
import '../user/chat_screen.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  Stream<List<QueryDocumentSnapshot>> _matchesStream(String currentUserId) {
    final firestore = FirebaseFirestore.instance;
    final asUser1 = firestore
        .collection('matches')
        .where('user1Id', isEqualTo: currentUserId)
        .where('bothAgreed', isEqualTo: true)
        .snapshots();
    final asUser2 = firestore
        .collection('matches')
        .where('user2Id', isEqualTo: currentUserId)
        .where('bothAgreed', isEqualTo: true)
        .snapshots();
    return asUser1.asyncExpand((snap1) {
      return asUser2.map((snap2) {
        final seen = <String>{};
        final merged = <QueryDocumentSnapshot>[];
        for (final doc in [...snap1.docs, ...snap2.docs]) {
          if (seen.add(doc.id)) merged.add(doc);
        }
        return merged;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Your Matches',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _matchesStream(currentUserId),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count match${count == 1 ? '' : 'es'}',
                    style: TextStyle(
                      color: Colors.deepPurple.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: _matchesStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 60, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load matches',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            );
          }

          final matches = snapshot.data!;

          if (matches.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_border_rounded,
                        size: 56,
                        color: Colors.deepPurple.shade200,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No matches yet',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Keep discovering people — your first match is just a swipe away!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              final matchData = match.data() as Map<String, dynamic>;
              final otherUserId = matchData['user1Id'] == currentUserId
                  ? matchData['user2Id']
                  : matchData['user1Id'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return _MatchSkeleton();
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  if (userData == null) return const SizedBox.shrink();

                  final user = UserModel.fromMap(otherUserId, userData);

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(match.id)
                        .collection('messages')
                        .where('receiverId', isEqualTo: currentUserId)
                        .where('isRead', isEqualTo: false)
                        .snapshots(),
                    builder: (context, msgSnapshot) {
                      final unreadCount =
                          msgSnapshot.hasData ? msgSnapshot.data!.docs.length : 0;
                      return MatchCard(
                        user: user,
                        unreadCount: unreadCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              matchId: match.id,
                              otherUserId: otherUserId,
                              otherUserName: user.displayName ?? 'User',
                            ),
                          ),
                        ),
                      );
                    },
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

class _MatchSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 14,
                    width: 120,
                    color: Colors.grey.shade200),
                const SizedBox(height: 8),
                Container(
                    height: 10,
                    width: 180,
                    color: Colors.grey.shade100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
