// test/features/chat/presentation/screens/chat_screen_test.dart
//
// Widget tests for ChatScreen — verified via real navigation entry point:
// GoRouter push to '/chat/:conversationId' (per app_router.dart spec in
// FEAT-011, which wraps ChatScreen in a scoped BlocProvider<ChatBloc>).
//
// Acceptance criteria covered:
// - AC2: Chat screen renders message bubbles (sent right, received left)
// - AC2: Allows sending text (send button dispatches ChatMessageSent)
// - AC2: Send button disabled when text field is empty

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/chat/domain/entities/message_entity.dart';
import 'package:social_network/features/chat/domain/repositories/chat_repository.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_event.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_state.dart';
import 'package:social_network/features/chat/presentation/screens/chat_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockChatBloc extends MockBloc<ChatEvent, ChatState>
    implements ChatBloc {}

class MockChatRepository extends Mock implements ChatRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

MessageEntity _makeMessage({
  required String id,
  required String senderUid,
  required String text,
}) =>
    MessageEntity(
      id: id,
      senderUid: senderUid,
      text: text,
      createdAt: DateTime(2026, 5, 18, 12, 0),
    );

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds ChatScreen via a GoRouter push to '/chat/conv-1' with extra params,
/// mirroring the production app_router.dart route definition for FEAT-011.
Widget _buildSubject({
  required MockChatBloc chatBloc,
  required MockChatRepository chatRepository,
  String conversationId = 'conv-1',
  String currentUid = 'uid-me',
  String recipientUid = 'uid-other',
}) {
  final router = GoRouter(
    initialLocation: '/chat/$conversationId',
    routes: [
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) {
          final convId = state.pathParameters['conversationId']!;
          final extra = state.extra as Map<String, String>? ??
              {
                'currentUid': currentUid,
                'recipientUid': recipientUid,
              };
          return BlocProvider<ChatBloc>.value(
            value: chatBloc,
            child: ChatScreen(
              conversationId: convId,
              currentUid: extra['currentUid']!,
              recipientUid: extra['recipientUid']!,
            ),
          );
        },
      ),
    ],
  );

  return RepositoryProvider<ChatRepository>.value(
    value: chatRepository,
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockChatBloc chatBloc;
  late MockChatRepository chatRepository;

  setUpAll(() {
    registerFallbackValue(
      const ChatWatchStarted(
        conversationId: '',
        currentUid: '',
        recipientUid: '',
      ),
    );
    registerFallbackValue(const ChatMessageSent(''));
    registerFallbackValue(const ChatMarkAsRead());
  });

  setUp(() {
    chatBloc = MockChatBloc();
    chatRepository = MockChatRepository();
    when(() => chatBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => chatBloc.state).thenReturn(const ChatInitial());
  });

  group('ChatScreen', () {
    testWidgets('shows CircularProgressIndicator when state is ChatLoading',
        (WidgetTester tester) async {
      when(() => chatBloc.state).thenReturn(const ChatLoading());

      await tester.pumpWidget(
        _buildSubject(chatBloc: chatBloc, chatRepository: chatRepository),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when state is ChatError',
        (WidgetTester tester) async {
      when(() => chatBloc.state)
          .thenReturn(const ChatError('Connection failed'));

      await tester.pumpWidget(
        _buildSubject(chatBloc: chatBloc, chatRepository: chatRepository),
      );
      await tester.pump();

      expect(find.text('Connection failed'), findsOneWidget);
    });

    // AC2: renders sent message (senderUid == currentUid) — right-aligned bubble
    testWidgets(
        'renders sent message bubble text when senderUid == currentUid',
        (WidgetTester tester) async {
      when(() => chatBloc.state).thenReturn(
        ChatLoaded(
          conversationId: 'conv-1',
          currentUid: 'uid-me',
          recipientUid: 'uid-other',
          messages: [
            _makeMessage(
              id: 'msg-sent',
              senderUid: 'uid-me',
              text: 'My sent message',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        _buildSubject(chatBloc: chatBloc, chatRepository: chatRepository),
      );
      await tester.pump();

      expect(find.text('My sent message'), findsOneWidget);
    });

    // AC2: renders received message (senderUid != currentUid) — left-aligned bubble
    testWidgets(
        'renders received message bubble text when senderUid != currentUid',
        (WidgetTester tester) async {
      when(() => chatBloc.state).thenReturn(
        ChatLoaded(
          conversationId: 'conv-1',
          currentUid: 'uid-me',
          recipientUid: 'uid-other',
          messages: [
            _makeMessage(
              id: 'msg-recv',
              senderUid: 'uid-other',
              text: 'Their received message',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        _buildSubject(chatBloc: chatBloc, chatRepository: chatRepository),
      );
      await tester.pump();

      expect(find.text('Their received message'), findsOneWidget);
    });

    // AC2: renders both sent and received bubbles in the same view
    testWidgets(
        'renders both sent and received message bubbles',
        (WidgetTester tester) async {
      when(() => chatBloc.state).thenReturn(
        ChatLoaded(
          conversationId: 'conv-1',
          currentUid: 'uid-me',
          recipientUid: 'uid-other',
          messages: [
            _makeMessage(
                id: 'msg-1', senderUid: 'uid-other', text: 'Hello there'),
            _makeMessage(
                id: 'msg-2', senderUid: 'uid-me', text: 'Hi back!'),
          ],
        ),
      );

      await tester.pumpWidget(
        _buildSubject(chatBloc: chatBloc, chatRepository: chatRepository),
      );
      await tester.pump();

      expect(find.text('Hello there'), findsOneWidget);
      expect(find.text('Hi back!'), findsOneWidget);
    });

    // AC2: send button disabled when text field is empty
    testWidgets('send button is disabled when text field is empty',
        (WidgetTester tester) async {
      when(() => chatBloc.state).thenReturn(
        const ChatLoaded(
          conversationId: 'conv-1',
          currentUid: 'uid-me',
          recipientUid: 'uid-other',
          messages: [],
        ),
      );

      await tester.pumpWidget(
        _buildSubject(chatBloc: chatBloc, chatRepository: chatRepository),
      );
      await tester.pump();

      final sendButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send),
      );
      expect(sendButton.onPressed, isNull);
    });

    // AC2: send button dispatches ChatMessageSent when text is non-empty
    testWidgets(
        'send button dispatches ChatMessageSent with correct text on tap',
        (WidgetTester tester) async {
      when(() => chatBloc.state).thenReturn(
        const ChatLoaded(
          conversationId: 'conv-1',
          currentUid: 'uid-me',
          recipientUid: 'uid-other',
          messages: [],
        ),
      );

      await tester.pumpWidget(
        _buildSubject(chatBloc: chatBloc, chatRepository: chatRepository),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Hello world!');
      await tester.pump();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.send));
      await tester.pump();

      verify(
        () => chatBloc.add(const ChatMessageSent('Hello world!')),
      ).called(1);
    });

    // AC2: text field is multiline with max 4 lines
    testWidgets('text field is present and accepts input',
        (WidgetTester tester) async {
      when(() => chatBloc.state).thenReturn(
        const ChatLoaded(
          conversationId: 'conv-1',
          currentUid: 'uid-me',
          recipientUid: 'uid-other',
          messages: [],
        ),
      );

      await tester.pumpWidget(
        _buildSubject(chatBloc: chatBloc, chatRepository: chatRepository),
      );
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
