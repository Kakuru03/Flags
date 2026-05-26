import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/match_model.dart';

class MatchService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Automatic matching based on bio and parameters
  Future<List<UserModel>> getAutoMatches(String currentUserId, UserModel currentUser) async {
    try {
      QuerySnapshot usersQuery = await _firestore
          .collection('users')
          .where('isPrivate', isEqualTo: false)
          .where('isFrozen', isEqualTo: false)
          .where('isBanned', isEqualTo: false)
          .limit(50)
          .get();
      
      List<UserModel> potentialMatches = [];
      
      for (var doc in usersQuery.docs) {
        if (doc.id == currentUserId) continue;
        
        UserModel potential = UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
        
        // Calculate match score based on bio content, interests, etc.
        int matchScore = calculateMatchScore(currentUser, potential);
        
        // ACTION REQUIRED: 
        // Implement your matching algorithm here
        // - Use NLP for bio matching (consider using free NLP APIs)
        // - Check location proximity
        // - Age range preferences
        // - Interest overlap
        
        if (matchScore > 50) { // Threshold for good match
          potentialMatches.add(potential);
        }
      }
      
      // Sort by match score
      potentialMatches.sort((a, b) => calculateMatchScore(currentUser, b).compareTo(
            calculateMatchScore(currentUser, a),
          ));
      
      return potentialMatches;
    } catch (e) {
      print('Error getting auto matches: $e');
      return [];
    }
  }
  
  int calculateMatchScore(UserModel user1, UserModel user2) {
    int score = 0;

    // Shared interest matching (60 points max — at least 1 required)
    final Set<String> interests1 = Set.from(user1.interests);
    final Set<String> interests2 = Set.from(user2.interests);
    final int sharedCount = interests1.intersection(interests2).length;
    if (sharedCount == 0) return 0; // Hard requirement
    final int maxInterests = interests1.length > 0 ? interests1.length : 1;
    score += (sharedCount / maxInterests * 60).clamp(0, 60).toInt();

    // Bio keyword matching (20 points)
    if (user1.bio != null && user2.bio != null && user1.bio!.isNotEmpty) {
      final List<String> bio1Words = user1.bio!.toLowerCase().split(' ');
      final List<String> bio2Words = user2.bio!.toLowerCase().split(' ');
      final int commonWords = bio1Words.where((w) => w.length > 3 && bio2Words.contains(w)).length;
      score += (commonWords / bio1Words.length * 20).clamp(0, 20).toInt();
    }

    // Gender/seeking preference (20 points)
    if (user1.seeking != null && user1.seeking == user2.gender) score += 10;
    if (user2.seeking != null && user2.seeking == user1.gender) score += 10;

    return score;
  }
  
  Future<void> createMatch(String userId1, String userId2) async {
    String matchId = '${userId1}_$userId2';
    
    MatchModel match = MatchModel(
      matchId: matchId,
      user1Id: userId1,
      user2Id: userId2,
      matchedAt: DateTime.now(),
      bothAgreed: false,
    );
    
    await _firestore.collection('matches').doc(matchId).set(match.toMap());
  }
  
  Future<List<UserModel>> getPotentialMatches(String currentUserId, UserModel currentUser) async {
    try {
      QuerySnapshot usersQuery = await _firestore
          .collection('users')
          .where('isPrivate', isEqualTo: false)
          .where('isFrozen', isEqualTo: false)
          .where('isBanned', isEqualTo: false)
          .limit(50)
          .get();
      
      List<UserModel> potentialMatches = [];
      
      for (var doc in usersQuery.docs) {
        if (doc.id == currentUserId) continue;
        UserModel potential = UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
        // Require at least 1 shared interest
        final shared = currentUser.interests.toSet().intersection(potential.interests.toSet());
        if (currentUser.interests.isEmpty || shared.isNotEmpty) {
          potentialMatches.add(potential);
        }
      }
      return potentialMatches;
    } catch (e) {
      debugPrint('Error getting potential matches: $e');
      return [];
    }
  }
  
  Future<bool> checkAndCreateMatch(String currentUserId, String likedUserId) async {
    try {
      // Check if the liked user has already liked the current user
      String reverseMatchId = '${likedUserId}_$currentUserId';
      DocumentSnapshot reverseMatch = await _firestore.collection('matches').doc(reverseMatchId).get();
      
      if (reverseMatch.exists) {
        // It's a match! Update the existing match
        await _firestore.collection('matches').doc(reverseMatchId).update({
          'bothAgreed': true,
          'matchedAt': Timestamp.now(),
        });
        
        // Freeze both accounts
        await _firestore.collection('users').doc(currentUserId).update({
          'isFrozen': true,
          'matchedWithUid': likedUserId,
        });
        
        await _firestore.collection('users').doc(likedUserId).update({
          'isFrozen': true,
          'matchedWithUid': currentUserId,
        });
        
        return true;
      } else {
        // Create a new match document
        String matchId = '${currentUserId}_$likedUserId';
        MatchModel match = MatchModel(
          matchId: matchId,
          user1Id: currentUserId,
          user2Id: likedUserId,
          matchedAt: DateTime.now(),
          bothAgreed: false,
        );
        
        await _firestore.collection('matches').doc(matchId).set(match.toMap());
        return false;
      }
    } catch (e) {
      debugPrint('Error checking/creating match: $e');
      return false;
    }
  }
  
  Future<void> agreeToMatch(String matchId, String userId) async {
    DocumentReference matchRef = _firestore.collection('matches').doc(matchId);
    DocumentSnapshot matchDoc = await matchRef.get();
    
    if (matchDoc.exists) {
      Map<String, dynamic> data = matchDoc.data() as Map<String, dynamic>;
      
      await matchRef.update({
        'agreedBy': userId,
        'bothAgreed': true,
      });
      
      // Freeze both accounts
      await _firestore.collection('users').doc(data['user1Id']).update({
        'isFrozen': true,
        'matchedWithUid': data['user2Id'],
      });
      
      await _firestore.collection('users').doc(data['user2Id']).update({
        'isFrozen': true,
        'matchedWithUid': data['user1Id'],
      });
    }
  }
}