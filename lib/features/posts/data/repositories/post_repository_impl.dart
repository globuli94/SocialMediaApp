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

    await _firestore.collection('users').doc(authorUid).update({
      'postCount': FieldValue.increment(1),
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

    String? authorUid;
    if (snapshot.exists) {
      final data = snapshot.data();
      authorUid = data?['authorUid'] as String?;
      final imageUrl = data?['imageUrl'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(imageUrl).delete();
        } catch (_) {
          // Ignore storage deletion errors — proceed to delete the document.
        }
      }
    }

    await docRef.delete();

    if (authorUid != null) {
      await _firestore.collection('users').doc(authorUid).update({
        'postCount': FieldValue.increment(-1),
      });
    }
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
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> likePost(String postId, String userId) async {
    // Fetch the post to determine the author, and fetch the actor's profile so
    // we can write a rich notification document in the same batch.
    final postDoc = await _firestore.collection('posts').doc(postId).get();
    final actorDoc = await _firestore.collection('users').doc(userId).get();

    final postData = postDoc.data() ?? {};
    final actorData = actorDoc.data() ?? {};
    final postAuthorUid = postData['authorUid'] as String? ?? '';
    final actorDisplayName = actorData['displayName'] as String? ?? '';
    final actorAvatarUrl = actorData['avatarUrl'] as String?;

    final batch = _firestore.batch();
    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);

    batch.update(postRef, {
      'likeCount': FieldValue.increment(1),
    });
    batch.set(likeRef, {
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Write a like notification unless the liker is the post author.
    if (postAuthorUid.isNotEmpty && postAuthorUid != userId) {
      final notifRef = _firestore
          .collection('users')
          .doc(postAuthorUid)
          .collection('notifications')
          .doc();
      batch.set(notifRef, {
        'type': 'like',
        'actorUid': userId,
        'actorDisplayName': actorDisplayName,
        'actorAvatarUrl': actorAvatarUrl,
        'postId': postId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  @override
  Future<void> unlikePost(String postId, String userId) async {
    final batch = _firestore.batch();
    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);

    batch.update(postRef, {
      'likeCount': FieldValue.increment(-1),
    });
    batch.delete(likeRef);

    await batch.commit();
  }

  @override
  Stream<bool> watchPostLiked(String postId, String userId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  @override
  Stream<List<PostEntity>> watchPostsByAuthorUid(String authorUid) {
    return _firestore
        .collection('posts')
        .where('authorUid', isEqualTo: authorUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_docToEntity).toList());
  }
}
