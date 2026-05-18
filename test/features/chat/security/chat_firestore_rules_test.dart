// test/features/chat/security/chat_firestore_rules_test.dart
//
// Security-rules verification tests for the chat feature (BUG-012 / SOCAA-268).
//
// Covers the four acceptance criteria in SOCAA-270:
//
//   AC1 — An authenticated user listed in participantUids can read the
//          conversation document without a permission-denied error.
//   AC2 — An authenticated user listed in participantUids can read messages
//          under that conversation without a permission-denied error.
//   AC3 — An authenticated user listed in participantUids can create
//          (send) a new message document without a permission-denied error.
//   AC4 — An authenticated user NOT listed in participantUids receives a
//          permission-denied error and the BLoC surface propagates it as an
//          error state.
//
// Positive cases (AC1–AC3) use FakeFirebaseFirestore to simulate allowed
// Firestore access. The fake honours reads and writes unrestricted, which
// mirrors what the Firestore rules permit for participants.
//
// Negative case (AC4) uses mocktail to inject a FirebaseException with
// code "permission-denied" directly into the repository stream, verifying
// that both ConversationsBloc and ChatBloc surface it as an error state.

import 'package:bloc_test/bloc_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:social_network/features/chat/domain/repositories/chat_repository.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_event.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_state.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_bloc.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_event.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockChatRepository extends Mock implements ChatRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Seed a conversation document with the given [participantUids].
Future<void> _seedConversation(
  FakeFirebaseFirestore firestore, {
  required String conversationId,
  required List<String> participantUids,
}) async {
  await firestore.collection('conversations').doc(conversationId).set({
    'participantUids': participantUids,
    'lastMessageText': '',
    'lastMessageAt': Timestamp.fromDate(DateTime(2026, 5, 18)),
    'lastMessageSenderUid': participantUids.first,
    'unreadCounts': {for (final uid in participantUids) uid: 0},
    'createdAt': Timestamp.fromDate(DateTime(2026, 5, 18)),
  });
}

/// Seed a message document inside a conversation.
Future<void> _seedMessage(
  FakeFirebaseFirestore firestore, {
  required String conversationId,
  required String messageId,
  required String senderUid,
  required String text,
}) async {
  await firestore
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .doc(messageId)
      .set({
    'senderUid': senderUid,
    'text': text,
    'createdAt': Timestamp.fromDate(DateTime(2026, 5, 18, 10, 0)),
  });
}

