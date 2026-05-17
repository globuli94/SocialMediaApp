// lib/features/posts/domain/entities/post_entity.dart
//
// PostEntity — pure Dart domain entity for a post. No Firebase imports.

/// Immutable domain entity representing a post in the feed.
class PostEntity {
  const PostEntity({
    required this.id,
    required this.authorUid,
    required this.authorDisplayName,
    required this.content,
    required this.createdAt,
    this.authorAvatarUrl,
    this.imageUrl,
    this.likeCount = 0,
  });

  final String id;
  final String authorUid;
  final String authorDisplayName;
  final String content;
  final DateTime createdAt;
  final String? authorAvatarUrl;
  final String? imageUrl;
  final int likeCount;
}
