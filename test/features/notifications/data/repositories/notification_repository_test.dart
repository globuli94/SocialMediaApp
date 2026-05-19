// test/features/notifications/data/repositories/notification_repository_test.dart
//
// Unit tests for NotificationRepository — verifies notifications() stream,
// unreadCount() stream, markAsRead() updates, and no cross-user leakage.
//
// Uses FakeFirebaseFirestore to avoid hitting real Firebase while still
// exercising Firestore read/write/query logic.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_network/features/notifications/data/repositories/notification_repository.dart';
import 'package:social_network/features/notifications/domain/entities/notification_model.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late NotificationRepository sut;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    sut = NotificationRepository(firestore: fakeFirestore);
  });

  group('NotificationRepository', () {
    // -------------------------------------------------------------------------
    // notifications(uid)
    // -------------------------------------------------------------------------

    group('notifications(uid)', () {
      test('returns empty list when subcollection is empty', () async {
        final stream = sut.notifications('uid-alice');
        final notifs = await stream.first;

        expect(notifs, isEmpty);
      });

      test('returns stream of NotificationModel list ordered by createdAt descending',
          () async {
        final older = Timestamp.fromDate(DateTime(2026, 5, 20, 10, 0));
        final newer = Timestamp.fromDate(DateTime(2026, 5, 20, 11, 0));

        // Create two notifications in chronological order
        await fakeFirestore
            .collection('users')
            .doc('uid-alice')
            .collection('notifications')
            .doc('notif-old')
            .set({
          'actorUid': 'uid-bob',
          'actorDisplayName': 'Bob',
          'type': 'follow',
          'postId': null,
          'isRead': false,
          'createdAt': older,
        });

        await fakeFirestore
            .collection('users')
            .doc('uid-alice')
            .collection('notifications')
            .doc('notif-new')
            .set({
          'actorUid': 'uid-charlie',
          'actorDisplayName': 'Charlie',
          'actorAvatarUrl': 'https://example.com/charlie.jpg',
          'type': 'like',
          'postId': 'post-123',
          'isRead': true,
          'createdAt': newer,
        });

        final notifs = await sut.notifications('uid-alice').first;

        expect(notifs, hasLength(2));
        // Should be ordered newest-first
        expect(notifs.first.id, 'notif-new');
        expect(notifs.last.id, 'notif-old');
      });

      test('maps all NotificationModel fields correctly', () async {
        final ts = Timestamp.fromDate(DateTime(2026, 5, 20, 14, 30));

        await fakeFirestore
            .collection('users')
            .doc('uid-alice')
            .collection('notifications')
            .doc('notif-complete')
            .set({
          'actorUid': 'uid-dave',
          'actorDisplayName': 'Dave Smith',
          'actorAvatarUrl': 'https://example.com/dave.jpg',
          'type': 'like',
          'postId': 'post-456',
          'isRead': false,
          'createdAt': ts,
        });

        final notifs = await sut.notifications('uid-alice').first;
        final notif = notifs.single;

        expect(notif, isA<NotificationModel>());
        expect(notif.id, 'notif-complete');
        expect(notif.actorUid, 'uid-dave');
        expect(notif.actorDisplayName, 'Dave Smith');
        expect(notif.actorAvatarUrl, 'https://example.com/dave.jpg');
        expect(notif.type, 'like');
        expect(notif.postId, 'post-456');
        expect(notif.isRead, false);
        expect(notif.createdAt, DateTime(2026, 5, 20, 14, 30));
      });

      test('no cross-user leakage: returns only uid\'s notifications',
          () async {
        final ts = Timestamp.fromDate(DateTime(2026, 5, 20));

        // Add notifications for uid-alice
        await fakeFirestore
            .collection('users')
            .doc('uid-alice')
            .collection('notifications')
            .doc('notif-alice-1')
            .set({
          'actorUid': 'uid-bob',
          'actorDisplayName': 'Bob',
          'type': 'follow',
          'postId': null,
          'isRead': false,
          'createdAt': ts,
        });

        // Add notifications for uid-bob
        await fakeFirestore
            .collection('users')
            .doc('uid-bob')
            .collection('notifications')
            .doc('notif-bob-1')
            .set({
          'actorUid': 'uid-alice',
          'actorDisplayName': 'Alice',
          'type': 'follow',
          'postId': null,
          'isRead': true,
          'createdAt': ts,
        });

        // Query alice's notifications
        final aliceNotifs = await sut.notifications('uid-alice').first;
        // Query bob's notifications
        final bobNotifs = await sut.notifications('uid-bob').first;

        expect(aliceNotifs, hasLength(1));
        expect(aliceNotifs.single.id, 'notif-alice-1');
        expect(bobNotifs, hasLength(1));
        expect(bobNotifs.single.id, 'notif-bob-1');
      });
    });

    // -------------------------------------------------------------------------
    // unreadCount(uid)
    // -------------------------------------------------------------------------

    group('unreadCount(uid)', () {
      test('returns stream of count = 0 when no notifications exist', () async {
        final count = await sut.unreadCount('uid-frank').first;
        expect(count, 0);
      });

      test('returns count of documents where isRead == false', () async {
        final ts = Timestamp.fromDate(DateTime(2026, 5, 20));

        // Create 3 notifications: 2 unread, 1 read
        await fakeFirestore
            .collection('users')
            .doc('uid-grace')
            .collection('notifications')
            .doc('notif-unread-1')
            .set({
          'actorUid': 'uid-bob',
          'actorDisplayName': 'Bob',
          'type': 'follow',
          'postId': null,
          'isRead': false,
          'createdAt': ts,
        });

        await fakeFirestore
            .collection('users')
            .doc('uid-grace')
            .collection('notifications')
            .doc('notif-unread-2')
            .set({
          'actorUid': 'uid-charlie',
          'actorDisplayName': 'Charlie',
          'type': 'like',
          'postId': 'post-123',
          'isRead': false,
          'createdAt': ts,
        });

        await fakeFirestore
            .collection('users')
            .doc('uid-grace')
            .collection('notifications')
            .doc('notif-read-1')
            .set({
          'actorUid': 'uid-dave',
          'actorDisplayName': 'Dave',
          'type': 'follow',
          'postId': null,
          'isRead': true,
          'createdAt': ts,
        });

        final count = await sut.unreadCount('uid-grace').first;
        expect(count, 2);
      });

      test('emits correct count after markAsRead updates document', () async {
        final ts = Timestamp.fromDate(DateTime(2026, 5, 20));

        // Create one unread notification
        await fakeFirestore
            .collection('users')
            .doc('uid-henry')
            .collection('notifications')
            .doc('notif-1')
            .set({
          'actorUid': 'uid-iris',
          'actorDisplayName': 'Iris',
          'type': 'follow',
          'postId': null,
          'isRead': false,
          'createdAt': ts,
        });

        // Check initial count
        final initialCount = await sut.unreadCount('uid-henry').first;
        expect(initialCount, 1);

        // Mark as read
        await sut.markAsRead('uid-henry', 'notif-1');

        // Check updated count after marking as read
        final updatedCount = await sut.unreadCount('uid-henry').first;
        expect(updatedCount, 0);
      });
    });

    // -------------------------------------------------------------------------
    // markAsRead(uid, notificationId)
    // -------------------------------------------------------------------------

    group('markAsRead(uid, notificationId)', () {
      test('updates isRead to true on the correct document', () async {
        final ts = Timestamp.fromDate(DateTime(2026, 5, 20));

        // Create notification with isRead=false
        await fakeFirestore
            .collection('users')
            .doc('uid-jack')
            .collection('notifications')
            .doc('notif-to-read')
            .set({
          'actorUid': 'uid-alice',
          'actorDisplayName': 'Alice',
          'type': 'like',
          'postId': 'post-999',
          'isRead': false,
          'createdAt': ts,
        });

        // Mark as read
        await sut.markAsRead('uid-jack', 'notif-to-read');

        // Verify the update
        final docSnap = await fakeFirestore
            .collection('users')
            .doc('uid-jack')
            .collection('notifications')
            .doc('notif-to-read')
            .get();

        expect(docSnap.data()?['isRead'], true);
      });

      test('does not affect other notifications', () async {
        final ts = Timestamp.fromDate(DateTime(2026, 5, 20));

        // Create two notifications
        await fakeFirestore
            .collection('users')
            .doc('uid-kate')
            .collection('notifications')
            .doc('notif-1')
            .set({
          'actorUid': 'uid-alice',
          'actorDisplayName': 'Alice',
          'type': 'follow',
          'postId': null,
          'isRead': false,
          'createdAt': ts,
        });

        await fakeFirestore
            .collection('users')
            .doc('uid-kate')
            .collection('notifications')
            .doc('notif-2')
            .set({
          'actorUid': 'uid-bob',
          'actorDisplayName': 'Bob',
          'type': 'like',
          'postId': 'post-123',
          'isRead': false,
          'createdAt': ts,
        });

        // Mark notif-1 as read
        await sut.markAsRead('uid-kate', 'notif-1');

        // Verify notif-1 is read and notif-2 is still unread
        final snap1 = await fakeFirestore
            .collection('users')
            .doc('uid-kate')
            .collection('notifications')
            .doc('notif-1')
            .get();

        final snap2 = await fakeFirestore
            .collection('users')
            .doc('uid-kate')
            .collection('notifications')
            .doc('notif-2')
            .get();

        expect(snap1.data()?['isRead'], true);
        expect(snap2.data()?['isRead'], false);
      });
    });
  });
}
