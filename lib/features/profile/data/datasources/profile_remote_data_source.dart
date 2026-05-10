// lib/features/profile/data/datasources/profile_remote_data_source.dart
//
// ProfileRemoteDataSource — Firestore and Firebase Storage operations for
// user profiles.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Data source that performs Firestore and Firebase Storage operations for
/// user profiles.
///
/// This is the only layer that imports Firebase packages for profile data.
class ProfileRemoteDataSource {
  /// Creates a [ProfileRemoteDataSource].
  ProfileRemoteDataSource({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required FirebaseAuth firebaseAuth,
  })  : _firestore = firestore,
        _storage = storage,
        _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _firebaseAuth;

  /// Returns the raw Firestore data for [uid].
  ///
  /// If no document exists, creates one with default values derived from the
  /// currently signed-in Firebase Auth user and returns those defaults.
  Future<Map<String, dynamic>> fetchProfile(String uid) async {
    final ref = _firestore.collection('users').doc(uid);
    final snap = await ref.get();

    if (snap.exists) {
      return snap.data()!;
    }

    // Document missing — create with defaults so the profile always exists.
    final currentUser = _firebaseAuth.currentUser;
    final displayName = currentUser?.email?.split('@').first ?? uid;
    final defaults = <String, dynamic>{
      'uid': uid,
      'displayName': displayName,
      'bio': '',
      'avatarUrl': null,
      'postCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await ref.set(defaults);

    // Return without the server-timestamp sentinel so callers get real values.
    return <String, dynamic>{
      'uid': uid,
      'displayName': displayName,
      'bio': '',
      'avatarUrl': null,
      'postCount': 0,
    };
  }

  /// Writes [displayName] and [bio] to `users/{uid}`.
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String bio,
  }) async {
    await _firestore.collection('users').doc(uid).update(<String, dynamic>{
      'displayName': displayName,
      'bio': bio,
    });
  }

  /// Uploads [bytes] to `avatars/{uid}{extension}` in Firebase Storage and
  /// returns the public download URL.
  Future<String> uploadAvatarBytes({
    required String uid,
    required Uint8List bytes,
    required String extension,
  }) async {
    final ref = _storage.ref('avatars/$uid$extension');
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }

  /// Updates the `avatarUrl` field on `users/{uid}` in Firestore.
  Future<void> updateAvatarUrl({
    required String uid,
    required String avatarUrl,
  }) async {
    await _firestore.collection('users').doc(uid).update(<String, dynamic>{
      'avatarUrl': avatarUrl,
    });
  }
}
