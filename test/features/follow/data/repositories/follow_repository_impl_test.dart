// test/features/follow/data/repositories/follow_repository_impl_test.dart
//
// Unit tests for FollowRepositoryImpl — covers follow(), unfollow(),
// watchIsFollowing(), watchFollowers(), and watchFollowing() to satisfy the
// ≥ 80% repository coverage threshold.
//
// Uses fake_cloud_firestore so no real Firebase instance is required.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_network/features/follow/data/repositories/follow_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FollowRepositoryImpl sut;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    sut = FollowRepositoryImpl(firestore: fakeFirestore);
  });

  // ---------------------------------------------------------------------------
  // watchIsFollowing
  // ---------------------------------------------------------------------------

  group('watchIsFollowing', () {
    test('emits false when the following doc does not exist', () async {
      final stream = sut.watchIsFollowing(
        followerId: 'uid-a',
        followeeId: 'uid-b',
      );

      expect(await stream.first, isFalse);
    });

    test('emits true after the following doc is created', () async {
      // Pre-seed the subcollection document.
      await fakeFirestore
          .collection('users')
          .doc('uid-a')
          .collection('following')
          .doc('uid-b')
          .set({'followeeId': 'uid-b'});

      final stream = sut.watchIsFollowing(
        followerId: 'uid-a',
        followeeId: 'uid-b',
      );

      expect(await stream.first, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // follow
  // ---------------------------------------------------------------------------

  group('follow()', () {
    // batch.update requires the target documents to exist in both real and
    // fake Firestore. Pre-seed both user docs before each test.
    setUp(() async {
      await fakeFirestore.collection('users').doc('uid-a').set({
        'followingCount': 2,
        'followerCount': 0,
      });
      await fakeFirestore.collection('users').doc('uid-b').set({
        'followerCount': 5,
        'followingCount': 0,
      });
    });

    test('creates users/A/following/B document', () async {
      await sut.follow(followerId: 'uid-a', followeeId: 'uid-b');

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-a')
          .collection('following')
          .doc('uid-b')
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()?['followeeId'], equals('uid-b'));
    });

    test('creates users/B/followers/A document', () async {
      await sut.follow(followerId: 'uid-a', followeeId: 'uid-b');

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-b')
          .collection('followers')
          .doc('uid-a')
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()?['followerId'], equals('uid-a'));
    });

    test('increments followingCount on follower document', () async {
      await sut.follow(followerId: 'uid-a', followeeId: 'uid-b');

      final snap =
          await fakeFirestore.collection('users').doc('uid-a').get();
      // setUp seeds followingCount = 2; follow() increments to 3.
      expect(snap.data()?['followingCount'], equals(3));
    });

    test('increments followerCount on followee document', () async {
      await sut.follow(followerId: 'uid-a', followeeId: 'uid-b');

      final snap =
          await fakeFirestore.collection('users').doc('uid-b').get();
      // setUp seeds followerCount = 5; follow() increments to 6.
      expect(snap.data()?['followerCount'], equals(6));
    });
  });

  // ---------------------------------------------------------------------------
  // watchFollowers
  // ---------------------------------------------------------------------------

  group('watchFollowers()', () {
    test('emits empty list when no followers subcollection docs exist',
        () async {
      await fakeFirestore.collection('users').doc('uid-a').set({});

      final result = await sut.watchFollowers('uid-a').first;

      expect(result, isEmpty);
    });

    test('emits FollowUserEntity for each follower doc', () async {
      // Pre-seed the user profile for the follower.
      await fakeFirestore.collection('users').doc('uid-b').set({
        'displayName': 'Bob',
        'avatarUrl': null,
      });

      // Create the follower subcollection entry.
      await fakeFirestore
          .collection('users')
          .doc('uid-a')
          .collection('followers')
          .doc('uid-b')
          .set({'followerId': 'uid-b'});

      final result = await sut.watchFollowers('uid-a').first;

      expect(result, hasLength(1));
      expect(result.first.uid, equals('uid-b'));
      expect(result.first.displayName, equals('Bob'));
    });

    test('returns empty displayName when follower user doc is missing',
        () async {
      await fakeFirestore
          .collection('users')
          .doc('uid-a')
          .collection('followers')
          .doc('uid-ghost')
          .set({'followerId': 'uid-ghost'});

      final result = await sut.watchFollowers('uid-a').first;

      expect(result, hasLength(1));
      expect(result.first.uid, equals('uid-ghost'));
      expect(result.first.displayName, equals(''));
      expect(result.first.avatarUrl, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // watchFollowing
  // ---------------------------------------------------------------------------

  group('watchFollowing()', () {
    test('emits empty list when no following subcollection docs exist',
        () async {
      await fakeFirestore.collection('users').doc('uid-a').set({});

      final result = await sut.watchFollowing('uid-a').first;

      expect(result, isEmpty);
    });

    test('emits FollowUserEntity for each following doc', () async {
      // Pre-seed the user profile for the followee.
      await fakeFirestore.collection('users').doc('uid-c').set({
        'displayName': 'Carol',
        'avatarUrl': 'https://example.com/carol.png',
      });

      // Create the following subcollection entry.
      await fakeFirestore
          .collection('users')
          .doc('uid-a')
          .collection('following')
          .doc('uid-c')
          .set({'followeeId': 'uid-c'});

      final result = await sut.watchFollowing('uid-a').first;

      expect(result, hasLength(1));
      expect(result.first.uid, equals('uid-c'));
      expect(result.first.displayName, equals('Carol'));
      expect(result.first.avatarUrl, equals('https://example.com/carol.png'));
    });

    test('returns empty displayName when following user doc is missing',
        () async {
      await fakeFirestore
          .collection('users')
          .doc('uid-a')
          .collection('following')
          .doc('uid-ghost')
          .set({'followeeId': 'uid-ghost'});

      final result = await sut.watchFollowing('uid-a').first;

      expect(result, hasLength(1));
      expect(result.first.uid, equals('uid-ghost'));
      expect(result.first.displayName, equals(''));
      expect(result.first.avatarUrl, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // unfollow
  // ---------------------------------------------------------------------------

  group('unfollow()', () {
    setUp(() async {
      // Pre-seed both subcollection docs and user counters so unfollow has
      // something to remove / decrement.
      await fakeFirestore
          .collection('users')
          .doc('uid-a')
          .collection('following')
          .doc('uid-b')
          .set({'followeeId': 'uid-b'});

      await fakeFirestore
          .collection('users')
          .doc('uid-b')
          .collection('followers')
          .doc('uid-a')
          .set({'followerId': 'uid-a'});

      await fakeFirestore.collection('users').doc('uid-a').set({
        'followingCount': 3,
        'followerCount': 0,
      });

      await fakeFirestore.collection('users').doc('uid-b').set({
        'followerCount': 7,
        'followingCount': 0,
      });
    });

    test('removes users/A/following/B document', () async {
      await sut.unfollow(followerId: 'uid-a', followeeId: 'uid-b');

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-a')
          .collection('following')
          .doc('uid-b')
          .get();

      expect(doc.exists, isFalse);
    });

    test('removes users/B/followers/A document', () async {
      await sut.unfollow(followerId: 'uid-a', followeeId: 'uid-b');

      final doc = await fakeFirestore
          .collection('users')
          .doc('uid-b')
          .collection('followers')
          .doc('uid-a')
          .get();

      expect(doc.exists, isFalse);
    });

    test('decrements followingCount on follower document', () async {
      await sut.unfollow(followerId: 'uid-a', followeeId: 'uid-b');

      final snap =
          await fakeFirestore.collection('users').doc('uid-a').get();
      expect(snap.data()?['followingCount'], equals(2));
    });

    test('decrements followerCount on followee document', () async {
      await sut.unfollow(followerId: 'uid-a', followeeId: 'uid-b');

      final snap =
          await fakeFirestore.collection('users').doc('uid-b').get();
      expect(snap.data()?['followerCount'], equals(6));
    });
  });
}
