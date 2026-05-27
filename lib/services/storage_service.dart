import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload a single image – works on mobile (File) and web (Uint8List)
  Future<String?> uploadImage(dynamic image, String userId, String imageName) async {
    try {
      String fileName = 'users/$userId/images/$imageName-${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child(fileName);

      if (kIsWeb) {
        // Web: image is a Uint8List (from XFile.readAsBytes())
        final bytes = image as Uint8List;
        await ref.putData(bytes);
      } else {
        // Mobile: image is a File
        final file = image as File;
        await ref.putFile(file);
      }
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // Upload multiple images – accepts List<Uint8List> on web, List<File> on mobile
  Future<List<String>> uploadMultipleImages(List<dynamic> images, String userId) async {
    List<String> urls = [];
    for (int i = 0; i < images.length; i++) {
      String? url = await uploadImage(images[i], userId, 'img_$i');
      if (url != null) urls.add(url);
    }
    return urls;
  }

  // Cache image locally (mobile only – web just returns the original URL)
  Future<String> cacheImage(String imageUrl) async {
    if (kIsWeb) {
      return imageUrl;
    }
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
      return imageUrl;
    }
  }

  // Delete image (works everywhere)
  Future<void> deleteImage(String imageUrl) async {
    try {
      Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }

  // Upload chat media – accepts File (mobile) or Uint8List (web)
  Future<String?> uploadChatMedia(dynamic mediaFile, String matchId, String mediaType) async {
    try {
      String fileName = 'chats/$matchId/${DateTime.now().millisecondsSinceEpoch}.$mediaType';
      Reference ref = _storage.ref().child(fileName);

      if (kIsWeb) {
        final bytes = mediaFile as Uint8List;
        await ref.putData(bytes);
      } else {
        final file = mediaFile as File;
        await ref.putFile(file);
      }
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading chat media: $e');
      return null;
    }
  }
}