// test/features/notifications/domain/notification_model_test.dart
//
// Unit tests for NotificationModel — verifies constructor, nullable field
// handling, and equatable equality.

import 'package:flutter_test/flutter_test.dart';
import 'package:social_network/features/notifications/domain/entities/notification_model.dart';

void main() {
  group('NotificationModel', () {
    // -------------------------------------------------------------------------
    // Constructor — all fields
    // -------------------------------------------------------------------------

    group('Constructor', () {
      test('correctly initializes all required fields', () {
        final createdAt = DateTime(2026, 5, 20, 10, 30, 0);
        final notif = NotificationModel(
          id: 'notif-1',
          type: 'like',
          actorUid: 'uid-bob',
          actorDisplayName: 'Bob Smith',
          postId: 'post-123',
          isRead: false,
          createdAt: createdAt,
        );

        expect(notif.id, 'notif-1');
        expect(notif.type, 'like');
        expect(notif.actorUid, 'uid-bob');
        expect(notif.actorDisplayName, 'Bob Smith');
        expect(notif.postId, 'post-123');
        expect(notif.isRead, false);
        expect(notif.createdAt, createdAt);
      });

      test('handles nullable actorAvatarUrl as null', () {
        final notif = NotificationModel(
          id: 'notif-2',
          type: 'follow',
          actorUid: 'uid-charlie',
          actorDisplayName: 'Charlie',
          actorAvatarUrl: null,
          postId: null,
          isRead: true,
          createdAt: DateTime(2026, 5, 20),
        );

        expect(notif.actorAvatarUrl, isNull);
      });

      test('handles nullable postId as null for follow notifications', () {
        final notif = NotificationModel(
          id: 'notif-3',
          type: 'follow',
          actorUid: 'uid-dave',
          actorDisplayName: 'Dave',
          postId: null,
          isRead: false,
          createdAt: DateTime(2026, 5, 20),
        );

        expect(notif.postId, isNull);
      });

      test('stores postId when present for like notifications', () {
        final notif = NotificationModel(
          id: 'notif-4',
          type: 'like',
          actorUid: 'uid-eve',
          actorDisplayName: 'Eve',
          postId: 'post-456',
          isRead: true,
          createdAt: DateTime(2026, 5, 20),
        );

        expect(notif.postId, 'post-456');
      });

      test('stores actorAvatarUrl when provided', () {
        final notif = NotificationModel(
          id: 'notif-5',
          type: 'like',
          actorUid: 'uid-frank',
          actorDisplayName: 'Frank',
          actorAvatarUrl: 'https://example.com/frank.jpg',
          postId: 'post-789',
          isRead: false,
          createdAt: DateTime(2026, 5, 20),
        );

        expect(notif.actorAvatarUrl, 'https://example.com/frank.jpg');
      });
    });

    // -------------------------------------------------------------------------
    // Equatable equality
    // -------------------------------------------------------------------------

    group('Equatable equality', () {
      test('two instances with same fields are equal', () {
        final createdAt = DateTime(2026, 5, 20);
        final notif1 = NotificationModel(
          id: 'notif-7',
          type: 'like',
          actorUid: 'uid-henry',
          actorDisplayName: 'Henry',
          actorAvatarUrl: 'https://example.com/henry.jpg',
          postId: 'post-111',
          isRead: false,
          createdAt: createdAt,
        );

        final notif2 = NotificationModel(
          id: 'notif-7',
          type: 'like',
          actorUid: 'uid-henry',
          actorDisplayName: 'Henry',
          actorAvatarUrl: 'https://example.com/henry.jpg',
          postId: 'post-111',
          isRead: false,
          createdAt: createdAt,
        );

        expect(notif1, equals(notif2));
      });

      test('instances with different isRead are not equal', () {
        final createdAt = DateTime(2026, 5, 20);
        final notif1 = NotificationModel(
          id: 'notif-8',
          type: 'follow',
          actorUid: 'uid-iris',
          actorDisplayName: 'Iris',
          postId: null,
          isRead: false,
          createdAt: createdAt,
        );

        final notif2 = NotificationModel(
          id: 'notif-8',
          type: 'follow',
          actorUid: 'uid-iris',
          actorDisplayName: 'Iris',
          postId: null,
          isRead: true,
          createdAt: createdAt,
        );

        expect(notif1, isNot(equals(notif2)));
      });

      test('instances with different ids are not equal', () {
        final createdAt = DateTime(2026, 5, 20);
        final notif1 = NotificationModel(
          id: 'notif-1',
          type: 'like',
          actorUid: 'uid-jack',
          actorDisplayName: 'Jack',
          postId: 'post-222',
          isRead: false,
          createdAt: createdAt,
        );

        final notif2 = NotificationModel(
          id: 'notif-2',
          type: 'like',
          actorUid: 'uid-jack',
          actorDisplayName: 'Jack',
          postId: 'post-222',
          isRead: false,
          createdAt: createdAt,
        );

        expect(notif1, isNot(equals(notif2)));
      });
    });
  });
}
