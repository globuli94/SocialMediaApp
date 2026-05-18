// test/features/chat/presentation/bloc/conversations_bloc_test.dart
//
// Unit tests for ConversationsBloc — covers ConversationsWatchStarted,
// ConversationsOpenOrCreate, totalUnread getter on ConversationsLoaded,
// and error path.
//
// Acceptance criteria covered:
// - AC1: Conversations list renders active chats (stream → Loaded state)
// - AC5: ConversationsOpenOrCreate opens or creates a conversation
// - AC6: totalUnread getter drives the unread badge

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/chat/domain/entities/conversation_entity.dart';
import 'package:social_network/features/chat/domain/repositories/chat_repository.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_bloc.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_event.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockChatRepository extends Mock implements ChatRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _now = DateTime(2026, 5, 18);

ConversationEntity _makeConversation({
  String id = 'conv-1',
  int unreadForMe = 0,
}) =>
    ConversationEntity(
      id: id,
      participantUids: const ['uid-me', 'uid-other'],
      lastMessageText: 'Hi',
      lastMessageAt: _now,
      lastMessageSenderUid: 'uid-other',
      unreadCounts: {'uid-me': unreadForMe, 'uid-other': 0},
      createdAt: _now,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockChatRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(_makeConversation());
  });

  setUp(() {
    mockRepo = MockChatRepository();
  });

  // -------------------------------------------------------------------------
  // ConversationsWatchStarted
  // -------------------------------------------------------------------------

  group('ConversationsWatchStarted', () {
    blocTest<ConversationsBloc, ConversationsState>(
      'emits [ConversationsLoading, ConversationsLoaded] when stream emits list',
      setUp: () {
        when(() => mockRepo.watchConversations('uid-me')).thenAnswer(
          (_) => Stream.value([_makeConversation()]),
        );
      },
      build: () => ConversationsBloc(chatRepository: mockRepo),
      act: (bloc) => bloc.add(const ConversationsWatchStarted('uid-me')),
      expect: () => [
        isA<ConversationsLoading>(),
        isA<ConversationsLoaded>()
            .having((s) => s.conversations.length, 'conversations.length', 1)
            .having((s) => s.currentUid, 'currentUid', 'uid-me'),
      ],
      verify: (_) =>
          verify(() => mockRepo.watchConversations('uid-me')).called(1),
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'emits [ConversationsLoading, ConversationsLoaded(empty)] when stream emits empty',
      setUp: () {
        when(() => mockRepo.watchConversations('uid-me')).thenAnswer(
          (_) => Stream.value([]),
        );
      },
      build: () => ConversationsBloc(chatRepository: mockRepo),
      act: (bloc) => bloc.add(const ConversationsWatchStarted('uid-me')),
      expect: () => [
        isA<ConversationsLoading>(),
        isA<ConversationsLoaded>()
            .having((s) => s.conversations, 'conversations', isEmpty),
      ],
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'emits [ConversationsLoading, ConversationsError] when stream errors',
      setUp: () {
        when(() => mockRepo.watchConversations('uid-me')).thenAnswer(
          (_) => Stream.error(Exception('Firestore error')),
        );
      },
      build: () => ConversationsBloc(chatRepository: mockRepo),
      act: (bloc) => bloc.add(const ConversationsWatchStarted('uid-me')),
      expect: () => [
        isA<ConversationsLoading>(),
        isA<ConversationsError>(),
      ],
    );

    blocTest<ConversationsBloc, ConversationsState>(
      'emits multiple ConversationsLoaded states as stream updates (real-time)',
      setUp: () {
        final controller = StreamController<List<ConversationEntity>>();
        when(() => mockRepo.watchConversations('uid-me'))
            .thenAnswer((_) => controller.stream);
        Future.microtask(() async {
          controller.add([_makeConversation(id: 'conv-1')]);
          await Future<void>.delayed(Duration.zero);
          controller.add([
            _makeConversation(id: 'conv-1'),
            _makeConversation(id: 'conv-2'),
          ]);
          await Future<void>.delayed(Duration.zero);
          await controller.close();
        });
      },
      build: () => ConversationsBloc(chatRepository: mockRepo),
      act: (bloc) => bloc.add(const ConversationsWatchStarted('uid-me')),
      expect: () => [
        isA<ConversationsLoading>(),
        isA<ConversationsLoaded>()
            .having((s) => s.conversations.length, 'length', 1),
        isA<ConversationsLoaded>()
            .having((s) => s.conversations.length, 'length', 2),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // ConversationsLoaded.totalUnread — AC6: unread badge
  // -------------------------------------------------------------------------

  group('ConversationsLoaded.totalUnread', () {
    test('returns 0 when no conversations have unread messages', () {
      final state = ConversationsLoaded(
        conversations: [_makeConversation(unreadForMe: 0)],
        currentUid: 'uid-me',
      );
      expect(state.totalUnread, 0);
    });

    test('sums unread counts from all conversations', () {
      final state = ConversationsLoaded(
        conversations: [
          _makeConversation(id: 'conv-1', unreadForMe: 3),
          _makeConversation(id: 'conv-2', unreadForMe: 2),
        ],
        currentUid: 'uid-me',
      );
      expect(state.totalUnread, 5);
    });

    test('returns 0 when conversations list is empty', () {
      final state = ConversationsLoaded(
        conversations: const [],
        currentUid: 'uid-me',
      );
      expect(state.totalUnread, 0);
    });
  });

  // -------------------------------------------------------------------------
  // ConversationsOpenOrCreate — AC5: Message button on ProfileScreen
  // -------------------------------------------------------------------------

  group('ConversationsOpenOrCreate', () {
    blocTest<ConversationsBloc, ConversationsState>(
      'emits ConversationsNavigateToChat then re-emits previous Loaded state',
      setUp: () {
        when(
          () => mockRepo.getOrCreateConversation('uid-me', 'uid-other'),
        ).thenAnswer((_) async => _makeConversation());
      },
      build: () => ConversationsBloc(chatRepository: mockRepo),
      seed: () => ConversationsLoaded(
        conversations: [_makeConversation()],
        currentUid: 'uid-me',
      ),
      act: (bloc) => bloc.add(
        const ConversationsOpenOrCreate(
          currentUid: 'uid-me',
          otherUid: 'uid-other',
        ),
      ),
      expect: () => [
        isA<ConversationsNavigateToChat>()
            .having((s) => s.conversation.id, 'conversation.id', 'conv-1'),
      ],
      verify: (_) => verify(
        () => mockRepo.getOrCreateConversation('uid-me', 'uid-other'),
      ).called(1),
    );
  });

  // -------------------------------------------------------------------------
  // Event / State props and equality
  // -------------------------------------------------------------------------

  group('ConversationsWatchStarted props', () {
    test('contains uid', () {
      const event = ConversationsWatchStarted('uid-x');
      expect(event.props, equals(['uid-x']));
    });

    test('supports value equality', () {
      const a = ConversationsWatchStarted('uid-x');
      const b = ConversationsWatchStarted('uid-x');
      expect(a, equals(b));
    });
  });

  group('ConversationsOpenOrCreate props', () {
    test('contains currentUid and otherUid', () {
      const event = ConversationsOpenOrCreate(
        currentUid: 'uid-me',
        otherUid: 'uid-other',
      );
      expect(event.props, containsAll(['uid-me', 'uid-other']));
    });
  });
}
