import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload image to Firebase Storage
  Future<String?> uploadImage(File imageFile, String userId, String imageName) async {
    try {
      String fileName = 'users/$userId/images/$imageName-${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child(fileName);
      
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // Upload multiple images
  Future<List<String>> uploadMultipleImages(List<File> images, String userId) async {
    List<String> urls = [];
    for (int i = 0; i < images.length; i++) {
      String? url = await uploadImage(images[i], userId, 'img_$i');
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }

  // Cache image locally
  Future<String> cacheImage(String imageUrl) async {
    try {
      Directory tempDir = await getTemporaryDirectory();
      String fileName = imageUrl.split('/').last;
      String filePath = '${tempDir.path}/$fileName';
      
      File cachedFile = File(filePath);
      
      if (!await cachedFile.exists()) {
        http.Response response = await http.get(Uri.parse(imageUrl));
        await cachedFile.writeAsBytes(response.bodyBytes);
      }
      
      return filePath;
    } catch (e) {
      debugPrint('Error caching image: $e');
      return imageUrl; // Return original URL if caching fails
    }
  }

  // Delete image
  Future<void> deleteImage(String imageUrl) async {
    try {
      Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }

  // Upload chat media
  Future<String?> uploadChatMedia(File mediaFile, String matchId, String mediaType) async {
    try {
      String fileName = 'chats/$matchId/${DateTime.now().millisecondsSinceEpoch}.$mediaType';
      Reference ref = _storage.ref().child(fileName);
      
      UploadTask uploadTask = ref.putFile(mediaFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading chat media: $e');
      return null;
    }
  }
}