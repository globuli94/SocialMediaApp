// test/features/chat/data/repositories/chat_repository_impl_test.dart
//
// Unit tests for ChatRepositoryImpl — exercises watchConversations,
// watchMessages, getOrCreateConversation, sendMessage, and markAsRead
// against FakeFirebaseFirestore (no real Firebase).
//
// Field names are derived from firebase-schema.md (conversations collection
// and conversations/{id}/messages subcollection).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_network/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:social_network/features/chat/domain/entities/conversation_entity.dart';
import 'package:social_network/features/chat/domain/entities/message_entity.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ChatRepositoryImpl sut;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    sut = ChatRepositoryImpl(firestore: fakeFirestore);
  });

  // -------------------------------------------------------------------------
  // watchConversations — AC1: conversations list
  // -------------------------------------------------------------------------

  group('watchConversations', () {
    test('emits empty list when no conversations exist', () async {
      final result = await sut.watchConversations('uid-me').first;
      expect(result, isEmpty);
    });

    test('emits conversations that contain the current uid', () async {
      await fakeFirestore.collection('conversations').doc('conv-1').set({
        'participantUids': ['uid-me', 'uid-other'],
        'lastMessageText': 'Hello',
        'lastMessageAt': Timestamp.fromDate(DateTime(2026, 5, 18)),
        'lastMessageSenderUid': 'uid-other',
        'unreadCounts': {'uid-me': 1, 'uid-other': 0},
        'createdAt': Timestamp.fromDate(DateTime(2026, 5, 17)),
      });

      final result = await sut.watchConversations('uid-me').first;
      expect(result, hasLength(1));
      expect(result.first, isA<ConversationEntity>());
      expect(result.first.participantUids, contains('uid-me'));
      expect(result.first.lastMessageText, 'Hello');
    });

    test('maps Timestamp to DateTime via .toDate()', () async {
      final ts = DateTime(2026, 5, 18, 10, 30);
      await fakeFirestore.collection('conversations').doc('conv-ts').set({
        'participantUids': ['uid-me', 'uid-b'],
        'lastMessageText': 'Time test',
        'lastMessageAt': Timestamp.fromDate(ts),
        'lastMessageSenderUid': 'uid-b',
        'unreadCounts': {'uid-me': 0, 'uid-b': 0},
        'createdAt': Timestamp.fromDate(ts),
      });

      final convs = await sut.watchConversations('uid-me').first;
      expect(convs.first.lastMessageAt, ts);
      expect(convs.first.createdAt, ts);
    });

    test('maps unreadCounts correctly as Map<String, int>', () async {
      await fakeFirestore.collection('conversations').doc('conv-unread').set({
        'participantUids': ['uid-me', 'uid-b'],
        'lastMessageText': 'Hey',
        'lastMessageAt': Timestamp.fromDate(DateTime(2026, 5, 18)),
        'lastMessageSenderUid': 'uid-b',
        'unreadCounts': {'uid-me': 3, 'uid-b': 0},
        'createdAt': Timestamp.fromDate(DateTime(2026, 5, 17)),
      });

      final convs = await sut.watchConversations('uid-me').first;
      expect(convs.first.unreadCountFor('uid-me'), 3);
      expect(convs.first.unreadCountFor('uid-b'), 0);
    });
  });

  // -------------------------------------------------------------------------
  // watchMessages — AC3: real-time messages
  // -------------------------------------------------------------------------

  group('watchMessages', () {
    test('emits empty list when no messages exist', () async {
      final result = await sut.watchMessages('conv-1').first;
      expect(result, isEmpty);
    });

    test('emits MessageEntity list ordered by createdAt ascending', () async {
      final older = Timestamp.fromDate(DateTime(2026, 5, 18, 10, 0));
      final newer = Timestamp.fromDate(DateTime(2026, 5, 18, 11, 0));

      await fakeFirestore
          .collection('conversations')
          .doc('conv-1')
          .collection('messages')
          .doc('msg-old')
          .set({
        'senderUid': 'uid-a',
        'text': 'First message',
        'createdAt': older,
      });
      await fakeFirestore
          .collection('conversations')
          .doc('conv-1')
          .collection('messages')
          .doc('msg-new')
          .set({
        'senderUid': 'uid-b',
        'text': 'Second message',
        'createdAt': newer,
      });

      final msgs = await sut.watchMessages('conv-1').first;
      expect(msgs, hasLength(2));
      // Ordered oldest-first (ascending).
      expect(msgs.first.text, 'First message');
      expect(msgs.last.text, 'Second message');
    });

    test('maps MessageEntity fields correctly', () async {
      await fakeFirestore
          .collection('conversations')
          .doc('conv-x')
          .collection('messages')
          .doc('msg-1')
          .set({
        'senderUid': 'uid-sender',
        'text': 'Test text',
        'createdAt': Timestamp.fromDate(DateTime(2026, 5, 18, 9, 0)),
      });

      final msgs = await sut.watchMessages('conv-x').first;
      final msg = msgs.single;

      expect(msg, isA<MessageEntity>());
      expect(msg.id, 'msg-1');
      expect(msg.senderUid, 'uid-sender');
      expect(msg.text, 'Test text');
      expect(msg.createdAt, DateTime(2026, 5, 18, 9, 0));
    });
  });

  // -------------------------------------------------------------------------
  // getOrCreateConversation — AC5: Message button opens/creates conversation
  // -------------------------------------------------------------------------

  group('getOrCreateConversation', () {
    test('creates new conversation when none exists for that pair', () async {
      final conv =
          await sut.getOrCreateConversation('uid-alice', 'uid-bob');

      expect(conv, isA<ConversationEntity>());
      expect(conv.participantUids, containsAll(['uid-alice', 'uid-bob']));
      expect(conv.lastMessageText, '');
      expect(conv.unreadCountFor('uid-alice'), 0);
      expect(conv.unreadCountFor('uid-bob'), 0);

      final docs = await fakeFirestore.collection('conversations').get();
      expect(docs.docs, hasLength(1));
    });

    test('returns existing conversation when one already exists', () async {
      await fakeFirestore
          .collection('conversations')
          .doc('existing-conv')
          .set({
        'participantUids': ['uid-alice', 'uid-bob'],
        'lastMessageText': 'Previous message',
        'lastMessageAt': Timestamp.fromDate(DateTime(2026, 5, 18)),
        'lastMessageSenderUid': 'uid-bob',
        'unreadCounts': {'uid-alice': 0, 'uid-bob': 0},
        'createdAt': Timestamp.fromDate(DateTime(2026, 5, 17)),
      });

      final conv =
          await sut.getOrCreateConversation('uid-alice', 'uid-bob');

      expect(conv.id, 'existing-conv');
      expect(conv.lastMessageText, 'Previous message');

      // No new document should be created.
      final docs = await fakeFirestore.collection('conversations').get();
      expect(docs.docs, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // sendMessage — AC2: allows sending text
  // -------------------------------------------------------------------------

  group('sendMessage', () {
    test('adds document to messages subcollection', () async {
      // Seed the conversation doc so the batch update() does not throw not-found.
      await fakeFirestore.collection('conversations').doc('conv-1').set({
        'participantUids': ['uid-me', 'uid-other'],
        'lastMessageText': '',
        'lastMessageAt': Timestamp.fromDate(DateTime(2026, 5, 18)),
        'lastMessageSenderUid': 'uid-me',
        'unreadCounts': {'uid-me': 0, 'uid-other': 0},
        'createdAt': Timestamp.fromDate(DateTime(2026, 5, 18)),
      });

      await sut.sendMessage(
        conversationId: 'conv-1',
        senderUid: 'uid-me',
        recipientUid: 'uid-other',
        text: 'Hello!',
      );

      final msgs = await fakeFirestore
          .collection('conversations')
          .doc('conv-1')
          .collection('messages')
          .get();
      expect(msgs.docs, hasLength(1));
      expect(msgs.docs.first.data()['text'], 'Hello!');
      expect(msgs.docs.first.data()['senderUid'], 'uid-me');
    });

    test('updates conversation lastMessageText and lastMessageSenderUid',
        () async {
      await fakeFirestore.collection('conversations').doc('conv-1').set({
        'participantUids': ['uid-me', 'uid-other'],
        'lastMessageText': '',
        'lastMessageAt': Timestamp.fromDate(DateTime(2026, 5, 18)),
        'lastMessageSenderUid': 'uid-me',
        'unreadCounts': {'uid-me': 0, 'uid-other': 0},
        'createdAt': Timestamp.fromDate(DateTime(2026, 5, 18)),
      });

      await sut.sendMessage(
        conversationId: 'conv-1',
        senderUid: 'uid-me',
        recipientUid: 'uid-other',
        text: 'New message',
      );

      final snap = await fakeFirestore
          .collection('conversations')
          .doc('conv-1')
          .get();
      expect(snap.data()?['lastMessageText'], 'New message');
      expect(snap.data()?['lastMessageSenderUid'], 'uid-me');
    });
  });

  // -------------------------------------------------------------------------
  // markAsRead — AC7: unread count resets to 0 when chat opened
  // -------------------------------------------------------------------------

  group('markAsRead', () {
    test('sets unreadCount for uid to 0', () async {
      await fakeFirestore.collection('conversations').doc('conv-1').set({
        'participantUids': ['uid-me', 'uid-other'],
        'lastMessageText': 'Hi',
        'lastMessageAt': Timestamp.fromDate(DateTime(2026, 5, 18)),
        'lastMessageSenderUid': 'uid-other',
        'unreadCounts': {'uid-me': 5, 'uid-other': 0},
        'createdAt': Timestamp.fromDate(DateTime(2026, 5, 18)),
      });

      await sut.markAsRead(conversationId: 'conv-1', uid: 'uid-me');

      final snap = await fakeFirestore
          .collection('conversations')
          .doc('conv-1')
          .get();
      final data = snap.data()!;
      // Dot-notation update stores nested field: unreadCounts.uid-me = 0
      final unreadCounts = data['unreadCounts'] as Map<String, dynamic>;
      expect(unreadCounts['uid-me'], 0);
    });
  });
}
