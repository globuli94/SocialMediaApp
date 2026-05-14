// lib/features/profile/domain/entities/user_profile_entity.dart
//
// UserProfileEntity — pure Dart domain entity for a user profile.

/// Immutable domain entity representing a user profile stored in Firestore.
///
/// Contains no Firebase imports — all Firebase-specific types are
/// mapped at the data layer boundary.
class UserProfileEntity {
  /// Creates a [UserProfileEntity].
  const UserProfileEntity({
    required this.uid,
    required this.displayName,
    required this.bio,
    this.avatarUrl,
    required this.postCount,
    this.followerCount = 0,
    this.followingCount = 0,
  });

  /// Firebase Auth UID — matches the Firestore `users/{uid}` document ID.
  final String uid;

  /// Publicly visible display name.
  final String displayName;

  /// Short user biography. May be empty.
  final String bio;

  /// URL to the profile picture stored in Firebase Storage, or `null` if unset.
  final String? avatarUrl;

  /// Cached count of the user's posts. Defaults to 0.
  final int postCount;

  /// Cached count of users following this profile. Defaults to 0.
  final int followerCount;

  /// Cached count of users this profile is following. Defaults to 0.
  final int followingCount;
}
