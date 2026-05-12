// lib/features/posts/data/datasources/post_storage_service.dart
//
// Abstract interface for Firebase Storage operations needed by
// PostRemoteDataSource.  Concrete implementation wraps FirebaseStorage;
// tests supply a mock.

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Provides byte-upload, URL-retrieval, and deletion operations without
/// coupling [PostRemoteDataSource] to [FirebaseStorage] directly.
abstract class PostStorageService {
  /// Uploads [bytes] to [path] with the given [contentType].
  Future<void> uploadBytes(String path, Uint8List bytes, String contentType);

  /// Returns the public download URL for [path].
  Future<String> getDownloadUrl(String path);

  /// Deletes the file at [path].
  ///
  /// Silently succeeds if the file does not exist.
  Future<void> delete(String path);
}

/// Production implementation backed by [FirebaseStorage].
class FirebasePostStorageService implements PostStorageService {
  /// Creates a [FirebasePostStorageService].
  const FirebasePostStorageService(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<void> uploadBytes(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    await _storage.ref(path).putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
  }

  @override
  Future<String> getDownloadUrl(String path) async {
    return _storage.ref(path).getDownloadURL();
  }

  @override
  Future<void> delete(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (_) {
      // Silently ignore — object may not exist.
    }
  }
}
