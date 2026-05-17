// lib/features/follow/domain/repositories/follow_repository.dart
//
// FollowRepository — abstract contract for follow / unfollow operations.

import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';

/// Abstract contract for follow / unfollow operations and follow-status streams.
abstract class FollowRepository {
  /// Creates the Firestore follow relationship between [followerId] and
  /// [followeeId] and increments both parties' counts atomically.
  Future<void> follow({
    required String followerId,
    required String followeeId,
  });

  /// Removes the Firestore follow relationship between [followerId] and
  /// [followeeId] and decrements both parties' counts atomically.
  Future<void> unfollow({
    required String followerId,
    required String followeeId,
  });

  /// Emits `true` whenever [followerId] is following [followeeId], `false`
  /// otherwise.
  Stream<bool> watchIsFollowing({
    required String followerId,
    required String followeeId,
  });

  /// Emits a stream of users who follow the user with [uid].
  /// Ordered by createdAt descending.
  Stream<List<UserProfileEntity>> watchFollowers(String uid);

  /// Emits a stream of users that the user with [uid] is following.
  /// Ordered by createdAt descending.
  Stream<List<UserProfileEntity>> watchFollowing(String uid);
}
