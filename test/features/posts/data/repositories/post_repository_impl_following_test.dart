// test/features/posts/data/repositories/post_repository_impl_following_test.dart
//
// Unit tests for PostRepositoryImpl.watchFollowingFeed — covers the following
// feed stream that switches between filtered posts (when user follows others)
// and all posts (when following list is empty).
//
// Uses FakeFirebaseFirestore to simulate Firestore without hitting real
// Firebase. Firestore operations and document snapshots remain in-memory.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/posts/data/repositories/post_repository_impl.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';

// ---------------------------------------------------------------------------
// Mocks & fakes
// ---------------------------------------------------------------------------

class MockFirebaseStorage extends Mock implements FirebaseStorage {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseStorage mockStorage;
  late PostRepositoryImpl sut;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    mockStorage = MockFirebaseStorage();
    sut = PostRepositoryImpl(
      firestore: fakeFirestore,
      storage: mockStorage,
    );
  });

  group('watchFollowingFeed', () {
    // -----------------------------------------------------------------------
    // AC 1: Empty following list → all posts ordered by recency
    // -----------------------------------------------------------------------

    test('returns all posts ordered by createdAt desc when following is empty',
        () async {
      // Create test posts with different timestamps
      final older = Timestamp.fromDate(DateTime(2026, 1, 1));
      final newer = Timestamp.fromDate(DateTime(2026, 1, 2));

      await fakeFirestore.collection('posts').doc('post-alice-old').set({
        'id': 'post-alice-old',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Alice older post',
        'createdAt': older,
        'likeCount': 0,
      });

      await fakeFirestore.collection('posts').doc('post-bob-new').set({
        'id': 'post-bob-new',
        'authorUid': 'uid-bob',
        'authorDisplayName': 'Bob',
        'content': 'Bob newer post',
        'createdAt': newer,
        'likeCount': 0,
      });

      // User uid-me has no following list at all
      final result = await sut.watchFollowingFeed('uid-me').first;

      // Should return all posts
      expect(result, hasLength(2));
      // Should be ordered newest-first
      expect(result.first.id, 'post-bob-new');
      expect(result.last.id, 'post-alice-old');
    });

    test(
        'returns empty list when following is empty and no posts in collection',
        () async {
      // No posts, no following — should return empty list
      final result = await sut.watchFollowingFeed('uid-me').first;
      expect(result, isEmpty);
    });

    test('empty following list has all-posts fallback behavior', () async {
      // Add one post
      await fakeFirestore.collection('posts').doc('post-1').set({
        'id': 'post-1',
        'authorUid': 'uid-author',
        'authorDisplayName': 'Author',
        'content': 'Some post',
        'createdAt': Timestamp.now(),
        'likeCount': 0,
      });

      // User has empty following list (document exists but with no following entries)
      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('following')
          .doc('placeholder')
          .set({}, SetOptions(merge: true));
      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('following')
          .doc('placeholder')
          .delete();

      final result = await sut.watchFollowingFeed('uid-me').first;

      // Should show all posts
      expect(result, hasLength(1));
      expect(result.first.id, 'post-1');
    });

    // -----------------------------------------------------------------------
    // AC 2: Non-empty following list → only posts from followed users
    // -----------------------------------------------------------------------

    test(
        'returns only posts from followed users when following list is non-empty',
        () async {
      final ts = Timestamp.now();

      // Create posts from different authors
      await fakeFirestore.collection('posts').doc('alice-post').set({
        'id': 'alice-post',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Alice post',
        'createdAt': ts,
        'likeCount': 0,
      });

      await fakeFirestore.collection('posts').doc('bob-post').set({
        'id': 'bob-post',
        'authorUid': 'uid-bob',
        'authorDisplayName': 'Bob',
        'content': 'Bob post',
        'createdAt': ts,
        'likeCount': 0,
      });

      await fakeFirestore.collection('posts').doc('charlie-post').set({
        'id': 'charlie-post',
        'authorUid': 'uid-charlie',
        'authorDisplayName': 'Charlie',
        'content': 'Charlie post',
        'createdAt': ts,
        'likeCount': 0,
      });

      // User uid-me follows alice and bob, but not charlie
      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('following')
          .doc('uid-alice')
          .set({
        'followeeId': 'uid-alice',
        'createdAt': ts,
      });

      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('following')
          .doc('uid-bob')
          .set({
        'followeeId': 'uid-bob',
        'createdAt': ts,
      });

      final result = await sut.watchFollowingFeed('uid-me').first;

      // Should show only posts from alice and bob
      expect(result, hasLength(2));
      final ids = result.map((p) => p.id).toSet();
      expect(ids, containsAll(['alice-post', 'bob-post']));
      expect(ids, isNot(contains('charlie-post')));
    });

    test('filters by exact followeeId match (not substring)', () async {
      final ts = Timestamp.now();

      // Create posts from users with similar UIDs
      await fakeFirestore.collection('posts').doc('post-1').set({
        'id': 'post-1',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Content',
        'createdAt': ts,
        'likeCount': 0,
      });

      await fakeFirestore.collection('posts').doc('post-2').set({
        'id': 'post-2',
        'authorUid': 'uid-alice-friend',
        'authorDisplayName': 'Alice Friend',
        'content': 'Content',
        'createdAt': ts,
        'likeCount': 0,
      });

      // User follows only uid-alice
      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('following')
          .doc('uid-alice')
          .set({
        'followeeId': 'uid-alice',
        'createdAt': ts,
      });

      final result = await sut.watchFollowingFeed('uid-me').first;

      // Should only show posts from uid-alice, not uid-alice-friend
      expect(result, hasLength(1));
      expect(result.first.id, 'post-1');
    });

    // -----------------------------------------------------------------------
    // AC 3: Automatic switching between modes
    // -----------------------------------------------------------------------

    test(
        'emits new stream when following list changes (switches from all to filtered)',
        () async {
      final ts1 = Timestamp.fromDate(DateTime(2026, 1, 1));
      final ts2 = Timestamp.fromDate(DateTime(2026, 1, 2));

      // Create posts from different authors
      await fakeFirestore.collection('posts').doc('alice-post').set({
        'id': 'alice-post',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Alice post',
        'createdAt': ts2,
        'likeCount': 0,
      });

      await fakeFirestore.collection('posts').doc('bob-post').set({
        'id': 'bob-post',
        'authorUid': 'uid-bob',
        'authorDisplayName': 'Bob',
        'content': 'Bob post',
        'createdAt': ts1,
        'likeCount': 0,
      });

      // Listen to the stream
      final stream = sut.watchFollowingFeed('uid-me');
      final emissions = [];

      final subscription = stream.listen((posts) {
        emissions.add(posts.map((p) => p.id).toSet());
      });

      // Initially should emit all posts (empty following)
      await Future.delayed(const Duration(milliseconds: 100));
      expect(emissions.length, greaterThan(0));
      expect(emissions.first, hasLength(2));

      // Now user follows alice — should switch to filtered
      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('following')
          .doc('uid-alice')
          .set({
        'followeeId': 'uid-alice',
        'createdAt': ts1,
      });

      await Future.delayed(const Duration(milliseconds: 100));

      // Should have emitted a new event with only alice's post
      expect(emissions.length, greaterThan(1));
      expect(emissions.last, {'alice-post'});

      await subscription.cancel();
    });

    test('switches from filtered back to all when last following is removed',
        () async {
      final ts = Timestamp.now();

      // Create posts
      await fakeFirestore.collection('posts').doc('alice-post').set({
        'id': 'alice-post',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Alice post',
        'createdAt': ts,
        'likeCount': 0,
      });

      await fakeFirestore.collection('posts').doc('bob-post').set({
        'id': 'bob-post',
        'authorUid': 'uid-bob',
        'authorDisplayName': 'Bob',
        'content': 'Bob post',
        'createdAt': ts,
        'likeCount': 0,
      });

      // User starts following alice
      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('following')
          .doc('uid-alice')
          .set({
        'followeeId': 'uid-alice',
        'createdAt': ts,
      });

      final stream = sut.watchFollowingFeed('uid-me');
      final emissions = [];

      final subscription = stream.listen((posts) {
        emissions.add(posts.map((p) => p.id).toSet());
      });

      // Initially should emit only alice's post
      await Future.delayed(const Duration(milliseconds: 100));
      expect(emissions.first, {'alice-post'});

      // Now unfollow alice (remove the following entry)
      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('following')
          .doc('uid-alice')
          .delete();

      await Future.delayed(const Duration(milliseconds: 100));

      // Should switch back to all posts
      expect(emissions.length, greaterThan(1));
      expect(emissions.last, hasLength(2));

      await subscription.cancel();
    });

    // -----------------------------------------------------------------------
    // AC 4: Posts ordered by recency in both modes
    // -----------------------------------------------------------------------

    test('orders posts by createdAt desc when showing filtered posts',
        () async {
      final old = Timestamp.fromDate(DateTime(2026, 1, 1));
      final mid = Timestamp.fromDate(DateTime(2026, 1, 2));
      final new_ = Timestamp.fromDate(DateTime(2026, 1, 3));

      // Create posts in mixed order
      await fakeFirestore.collection('posts').doc('post-new').set({
        'id': 'post-new',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Newest',
        'createdAt': new_,
        'likeCount': 0,
      });

      await fakeFirestore.collection('posts').doc('post-old').set({
        'id': 'post-old',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Oldest',
        'createdAt': old,
        'likeCount': 0,
      });

      await fakeFirestore.collection('posts').doc('post-mid').set({
        'id': 'post-mid',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Middle',
        'createdAt': mid,
        'likeCount': 0,
      });

      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('following')
          .doc('uid-alice')
          .set({
        'followeeId': 'uid-alice',
        'createdAt': Timestamp.now(),
      });

      final result = await sut.watchFollowingFeed('uid-me').first;

      // Should be ordered newest-first
      expect(result.map((p) => p.id), ['post-new', 'post-mid', 'post-old']);
    });

    // -----------------------------------------------------------------------
    // AC 5: Feed updates immediately after follow/unfollow (no manual refresh)
    // -----------------------------------------------------------------------

    test(
        'emits updated posts immediately after follow without manual refresh',
        () async {
      final ts = Timestamp.now();

      // Create posts from alice and bob
      await fakeFirestore.collection('posts').doc('alice-post').set({
        'id': 'alice-post',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Content',
        'createdAt': ts,
        'likeCount': 0,
      });

      await fakeFirestore.collection('posts').doc('bob-post').set({
        'id': 'bob-post',
        'authorUid': 'uid-bob',
        'authorDisplayName': 'Bob',
        'content': 'Content',
        'createdAt': ts,
        'likeCount': 0,
      });

      final stream = sut.watchFollowingFeed('uid-me');
      final emissions = [];

      final subscription = stream.listen((posts) {
        emissions.add(posts.map((p) => p.id).toSet());
      });

      // Initially empty following → all posts
      await Future.delayed(const Duration(milliseconds: 50));
      final initialCount = emissions.length;

      // Follow alice
      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('following')
          .doc('uid-alice')
          .set({
        'followeeId': 'uid-alice',
        'createdAt': ts,
      });

      // Wait a bit for stream to emit
      await Future.delayed(const Duration(milliseconds: 100));

      // Should have emitted a new event without manual refresh
      expect(emissions.length, greaterThan(initialCount));
      expect(emissions.last, {'alice-post'});

      await subscription.cancel();
    });

    test(
        'emits updated posts immediately after unfollow without manual refresh',
        () async {
      final ts = Timestamp.now();

      // Create posts
      await fakeFirestore.collection('posts').doc('alice-post').set({
        'id': 'alice-post',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Content',
        'createdAt': ts,
        'likeCount': 0,
      });

      await fakeFirestore.collection('posts').doc('bob-post').set({
        'id': 'bob-post',
        'authorUid': 'uid-bob',
        'authorDisplayName': 'Bob',
        'content': 'Content',
        'createdAt': ts,
        'likeCount': 0,
      });

      // User follows alice
      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('following')
          .doc('uid-alice')
          .set({
        'followeeId': 'uid-alice',
        'createdAt': ts,
      });

      final stream = sut.watchFollowingFeed('uid-me');
      final emissions = [];

      final subscription = stream.listen((posts) {
        emissions.add(posts.map((p) => p.id).toSet());
      });

      // Initially should show only alice's post
      await Future.delayed(const Duration(milliseconds: 50));
      final initialCount = emissions.length;

      // Unfollow alice
      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('following')
          .doc('uid-alice')
          .delete();

      await Future.delayed(const Duration(milliseconds: 100));

      // Should have emitted a new event with all posts
      expect(emissions.length, greaterThan(initialCount));
      expect(emissions.last, hasLength(2));

      await subscription.cancel();
    });
  });
}
