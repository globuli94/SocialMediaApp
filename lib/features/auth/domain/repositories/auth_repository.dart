// lib/features/auth/domain/repositories/auth_repository.dart
//
// AuthRepository — abstract interface for all authentication operations.

import 'package:social_network/features/auth/domain/entities/user_entity.dart';

/// Abstract repository that defines all authentication operations.
///
/// Implementations wrap `firebase_auth`; the domain layer never imports Firebase.
abstract class AuthRepository {
  /// Stream that emits the current [UserEntity] when authenticated,
  /// or `null` when the user signs out.
  Stream<UserEntity?> get authStateChanges;

  /// The synchronously available current user, or `null` if not signed in.
  UserEntity? get currentUser;

  /// Signs in with [email] and [password].
  ///
  /// Throws a human-readable [String] on failure.
  Future<void> signIn({required String email, required String password});

  /// Creates a new account with [email] and [password] and writes a
  /// `users/{uid}` document to Firestore with `uid`, `displayName`,
  /// and `createdAt`.
  ///
  /// Throws a human-readable [String] on failure.
  Future<void> signUp({required String email, required String password});

  /// Sends a password-reset email to [email].
  ///
  /// Throws a human-readable [String] on failure.
  Future<void> sendPasswordResetEmail({required String email});

  /// Signs the current user out.
  Future<void> signOut();
}
