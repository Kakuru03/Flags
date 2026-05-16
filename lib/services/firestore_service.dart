import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generic CRUD operations
  Future<void> setData(String collection, String docId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).doc(docId).set(data);
    } catch (e) {
      debugPrint('Error setting data: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getData(String collection, String docId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(collection).doc(docId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting data: $e');
    }
    return null;
  }

  Future<void> updateData(String collection, String docId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).doc(docId).update(data);
    } catch (e) {
      debugPrint('Error updating data: $e');
      rethrow;
    }
  }

  Future<void> deleteData(String collection, String docId) async {
    try {
      await _firestore.collection(collection).doc(docId).delete();
    } catch (e) {
      debugPrint('Error deleting data: $e');
      rethrow;
    }
  }

  // Real-time listeners
  Stream<QuerySnapshot> getCollectionStream(String collection) {
    return _firestore.collection(collection).snapshots();
  }

  Stream<DocumentSnapshot> getDocumentStream(String collection, String docId) {
    return _firestore.collection(collection).doc(docId).snapshots();
  }

  // Batch operations
  Future<void> batchWrite(List<Function> operations) async {
    WriteBatch batch = _firestore.batch();
    // Execute operations on batch
    await batch.commit();
  }

  // Geospatial queries for nearby users
  Future<List<UserModel>> getNearbyUsers(double latitude, double longitude, double radiusKm) async {
    // Firestore doesn't support native geospatial queries
    // You'll need to implement with GeoFire or similar
    // For now, fetching all and filtering
    QuerySnapshot users = await _firestore
        .collection('users')
        .where('isPrivate', isEqualTo: false)
        .limit(100)
        .get();

    List<UserModel> nearbyUsers = [];
    for (var doc in users.docs) {
      UserModel user = UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      if (user.latitude != null && user.longitude != null) {
        double distance = _calculateDistance(
          latitude, longitude,
          user.latitude!, user.longitude!,
        );
        if (distance <= radiusKm) {
          nearbyUsers.add(user);
        }
      }
    }
    return nearbyUsers;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Earth's radius in km
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) => degree * pi / 180;
}