import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? bio;
  final List<String> photos;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? seeking;
  final double? latitude;
  final double? longitude;
  final List<String> interests;
  final bool isPrivate;
  final bool isFrozen;
  final String? matchedWithUid; // When matched, store the partner's UID
  final DateTime? createdAt;
  final DateTime? lastActive;
  final int reportCount;
  final bool isBanned;
  final String? banReason;
  
  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.bio,
    this.photos = const [],
    this.dateOfBirth,
    this.gender,
    this.seeking,
    this.latitude,
    this.longitude,
    this.interests = const [],
    this.isPrivate = false,
    this.isFrozen = false,
    this.matchedWithUid,
    this.createdAt,
    this.lastActive,
    this.reportCount = 0,
    this.isBanned = false,
    this.banReason,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'bio': bio,
      'photos': photos,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'seeking': seeking,
      'latitude': latitude,
      'longitude': longitude,
      'interests': interests,
      'isPrivate': isPrivate,
      'isFrozen': isFrozen,
      'matchedWithUid': matchedWithUid,
      'createdAt': createdAt?.toIso8601String() ?? FieldValue.serverTimestamp(),
      'lastActive': lastActive?.toIso8601String() ?? FieldValue.serverTimestamp(),
      'reportCount': reportCount,
      'isBanned': isBanned,
      'banReason': banReason,
    };
  }
  
  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'],
      bio: map['bio'],
      photos: List<String>.from(map['photos'] ?? []),
      dateOfBirth: map['dateOfBirth'] != null ? DateTime.parse(map['dateOfBirth']) : null,
      gender: map['gender'],
      seeking: map['seeking'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      interests: List<String>.from(map['interests'] ?? []),
      isPrivate: map['isPrivate'] ?? false,
      isFrozen: map['isFrozen'] ?? false,
      matchedWithUid: map['matchedWithUid'],
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      lastActive: map['lastActive'] != null ? (map['lastActive'] as Timestamp).toDate() : null,
      reportCount: map['reportCount'] ?? 0,
      isBanned: map['isBanned'] ?? false,
      banReason: map['banReason'],
    );
  }
}

