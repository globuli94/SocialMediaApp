// lib/features/likes/domain/entities/like_entity.dart
//
// LikeEntity — pure Dart domain entity for a like. No Firebase imports.

/// Immutable domain entity representing a like on a post.
class LikeEntity {
  const LikeEntity({
    required this.userId,
    required this.createdAt,
  });

  final String userId;
  final DateTime createdAt;
}