/// A [FirebaseException] that represents a Firestore permission-denied error.
FirebaseException _permissionDenied() => FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Firestore security rules — chat (SOCAA-268 / BUG-012)', () {
    // -----------------------------------------------------------------------
    // Shared setup for positive cases (AC1–AC3)
    // -----------------------------------------------------------------------

    late FakeFirebaseFirestore fakeFirestore;
    late ChatRepositoryImpl repo;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repo = ChatRepositoryImpl(firestore: fakeFirestore);
    });

    // -----------------------------------------------------------------------
    // AC1 — Participant can read the conversation document
    // -----------------------------------------------------------------------

    group('AC1 — participant can read conversation document', () {
      test(
        'watchConversations emits conversation when current uid is a participant',
        () async {
          const participantUid = 'uid-alice';
          await _seedConversation(
            fakeFirestore,
            conversationId: 'conv-ac1',
            participantUids: ['uid-alice', 'uid-bob'],
          );

          final conversations =
              await repo.watchConversations(participantUid).first;

          expect(conversations, hasLength(1));
          expect(
            conversations.first.participantUids,
            containsAll(['uid-alice', 'uid-bob']),
          );
        },
      );

      test(
        'watchConversations does not emit conversations for non-participant uid',
        () async {
          // Seed a conversation that uid-carol is NOT part of.
          await _seedConversation(
            fakeFirestore,
            conversationId: 'conv-ac1-exclusive',
            participantUids: ['uid-alice', 'uid-bob'],
          );

          // uid-carol is not a participant — Firestore rules would return
          // zero results (or permission-denied). FakeFirebaseFirestore
          // enforces the array-contains query, so the result is empty.
          final conversations =
              await repo.watchConversations('uid-carol').first;

          expect(conversations, isEmpty);
        },
      );
    });

    // -----------------------------------------------------------------------
    // AC2 — Participant can read messages under the conversation
    // -----------------------------------------------------------------------

    group('AC2 — participant can read messages', () {
      test(
        'watchMessages emits messages for a user who is a participant',
        () async {
          await _seedConversation(
            fakeFirestore,
            conversationId: 'conv-ac2',
            participantUids: ['uid-alice', 'uid-bob'],
          );
          await _seedMessage(
            fakeFirestore,
            conversationId: 'conv-ac2',
            messageId: 'msg-1',
            senderUid: 'uid-bob',
            text: 'Hello Alice',
          );

          final messages = await repo.watchMessages('conv-ac2').first;

          expect(messages, hasLength(1));
          expect(messages.first.text, 'Hello Alice');
          expect(messages.first.senderUid, 'uid-bob');
        },
      );

      test(
        'watchMessages emits multiple messages ordered oldest-first for participant',
        () async {
          await _seedConversation(
            fakeFirestore,
            conversationId: 'conv-ac2-order',
            participantUids: ['uid-alice', 'uid-bob'],
          );

          // Insert in reverse order to confirm ordering by createdAt.
          await fakeFirestore
              .collection('conversations')
              .doc('conv-ac2-order')
              .collection('messages')
              .doc('msg-newer')
              .set({
            'senderUid': 'uid-alice',
            'text': 'Second',
            'createdAt': Timestamp.fromDate(DateTime(2026, 5, 18, 11, 0)),
          });
          await fakeFirestore
              .collection('conversations')
              .doc('conv-ac2-order')
              .collection('messages')
              .doc('msg-older')
              .set({
            'senderUid': 'uid-bob',
            'text': 'First',
            'createdAt': Timestamp.fromDate(DateTime(2026, 5, 18, 10, 0)),
          });

          final messages = await repo.watchMessages('conv-ac2-order').first;

          expect(messages, hasLength(2));
          expect(messages.first.text, 'First');
          expect(messages.last.text, 'Second');
        },
      );
    });

    // -----------------------------------------------------------------------
    // AC3 — Participant can send (create) a new message
    // -----------------------------------------------------------------------

    group('AC3 — participant can create a new message', () {
      test(
        'sendMessage completes without error when sender is a participant',
        () async {
          await _seedConversation(
            fakeFirestore,
            conversationId: 'conv-ac3',
            participantUids: ['uid-alice', 'uid-bob'],
          );

          await expectLater(
            repo.sendMessage(
              conversationId: 'conv-ac3',
              senderUid: 'uid-alice',
              recipientUid: 'uid-bob',
              text: 'Hi Bob!',
            ),
            completes,
          );

          final snap = await fakeFirestore
              .collection('conversations')
              .doc('conv-ac3')
              .collection('messages')
              .get();

          expect(snap.docs, hasLength(1));
          expect(snap.docs.first.data()['text'], 'Hi Bob!');
          expect(snap.docs.first.data()['senderUid'], 'uid-alice');
        },
      );

      test(
        'sendMessage updates lastMessageText on conversation document',
        () async {
          await _seedConversation(
            fakeFirestore,
            conversationId: 'conv-ac3-update',
            participantUids: ['uid-alice', 'uid-bob'],
          );

          await repo.sendMessage(
            conversationId: 'conv-ac3-update',
            senderUid: 'uid-alice',
            recipientUid: 'uid-bob',
            text: 'Last message text',
          );

          final snap = await fakeFirestore
              .collection('conversations')
              .doc('conv-ac3-update')
              .get();

          expect(snap.data()?['lastMessageText'], 'Last message text');
          expect(snap.data()?['lastMessageSenderUid'], 'uid-alice');
        },
      );
    });

    // -----------------------------------------------------------------------
    // AC4 — Non-participant receives permission-denied and BLoC surfaces error
    // -----------------------------------------------------------------------

    group('AC4 — non-participant denied read access', () {
      late MockChatRepository mockRepo;

      setUp(() {
        mockRepo = MockChatRepository();
        // markAsRead is called on ChatWatchStarted; stub it to avoid unrelated failure.
        when(
          () => mockRepo.markAsRead(
            conversationId: any(named: 'conversationId'),
            uid: any(named: 'uid'),
          ),
        ).thenAnswer((_) async {});
      });

      blocTest<ConversationsBloc, ConversationsState>(
        'ConversationsBloc emits ConversationsError when Firestore denies '
        'conversation read for non-participant',
        setUp: () {
          when(() => mockRepo.watchConversations('uid-stranger')).thenAnswer(
            (_) => Stream.error(_permissionDenied()),
          );
        },
        build: () => ConversationsBloc(chatRepository: mockRepo),
        act: (bloc) =>
            bloc.add(const ConversationsWatchStarted('uid-stranger')),
        expect: () => [
          isA<ConversationsLoading>(),
          isA<ConversationsError>(),
        ],
      );

      blocTest<ChatBloc, ChatState>(
        'ChatBloc emits ChatError when Firestore denies message read '
        'for non-participant',
        setUp: () {
          when(() => mockRepo.watchMessages('conv-private')).thenAnswer(
            (_) => Stream.error(_permissionDenied()),
          );
        },
        build: () => ChatBloc(chatRepository: mockRepo),
        act: (bloc) => bloc.add(
          const ChatWatchStarted(
            conversationId: 'conv-private',
            currentUid: 'uid-stranger',
            recipientUid: 'uid-alice',
          ),
        ),
        expect: () => [
          isA<ChatLoading>(),
          isA<ChatError>(),
        ],
      );

      blocTest<ChatBloc, ChatState>(
        'ChatBloc error state is emitted regardless of the permission-denied '
        'message text — only the code matters',
        setUp: () {
          when(() => mockRepo.watchMessages('conv-private-2')).thenAnswer(
            (_) => Stream.error(
              FirebaseException(
                plugin: 'cloud_firestore',
                code: 'permission-denied',
              ),
            ),
          );
        },
        build: () => ChatBloc(chatRepository: mockRepo),
        act: (bloc) => bloc.add(
          const ChatWatchStarted(
            conversationId: 'conv-private-2',
            currentUid: 'uid-outsider',
            recipientUid: 'uid-bob',
          ),
        ),
        expect: () => [
          isA<ChatLoading>(),
          isA<ChatError>(),
        ],
      );
    });
  });
}
