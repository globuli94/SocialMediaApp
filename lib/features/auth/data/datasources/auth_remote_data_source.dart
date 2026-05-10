// lib/features/auth/data/datasources/auth_remote_data_source.dart
//
// AuthRemoteDataSource — Firebase Auth and Firestore operations for authentication.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Data source that performs Firebase Auth and Firestore operations.
///
/// This is the only place in the app where Firebase is called directly.
class AuthRemoteDataSource {
  /// Creates an [AuthRemoteDataSource].
  AuthRemoteDataSource({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  /// Stream of [User?] from Firebase Auth reflecting auth state changes.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// The synchronously available current Firebase [User], or `null`.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Signs in with [email] and [password].
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Creates a new account and writes the user profile to Firestore.
  ///
  /// The `users/{uid}` document is written with `uid`, `displayName`
  /// (derived from the email prefix), and `createdAt` fields as defined
  /// in `schema/firebase-schema.md`.
  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    final displayName = email.split('@').first;
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'displayName': displayName,
      'bio': '',
      'avatarUrl': null,
      'postCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Sends a password reset email to [email].
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
