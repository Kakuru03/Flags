import 'package:cloud_firestore/cloud_firestore.dart';

class MatchModel {
  final String matchId;
  final String user1Id;
  final String user2Id;
  final DateTime matchedAt;
  final bool bothAgreed;
  final String? agreedBy;
  final bool isActive;
  final DateTime? lastInteraction;

  MatchModel({
    required this.matchId,
    required this.user1Id,
    required this.user2Id,
    required this.matchedAt,
    required this.bothAgreed,
    this.agreedBy,
    this.isActive = true,
    this.lastInteraction,
  });

  Map<String, dynamic> toMap() {
    return {
      'matchId': matchId,
      'user1Id': user1Id,
      'user2Id': user2Id,
      'matchedAt': Timestamp.fromDate(matchedAt),
      'bothAgreed': bothAgreed,
      'agreedBy': agreedBy,
      'isActive': isActive,
      'lastInteraction': lastInteraction != null ? Timestamp.fromDate(lastInteraction!) : null,
    };
  }

  factory MatchModel.fromMap(String id, Map<String, dynamic> map) {
    return MatchModel(
      matchId: id,
      user1Id: map['user1Id'] ?? '',
      user2Id: map['user2Id'] ?? '',
      matchedAt: (map['matchedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bothAgreed: map['bothAgreed'] ?? false,
      agreedBy: map['agreedBy'],
      isActive: map['isActive'] ?? true,
      lastInteraction: (map['lastInteraction'] as Timestamp?)?.toDate(),
    );
  }
}