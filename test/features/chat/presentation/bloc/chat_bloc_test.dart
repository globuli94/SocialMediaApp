// test/features/chat/presentation/bloc/chat_bloc_test.dart
//
// Unit tests for ChatBloc — covers ChatWatchStarted, ChatMessageSent,
// and ChatMarkAsRead event handlers.
//
// Acceptance criteria covered:
// - AC2: Chat screen allows sending text (ChatMessageSent → sendMessage)
// - AC3: Messages update in real time (stream → ChatLoaded on each emission)
// - AC7: Unread count resets to 0 when chat is opened (markAsRead on start)

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/chat/domain/entities/message_entity.dart';
import 'package:social_network/features/chat/domain/repositories/chat_repository.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_event.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockChatRepository extends Mock implements ChatRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

MessageEntity _makeMessage({
  String id = 'msg-1',
  String senderUid = 'uid-me',
  String text = 'Hello',
}) =>
    MessageEntity(
      id: id,
      senderUid: senderUid,
      text: text,
      createdAt: DateTime(2026, 5, 18, 12, 0),
    );

const _watchStarted = ChatWatchStarted(
  conversationId: 'conv-1',
  currentUid: 'uid-me',
  recipientUid: 'uid-other',
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockChatRepository mockRepo;

  setUp(() {
    mockRepo = MockChatRepository();
    // Default stub for markAsRead (called on ChatWatchStarted)
    when(
      () => mockRepo.markAsRead(
        conversationId: any(named: 'conversationId'),
        uid: any(named: 'uid'),
      ),
    ).thenAnswer((_) async {});
  });

  // -------------------------------------------------------------------------
  // ChatWatchStarted — AC3: real-time messages
  // -------------------------------------------------------------------------

  group('ChatWatchStarted', () {
    blocTest<ChatBloc, ChatState>(
      'emits [ChatLoading, ChatLoaded] when stream emits messages',
      setUp: () {
        when(() => mockRepo.watchMessages('conv-1')).thenAnswer(
          (_) => Stream.value([_makeMessage()]),
        );
      },
      build: () => ChatBloc(chatRepository: mockRepo),
      act: (bloc) => bloc.add(_watchStarted),
      expect: () => [
        isA<ChatLoading>(),
        isA<ChatLoaded>()
            .having((s) => s.messages.length, 'messages.length', 1)
            .having((s) => s.currentUid, 'currentUid', 'uid-me')
            .having((s) => s.conversationId, 'conversationId', 'conv-1')
            .having((s) => s.recipientUid, 'recipientUid', 'uid-other'),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'emits [ChatLoading, ChatLoaded(empty)] when stream emits no messages',
      setUp: () {
        when(() => mockRepo.watchMessages('conv-1')).thenAnswer(
          (_) => Stream.value([]),
        );
      },
      build: () => ChatBloc(chatRepository: mockRepo),
      act: (bloc) => bloc.add(_watchStarted),
      expect: () => [
        isA<ChatLoading>(),
        isA<ChatLoaded>().having((s) => s.messages, 'messages', isEmpty),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'emits [ChatLoading, ChatError] when stream errors',
      setUp: () {
        when(() => mockRepo.watchMessages('conv-1')).thenAnswer(
          (_) => Stream.error(Exception('network error')),
        );
      },
      build: () => ChatBloc(chatRepository: mockRepo),
      act: (bloc) => bloc.add(_watchStarted),
      expect: () => [
        isA<ChatLoading>(),
        isA<ChatError>(),
      ],
    );

    // AC7: markAsRead called immediately on subscribe
    blocTest<ChatBloc, ChatState>(
      'calls markAsRead immediately after subscribing to messages',
      setUp: () {
        when(() => mockRepo.watchMessages('conv-1')).thenAnswer(
          (_) => Stream.value([]),
        );
      },
      build: () => ChatBloc(chatRepository: mockRepo),
      act: (bloc) => bloc.add(_watchStarted),
      verify: (_) => verify(
        () => mockRepo.markAsRead(
          conversationId: 'conv-1',
          uid: 'uid-me',
        ),
      ).called(1),
    );

    // AC3: real-time updates emit new ChatLoaded on each stream event
    blocTest<ChatBloc, ChatState>(
      'emits multiple ChatLoaded states as stream updates (real-time)',
      setUp: () {
        final controller = StreamController<List<MessageEntity>>();
        when(() => mockRepo.watchMessages('conv-1'))
            .thenAnswer((_) => controller.stream);
        Future.microtask(() async {
          controller.add([_makeMessage(id: 'msg-1')]);
          await Future<void>.delayed(Duration.zero);
          controller.add([
            _makeMessage(id: 'msg-1'),
            _makeMessage(id: 'msg-2'),
          ]);
          await Future<void>.delayed(Duration.zero);
          await controller.close();
        });
      },
      build: () => ChatBloc(chatRepository: mockRepo),
      act: (bloc) => bloc.add(_watchStarted),
      expect: () => [
        isA<ChatLoading>(),
        isA<ChatLoaded>().having((s) => s.messages.length, 'length', 1),
        isA<ChatLoaded>().having((s) => s.messages.length, 'length', 2),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // ChatMessageSent — AC2: allows sending text
  // -------------------------------------------------------------------------

  group('ChatMessageSent', () {
    blocTest<ChatBloc, ChatState>(
      'calls sendMessage with correct params when state is ChatLoaded',
      setUp: () {
        when(
          () => mockRepo.sendMessage(
            conversationId: any(named: 'conversationId'),
            senderUid: any(named: 'senderUid'),
            recipientUid: any(named: 'recipientUid'),
            text: any(named: 'text'),
          ),
        ).thenAnswer((_) async {});
      },
      build: () => ChatBloc(chatRepository: mockRepo),
      seed: () => const ChatLoaded(
        conversationId: 'conv-1',
        currentUid: 'uid-me',
        recipientUid: 'uid-other',
        messages: [],
      ),
      act: (bloc) => bloc.add(const ChatMessageSent('Hello!')),
      verify: (_) => verify(
        () => mockRepo.sendMessage(
          conversationId: 'conv-1',
          senderUid: 'uid-me',
          recipientUid: 'uid-other',
          text: 'Hello!',
        ),
      ).called(1),
    );

    blocTest<ChatBloc, ChatState>(
      'does nothing when state is not ChatLoaded',
      build: () => ChatBloc(chatRepository: mockRepo),
      // initial state is ChatInitial
      act: (bloc) => bloc.add(const ChatMessageSent('Hello!')),
      expect: () => <ChatState>[],
      verify: (_) => verifyNever(
        () => mockRepo.sendMessage(
          conversationId: any(named: 'conversationId'),
          senderUid: any(named: 'senderUid'),
          recipientUid: any(named: 'recipientUid'),
          text: any(named: 'text'),
        ),
      ),
    );
  });

  // -------------------------------------------------------------------------
  // ChatMarkAsRead — AC7: unread count resets to 0 when chat opened
  // -------------------------------------------------------------------------

  group('ChatMarkAsRead', () {
    blocTest<ChatBloc, ChatState>(
      'calls markAsRead when state is ChatLoaded',
      build: () => ChatBloc(chatRepository: mockRepo),
      seed: () => const ChatLoaded(
        conversationId: 'conv-1',
        currentUid: 'uid-me',
        recipientUid: 'uid-other',
        messages: [],
      ),
      act: (bloc) => bloc.add(const ChatMarkAsRead()),
      verify: (_) => verify(
        () => mockRepo.markAsRead(
          conversationId: 'conv-1',
          uid: 'uid-me',
        ),
      ).called(1),
    );

    blocTest<ChatBloc, ChatState>(
      'does nothing when state is not ChatLoaded',
      build: () => ChatBloc(chatRepository: mockRepo),
      act: (bloc) => bloc.add(const ChatMarkAsRead()),
      expect: () => <ChatState>[],
      verify: (_) => verifyNever(
        () => mockRepo.markAsRead(
          conversationId: any(named: 'conversationId'),
          uid: any(named: 'uid'),
        ),
      ),
    );
  });

  // -------------------------------------------------------------------------
  // Event / State props and equality
  // -------------------------------------------------------------------------

  group('ChatWatchStarted props', () {
    test('contains conversationId, currentUid, recipientUid', () {
      const event = ChatWatchStarted(
        conversationId: 'conv-1',
        currentUid: 'uid-me',
        recipientUid: 'uid-other',
      );
      expect(
        event.props,
        containsAll(['conv-1', 'uid-me', 'uid-other']),
      );
    });
  });

  group('ChatMessageSent props', () {
    test('contains text', () {
      const event = ChatMessageSent('Hi');
      expect(event.props, equals(['Hi']));
    });

    test('supports value equality', () {
      const a = ChatMessageSent('Hi');
      const b = ChatMessageSent('Hi');
      expect(a, equals(b));
    });
  });

  group('ChatLoaded', () {
    test('props contains all fields', () {
      const state = ChatLoaded(
        conversationId: 'conv-1',
        currentUid: 'uid-me',
        recipientUid: 'uid-other',
        messages: [],
      );
      expect(state.props, isNotEmpty);
    });
  });

  group('ChatError', () {
    test('contains message in props', () {
      const state = ChatError('oops');
      expect(state.props, equals(['oops']));
    });

    test('supports value equality', () {
      const a = ChatError('oops');
      const b = ChatError('oops');
      expect(a, equals(b));
    });
  });
}
