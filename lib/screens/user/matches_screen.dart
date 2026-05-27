import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/match_service.dart';
import '../../models/user_model.dart';
import '../user/chat_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final MatchService _matchService = MatchService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Cache: otherUserId -> { matchId, bothAgreed, otherLikedMe }
  Map<String, Map<String, dynamic>> _matchesCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (_currentUserId != null) {
      _loadMatchesOnce();
      _listenToMatchUpdates();
    }
  }

  /// One‑time load of existing matches (for initial cache)
  Future<void> _loadMatchesOnce() async {
    if (_currentUserId == null) return;
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
          'otherLikedMe': (data['user1Id'] == _currentUserId
              ? data['user2Agreed']
              : data['user1Agreed']) ==
              true,
        };
      }
      if (mounted) {
        setState(() {
          _matchesCache = cache;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading matches: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Listen to real‑time changes in matches involving the current user
  void _listenToMatchUpdates() {
    if (_currentUserId == null) return;
    final firestore = FirebaseFirestore.instance;
    // Listen to both directions
    firestore
        .collection('matches')
        .where('user1Id', isEqualTo: _currentUserId)
        .snapshots()
        .listen(_updateCacheFromSnapshot);
    firestore
        .collection('matches')
        .where('user2Id', isEqualTo: _currentUserId)
        .snapshots()
        .listen(_updateCacheFromSnapshot);
  }

  void _updateCacheFromSnapshot(QuerySnapshot snapshot) {
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final otherId = data['user1Id'] == _currentUserId
          ? data['user2Id']
          : data['user1Id'];
      final bothAgreed = data['bothAgreed'] == true;
      final otherLikedMe = (data['user1Id'] == _currentUserId
          ? data['user2Agreed']
          : data['user1Agreed']) ==
          true;
      setState(() {
        _matchesCache[otherId] = {
          'matchId': doc.id,
          'bothAgreed': bothAgreed,
          'otherLikedMe': otherLikedMe,
        };
      });
    }
  }

  /// Handle like action – uses MatchService to check for mutual match
  Future<void> _sendLike(String otherUserId) async {
    if (_currentUserId == null) return;
    try {
      final isMatch = await _matchService.checkAndCreateMatch(_currentUserId!, otherUserId);
      // After this, the real‑time listener will update the cache automatically.
      if (isMatch && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('It\'s a match! Start chatting now.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Like sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Accept a pending like from someone (create the mutual match)
  Future<void> _acceptLike(String otherUserId, String existingMatchId) async {
    if (_currentUserId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(existingMatchId)
          .update({
        'bothAgreed': true,
        'matchedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match accepted! You can now chat.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept: $e'), backgroundColor: Colors.red),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

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
              final bothAgreed = matchInfo?['bothAgreed'] == true;
              final matchId = matchInfo?['matchId'] as String?;
              final otherLikedMe = matchInfo?['otherLikedMe'] == true;

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
                        ? Image.network(
                      user.photos.first,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultAvatar(),
                    )
                        : _defaultAvatar(),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.displayName ?? 'Anonymous',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (bothAgreed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite, size: 14, color: Colors.green.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Matched',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user.bio != null && user.bio!.isNotEmpty)
                        Text(
                          user.bio!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      if (user.interests.isNotEmpty)
                        Text(
                          user.interests.take(3).join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade300),
                        ),
                    ],
                  ),
                  trailing: _buildActionButton(
                    bothAgreed: bothAgreed,
                    matchId: matchId,
                    otherLikedMe: otherLikedMe,
                    otherId: otherId,
                    userName: user.displayName ?? 'User',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required bool bothAgreed,
    required String? matchId,
    required bool otherLikedMe,
    required String otherId,
    required String userName,
  }) {
    if (bothAgreed && matchId != null) {
      // Mutual match – show Chat button
      return ElevatedButton.icon(
        onPressed: () => _openChat(matchId, otherId, userName),
        icon: const Icon(Icons.chat, size: 18),
        label: const Text('Chat'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          shape: StadiumBorder(),
        ),
      );
    } else if (otherLikedMe && matchId != null) {
      // Someone liked you – show "Accept" button
      return OutlinedButton.icon(
        onPressed: () => _acceptLike(otherId, matchId),
        icon: const Icon(Icons.favorite, size: 18, color: Colors.green),
        label: const Text('Accept'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.green,
          side: const BorderSide(color: Colors.green),
          shape: StadiumBorder(),
        ),
      );
    } else if (matchId != null) {
      // You already liked them, waiting for response
      return OutlinedButton(
        onPressed: null,
        child: const Text('Request sent'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey,
          side: BorderSide(color: Colors.grey.shade400),
          shape: StadiumBorder(),
        ),
      );
    } else {
      // No action yet – show Like button
      return OutlinedButton.icon(
        onPressed: () => _sendLike(otherId),
        icon: const Icon(Icons.favorite_border, size: 18),
        label: const Text('Like'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.deepPurple,
          side: const BorderSide(color: Colors.deepPurple),
          shape: StadiumBorder(),
        ),
      );
    }
  }

  Widget _defaultAvatar() => Container(
    width: 64,
    height: 64,
    color: Colors.grey.shade200,
    child: const Icon(Icons.person, size: 32, color: Colors.grey),
  );
}