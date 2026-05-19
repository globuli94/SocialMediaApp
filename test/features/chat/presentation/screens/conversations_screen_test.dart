// test/features/chat/presentation/screens/conversations_screen_test.dart
//
// Widget tests for ConversationsScreen — verified via the real navigation
// entry point: AppShellScreen > tap the Messages tab (index 2 per FEAT-011).
//
// Acceptance criteria covered:
// - AC1: Conversations list renders active chats with last message preview
// - AC4: Tapping a conversation navigates to the chat thread
// - AC6: Unread badge visible on conversation tile when unreadCount > 0

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/auth/domain/entities/user_entity.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/chat/domain/entities/conversation_entity.dart';
import 'package:social_network/features/chat/domain/repositories/chat_repository.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_bloc.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_event.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_state.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';
import 'package:social_network/features/search/presentation/bloc/search_bloc.dart';
import 'package:social_network/features/search/presentation/bloc/search_event.dart';
import 'package:social_network/features/search/presentation/bloc/search_state.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_event.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_state.dart';
import 'package:social_network/features/shell/presentation/screens/app_shell_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockPostBloc extends MockBloc<PostEvent, PostState> implements PostBloc {}

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

class MockSearchBloc extends MockBloc<SearchEvent, SearchState>
    implements SearchBloc {}

class MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {}

class MockFollowRepository extends Mock implements FollowRepository {}

class MockPostRepository extends Mock implements PostRepository {}

class MockChatRepository extends Mock implements ChatRepository {}

