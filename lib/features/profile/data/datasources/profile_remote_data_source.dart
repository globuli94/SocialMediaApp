// lib/features/profile/data/datasources/profile_remote_data_source.dart
//
// ProfileRemoteDataSource — Firestore and Firebase Storage operations for
// user profiles.  All Firebase SDK types are accessed through abstract
// service interfaces so that tests can supply mocktail doubles.

import 'dart:typed_data';

import 'package:social_network/features/profile/data/datasources/profile_auth_service.dart';
import 'package:social_network/features/profile/data/datasources/profile_firestore_service.dart';
import 'package:social_network/features/profile/data/datasources/profile_storage_service.dart';

/// Data source that performs Firestore and Firebase Storage operations for
/// user profiles.
///
/// This is the only layer that imports Firebase packages for profile data.
class ProfileRemoteDataSource {
  /// Creates a [ProfileRemoteDataSource].
  ProfileRemoteDataSource({
    required ProfileFirestoreService firestoreService,
    required ProfileStorageService storageService,
    required ProfileAuthService authService,
  })  : _firestoreService = firestoreService,
        _storageService = storageService,
        _authService = authService;

  final ProfileFirestoreService _firestoreService;
  final ProfileStorageService _storageService;
  final ProfileAuthService _authService;

  /// Returns the raw Firestore data for [uid].
  ///
  /// If no document exists, creates one with default values derived from the
  /// currently signed-in Firebase Auth user and returns those defaults.
  Future<Map<String, dynamic>> fetchProfile(String uid) async {
    final data = await _firestoreService.getUser(uid);

    if (data != null) {
      return data;
    }

    // Document missing — create with defaults so the profile always exists.
    final displayName = _authService.currentUserEmail?.split('@').first ?? uid;
    final defaults = <String, dynamic>{
      'uid': uid,
      'displayName': displayName,
      'bio': '',
      'avatarUrl': null,
      'postCount': 0,
    };
    await _firestoreService.createUser(uid, defaults);
    return defaults;
  }

  /// Writes [displayName] and [bio] to `users/{uid}`.
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String bio,
  }) async {
    await _firestoreService.updateUser(uid, {
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
    final path = 'avatars/$uid$extension';
    await _storageService.uploadBytes(path, bytes);
    return _storageService.getDownloadUrl(path);
  }

  /// Updates the `avatarUrl` field on `users/{uid}` in Firestore.
  Future<void> updateAvatarUrl({
    required String uid,
    required String avatarUrl,
  }) async {
    await _firestoreService.updateUser(uid, {'avatarUrl': avatarUrl});
  }
}
