// lib/features/profile/domain/repositories/profile_repository.dart
//
// ProfileRepository — abstract interface for profile data operations.

import 'dart:typed_data';

import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';

/// Abstract repository for user profile operations.
///
/// Implementations may use Firebase Firestore and Firebase Storage.
/// Domain and presentation layers depend only on this interface.
abstract class ProfileRepository {
  /// Returns the profile for [uid].
  ///
  /// If no document exists at `users/{uid}`, creates one with default values
  /// derived from the currently signed-in Firebase Auth user.
  Future<UserProfileEntity> getProfile(String uid);

  /// Writes [displayName] and [bio] to `users/{uid}` in Firestore.
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String bio,
  });

  /// Uploads [bytes] as the avatar for [uid] to Firebase Storage at
  /// `avatars/{uid}`, then updates `avatarUrl` in `users/{uid}`.
  ///
  /// [extension] must include the leading dot, e.g. `.jpg`.
  Future<void> uploadAvatar({
    required String uid,
    required Uint8List bytes,
    required String extension,
  });

  /// Returns a stream that emits the [UserProfileEntity] for [uid] on every
  /// Firestore change, enabling real-time follower/following count updates.
  Stream<UserProfileEntity> watchProfile(String uid);

  /// Returns up to 20 [UserProfileEntity] results whose displayName starts with
  /// [query], excluding the user identified by [excludeUid].
  Future<List<UserProfileEntity>> searchUsers({
    required String query,
    required String excludeUid,
  });
}
