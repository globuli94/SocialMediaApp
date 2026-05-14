// lib/features/follow/domain/entities/follow_user_entity.dart
//
// FollowUserEntity — lightweight user summary used in followers/following lists.

/// Immutable domain entity representing a user entry in a followers or
/// following list.
class FollowUserEntity {
  const FollowUserEntity({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
  });

  final String uid;
  final String displayName;
  final String? avatarUrl;
}
