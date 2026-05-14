// lib/features/profile/data/datasources/profile_firestore_service.dart
//
// Abstract interface for Firestore operations needed by ProfileRemoteDataSource.
// Concrete implementation wraps FirebaseFirestore; tests supply a mock.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Provides user-document CRUD operations without coupling
/// [ProfileRemoteDataSource] to FirebaseFirestore directly.
abstract class ProfileFirestoreService {
  /// Returns the raw data map for [uid], or `null` if the document does not exist.
  Future<Map<String, dynamic>?> getUser(String uid);

  /// Creates a new user document for [uid] with [data].
  Future<void> createUser(String uid, Map<String, dynamic> data);

  /// Merges [data] into the existing user document for [uid].
  Future<void> updateUser(String uid, Map<String, dynamic> data);

  /// Returns a stream that emits the raw data map for [uid] on every change,
  /// or `null` if the document does not exist.
  Stream<Map<String, dynamic>?> watchUser(String uid);
}

/// Production implementation backed by [FirebaseFirestore].
class FirebaseProfileFirestoreService implements ProfileFirestoreService {
  /// Creates a [FirebaseProfileFirestoreService].
  const FirebaseProfileFirestoreService(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    return snap.exists ? snap.data() : null;
  }

  @override
  Future<void> createUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).set(data);
  }

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  @override
  Stream<Map<String, dynamic>?> watchUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists ? snap.data() : null);
  }
}
