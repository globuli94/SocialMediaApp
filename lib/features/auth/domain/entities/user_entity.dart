// lib/features/auth/domain/entities/user_entity.dart
//
// UserEntity — pure Dart domain entity representing an authenticated user.

/// Immutable domain entity for an authenticated user.
///
/// Contains no Firebase imports — all Firebase-specific types are
/// mapped at the data layer boundary.
class UserEntity {
  /// Creates a [UserEntity].
  const UserEntity({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  /// Firebase Auth UID — matches the Firestore `users/{uid}` document ID.
  final String uid;

  /// The user's email address.
  final String email;

  /// Publicly visible display name, derived from the email prefix on sign-up.
  final String displayName;
}