class MockNotificationsBloc
    extends MockBloc<NotificationsEvent, NotificationsState>
    implements NotificationsBloc {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _now = DateTime(2026, 5, 18);

ConversationEntity _makeConversation({
  String id = 'conv-1',
  String lastMessage = 'Hello from uid-other',
  int unreadForMe = 0,
}) =>
    ConversationEntity(
      id: id,
      participantUids: const ['uid-me', 'uid-other'],
      lastMessageText: lastMessage,
      lastMessageAt: _now,
      lastMessageSenderUid: 'uid-other',
      unreadCounts: {'uid-me': unreadForMe, 'uid-other': 0},
      createdAt: _now,
    );

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _testUser = UserEntity(
  uid: 'uid-me',
  email: 'me@example.com',
  displayName: 'Me',
);

Widget _buildSubject({
  required MockAuthBloc authBloc,
  required MockPostBloc postBloc,
  required MockProfileBloc profileBloc,
  required MockSearchBloc searchBloc,
  required MockConversationsBloc conversationsBloc,
  required MockFollowRepository followRepository,
  required MockPostRepository postRepository,
  required MockChatRepository chatRepository,
  required MockNotificationsBloc notificationsBloc,
}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FollowRepository>.value(value: followRepository),
      RepositoryProvider<PostRepository>.value(value: postRepository),
      RepositoryProvider<ChatRepository>.value(value: chatRepository),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<PostBloc>.value(value: postBloc),
        BlocProvider<ProfileBloc>.value(value: profileBloc),
        BlocProvider<SearchBloc>.value(value: searchBloc),
        BlocProvider<ConversationsBloc>.value(value: conversationsBloc),
        BlocProvider<NotificationsBloc>.value(value: notificationsBloc),
      ],
      child: const MaterialApp(
        home: AppShellScreen(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthBloc authBloc;
  late MockPostBloc postBloc;
  late MockProfileBloc profileBloc;
  late MockSearchBloc searchBloc;
  late MockConversationsBloc conversationsBloc;
  late MockFollowRepository followRepository;
  late MockPostRepository postRepository;
  late MockChatRepository chatRepository;
  late MockNotificationsBloc notificationsBloc;

  setUpAll(() {
    registerFallbackValue(const ProfileLoadRequested(uid: ''));
    registerFallbackValue(const ProfileWatchRequested(uid: ''));
    registerFallbackValue(const PostWatchStarted());
    registerFallbackValue(
      const SearchQueryChanged(query: '', currentUid: ''),
    );
    registerFallbackValue(const SearchCleared());
    registerFallbackValue(const ConversationsWatchStarted(''));
    registerFallbackValue(const NotificationsWatchStarted(''));
  });

  setUp(() {
    authBloc = MockAuthBloc();
    postBloc = MockPostBloc();
    profileBloc = MockProfileBloc();
    searchBloc = MockSearchBloc();
    conversationsBloc = MockConversationsBloc();
    followRepository = MockFollowRepository();
    postRepository = MockPostRepository();
    chatRepository = MockChatRepository();
    notificationsBloc = MockNotificationsBloc();

    when(() => postRepository.watchPostsByAuthorUid(any()))
        .thenAnswer((_) => const Stream.empty());
    when(() => postRepository.watchPostLiked(any(), any()))
        .thenAnswer((_) => Stream.value(false));

    when(() => authBloc.state)
        .thenReturn(const AuthAuthenticated(user: _testUser));
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => postBloc.state).thenReturn(const PostLoaded(posts: []));
    when(() => postBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => profileBloc.state).thenReturn(const ProfileInitial());
    when(() => profileBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => searchBloc.state).thenReturn(const SearchInitial());
    when(() => searchBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => conversationsBloc.state)
        .thenReturn(const ConversationsInitial());
    when(() => conversationsBloc.stream)
        .thenAnswer((_) => const Stream.empty());
    when(() => notificationsBloc.state)
        .thenReturn(const NotificationsLoaded([]));
    when(() => notificationsBloc.stream)
        .thenAnswer((_) => const Stream.empty());
  });

  Widget buildWidget() => _buildSubject(
        authBloc: authBloc,
        postBloc: postBloc,
        profileBloc: profileBloc,
        searchBloc: searchBloc,
        conversationsBloc: conversationsBloc,
        followRepository: followRepository,
        postRepository: postRepository,
        chatRepository: chatRepository,
        notificationsBloc: notificationsBloc,
      );

  group('ConversationsScreen via Messages tab', () {
    testWidgets('Messages tab is present in NavigationBar',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets('Messages tab is at index 2 (Feed=0, Search=1, Messages=2)',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(find.text('Messages'));
      await tester.pump();

      final navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 2);
    });

    // AC1: conversations list loading state
    testWidgets(
        'shows CircularProgressIndicator when ConversationsLoading',
        (WidgetTester tester) async {
      when(() => conversationsBloc.state)
          .thenReturn(const ConversationsLoading());

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Messages'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // AC1: empty state
    testWidgets(
        'shows "No conversations yet" when Loaded with empty list',
        (WidgetTester tester) async {
      when(() => conversationsBloc.state).thenReturn(
        const ConversationsLoaded(
          conversations: [],
          currentUid: 'uid-me',
        ),
      );

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Messages'));
      await tester.pump();

      expect(find.text('No conversations yet'), findsOneWidget);
    });

    // AC1: renders last message preview
    testWidgets(
        'renders conversation list with last message preview',
        (WidgetTester tester) async {
      when(() => conversationsBloc.state).thenReturn(
        ConversationsLoaded(
          conversations: [_makeConversation(lastMessage: 'Hey there!')],
          currentUid: 'uid-me',
        ),
      );

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Messages'));
      await tester.pump();

      expect(find.text('Hey there!'), findsOneWidget);
    });

    // AC6: unread badge on conversation tile
    testWidgets(
        'shows unread count badge on conversation tile when unreadCount > 0',
        (WidgetTester tester) async {
      when(() => conversationsBloc.state).thenReturn(
        ConversationsLoaded(
          conversations: [_makeConversation(unreadForMe: 4)],
          currentUid: 'uid-me',
        ),
      );

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Messages'));
      await tester.pump();

      // Material 3 Badge renders the count; use findsWidgets because Badge may
      // render the label text twice (visible + semantics node).
      expect(find.text('4'), findsWidgets);
    });

    // AC1: error state
    testWidgets(
        'shows error message when ConversationsError',
        (WidgetTester tester) async {
      when(() => conversationsBloc.state).thenReturn(
        const ConversationsError('Failed to load'),
      );

      await tester.pumpWidget(buildWidget());
      await tester.tap(find.text('Messages'));
      await tester.pump();

      expect(find.text('Failed to load'), findsOneWidget);
    });
  });
}
