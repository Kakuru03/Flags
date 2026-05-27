import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../user/chat_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  Map<String, Map<String, dynamic>> _matchesCache = {};
  bool _isLoadingMatches = false;

  @override
  void initState() {
    super.initState();
    if (_currentUserId != null) {
      _loadMatchesOnce();
    }
  }

  /// Load all matches involving current user once (no stream, just a one‑time fetch)
  Future<void> _loadMatchesOnce() async {
    if (_isLoadingMatches) return;
    setState(() => _isLoadingMatches = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final q1 = await firestore
          .collection('matches')
          .where('user1Id', isEqualTo: _currentUserId)
          .get();
      final q2 = await firestore
          .collection('matches')
          .where('user2Id', isEqualTo: _currentUserId)
          .get();

      final allDocs = [...q1.docs, ...q2.docs];
      final cache = <String, Map<String, dynamic>>{};
      for (var doc in allDocs) {
        final data = doc.data();
        final otherId = data['user1Id'] == _currentUserId
            ? data['user2Id']
            : data['user1Id'];
        cache[otherId] = {
          'matchId': doc.id,
          'bothAgreed': data['bothAgreed'] == true,
        };
      }
      if (mounted) {
        setState(() {
          _matchesCache = cache;
          _isLoadingMatches = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading matches: $e');
      if (mounted) setState(() => _isLoadingMatches = false);
    }
  }

  /// Send a like (match request)
  Future<void> _sendMatchRequest(String otherUserId) async {
    if (_currentUserId == null) return;
    try {
      final firestore = FirebaseFirestore.instance;
      final matchRef = firestore.collection('matches').doc();
      await matchRef.set({
        'user1Id': _currentUserId,
        'user2Id': otherUserId,
        'user1Agreed': true,
        'user2Agreed': false,
        'bothAgreed': false,
        'matchedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      _matchesCache[otherUserId] = {
        'matchId': matchRef.id,
        'bothAgreed': false,
      };
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Like sent!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openChat(String matchId, String otherUserId, String otherUserName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          matchId: matchId,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Discover People'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('matches')
                  .where('user1Id', isEqualTo: _currentUserId)
                  .where('bothAgreed', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
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
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter out current user client‑side
          final users = snapshot.data!.docs.where((doc) => doc.id != _currentUserId).toList();

          if (users.isEmpty) {
            return const Center(child: Text('No other users found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final doc = users[index];
              final data = doc.data() as Map<String, dynamic>;
              final otherId = doc.id;
              final user = UserModel.fromMap(otherId, data);

              final matchInfo = _matchesCache[otherId];
              final isMatched = matchInfo?['bothAgreed'] == true;
              final matchId = matchInfo?['matchId'] as String?;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8),
                  ],
                ),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: user.photos.isNotEmpty
                        ? Image.network(user.photos.first, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultAvatar())
                        : _defaultAvatar(),
                  ),
                  title: Text(user.displayName ?? 'Anonymous'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user.bio != null && user.bio!.isNotEmpty)
                        Text(user.bio!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      if (user.interests.isNotEmpty)
                        Text(user.interests.take(3).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade300)),
                    ],
                  ),
                  trailing: isMatched
                      ? ElevatedButton.icon(
                    onPressed: () => _openChat(matchId!, otherId, user.displayName ?? 'User'),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Chat'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, shape: StadiumBorder()),
                  )
                      : matchId != null
                      ? OutlinedButton(
                    onPressed: null,
                    child: const Text('Request sent'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey, side: BorderSide(color: Colors.grey.shade400), shape: StadiumBorder()),
                  )
                      : OutlinedButton.icon(
                    onPressed: _isLoadingMatches ? null : () => _sendMatchRequest(otherId),
                    icon: const Icon(Icons.favorite_border, size: 18),
                    label: const Text('Like'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.deepPurple, side: const BorderSide(color: Colors.deepPurple), shape: StadiumBorder()),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _defaultAvatar() => Container(width: 64, height: 64, color: Colors.grey.shade200, child: const Icon(Icons.person, size: 32, color: Colors.grey));
}