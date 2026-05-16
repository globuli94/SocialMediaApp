// lib/features/likes/domain/repositories/like_repository.dart
//
// LikeRepository — abstract interface for like data operations.

/// Abstract repository for like operations.
///
/// Implementations may use Firebase Firestore.
/// Domain and presentation layers depend only on this interface.
abstract class LikeRepository {
  /// Toggles a like on a post. If the current user has already liked the post,
  /// this removes the like. Otherwise, it adds a like.
  ///
  /// Returns true if the post is now liked, false otherwise.
  Future<bool> toggleLike({
    required String postId,
    required String userId,
  });

  /// Watches whether the current user has liked a specific post.
  /// Returns a stream of boolean values — true if liked, false if not.
  Stream<bool> watchIsLiked({
    required String postId,
    required String userId,
  });

  /// Gets the current like count for a post.
  /// Returns a stream of the like count.
  Stream<int> watchLikeCount({required String postId});
}
