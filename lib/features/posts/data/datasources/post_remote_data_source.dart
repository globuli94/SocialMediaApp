// lib/features/posts/data/datasources/post_remote_data_source.dart
//
// PostRemoteDataSource — Firestore and Firebase Storage operations for posts.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_network/features/posts/data/datasources/post_firestore_service.dart';
import 'package:social_network/features/posts/data/datasources/post_storage_service.dart';

/// Data source for all post-related Firebase operations.
///
/// Author display name and avatar URL are denormalized into each post document
/// at creation time so that [watchFeed] requires no per-post user look-ups.
class PostRemoteDataSource {
  /// Creates a [PostRemoteDataSource].
  PostRemoteDataSource({
    required PostFirestoreService firestoreService,
    required PostStorageService storageService,
  })  : _firestoreService = firestoreService,
        _storageService = storageService;

  final PostFirestoreService _firestoreService;
  final PostStorageService _storageService;

  /// Emits the 20 most recent post maps whenever Firestore changes.
  Stream<List<Map<String, dynamic>>> watchFeed() {
    return _firestoreService.watchPosts();
  }

  /// Creates a post document, optionally uploading an image first.
  ///
  /// Returns the raw data map of the created post (including its generated ID).
  Future<Map<String, dynamic>> createPost({
    required String authorUid,
    required String authorDisplayName,
    String? authorAvatarUrl,
    required String content,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final postId = _firestoreService.generatePostId();

    String? imageUrl;
    if (imageBytes != null && imageExtension != null) {
      final storagePath = 'posts/$postId';
      final contentType = switch (imageExtension.toLowerCase()) {
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      await _storageService.uploadBytes(storagePath, imageBytes, contentType);
      imageUrl = await _storageService.getDownloadUrl(storagePath);
    }

    final data = <String, dynamic>{
      'id': postId,
      'authorUid': authorUid,
      'authorDisplayName': authorDisplayName,
      if (authorAvatarUrl != null) 'authorAvatarUrl': authorAvatarUrl,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': 0,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };

    await _firestoreService.createPostWithId(postId, data);
    await _firestoreService.adjustPostCount(authorUid, 1);

    // Return a local map (serverTimestamp not resolved yet — use now as approx).
    return {
      ...data,
      'createdAt': DateTime.now(),
    };
  }

  /// Deletes the post document and its Storage image (if [imageUrl] is set).
  ///
  /// Also decrements the author's `postCount`.
  Future<void> deletePost({
    required String postId,
    required String authorUid,
    String? imageUrl,
  }) async {
    await _firestoreService.deletePost(postId);
    if (imageUrl != null) {
      await _storageService.delete('posts/$postId');
    }
    await _firestoreService.adjustPostCount(authorUid, -1);
  }
}
