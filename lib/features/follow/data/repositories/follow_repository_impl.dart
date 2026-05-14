// lib/features/follow/data/repositories/follow_repository_impl.dart
//
// FollowRepositoryImpl — Firestore-backed implementation of FollowRepository.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';

/// Concrete [FollowRepository] backed by [FirebaseFirestore].
///
/// All writes are executed as atomic [WriteBatch] commits to ensure
/// the following/followers subcollections and the denormalized counts
/// on the user documents stay in sync.
class FollowRepositoryImpl implements FollowRepository {
  /// Creates a [FollowRepositoryImpl].
  FollowRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Stream<bool> watchIsFollowing({
    required String followerId,
    required String followeeId,
  }) =>
      _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followeeId)
          .snapshots()
          .map((snap) => snap.exists);

  @override
  Future<void> follow({
    required String followerId,
    required String followeeId,
  }) async {
    final batch = _firestore.batch();

    // 1. Record in follower's following sub-collection.
    batch.set(
      _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followeeId),
      {'followeeId': followeeId, 'createdAt': FieldValue.serverTimestamp()},
    );

    // 2. Record in followee's followers sub-collection.
    batch.set(
      _firestore
          .collection('users')
          .doc(followeeId)
          .collection('followers')
          .doc(followerId),
      {'followerId': followerId, 'createdAt': FieldValue.serverTimestamp()},
    );

    // 3. Increment follower's followingCount.
    batch.update(
      _firestore.collection('users').doc(followerId),
      {'followingCount': FieldValue.increment(1)},
    );

    // 4. Increment followee's followerCount.
    batch.update(
      _firestore.collection('users').doc(followeeId),
      {'followerCount': FieldValue.increment(1)},
    );

    await batch.commit();
  }

  @override
  Future<void> unfollow({
    required String followerId,
    required String followeeId,
  }) async {
    final batch = _firestore.batch();

    // 1. Remove from follower's following sub-collection.
    batch.delete(
      _firestore
          .collection('users')
          .doc(followerId)
          .collection('following')
          .doc(followeeId),
    );

    // 2. Remove from followee's followers sub-collection.
    batch.delete(
      _firestore
          .collection('users')
          .doc(followeeId)
          .collection('followers')
          .doc(followerId),
    );

    // 3. Decrement follower's followingCount.
    batch.update(
      _firestore.collection('users').doc(followerId),
      {'followingCount': FieldValue.increment(-1)},
    );

    // 4. Decrement followee's followerCount.
    batch.update(
      _firestore.collection('users').doc(followeeId),
      {'followerCount': FieldValue.increment(-1)},
    );

    await batch.commit();
  }
}
