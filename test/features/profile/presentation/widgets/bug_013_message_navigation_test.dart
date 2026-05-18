// test/features/profile/presentation/widgets/bug_013_message_navigation_test.dart
//
// BUG-013 regression tests — isCurrent guard on ProfileScreen BlocListener.
//
// Root cause: ProfileScreen was simultaneously mounted in two places
// (AppShellScreen IndexedStack tab + pushed /profile/:uid route). Both
// BlocListeners subscribed to ConversationsBloc and both would navigate on
// ConversationsNavigateToChat, causing a double-push that cancelled out.
//
// Fix: ModalRoute.of(context)?.isCurrent == true guard in the BlocListener.
// Commit 3b2f907 on feat/SOCAA-262-chat.
//
// Acceptance criteria (SOCAA-272):
// 1. Happy path — Message button tap dispatches ConversationsOpenOrCreate.
// 2. Own profile — Message button is absent on the logged-in user's own profile.
// 3. No double-push — ConversationsNavigateToChat navigates to /chat/conv-1 once;
//    pressing back returns to the profile screen.
// 4. Background tab unaffected — a non-current ProfileScreen (isCurrent==false)
//    does NOT navigate when ConversationsNavigateToChat is emitted.
// 5. Regression — verified by running the full test suite (flutter test).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/auth/domain/entities/user_entity.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/chat/domain/entities/conversation_entity.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_bloc.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_event.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_state.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_bloc.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_state.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';
import 'package:social_network/features/profile/presentation/screens/profile_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

class MockFollowBloc extends MockBloc<FollowEvent, FollowState>
    implements FollowBloc {}

class MockPostBloc extends MockBloc<PostEvent, PostState> implements PostBloc {}

class MockPostRepository extends Mock implements PostRepository {}

class MockConversationsBloc
    extends MockBloc<ConversationsEvent, ConversationsState>
    implements ConversationsBloc {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _testUser = UserEntity(
  uid: 'uid-me',
  email: 'me@example.com',
  displayName: 'Me',
);

const _ownProfile = UserProfileEntity(
  uid: 'uid-me',
  displayName: 'Alice',
  bio: 'I love Flutter',
  avatarUrl: null,
  postCount: 7,
);

const _otherProfile = UserProfileEntity(
  uid: 'uid-other',
  displayName: 'Bob',
  bio: '',
  avatarUrl: null,
  postCount: 2,
);

final _now = DateTime(2026, 5, 18);

ConversationEntity _makeConversation({String id = 'conv-1'}) =>
    ConversationEntity(
      id: id,
      participantUids: const ['uid-me', 'uid-other'],
      lastMessageText: 'Hi',
      lastMessageAt: _now,
      lastMessageSenderUid: 'uid-other',
      unreadCounts: const {'uid-me': 0, 'uid-other': 0},
      createdAt: _now,
    );

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a ProfileScreen inside a GoRouter with routes for profile, chat, and
/// an overlay screen. Used for tests that verify navigation behaviour.
Widget _buildNavigationSubject({
  required MockAuthBloc authBloc,
  required MockProfileBloc profileBloc,
  required MockFollowBloc followBloc,
  required MockPostBloc postBloc,
  required MockPostRepository postRepository,
  required MockConversationsBloc conversationsBloc,
  required GoRouter router,
}) {
  return RepositoryProvider<PostRepository>.value(
    value: postRepository,
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<ProfileBloc>.value(value: profileBloc),
        BlocProvider<FollowBloc>.value(value: followBloc),
        BlocProvider<PostBloc>.value(value: postBloc),
        BlocProvider<ConversationsBloc>.value(value: conversationsBloc),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

/// Minimal GoRouter for rendering the ProfileScreen via its normal route entry
/// point. Includes routes for /overlay and /chat/:conversationId stubs.
GoRouter _makeRouter({String initialLocation = '/profile/uid-other'}) =>
    GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/profile/:uid',
          builder: (context, state) =>
              ProfileScreen(uid: state.pathParameters['uid']),
        ),
        GoRoute(
          path: '/overlay',
          builder: (_, __) =>
              const Scaffold(body: Text('Overlay Screen')),
        ),
        GoRoute(
          path: '/chat/:conversationId',
          builder: (_, __) =>
              const Scaffold(body: Text('Chat Screen')),
        ),
      ],
    );

