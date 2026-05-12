// lib/features/posts/data/datasources/post_firestore_service.dart
//
// Abstract interface for Firestore operations needed by PostRemoteDataSource.
// Concrete implementation wraps FirebaseFirestore; tests supply a mock.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Provides post-document CRUD operations without coupling
/// [PostRemoteDataSource] to [FirebaseFirestore] directly.
///
/// Author display name and avatar URL are stored denormalized in the post
/// document for efficient streaming — no per-post user look-up needed.
abstract class PostFirestoreService {
  /// Returns a new auto-generated document ID for the `posts` collection.
  String generatePostId();

  /// Emits a list of raw post data maps whenever the collection changes,
  /// ordered by `createdAt` descending and limited to 20 documents.
  ///
  /// Each map includes an `'id'` key set to the document ID.
  Stream<List<Map<String, dynamic>>> watchPosts();

  /// Creates a post document at `posts/{postId}` with [data].
  Future<void> createPostWithId(String postId, Map<String, dynamic> data);

  /// Deletes the post document at `posts/{postId}`.
  Future<void> deletePost(String postId);

  /// Adjusts `postCount` on `users/{uid}` by [delta] (positive = increment,
  /// negative = decrement). Uses an atomic Firestore increment.
  Future<void> adjustPostCount(String uid, int delta);

  /// Fetches a page of posts ordered by `createdAt` descending.
  /// Pass [startAfter] (a [DocumentSnapshot]) to page forward.
  Future<QuerySnapshot<Map<String, dynamic>>> fetchPostsPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 10,
  });
}

/// Production implementation backed by [FirebaseFirestore].
class FirebasePostFirestoreService implements PostFirestoreService {
  /// Creates a [FirebasePostFirestoreService].
  const FirebasePostFirestoreService(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  String generatePostId() => _firestore.collection('posts').doc().id;

  @override
  Stream<List<Map<String, dynamic>>> watchPosts() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  @override
  Future<void> createPostWithId(
    String postId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('posts').doc(postId).set(data);
  }

  @override
  Future<void> deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
  }

  @override
  Future<void> adjustPostCount(String uid, int delta) async {
    await _firestore.collection('users').doc(uid).update({
      'postCount': FieldValue.increment(delta),
    });
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> fetchPostsPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 10,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    return query.get();
  }
}
