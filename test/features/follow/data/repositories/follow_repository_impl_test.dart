// test/features/follow/data/repositories/follow_repository_impl_test.dart
//
// Unit tests for FollowRepositoryImpl — covers follow(), unfollow(), and
// watchIsFollowing() to satisfy the ≥ 80% repository coverage threshold.
//
// Uses fake_cloud_firestore so no real Firebase instance is required.

import 'package:cloud_firestore/cloud_firestore.dart';
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
  // watchFollowers
  // ---------------------------------------------------------------------------

  group('watchFollowers()', () {
    test('emits empty list when the followers subcollection is empty',
        () async {
      final stream = sut.watchFollowers('uid-me');
      expect(await stream.first, isEmpty);
    });

    test('emits list of user profiles for each follower', () async {
      // Seed the follower user doc.
      await fakeFirestore.collection('users').doc('uid-alice').set({
        'displayName': 'Alice',
        'bio': 'Bio',
        'avatarUrl': null,
        'postCount': 0,
        'followerCount': 1,
        'followingCount': 0,
      });

      // Seed the followers subcollection under uid-me.
      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('followers')
          .doc('uid-alice')
          .set({
        'followerId': 'uid-alice',
        'createdAt': Timestamp.fromDate(DateTime(2024)),
      });

      final stream = sut.watchFollowers('uid-me');
      final users = await stream.first;

      expect(users.length, equals(1));
      expect(users.first.uid, equals('uid-alice'));
      expect(users.first.displayName, equals('Alice'));
    });

    test('excludes follower entries whose user doc does not exist', () async {
      // Seed the followers subcollection but NOT the user doc.
      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('followers')
          .doc('uid-ghost')
          .set({
        'followerId': 'uid-ghost',
        'createdAt': Timestamp.fromDate(DateTime(2024)),
      });

      final stream = sut.watchFollowers('uid-me');
      final users = await stream.first;

      expect(users, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // watchFollowing
  // ---------------------------------------------------------------------------

  group('watchFollowing()', () {
    test('emits empty list when the following subcollection is empty',
        () async {
      final stream = sut.watchFollowing('uid-me');
      expect(await stream.first, isEmpty);
    });

    test('emits list of user profiles for each followed user', () async {
      // Seed the followee user doc.
      await fakeFirestore.collection('users').doc('uid-bob').set({
        'displayName': 'Bob',
        'bio': '',
        'avatarUrl': null,
        'postCount': 2,
        'followerCount': 0,
        'followingCount': 1,
      });

      // Seed the following subcollection under uid-me.
      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('following')
          .doc('uid-bob')
          .set({
        'followeeId': 'uid-bob',
        'createdAt': Timestamp.fromDate(DateTime(2024)),
      });

      final stream = sut.watchFollowing('uid-me');
      final users = await stream.first;

      expect(users.length, equals(1));
      expect(users.first.uid, equals('uid-bob'));
      expect(users.first.displayName, equals('Bob'));
    });

    test('excludes following entries whose user doc does not exist', () async {
      // Seed the following subcollection but NOT the user doc.
      await fakeFirestore
          .collection('users')
          .doc('uid-me')
          .collection('following')
          .doc('uid-ghost')
          .set({
        'followeeId': 'uid-ghost',
        'createdAt': Timestamp.fromDate(DateTime(2024)),
      });

      final stream = sut.watchFollowing('uid-me');
      final users = await stream.first;

      expect(users, isEmpty);
    });
  });
}
