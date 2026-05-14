// lib/features/follow/domain/repositories/follow_repository.dart
//
// FollowRepository — abstract interface for follow/unfollow operations.

/// Abstract repository for follow/unfollow feature.
///
/// Implementations live in the data layer and interact with Firestore.
/// The domain and presentation layers depend only on this interface.
abstract class FollowRepository {
  /// Emits `true` when [followerId] is following [followeeId], `false` otherwise.
  ///
  /// The stream stays active until the listener cancels.
  Stream<bool> watchIsFollowing({
    required String followerId,
    required String followeeId,
  });

  /// Atomically records that [followerId] follows [followeeId] and increments
  /// both parties' counts.
  Future<void> follow({
    required String followerId,
    required String followeeId,
  });

  /// Atomically removes the follow relationship and decrements counts.
  Future<void> unfollow({
    required String followerId,
    required String followeeId,
  });
}
