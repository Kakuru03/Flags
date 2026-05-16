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
    
    // Interest matching (50 points max)
    Set<String> interests1 = Set.from(user1.interests);
    Set<String> interests2 = Set.from(user2.interests);
    int commonInterests = interests1.intersection(interests2).length;
    score += (commonInterests / user1.interests.length * 25).toInt();
    
    // Bio keyword matching (30 points)
    if (user1.bio != null && user2.bio != null) {
      List<String> bio1Words = user1.bio!.toLowerCase().split(' ');
      List<String> bio2Words = user2.bio!.toLowerCase().split(' ');
      int commonWords = bio1Words.where((word) => bio2Words.contains(word)).length;
      score += (commonWords / bio1Words.length * 30).toInt();
    }
    
    // Seeking preference (20 points)
    if (user1.seeking == user2.gender) score += 20;
    
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
        potentialMatches.add(potential);
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