// test/features/likes/data/repositories/like_repository_impl_test.dart
//
// Unit tests for LikeRepositoryImpl — verifies acceptance criteria from
// SOCAA-203: like/unlike toggling, like-count persistence, watchIsLiked stream,
// watchLikeCount stream, and multi-post independence.
//
// Firestore is exercised against FakeFirebaseFirestore so no real Firebase
// connection is required and sealed internal types are kept in-memory.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_network/features/likes/data/repositories/like_repository_impl.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late LikeRepositoryImpl sut;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    sut = LikeRepositoryImpl(firestore: fakeFirestore);

    // Seed a test post document so batch.update on likeCount doesn't throw in
    // fake_cloud_firestore (mirrors real Firestore's not-found behaviour).
    await fakeFirestore.collection('posts').doc('post-abc').set({
      'id': 'post-abc',
      'authorUid': 'uid-alice',
      'content': 'Test post',
      'likeCount': 0,
      'createdAt': Timestamp.now(),
    });
    await fakeFirestore.collection('posts').doc('post-xyz').set({
      'id': 'post-xyz',
      'authorUid': 'uid-bob',
      'content': 'Another post',
      'likeCount': 3,
      'createdAt': Timestamp.now(),
    });
  });

  // -------------------------------------------------------------------------
  // watchIsLiked
  // -------------------------------------------------------------------------

  group('watchIsLiked (AC: outlined heart when not liked, filled when liked)', () {
    test('returns false when user has NOT liked the post', () async {
      final result = await sut
          .watchIsLiked(postId: 'post-abc', userId: 'uid-alice')
          .first;

      expect(result, isFalse);
    });

    test('returns true after user likes the post', () async {
      // Add the like document directly to simulate a prior like.
      await fakeFirestore
          .collection('posts')
          .doc('post-abc')
          .collection('likes')
          .doc('uid-alice')
          .set({'userId': 'uid-alice', 'createdAt': Timestamp.now()});

      final result = await sut
          .watchIsLiked(postId: 'post-abc', userId: 'uid-alice')
          .first;

      expect(result, isTrue);
    });

    test('emits false → true stream update when like is added', () async {
      final stream = sut.watchIsLiked(postId: 'post-abc', userId: 'uid-alice');
      final values = <bool>[];
      final sub = stream.listen(values.add);

      // Trigger a like write
      await fakeFirestore
          .collection('posts')
          .doc('post-abc')
          .collection('likes')
          .doc('uid-alice')
          .set({'userId': 'uid-alice', 'createdAt': Timestamp.now()});

      await Future<void>.delayed(const Duration(milliseconds: 100));
      await sub.cancel();

      expect(values, contains(true));
    });

    test('like state is independent for different users on the same post', () async {
      await fakeFirestore
          .collection('posts')
          .doc('post-abc')
          .collection('likes')
          .doc('uid-alice')
          .set({'userId': 'uid-alice', 'createdAt': Timestamp.now()});

      final aliceLiked = await sut
          .watchIsLiked(postId: 'post-abc', userId: 'uid-alice')
          .first;
      final bobLiked = await sut
          .watchIsLiked(postId: 'post-abc', userId: 'uid-bob')
          .first;

      expect(aliceLiked, isTrue);
      expect(bobLiked, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // watchLikeCount
  // -------------------------------------------------------------------------

  group('watchLikeCount (AC: likeCount displayed and updates immediately)', () {
    test('returns 0 when post has no likes', () async {
      final count = await sut.watchLikeCount(postId: 'post-abc').first;
      expect(count, 0);
    });

    test('returns the existing likeCount from the post document', () async {
      final count = await sut.watchLikeCount(postId: 'post-xyz').first;
      expect(count, 3);
    });

    test('returns 0 when likeCount field is missing', () async {
      await fakeFirestore.collection('posts').doc('post-no-count').set({
        'id': 'post-no-count',
        'content': 'No count field',
      });

      final count =
          await sut.watchLikeCount(postId: 'post-no-count').first;
      expect(count, 0);
    });

    test('like count is independent per post (AC: multiple posts)', () async {
      final abcCount = await sut.watchLikeCount(postId: 'post-abc').first;
      final xyzCount = await sut.watchLikeCount(postId: 'post-xyz').first;

      expect(abcCount, 0);
      expect(xyzCount, 3);
    });
  });

  // -------------------------------------------------------------------------
  // toggleLike — like path (not liked → liked)
  // -------------------------------------------------------------------------

  group('toggleLike — like path (AC: tapping Like increments likeCount by 1)', () {
    test('creates like document and returns true (now liked)', () async {
      final result = await sut.toggleLike(
        postId: 'post-abc',
        userId: 'uid-alice',
      );

      expect(result, isTrue);

      final likeDoc = await fakeFirestore
          .collection('posts')
          .doc('post-abc')
          .collection('likes')
          .doc('uid-alice')
          .get();
      expect(likeDoc.exists, isTrue);
    });

    test('increments likeCount by 1 in Firestore', () async {
      await sut.toggleLike(postId: 'post-abc', userId: 'uid-alice');

      final postSnap =
          await fakeFirestore.collection('posts').doc('post-abc').get();
      expect(postSnap.data()?['likeCount'], 1);
    });

    test('like document contains userId field', () async {
      await sut.toggleLike(postId: 'post-abc', userId: 'uid-alice');

      final likeDoc = await fakeFirestore
          .collection('posts')
          .doc('post-abc')
          .collection('likes')
          .doc('uid-alice')
          .get();
      expect(likeDoc.data()?['userId'], 'uid-alice');
    });

    test('like state persists in Firestore after toggle '
        '(AC: like state persists across app restart)', () async {
      await sut.toggleLike(postId: 'post-abc', userId: 'uid-alice');

      // Re-query to simulate app restart reading from Firestore
      final likeDoc = await fakeFirestore
          .collection('posts')
          .doc('post-abc')
          .collection('likes')
          .doc('uid-alice')
          .get();
      expect(likeDoc.exists, isTrue);

      final postSnap =
          await fakeFirestore.collection('posts').doc('post-abc').get();
      expect(postSnap.data()?['likeCount'], 1);
    });
  });

  // -------------------------------------------------------------------------
  // toggleLike — unlike path (liked → not liked)
  // -------------------------------------------------------------------------

  group('toggleLike — unlike path (AC: tapping Unlike decrements likeCount by 1)', () {
    setUp(() async {
      // Pre-seed an existing like
      await fakeFirestore
          .collection('posts')
          .doc('post-abc')
          .collection('likes')
          .doc('uid-alice')
          .set({'userId': 'uid-alice', 'createdAt': Timestamp.now()});
      await fakeFirestore.collection('posts').doc('post-abc').update({
        'likeCount': 1,
      });
    });

    test('removes like document and returns false (now unliked)', () async {
      final result = await sut.toggleLike(
        postId: 'post-abc',
        userId: 'uid-alice',
      );

      expect(result, isFalse);

      final likeDoc = await fakeFirestore
          .collection('posts')
          .doc('post-abc')
          .collection('likes')
          .doc('uid-alice')
          .get();
      expect(likeDoc.exists, isFalse);
    });

    test('decrements likeCount by 1 in Firestore', () async {
      await sut.toggleLike(postId: 'post-abc', userId: 'uid-alice');

      final postSnap =
          await fakeFirestore.collection('posts').doc('post-abc').get();
      expect(postSnap.data()?['likeCount'], 0);
    });

    test('unlike state persists in Firestore after toggle '
        '(AC: like state persists across app restart)', () async {
      await sut.toggleLike(postId: 'post-abc', userId: 'uid-alice');

      // Re-query to simulate app restart
      final likeDoc = await fakeFirestore
          .collection('posts')
          .doc('post-abc')
          .collection('likes')
          .doc('uid-alice')
          .get();
      expect(likeDoc.exists, isFalse);

      final postSnap =
          await fakeFirestore.collection('posts').doc('post-abc').get();
      expect(postSnap.data()?['likeCount'], 0);
    });
  });

  // -------------------------------------------------------------------------
  // Multi-post independence
  // -------------------------------------------------------------------------

  group('multi-post independence (AC: like state correct for multiple posts)', () {
    test('liking post-abc does not affect post-xyz', () async {
      await sut.toggleLike(postId: 'post-abc', userId: 'uid-alice');

      final abcLike = await fakeFirestore
          .collection('posts')
          .doc('post-abc')
          .collection('likes')
          .doc('uid-alice')
          .get();
      final xyzLike = await fakeFirestore
          .collection('posts')
          .doc('post-xyz')
          .collection('likes')
          .doc('uid-alice')
          .get();

      expect(abcLike.exists, isTrue);
      expect(xyzLike.exists, isFalse);
    });

    test('likeCount increments only for the toggled post', () async {
      await sut.toggleLike(postId: 'post-abc', userId: 'uid-alice');

      final abcSnap =
          await fakeFirestore.collection('posts').doc('post-abc').get();
      final xyzSnap =
          await fakeFirestore.collection('posts').doc('post-xyz').get();

      expect(abcSnap.data()?['likeCount'], 1);
      expect(xyzSnap.data()?['likeCount'], 3); // unchanged
    });
  });
}
