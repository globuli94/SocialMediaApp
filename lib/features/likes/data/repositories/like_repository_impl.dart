// lib/features/likes/data/repositories/like_repository_impl.dart
//
// LikeRepositoryImpl — Firestore implementation of LikeRepository.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_network/features/likes/domain/repositories/like_repository.dart';

/// Concrete implementation of [LikeRepository] backed by [FirebaseFirestore].
///
/// All like/unlike mutations are executed as a single Firestore batch so the
/// like document and likeCount field stay consistent.
class LikeRepositoryImpl implements LikeRepository {
  /// Creates a [LikeRepositoryImpl].
  LikeRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Future<bool> toggleLike({
    required String postId,
    required String userId,
  }) async {
    final likeDocRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId);

    final likeSnapshot = await likeDocRef.get();
    final isCurrentlyLiked = likeSnapshot.exists;

    final batch = _firestore.batch();

    if (isCurrentlyLiked) {
      // Unlike: delete the like document and decrement likeCount
      batch.delete(likeDocRef);
      final postRef = _firestore.collection('posts').doc(postId);
      batch.update(postRef, {
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      // Like: create the like document and increment likeCount
      batch.set(likeDocRef, {
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      final postRef = _firestore.collection('posts').doc(postId);
      batch.update(postRef, {
        'likeCount': FieldValue.increment(1),
      });
    }

    await batch.commit();
    return !isCurrentlyLiked;
  }

  @override
  Stream<bool> watchIsLiked({
    required String postId,
    required String userId,
  }) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  @override
  Stream<int> watchLikeCount({required String postId}) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map((snapshot) => (snapshot.data()?['likeCount'] as int?) ?? 0);
  }
}