/// Sets up default stub responses shared across tests.
void _stubDefaults({
  required MockAuthBloc authBloc,
  required MockProfileBloc profileBloc,
  required MockFollowBloc followBloc,
  required MockPostBloc postBloc,
  required MockPostRepository postRepository,
  required MockConversationsBloc conversationsBloc,
  UserProfileEntity profile = _otherProfile,
}) {
  when(() => authBloc.state)
      .thenReturn(const AuthAuthenticated(user: _testUser));
  when(() => profileBloc.state).thenReturn(ProfileLoaded(profile: profile));
  when(() => followBloc.state).thenReturn(const FollowInitial());
  when(() => postBloc.state).thenReturn(const PostInitial());
  when(() => postBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => postRepository.watchPostLiked(any(), any()))
      .thenAnswer((_) => Stream.value(false));
  when(() => conversationsBloc.state)
      .thenReturn(const ConversationsInitial());
  when(() => conversationsBloc.stream)
      .thenAnswer((_) => const Stream.empty());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthBloc authBloc;
  late MockProfileBloc profileBloc;
  late MockFollowBloc followBloc;
  late MockPostBloc postBloc;
  late MockPostRepository postRepository;
  late MockConversationsBloc conversationsBloc;

  setUpAll(() {
    registerFallbackValue(const ProfileLoadRequested(uid: ''));
    registerFallbackValue(const AuthSignOutRequested());
    registerFallbackValue(
        const FollowWatchRequested(followerId: '', followeeId: ''));
    registerFallbackValue(
        const FollowRequested(followerId: '', followeeId: ''));
    registerFallbackValue(
        const UnfollowRequested(followerId: '', followeeId: ''));
    registerFallbackValue(
        const PostsByAuthorWatchStarted(authorUid: ''));
    registerFallbackValue(
        const ConversationsOpenOrCreate(currentUid: '', otherUid: ''));
  });

  setUp(() {
    authBloc = MockAuthBloc();
    profileBloc = MockProfileBloc();
    followBloc = MockFollowBloc();
    postBloc = MockPostBloc();
    postRepository = MockPostRepository();
    conversationsBloc = MockConversationsBloc();
  });

  // -------------------------------------------------------------------------
  // AC1 — Happy path: Message button visible and dispatches ConversationsOpenOrCreate
  // -------------------------------------------------------------------------

  group('AC1 — Happy path: Message button on other user profile', () {
    testWidgets(
        'Message button is visible when viewing another user profile',
        (tester) async {
      _stubDefaults(
        authBloc: authBloc,
        profileBloc: profileBloc,
        followBloc: followBloc,
        postBloc: postBloc,
        postRepository: postRepository,
        conversationsBloc: conversationsBloc,
        profile: _otherProfile,
      );
      when(() => followBloc.state)
          .thenReturn(const FollowLoaded(isFollowing: false));

      final router = _makeRouter();
      await tester.pumpWidget(_buildNavigationSubject(
        authBloc: authBloc,
        profileBloc: profileBloc,
        followBloc: followBloc,
        postBloc: postBloc,
        postRepository: postRepository,
        conversationsBloc: conversationsBloc,
        router: router,
      ));
      await tester.pump();

      expect(find.text('Message'), findsOneWidget);
    });

    testWidgets(
        'tapping Message button dispatches ConversationsOpenOrCreate',
        (tester) async {
      _stubDefaults(
        authBloc: authBloc,
        profileBloc: profileBloc,
        followBloc: followBloc,
        postBloc: postBloc,
        postRepository: postRepository,
        conversationsBloc: conversationsBloc,
        profile: _otherProfile,
      );
      when(() => followBloc.state)
          .thenReturn(const FollowLoaded(isFollowing: false));

      final router = _makeRouter();
      await tester.pumpWidget(_buildNavigationSubject(
        authBloc: authBloc,
        profileBloc: profileBloc,
        followBloc: followBloc,
        postBloc: postBloc,
        postRepository: postRepository,
        conversationsBloc: conversationsBloc,
        router: router,
      ));
      await tester.pump();

      await tester.tap(find.text('Message'));
      await tester.pump();

      verify(
        () => conversationsBloc.add(
          const ConversationsOpenOrCreate(
            currentUid: 'uid-me',
            otherUid: 'uid-other',
          ),
        ),
      ).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // AC2 — Own profile: Message button absent (no regression)
  // -------------------------------------------------------------------------

  group('AC2 — Own profile: Message button is absent', () {
    testWidgets(
        'Message button is NOT shown on own profile (uid == null)',
        (tester) async {
      _stubDefaults(
        authBloc: authBloc,
        profileBloc: profileBloc,
        followBloc: followBloc,
        postBloc: postBloc,
        postRepository: postRepository,
        conversationsBloc: conversationsBloc,
        profile: _ownProfile,
      );

      // Navigate to own profile via uid == null equivalent (own uid route)
      final router = GoRouter(
        initialLocation: '/profile/uid-me',
        routes: [
          GoRoute(
            path: '/profile/:uid',
            builder: (context, state) =>
                ProfileScreen(uid: state.pathParameters['uid']),
          ),
        ],
      );

      await tester.pumpWidget(_buildNavigationSubject(
        authBloc: authBloc,
        profileBloc: profileBloc,
        followBloc: followBloc,
        postBloc: postBloc,
        postRepository: postRepository,
        conversationsBloc: conversationsBloc,
        router: router,
      ));
      await tester.pump();

      expect(find.text('Message'), findsNothing);
    });

    testWidgets(
        'Message button is NOT shown when uid parameter is null (shell tab)',
        (tester) async {
      _stubDefaults(
        authBloc: authBloc,
        profileBloc: profileBloc,
        followBloc: followBloc,
        postBloc: postBloc,
        postRepository: postRepository,
        conversationsBloc: conversationsBloc,
        profile: _ownProfile,
      );

      // ProfileScreen with uid == null represents the own-profile shell tab
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            // uid: null → own profile
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      );

      await tester.pumpWidget(_buildNavigationSubject(
        authBloc: authBloc,
        profileBloc: profileBloc,
        followBloc: followBloc,
        postBloc: postBloc,
        postRepository: postRepository,
        conversationsBloc: conversationsBloc,
        router: router,
      ));
      await tester.pump();

      expect(find.text('Message'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // AC3 — No double-push: navigates to chat once; back returns to profile
  // -------------------------------------------------------------------------

  group('AC3 — No double-push: navigation goes to chat exactly once', () {
    testWidgets(
        'ConversationsNavigateToChat navigates to /chat/conv-1 and back returns to profile',
        (tester) async {
      final stateController =
          StreamController<ConversationsState>.broadcast();
      addTearDown(stateController.close);

      _stubDefaults(
        authBloc: authBloc,
        profileBloc: profileBloc,
        followBloc: followBloc,
        postBloc: postBloc,
        postRepository: postRepository,
        conversationsBloc: conversationsBloc,
        profile: _otherProfile,
      );
      when(() => conversationsBloc.stream)
          .thenAnswer((_) => stateController.stream);

      final router = _makeRouter();
      await tester.pumpWidget(_buildNavigationSubject(
        authBloc: authBloc,
        profileBloc: profileBloc,
        followBloc: followBloc,
        postBloc: postBloc,
        postRepository: postRepository,
        conversationsBloc: conversationsBloc,
        router: router,
      ));
      await tester.pumpAndSettle();

      // Emit ConversationsNavigateToChat → foreground ProfileScreen navigates
      stateController.add(ConversationsNavigateToChat(_makeConversation()));
      await tester.pumpAndSettle();

      // Chat screen should now be shown
      expect(find.text('Chat Screen'), findsOneWidget);

      // Pop back — should return to profile, not stuck at another chat push
      router.pop();
      await tester.pumpAndSettle();

      // Back at profile (showing Bob's display name), no chat screen
      expect(find.text('Chat Screen'), findsNothing);
      expect(find.text('Bob'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // AC4 — Background tab unaffected: isCurrent guard prevents navigation
  // -------------------------------------------------------------------------

  group('AC4 — Background tab unaffected: isCurrent guard', () {
    testWidgets(
        'background ProfileScreen (isCurrent==false) does NOT navigate '
        'when ConversationsNavigateToChat is emitted',
        (tester) async {
      final stateController =
          StreamController<ConversationsState>.broadcast();
      addTearDown(stateController.close);

      _stubDefaults(
        authBloc: authBloc,
        profileBloc: profileBloc,
        followBloc: followBloc,
        postBloc: postBloc,
        postRepository: postRepository,
        conversationsBloc: conversationsBloc,
        profile: _otherProfile,
      );
      when(() => conversationsBloc.stream)
          .thenAnswer((_) => stateController.stream);

      final router = _makeRouter();
      await tester.pumpWidget(_buildNavigationSubject(
        authBloc: authBloc,
        profileBloc: profileBloc,
        followBloc: followBloc,
        postBloc: postBloc,
        postRepository: postRepository,
        conversationsBloc: conversationsBloc,
        router: router,
      ));
      await tester.pumpAndSettle();

      // Push '/overlay' on top of ProfileScreen.
      // ProfileScreen is now mounted but NOT current (isCurrent == false).
      router.push('/overlay');
      await tester.pumpAndSettle();

      expect(find.text('Overlay Screen'), findsOneWidget);
      expect(find.text('Chat Screen'), findsNothing);

      // Emit ConversationsNavigateToChat — the background ProfileScreen
      // MUST honour the isCurrent guard and NOT navigate.
      stateController.add(ConversationsNavigateToChat(_makeConversation()));
      await tester.pumpAndSettle();

      // We must still be on the Overlay Screen, not the Chat Screen.
      expect(find.text('Overlay Screen'), findsOneWidget);
      expect(find.text('Chat Screen'), findsNothing);
    });

    testWidgets(
        'foreground ProfileScreen (isCurrent==true) DOES navigate '
        'when ConversationsNavigateToChat is emitted',
        (tester) async {
      final stateController =
          StreamController<ConversationsState>.broadcast();
      addTearDown(stateController.close);

      _stubDefaults(
        authBloc: authBloc,
        profileBloc: profileBloc,
        followBloc: followBloc,
        postBloc: postBloc,
        postRepository: postRepository,
        conversationsBloc: conversationsBloc,
        profile: _otherProfile,
      );
      when(() => conversationsBloc.stream)
          .thenAnswer((_) => stateController.stream);

      final router = _makeRouter();
      await tester.pumpWidget(_buildNavigationSubject(
        authBloc: authBloc,
        profileBloc: profileBloc,
        followBloc: followBloc,
        postBloc: postBloc,
        postRepository: postRepository,
        conversationsBloc: conversationsBloc,
        router: router,
      ));
      await tester.pumpAndSettle();

      // ProfileScreen IS the current route (isCurrent == true).
      // Emitting ConversationsNavigateToChat MUST trigger navigation.
      stateController.add(ConversationsNavigateToChat(_makeConversation()));
      await tester.pumpAndSettle();

      expect(find.text('Chat Screen'), findsOneWidget);
    });
  });
}
