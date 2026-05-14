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
}
