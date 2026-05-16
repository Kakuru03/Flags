import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/match_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../widgets/profile_card.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  _SwipeScreenState createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final MatchService _matchService = MatchService();
  List<UserModel> _profiles = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = await _getCurrentUser(authService.currentUser!.uid);
    
    if (currentUser != null) {
      // Get manual swipe profiles
      _profiles = await _matchService.getPotentialMatches(
        authService.currentUser!.uid,
        currentUser,
      );
      
      // Also get auto-matched profiles
      final autoMatches = await _matchService.getAutoMatches(
        authService.currentUser!.uid,
        currentUser,
      );
      
      _profiles.addAll(autoMatches);
      _profiles.shuffle(); // Mix manual and auto matches
    }
    
    setState(() => _isLoading = false);
  }

  Future<UserModel?> _getCurrentUser(String uid) async {
    // Fetch current user from Firestore
    // Implementation depends on your data structure
    return null;
  }

  void _swipeLeft() {
    if (_currentIndex < _profiles.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _showNoMoreProfiles();
    }
  }

  void _swipeRight() async {
    if (_currentIndex < _profiles.length) {
      final likedUser = _profiles[_currentIndex];
      
      // Check if it's a match
      final bool isMatch = await _matchService.checkAndCreateMatch(
        FirebaseAuth.instance.currentUser!.uid,
        likedUser.uid,
      );
      
      if (isMatch) {
        _showMatchDialog(likedUser);
      }
      
      if (_currentIndex < _profiles.length - 1) {
        setState(() {
          _currentIndex++;
        });
      } else {
        _showNoMoreProfiles();
      }
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
            onPressed: () {
              Navigator.pop(context);
              // Navigate to chat
            },
            child: const Text('Keep Swiping'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to chat screen
            },
            child: const Text('Send Message'),
          ),
        ],
      ),
    );
  }

  void _showNoMoreProfiles() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No More Profiles'),
        content: const Text('Check back later for new matches!'),
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
    
    if (_profiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'No more profiles to show',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 10),
            Text(
              'Check back later for new matches!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return Stack(
      children: [
        for (int i = _profiles.length - 1; i >= _currentIndex; i--)
          ProfileCard(
            user: _profiles[i],
            onSwipeLeft: _swipeLeft,
            onSwipeRight: _swipeRight,
          ),
      ],
    );
  }
}