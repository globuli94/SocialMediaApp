// lib/features/posts/data/repositories/post_repository_impl.dart
//
// PostRepositoryImpl — Firestore + Storage implementation of PostRepository.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';

/// Concrete implementation of [PostRepository] backed by Firestore and
/// Firebase Storage.
class PostRepositoryImpl implements PostRepository {
  PostRepositoryImpl({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  })  : _firestore = firestore,
        _storage = storage;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  @override
  Stream<List<PostEntity>> watchPosts() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_docToEntity).toList());
  }

  @override
  Future<PostEntity> createPost({
    required String authorUid,
    required String authorDisplayName,
    String? authorAvatarUrl,
    required String content,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final docRef = _firestore.collection('posts').doc();
    final postId = docRef.id;

    String? imageUrl;
    if (imageBytes != null) {
      final storagePath = 'posts/$postId${imageExtension ?? ''}';
      final contentType = switch ((imageExtension ?? '').toLowerCase()) {
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final uploadTask = await _storage
          .ref(storagePath)
          .putData(imageBytes, SettableMetadata(contentType: contentType));
      imageUrl = await uploadTask.ref.getDownloadURL();
    }

    await docRef.set({
      'id': postId,
      'authorUid': authorUid,
      'authorDisplayName': authorDisplayName,
      'authorAvatarUrl': authorAvatarUrl,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': 0,
      'imageUrl': imageUrl,
    });

    return PostEntity(
      id: postId,
      authorUid: authorUid,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
      content: content,
      createdAt: DateTime.now(),
      imageUrl: imageUrl,
    );
  }

  @override
  Future<void> deletePost(String postId) async {
    final docRef = _firestore.collection('posts').doc(postId);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      final imageUrl = snapshot.data()?['imageUrl'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(imageUrl).delete();
        } catch (_) {
          // Ignore storage deletion errors — proceed to delete the document.
        }
      }
    }

    await docRef.delete();
  }

  @override
  Future<(List<PostEntity>, Object?)> fetchFeedPage({
    Object? cursor,
    int limit = 10,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (cursor != null) {
      query = query.startAfterDocument(
          cursor as DocumentSnapshot<Map<String, dynamic>>);
    }
    final snapshot = await query.get();
    final posts = snapshot.docs.map(_docToEntity).toList();
    final nextCursor =
        snapshot.docs.length < limit ? null : snapshot.docs.last;
    return (posts, nextCursor as Object?);
  }

  PostEntity _docToEntity(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    return PostEntity(
      id: doc.id,
      authorUid: data['authorUid'] as String? ?? '',
      authorDisplayName: data['authorDisplayName'] as String? ?? '',
      content: data['content'] as String? ?? '',
      createdAt: createdAt,
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
      imageUrl: data['imageUrl'] as String?,
    );
  }
}
