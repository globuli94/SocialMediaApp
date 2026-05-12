// test/features/posts/data/datasources/post_firestore_service_test.dart
//
// Unit tests for FirebasePostFirestoreService — all five public methods
// are exercised against an in-memory FakeFirebaseFirestore so that sealed
// Firestore types (Query, DocumentReference, etc.) remain testable without
// hitting real Firebase.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_network/features/posts/data/datasources/post_firestore_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirebasePostFirestoreService sut;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    sut = FirebasePostFirestoreService(fakeFirestore);
  });

  // -------------------------------------------------------------------------
  // generatePostId
  // -------------------------------------------------------------------------

  group('generatePostId', () {
    test('returns a non-empty string', () {
      final id = sut.generatePostId();
      expect(id, isNotEmpty);
    });

    test('returns a unique ID on every call', () {
      final id1 = sut.generatePostId();
      final id2 = sut.generatePostId();
      expect(id1, isNot(equals(id2)));
    });
  });

  // -------------------------------------------------------------------------
  // createPostWithId + watchPosts
  // -------------------------------------------------------------------------

  group('createPostWithId', () {
    test('stores document so watchPosts emits it', () async {
      final ts = Timestamp.fromDate(DateTime(2026, 5, 1));
      await sut.createPostWithId('post-1', {
        'id': 'post-1',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Hello',
        'createdAt': ts,
        'likeCount': 0,
      });

      final snap = await fakeFirestore.collection('posts').doc('post-1').get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['content'], 'Hello');
    });
  });

  // -------------------------------------------------------------------------
  // watchPosts
  // -------------------------------------------------------------------------

  group('watchPosts', () {
    test('emits empty list when collection is empty', () async {
      final result = await sut.watchPosts().first;
      expect(result, isEmpty);
    });

    test('emits post maps with id key injected', () async {
      final ts = Timestamp.fromDate(DateTime(2026, 5, 1));
      await fakeFirestore.collection('posts').doc('p1').set({
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'First',
        'createdAt': ts,
        'likeCount': 0,
      });

      final result = await sut.watchPosts().first;

      expect(result, hasLength(1));
      expect(result.first['id'], 'p1');
      expect(result.first['content'], 'First');
    });

    test('emits posts ordered by createdAt descending', () async {
      final older = Timestamp.fromDate(DateTime(2026, 1, 1));
      final newer = Timestamp.fromDate(DateTime(2026, 6, 1));

      await fakeFirestore.collection('posts').doc('old').set({
        'authorUid': 'uid-a',
        'authorDisplayName': 'A',
        'content': 'Old',
        'createdAt': older,
        'likeCount': 0,
      });
      await fakeFirestore.collection('posts').doc('new').set({
        'authorUid': 'uid-b',
        'authorDisplayName': 'B',
        'content': 'New',
        'createdAt': newer,
        'likeCount': 0,
      });

      final result = await sut.watchPosts().first;

      expect(result.first['id'], 'new');
      expect(result.last['id'], 'old');
    });

    test('includes imageUrl in map when present', () async {
      final ts = Timestamp.fromDate(DateTime(2026, 5, 1));
      await fakeFirestore.collection('posts').doc('p-img').set({
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Has image',
        'createdAt': ts,
        'likeCount': 0,
        'imageUrl': 'https://example.com/img.jpg',
      });

      final result = await sut.watchPosts().first;
      expect(result.single['imageUrl'], 'https://example.com/img.jpg');
    });
  });

  // -------------------------------------------------------------------------
  // deletePost
  // -------------------------------------------------------------------------

  group('deletePost', () {
    test('removes document from collection', () async {
      await fakeFirestore.collection('posts').doc('to-delete').set({
        'content': 'Goodbye',
        'createdAt': Timestamp.now(),
      });

      await sut.deletePost('to-delete');

      final snap =
          await fakeFirestore.collection('posts').doc('to-delete').get();
      expect(snap.exists, isFalse);
    });

    test('completes without error when document does not exist', () async {
      await expectLater(sut.deletePost('ghost-doc'), completes);
    });
  });

  // -------------------------------------------------------------------------
  // adjustPostCount
  // -------------------------------------------------------------------------

  group('adjustPostCount', () {
    test('increments postCount by positive delta', () async {
      await fakeFirestore
          .collection('users')
          .doc('uid-alice')
          .set({'postCount': 3});

      await sut.adjustPostCount('uid-alice', 1);

      final doc =
          await fakeFirestore.collection('users').doc('uid-alice').get();
      expect(doc.data()!['postCount'], 4);
    });

    test('decrements postCount by negative delta', () async {
      await fakeFirestore
          .collection('users')
          .doc('uid-bob')
          .set({'postCount': 5});

      await sut.adjustPostCount('uid-bob', -1);

      final doc =
          await fakeFirestore.collection('users').doc('uid-bob').get();
      expect(doc.data()!['postCount'], 4);
    });
  });
}
