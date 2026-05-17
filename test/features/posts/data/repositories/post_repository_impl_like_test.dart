// test/features/posts/data/repositories/post_repository_impl_like_test.dart
//
// Unit tests for PostRepositoryImpl like/unlike methods — covers likePost,
// unlikePost, and watchPostLiked to satisfy the ≥ 80% repository coverage
// threshold for the like feature.
//
// Acceptance criteria verified (SOCAA-215):
//   AC2 — likePost atomically creates like document and increments likeCount
//   AC3 — unlikePost atomically removes like document and decrements likeCount
//   AC5 — watchPostLiked returns correct Stream<bool> from Firestore
//
// Firestore operations are exercised against FakeFirebaseFirestore so that
// sealed Firestore types remain in-memory without hitting real Firebase.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/posts/data/repositories/post_repository_impl.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFirebaseStorage extends Mock implements FirebaseStorage {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Seeds a post document in [firestore] with the given [postId] and
/// [likeCount] so like/unlike operations have a real document to update.
Future<void> _seedPost(
  FakeFirebaseFirestore firestore, {
  required String postId,
  int likeCount = 0,
}) async {
  await firestore.collection('posts').doc(postId).set({
    'id': postId,
    'authorUid': 'uid-alice',
    'authorDisplayName': 'Alice',
    'content': 'Test post',
    'createdAt': Timestamp.now(),
    'likeCount': likeCount,
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseStorage mockStorage;
  late PostRepositoryImpl sut;

  setUpAll(() {
    registerFallbackValue(SettableMetadata());
  });

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    mockStorage = MockFirebaseStorage();
    sut = PostRepositoryImpl(
      firestore: fakeFirestore,
      storage: mockStorage,
    );
    // Seed a test user document
    await fakeFirestore.collection('users').doc('uid-alice').set({
      'postCount': 0,
    });
  });

  // -------------------------------------------------------------------------
  // likePost — AC2
  // -------------------------------------------------------------------------

  group('likePost', () {
    test(
        'creates a like document in posts/{postId}/likes/{userId}',
        () async {
      await _seedPost(fakeFirestore, postId: 'p1');

      await sut.likePost('p1', 'uid-me');

      final likeDoc = await fakeFirestore
          .collection('posts')
          .doc('p1')
          .collection('likes')
          .doc('uid-me')
          .get();

      expect(likeDoc.exists, isTrue);
    });

    test('increments likeCount on the post document', () async {
      await _seedPost(fakeFirestore, postId: 'p2', likeCount: 3);

      await sut.likePost('p2', 'uid-me');

      final postSnap =
          await fakeFirestore.collection('posts').doc('p2').get();
      expect(postSnap.data()?['likeCount'], 4);
    });

    test('like document contains userId field', () async {
      await _seedPost(fakeFirestore, postId: 'p3');

      await sut.likePost('p3', 'uid-me');

      final likeDoc = await fakeFirestore
          .collection('posts')
          .doc('p3')
          .collection('likes')
          .doc('uid-me')
          .get();

      expect(likeDoc.data()?['userId'], 'uid-me');
    });

    test('like document contains a createdAt timestamp', () async {
      await _seedPost(fakeFirestore, postId: 'p4');

      await sut.likePost('p4', 'uid-me');

      final likeDoc = await fakeFirestore
          .collection('posts')
          .doc('p4')
          .collection('likes')
          .doc('uid-me')
          .get();

      expect(likeDoc.data()?['createdAt'], isNotNull);
    });

    test('stores like under the correct userId document ID', () async {
      await _seedPost(fakeFirestore, postId: 'p5');

      await sut.likePost('p5', 'uid-alice');

      final likeDoc = await fakeFirestore
          .collection('posts')
          .doc('p5')
          .collection('likes')
          .doc('uid-alice')
          .get();
      expect(likeDoc.exists, isTrue);

      // A different user's like document should not exist
      final otherLike = await fakeFirestore
          .collection('posts')
          .doc('p5')
          .collection('likes')
          .doc('uid-bob')
          .get();
      expect(otherLike.exists, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // unlikePost — AC3
  // -------------------------------------------------------------------------

  group('unlikePost', () {
    test(
        'removes the like document from posts/{postId}/likes/{userId}',
        () async {
      await _seedPost(fakeFirestore, postId: 'q1', likeCount: 1);
      await fakeFirestore
          .collection('posts')
          .doc('q1')
          .collection('likes')
          .doc('uid-me')
          .set({'userId': 'uid-me', 'createdAt': Timestamp.now()});

      await sut.unlikePost('q1', 'uid-me');

      final likeDoc = await fakeFirestore
          .collection('posts')
          .doc('q1')
          .collection('likes')
          .doc('uid-me')
          .get();

      expect(likeDoc.exists, isFalse);
    });

    test('decrements likeCount on the post document', () async {
      await _seedPost(fakeFirestore, postId: 'q2', likeCount: 5);
      await fakeFirestore
          .collection('posts')
          .doc('q2')
          .collection('likes')
          .doc('uid-me')
          .set({'userId': 'uid-me', 'createdAt': Timestamp.now()});

      await sut.unlikePost('q2', 'uid-me');

      final postSnap =
          await fakeFirestore.collection('posts').doc('q2').get();
      expect(postSnap.data()?['likeCount'], 4);
    });

    test('unlike only removes the specified user\'s like document', () async {
      await _seedPost(fakeFirestore, postId: 'q3', likeCount: 2);
      // Two users have liked the post
      await fakeFirestore
          .collection('posts')
          .doc('q3')
          .collection('likes')
          .doc('uid-me')
          .set({'userId': 'uid-me', 'createdAt': Timestamp.now()});
      await fakeFirestore
          .collection('posts')
          .doc('q3')
          .collection('likes')
          .doc('uid-other')
          .set({'userId': 'uid-other', 'createdAt': Timestamp.now()});

      await sut.unlikePost('q3', 'uid-me');

      // uid-me's like is gone
      final removedLike = await fakeFirestore
          .collection('posts')
          .doc('q3')
          .collection('likes')
          .doc('uid-me')
          .get();
      expect(removedLike.exists, isFalse);

      // uid-other's like remains
      final remainingLike = await fakeFirestore
          .collection('posts')
          .doc('q3')
          .collection('likes')
          .doc('uid-other')
          .get();
      expect(remainingLike.exists, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // watchPostLiked — AC5: stream returns correct like state from Firestore
  // -------------------------------------------------------------------------

  group('watchPostLiked', () {
    test('emits false when like document does not exist', () async {
      await _seedPost(fakeFirestore, postId: 'w1');

      final result = await sut.watchPostLiked('w1', 'uid-me').first;
      expect(result, isFalse);
    });

    test('emits true when like document exists for the given userId', () async {
      await _seedPost(fakeFirestore, postId: 'w2');
      await fakeFirestore
          .collection('posts')
          .doc('w2')
          .collection('likes')
          .doc('uid-me')
          .set({'userId': 'uid-me', 'createdAt': Timestamp.now()});

      final result = await sut.watchPostLiked('w2', 'uid-me').first;
      expect(result, isTrue);
    });

    test('emits false for a different user\'s like document', () async {
      await _seedPost(fakeFirestore, postId: 'w3');
      // A different user has liked the post
      await fakeFirestore
          .collection('posts')
          .doc('w3')
          .collection('likes')
          .doc('uid-other')
          .set({'userId': 'uid-other', 'createdAt': Timestamp.now()});

      final result = await sut.watchPostLiked('w3', 'uid-me').first;
      expect(result, isFalse);
    });

    test('returns a Stream<bool>', () {
      final stream = sut.watchPostLiked('w4', 'uid-me');
      expect(stream, isA<Stream<bool>>());
    });
  });
}
