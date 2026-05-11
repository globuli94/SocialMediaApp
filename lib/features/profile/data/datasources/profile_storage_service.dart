// lib/features/profile/data/datasources/profile_storage_service.dart
//
// Abstract interface for Firebase Storage operations needed by
// ProfileRemoteDataSource.  Concrete implementation wraps FirebaseStorage;
// tests supply a mock.

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Provides byte-upload and URL-retrieval operations without coupling
/// [ProfileRemoteDataSource] to FirebaseStorage directly.
abstract class ProfileStorageService {
  /// Uploads [bytes] to [path] in Firebase Storage.
  Future<void> uploadBytes(String path, Uint8List bytes);

  /// Returns the public download URL for [path].
  Future<String> getDownloadUrl(String path);
}

/// Production implementation backed by [FirebaseStorage].
class FirebaseProfileStorageService implements ProfileStorageService {
  /// Creates a [FirebaseProfileStorageService].
  const FirebaseProfileStorageService(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<void> uploadBytes(String path, Uint8List bytes) async {
    await _storage.ref(path).putData(bytes);
  }

  @override
  Future<String> getDownloadUrl(String path) async {
    return _storage.ref(path).getDownloadURL();
  }
}
