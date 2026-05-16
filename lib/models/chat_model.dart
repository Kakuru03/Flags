import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String matchId;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final List<String> readBy;
  final String? mediaUrl;
  final String? mediaType; // 'image', 'video', 'audio'

  MessageModel({
    required this.messageId,
    required this.matchId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.readBy = const [],
    this.mediaUrl,
    this.mediaType,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'matchId': matchId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'readBy': readBy,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
    };
  }

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MessageModel(
      messageId: id,
      matchId: map['matchId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(map['readBy'] ?? []),
      mediaUrl: map['mediaUrl'],
      mediaType: map['mediaType'],
    );
  }
}