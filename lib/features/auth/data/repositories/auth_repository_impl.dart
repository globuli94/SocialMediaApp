// lib/features/auth/data/repositories/auth_repository_impl.dart
//
// AuthRepositoryImpl — implements AuthRepository using Firebase Auth.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:social_network/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:social_network/features/auth/domain/entities/user_entity.dart';
import 'package:social_network/features/auth/domain/repositories/auth_repository.dart';

/// Concrete implementation of [AuthRepository] backed by [AuthRemoteDataSource].
///
/// Maps Firebase [User] objects to domain [UserEntity] instances so that
/// the domain and presentation layers remain free of Firebase imports.
class AuthRepositoryImpl implements AuthRepository {
  /// Creates an [AuthRepositoryImpl].
  AuthRepositoryImpl({required AuthRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final AuthRemoteDataSource _dataSource;

  @override
  Stream<UserEntity?> get authStateChanges =>
      _dataSource.authStateChanges.map(_mapFirebaseUser);

  @override
  UserEntity? get currentUser => _mapFirebaseUser(_dataSource.currentUser);

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _dataSource.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Sign-in failed.';
    }
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await _dataSource.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Sign-up failed.';
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _dataSource.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Failed to send password reset email.';
    }
  }

  @override
  Future<void> signOut() async {
    await _dataSource.signOut();
  }

  /// Maps a nullable Firebase [User] to a nullable domain [UserEntity].
  UserEntity? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return UserEntity(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? user.email?.split('@').first ?? '',
    );
  }
}
