// lib/features/follow/domain/repositories/follow_repository.dart
//
// FollowRepository — abstract contract for follow / unfollow operations.

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
}
