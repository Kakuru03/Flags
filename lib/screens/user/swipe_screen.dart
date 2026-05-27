import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/match_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../widgets/profile_card.dart';
import 'chat_screen.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final MatchService _matchService = MatchService();
  final Set<String> _swipedUserIds = {};
  List<UserModel> _currentBatch = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  late String _currentUserId;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _currentUser = await _fetchCurrentUser();
      if (_currentUser == null) throw Exception('User data not found');
      await _loadNextBatch(reset: true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<UserModel?> _fetchCurrentUser() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .get();
    if (doc.exists) {
      return UserModel.fromMap(_currentUserId, doc.data()!);
    }
    return null;
  }

  Future<void> _loadNextBatch({bool reset = false}) async {
    if (_currentUser == null) return;
    try {
      final allMatches = await _matchService.getPotentialMatches(_currentUserId, _currentUser!);
      final filtered = allMatches.where((u) => !_swipedUserIds.contains(u.uid)).toList();

      if (reset) {
        _currentBatch = filtered;
        _currentIndex = 0;
      } else {
        _currentBatch.addAll(filtered);
      }
    } catch (e) {
      if (!reset) rethrow;
      setState(() => _error = e.toString());
    } finally {
      if (reset) setState(() => _isLoading = false);
      setState(() => _isLoadingMore = false);
    }
  }

  void _swipeLeft() async {
    if (_currentIndex >= _currentBatch.length) return;
    final dislikedUser = _currentBatch[_currentIndex];
    _swipedUserIds.add(dislikedUser.uid);
    _advanceToNext();
  }

  void _swipeRight() async {
    if (_currentIndex >= _currentBatch.length) return;
    final likedUser = _currentBatch[_currentIndex];
    _swipedUserIds.add(likedUser.uid);

    final bool isMatch = await _matchService.checkAndCreateMatch(_currentUserId, likedUser.uid);
    if (isMatch && mounted) {
      _showMatchDialog(likedUser);
    }
    _advanceToNext();
  }

  void _advanceToNext() {
    if (_currentIndex < _currentBatch.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      await _loadNextBatch(reset: false);
      if (_currentBatch.isEmpty || _currentIndex >= _currentBatch.length) {
        _showNoMoreProfiles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _showMatchDialog(UserModel matchedUser) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.favorite, color: Colors.red, size: 50),
            SizedBox(height: 10),
            Text('It\'s a Match!'),
          ],
        ),
        content: Text('You and ${matchedUser.displayName} have liked each other!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Swiping'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToChat(matchedUser);
            },
            child: const Text('Send Message'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToChat(UserModel matchedUser) async {
    final matchId = await _getMatchId(matchedUser.uid);
    if (matchId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            matchId: matchId,
            otherUserId: matchedUser.uid,
            otherUserName: matchedUser.displayName ?? 'User',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open chat. Please try again.')),
      );
    }
  }

  Future<String?> _getMatchId(String otherUserId) async {
    final firestore = FirebaseFirestore.instance;
    final q1 = await firestore
        .collection('matches')
        .where('user1Id', isEqualTo: _currentUserId)
        .where('user2Id', isEqualTo: otherUserId)
        .limit(1)
        .get();
    if (q1.docs.isNotEmpty) return q1.docs.first.id;
    final q2 = await firestore
        .collection('matches')
        .where('user1Id', isEqualTo: otherUserId)
        .where('user2Id', isEqualTo: _currentUserId)
        .limit(1)
        .get();
    return q2.docs.isNotEmpty ? q2.docs.first.id : null;
  }

  void _showNoMoreProfiles() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No More Profiles'),
        content: const Text('We\'ll notify you when new people join.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_currentBatch.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'No more profiles to show',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            const Text(
              'Check back later for new matches!',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        for (int i = _currentBatch.length - 1; i >= _currentIndex; i--)
          ProfileCard(
            user: _currentBatch[i],
            onSwipeLeft: _swipeLeft,
            onSwipeRight: _swipeRight,
          ),
        if (_isLoadingMore)
          const Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}