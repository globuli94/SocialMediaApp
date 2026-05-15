// lib/features/posts/domain/repositories/post_repository.dart
//
// PostRepository — abstract interface for post data operations.

import 'dart:typed_data';

import 'package:social_network/features/posts/domain/entities/post_entity.dart';

/// Abstract repository for post operations.
///
/// Implementations may use Firebase Firestore and Firebase Storage.
/// Domain and presentation layers depend only on this interface.
abstract class PostRepository {
  /// Emits the latest feed list on every Firestore change.
  /// Ordered by createdAt descending.
  Stream<List<PostEntity>> watchPosts();

  /// Emits posts authored by [authorUid], ordered by createdAt descending.
  Stream<List<PostEntity>> watchPostsByAuthor(String authorUid);

  /// Creates a new post. Uploads [imageBytes] to Storage first when provided.
  /// Returns the created [PostEntity].
  Future<PostEntity> createPost({
    required String authorUid,
    required String authorDisplayName,
    String? authorAvatarUrl,
    required String content,
    Uint8List? imageBytes,
    String? imageExtension,
  });

  /// Deletes the post with [postId] and its Storage image (if any).
  Future<void> deletePost(String postId);
}
