// test/features/chat/domain/entities/conversation_entity_test.dart
//
// Unit tests for ConversationEntity — verifies Equatable props,
// unreadCountFor convenience method, and value equality.

import 'package:flutter_test/flutter_test.dart';
import 'package:social_network/features/chat/domain/entities/conversation_entity.dart';

void main() {
  final now = DateTime(2026, 5, 18);

  ConversationEntity makeEntity({
    Map<String, int> unreadCounts = const {'uid-a': 0, 'uid-b': 2},
  }) =>
      ConversationEntity(
        id: 'conv-1',
        participantUids: const ['uid-a', 'uid-b'],
        lastMessageText: 'Hello',
        lastMessageAt: now,
        lastMessageSenderUid: 'uid-a',
        unreadCounts: unreadCounts,
        createdAt: now,
      );

  group('ConversationEntity', () {
    group('unreadCountFor', () {
      test('returns correct count for a known uid with unread messages', () {
        expect(makeEntity().unreadCountFor('uid-b'), 2);
      });

      test('returns 0 for a uid with zero unread', () {
        expect(makeEntity().unreadCountFor('uid-a'), 0);
      });

      test('returns 0 for an unknown uid (not in the map)', () {
        expect(makeEntity().unreadCountFor('uid-unknown'), 0);
      });
    });

    group('Equatable', () {
      test('supports value equality for identical instances', () {
        final a = makeEntity();
        final b = makeEntity();
        expect(a, equals(b));
      });

      test('instances with different ids are not equal', () {
        final a = ConversationEntity(
          id: 'conv-1',
          participantUids: const ['uid-a', 'uid-b'],
          lastMessageText: 'Hello',
          lastMessageAt: now,
          lastMessageSenderUid: 'uid-a',
          unreadCounts: const {'uid-a': 0, 'uid-b': 0},
          createdAt: now,
        );
        final b = ConversationEntity(
          id: 'conv-2',
          participantUids: const ['uid-a', 'uid-b'],
          lastMessageText: 'Hello',
          lastMessageAt: now,
          lastMessageSenderUid: 'uid-a',
          unreadCounts: const {'uid-a': 0, 'uid-b': 0},
          createdAt: now,
        );
        expect(a, isNot(equals(b)));
      });

      test('props list is non-empty', () {
        expect(makeEntity().props, isNotEmpty);
      });
    });
  });
}
