// test/features/chat/domain/entities/message_entity_test.dart
//
// Unit tests for MessageEntity — verifies Equatable props and value equality.

import 'package:flutter_test/flutter_test.dart';
import 'package:social_network/features/chat/domain/entities/message_entity.dart';

void main() {
  final now = DateTime(2026, 5, 18, 12, 0);

  MessageEntity makeEntity({String id = 'msg-1'}) => MessageEntity(
        id: id,
        senderUid: 'uid-sender',
        text: 'Hello world',
        createdAt: now,
      );

  group('MessageEntity', () {
    test('supports value equality for identical instances', () {
      expect(makeEntity(), equals(makeEntity()));
    });

    test('instances with different ids are not equal', () {
      expect(makeEntity(id: 'msg-1'), isNot(equals(makeEntity(id: 'msg-2'))));
    });

    test('props list is non-empty', () {
      expect(makeEntity().props, isNotEmpty);
    });

    test('exposes all fields correctly', () {
      final entity = makeEntity();
      expect(entity.id, 'msg-1');
      expect(entity.senderUid, 'uid-sender');
      expect(entity.text, 'Hello world');
      expect(entity.createdAt, now);
    });
  });
}
