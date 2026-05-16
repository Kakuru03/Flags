import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';

class ChatService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendMessage(String matchId, String receiverId, String text, {String? mediaUrl, String? mediaType}) async {
    try {
      String messageId = DateTime.now().millisecondsSinceEpoch.toString();
      
      MessageModel message = MessageModel(
        messageId: messageId,
        matchId: matchId,
        senderId: FirebaseAuth.instance.currentUser!.uid,
        receiverId: receiverId,
        text: text,
        timestamp: DateTime.now(),
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      );
      
      await _firestore
          .collection('chats')
          .doc(matchId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());
      
      // Update last message in match document
      await _firestore.collection('matches').doc(matchId).update({
        'lastInteraction': Timestamp.now(),
        'lastMessage': text,
        'lastMessageTime': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getMessages(String matchId) {
    return _firestore
        .collection('chats')
        .doc(matchId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> markMessagesAsRead(String matchId, String currentUserId) async {
    try {
      QuerySnapshot unreadMessages = await _firestore
          .collection('chats')
          .doc(matchId)
          .collection('messages')
.where('receiverId', isEqualTo: currentUserId)
          .orderBy('timestamp')
          .limit(20)
          .get();
      
      WriteBatch batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([currentUserId])
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<int> getUnreadMessageCount(String currentUserId) async {
    try {
      // Get all matches for current user
      QuerySnapshot matches = await _firestore
          .collection('matches')
          .where('user1Id', isEqualTo: currentUserId)
          .get();
      
      QuerySnapshot matches2 = await _firestore
          .collection('matches')
          .where('user2Id', isEqualTo: currentUserId)
          .get();
      
      int unreadCount = 0;
      
      for (var match in matches.docs) {
        QuerySnapshot unread = await _firestore
            .collection('chats')
            .doc(match.id)
            .collection('messages')
.where('receiverId', isEqualTo: currentUserId)
            .orderBy('timestamp')
            .limit(20)
            .get();
        unreadCount += unread.docs.length;
      }
      
      for (var match in matches2.docs) {
        QuerySnapshot unread = await _firestore
            .collection('chats')
            .doc(match.id)
            .collection('messages')
.where('receiverId', isEqualTo: currentUserId)
            .orderBy('timestamp')
            .limit(20)
            .get();
        unreadCount += unread.docs.length;
      }
      
      return unreadCount;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  Stream<int> streamUnreadMessageCount(String currentUserId) {
    // This is complex to implement with stream, consider using Cloud Functions
    // For now, return a simple stream
    return Stream.periodic(const Duration(seconds: 5), (_) async {
      return await getUnreadMessageCount(currentUserId);
    }).asyncMap((event) => event);
  }
}