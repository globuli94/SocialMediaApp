// lib/features/follow/domain/entities/user_follow_entity.dart
//
// UserFollowEntity — pure Dart domain entity for user data in follower/following lists.

/// Immutable domain entity representing a user in a followers/following list.
class UserFollowEntity {
  /// Creates a [UserFollowEntity].
  const UserFollowEntity({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
  });

  /// Firebase Auth UID.
  final String uid;

  /// Publicly visible display name.
  final String displayName;

  /// URL to the profile picture, or `null` if unset.
  final String? avatarUrl;
}
