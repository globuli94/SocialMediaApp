// test/features/follow/data/repositories/follow_repository_impl_test.dart
//
// Unit tests for FollowRepositoryImpl — covers follow(), unfollow(), and
// watchIsFollowing() to satisfy the ≥ 80% repository coverage threshold.
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

  // ---------------------------------------------------------------------------
  // getFollowers
  // ---------------------------------------------------------------------------

  group('getFollowers()', () {
    test('returns empty list when user has no followers', () async {
      final result = await sut.getFollowers('uid-target');
      expect(result, isEmpty);
    });

    test('returns UserProfileEntity list for each follower', () async {
      // Seed follower subcollection entry.
      await fakeFirestore
          .collection('users')
          .doc('uid-target')
          .collection('followers')
          .doc('uid-a')
          .set({'followerId': 'uid-a'});

      // Seed the follower's profile document.
      await fakeFirestore.collection('users').doc('uid-a').set({
        'displayName': 'Alice',
        'bio': 'Hello',
        'avatarUrl': null,
        'postCount': 3,
        'followerCount': 10,
        'followingCount': 5,
      });

      final result = await sut.getFollowers('uid-target');

      expect(result, hasLength(1));
      expect(result.first.uid, equals('uid-a'));
      expect(result.first.displayName, equals('Alice'));
      expect(result.first.bio, equals('Hello'));
      expect(result.first.postCount, equals(3));
      expect(result.first.followerCount, equals(10));
      expect(result.first.followingCount, equals(5));
    });

    test('returns multiple followers when subcollection has multiple docs',
        () async {
      for (final id in ['uid-a', 'uid-b']) {
        await fakeFirestore
            .collection('users')
            .doc('uid-target')
            .collection('followers')
            .doc(id)
            .set({'followerId': id});

        await fakeFirestore.collection('users').doc(id).set({
          'displayName': 'User $id',
          'bio': '',
          'postCount': 0,
          'followerCount': 0,
          'followingCount': 0,
        });
      }

      final result = await sut.getFollowers('uid-target');
      expect(result, hasLength(2));
    });

    test('skips follower entry when user profile doc does not exist', () async {
      // Follower subcollection entry points to a non-existent user doc.
      await fakeFirestore
          .collection('users')
          .doc('uid-target')
          .collection('followers')
          .doc('uid-ghost')
          .set({'followerId': 'uid-ghost'});

      final result = await sut.getFollowers('uid-target');
      expect(result, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // getFollowing
  // ---------------------------------------------------------------------------

  group('getFollowing()', () {
    test('returns empty list when user follows nobody', () async {
      final result = await sut.getFollowing('uid-target');
      expect(result, isEmpty);
    });

    test('returns UserProfileEntity list for each followed user', () async {
      // Seed following subcollection entry.
      await fakeFirestore
          .collection('users')
          .doc('uid-target')
          .collection('following')
          .doc('uid-b')
          .set({'followeeId': 'uid-b'});

      // Seed the followee's profile document.
      await fakeFirestore.collection('users').doc('uid-b').set({
        'displayName': 'Bob',
        'bio': 'Developer',
        'avatarUrl': null,
        'postCount': 7,
        'followerCount': 20,
        'followingCount': 2,
      });

      final result = await sut.getFollowing('uid-target');

      expect(result, hasLength(1));
      expect(result.first.uid, equals('uid-b'));
      expect(result.first.displayName, equals('Bob'));
      expect(result.first.bio, equals('Developer'));
      expect(result.first.postCount, equals(7));
      expect(result.first.followerCount, equals(20));
      expect(result.first.followingCount, equals(2));
    });

    test('returns multiple followed users when subcollection has multiple docs',
        () async {
      for (final id in ['uid-c', 'uid-d']) {
        await fakeFirestore
            .collection('users')
            .doc('uid-target')
            .collection('following')
            .doc(id)
            .set({'followeeId': id});

        await fakeFirestore.collection('users').doc(id).set({
          'displayName': 'User $id',
          'bio': '',
          'postCount': 0,
          'followerCount': 0,
          'followingCount': 0,
        });
      }

      final result = await sut.getFollowing('uid-target');
      expect(result, hasLength(2));
    });

    test('skips following entry when user profile doc does not exist', () async {
      // Following subcollection entry points to a non-existent user doc.
      await fakeFirestore
          .collection('users')
          .doc('uid-target')
          .collection('following')
          .doc('uid-ghost')
          .set({'followeeId': 'uid-ghost'});

      final result = await sut.getFollowing('uid-target');
      expect(result, isEmpty);
    });
  });
}
