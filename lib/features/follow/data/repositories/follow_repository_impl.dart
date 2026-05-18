// lib/features/follow/data/repositories/follow_repository_impl.dart
//
// FollowRepositoryImpl — Firestore-backed implementation of FollowRepository.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';

/// Concrete implementation of [FollowRepository] backed by [FirebaseFirestore].
///
/// All follow / unfollow mutations are executed as a single Firestore batch so
/// subcollection documents and counter fields stay consistent.
class FollowRepositoryImpl implements FollowRepository {
  /// Creates a [FollowRepositoryImpl].
  FollowRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Future<void> follow({
    required String followerId,
    required String followeeId,
  }) async {
    final batch = _firestore.batch();

    // Write following entry under follower's subcollection.
    final followingRef = _firestore
        .collection('users')
        .doc(followerId)
        .collection('following')
        .doc(followeeId);
    batch.set(followingRef, {
      'followeeId': followeeId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Write follower entry under followee's subcollection.
    final followersRef = _firestore
        .collection('users')
        .doc(followeeId)
        .collection('followers')
        .doc(followerId);
    batch.set(followersRef, {
      'followerId': followerId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increment followingCount on follower's document.
    final followerDocRef = _firestore.collection('users').doc(followerId);
    batch.update(followerDocRef, {
      'followingCount': FieldValue.increment(1),
    });

    // Increment followerCount on followee's document.
    final followeeDocRef = _firestore.collection('users').doc(followeeId);
    batch.update(followeeDocRef, {
      'followerCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  @override
  Future<void> unfollow({
    required String followerId,
    required String followeeId,
  }) async {
    final batch = _firestore.batch();

    // Delete following entry from follower's subcollection.
    final followingRef = _firestore
        .collection('users')
        .doc(followerId)
        .collection('following')
        .doc(followeeId);
    batch.delete(followingRef);

    // Delete follower entry from followee's subcollection.
    final followersRef = _firestore
        .collection('users')
        .doc(followeeId)
        .collection('followers')
        .doc(followerId);
    batch.delete(followersRef);

    // Decrement followingCount on follower's document.
    final followerDocRef = _firestore.collection('users').doc(followerId);
    batch.update(followerDocRef, {
      'followingCount': FieldValue.increment(-1),
    });

    // Decrement followerCount on followee's document.
    final followeeDocRef = _firestore.collection('users').doc(followeeId);
    batch.update(followeeDocRef, {
      'followerCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  @override
  Stream<bool> watchIsFollowing({
    required String followerId,
    required String followeeId,
  }) {
    return _firestore
        .collection('users')
        .doc(followerId)
        .collection('following')
        .doc(followeeId)
        .snapshots()
        .map((s) => s.exists);
  }

  @override
  Future<List<UserProfileEntity>> getFollowers(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('followers')
          .get();

      final followers = <UserProfileEntity>[];
      for (final doc in snapshot.docs) {
        final followerId = doc['followerId'] as String?;
        if (followerId != null) {
          final userDoc = await _firestore
              .collection('users')
              .doc(followerId)
              .get();
          if (userDoc.exists) {
            final data = userDoc.data()!;
            followers.add(UserProfileEntity(
              uid: followerId,
              displayName: data['displayName'] as String? ?? '',
              bio: data['bio'] as String? ?? '',
              avatarUrl: data['avatarUrl'] as String?,
              postCount: (data['postCount'] as num?)?.toInt() ?? 0,
              followerCount: (data['followerCount'] as num?)?.toInt() ?? 0,
              followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
            ));
          }
        }
      }
      return followers;
    } catch (e) {
      throw Exception('Failed to fetch followers: $e');
    }
  }

  @override
  Future<List<UserProfileEntity>> getFollowing(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();

      final following = <UserProfileEntity>[];
      for (final doc in snapshot.docs) {
        final followeeId = doc['followeeId'] as String?;
        if (followeeId != null) {
          final userDoc = await _firestore
              .collection('users')
              .doc(followeeId)
              .get();
          if (userDoc.exists) {
            final data = userDoc.data()!;
            following.add(UserProfileEntity(
              uid: followeeId,
              displayName: data['displayName'] as String? ?? '',
              bio: data['bio'] as String? ?? '',
              avatarUrl: data['avatarUrl'] as String?,
              postCount: (data['postCount'] as num?)?.toInt() ?? 0,
              followerCount: (data['followerCount'] as num?)?.toInt() ?? 0,
              followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
            ));
          }
        }
      }
      return following;
    } catch (e) {
      throw Exception('Failed to fetch following: $e');
    }
  }
}
