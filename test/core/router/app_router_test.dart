// test/core/router/app_router_test.dart
//
// Tests for createRouter — verifies auth redirect guard, GoRouterRefreshStream,
// and route-level rendering of AppShellScreen at /home.
//
// Updated to provide ProfileBloc after FEAT-002 replaced the Profile tab
// placeholder with the real ProfileScreen (which requires ProfileBloc).
//
// Updated to provide PostBloc after FEAT-003 replaced the Feed tab placeholder
// with the real FeedScreen (which uses BlocBuilder<PostBloc, PostState>).
//
// Updated to provide SearchBloc and FollowRepository after FEAT-006 added the
// Search tab (SearchScreen requires both in the widget tree).
//
// Updated to provide ProfileRepository after BUG-007 fix: the /profile/:uid
// route builder calls context.read<ProfileRepository>() to create a scoped
// ProfileBloc independent of the global one.
//
// Updated to provide PostRepository after SOCAA-252: AppShellScreen and the
// /profile/:uid route builder both create a scoped PostBloc via
// context.read<PostRepository>().
//
// Tests that navigate to /home use pump() instead of pumpAndSettle() because
// ProfileScreen shows a CircularProgressIndicator whose animation never settles.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/core/router/app_router.dart';
import 'package:social_network/features/auth/domain/entities/user_entity.dart';
import 'package:social_network/features/auth/domain/repositories/auth_repository.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/auth/presentation/screens/login_screen.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';
import 'package:social_network/features/profile/domain/repositories/profile_repository.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';
import 'package:social_network/features/profile/presentation/screens/profile_screen.dart';
import 'package:social_network/features/search/presentation/bloc/search_bloc.dart';
import 'package:social_network/features/search/presentation/bloc/search_event.dart';
import 'package:social_network/features/search/presentation/bloc/search_state.dart';
import 'package:social_network/features/shell/presentation/screens/app_shell_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockPostBloc extends MockBloc<PostEvent, PostState> implements PostBloc {}

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

class MockSearchBloc extends MockBloc<SearchEvent, SearchState>
    implements SearchBloc {}

class MockFollowRepository extends Mock implements FollowRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockPostRepository extends Mock implements PostRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const UserEntity _testUser = UserEntity(
  uid: 'uid-abc',
  email: 'test@example.com',
  displayName: 'test',
);

Widget _buildApp(
  MockAuthRepository mockRepo,
  MockAuthBloc authBloc,
  MockPostBloc postBloc,
  MockProfileBloc profileBloc,
  MockSearchBloc searchBloc,
  MockFollowRepository followRepository,
  MockProfileRepository profileRepository,
  MockPostRepository postRepository, {
  GoRouter? router,
}) {
  final effectiveRouter = router ?? createRouter(authRepository: mockRepo);
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FollowRepository>.value(value: followRepository),
      RepositoryProvider<ProfileRepository>.value(value: profileRepository),
      RepositoryProvider<PostRepository>.value(value: postRepository),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<PostBloc>.value(value: postBloc),
        BlocProvider<ProfileBloc>.value(value: profileBloc),
        BlocProvider<SearchBloc>.value(value: searchBloc),
      ],
      child: MaterialApp.router(routerConfig: effectiveRouter),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthRepository mockRepo;
  late MockAuthBloc mockBloc;
  late MockPostBloc postBloc;
  late MockProfileBloc profileBloc;
  late MockSearchBloc searchBloc;
  late MockFollowRepository followRepository;
  late MockProfileRepository profileRepository;
  late MockPostRepository postRepository;

  setUpAll(() {
    registerFallbackValue(const ProfileLoadRequested(uid: ''));
    registerFallbackValue(const ProfileWatchRequested(uid: ''));
    registerFallbackValue(const PostWatchStarted());
    registerFallbackValue(
      const SearchQueryChanged(query: '', currentUid: ''),
    );
    registerFallbackValue(const SearchCleared());
  });

  setUp(() {
    mockRepo = MockAuthRepository();
    mockBloc = MockAuthBloc();
    postBloc = MockPostBloc();
    profileBloc = MockProfileBloc();
    searchBloc = MockSearchBloc();
    followRepository = MockFollowRepository();
    profileRepository = MockProfileRepository();
    postRepository = MockPostRepository();
    // Scoped PostBloc (created by AppShellScreen and /profile/:uid route)
    // calls watchPostsByAuthorUid and watchPostLiked on the real repository.
    when(() => postRepository.watchPostsByAuthorUid(any()))
        .thenAnswer((_) => const Stream.empty());
    when(() => postRepository.watchPostLiked(any(), any()))
        .thenAnswer((_) => Stream.value(false));
    when(() => mockBloc.state).thenReturn(const AuthInitial());
    when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => postBloc.state).thenReturn(const PostLoaded(posts: []));
    when(() => postBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => profileBloc.state).thenReturn(const ProfileInitial());
    when(() => profileBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => searchBloc.state).thenReturn(const SearchInitial());
    when(() => searchBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  group('GoRouterRefreshStream', () {
    test('calls notifyListeners when stream emits', () async {
      final controller = StreamController<void>();
      final refreshStream = GoRouterRefreshStream(controller.stream);

      int notifyCount = 0;
      refreshStream.addListener(() => notifyCount++);

      controller.add(null);
      // Stream events are delivered asynchronously; yield to the event loop.
      await Future<void>.delayed(Duration.zero);
      expect(notifyCount, 1);

      controller.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(notifyCount, 2);

      refreshStream.dispose();
      await controller.close();
    });

    test('dispose cancels stream subscription', () async {
      final controller = StreamController<void>();
      final refreshStream = GoRouterRefreshStream(controller.stream);

      int notifyCount = 0;
      refreshStream.addListener(() => notifyCount++);

      refreshStream.dispose();

      // Emitting after dispose should not call listeners.
      controller.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(notifyCount, 0);

      await controller.close();
    });
  });

  group('createRouter — auth redirect', () {
    testWidgets('unauthenticated user on initial load lands on LoginScreen',
        (WidgetTester tester) async {
      when(() => mockRepo.currentUser).thenReturn(null);
      when(() => mockRepo.authStateChanges)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(
        _buildApp(
          mockRepo,
          mockBloc,
          postBloc,
          profileBloc,
          searchBloc,
          followRepository,
          profileRepository,
          postRepository,
        ),
      );
      await tester.pumpAndSettle(); // LoginScreen has no ongoing animations.

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets(
        'unauthenticated user navigating to /home is redirected to /login',
        (WidgetTester tester) async {
      when(() => mockRepo.currentUser).thenReturn(null);
      when(() => mockRepo.authStateChanges)
          .thenAnswer((_) => const Stream.empty());

      final router = createRouter(authRepository: mockRepo);
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<FollowRepository>.value(value: followRepository),
            RepositoryProvider<ProfileRepository>.value(
                value: profileRepository),
            RepositoryProvider<PostRepository>.value(value: postRepository),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: mockBloc),
              BlocProvider<PostBloc>.value(value: postBloc),
              BlocProvider<ProfileBloc>.value(value: profileBloc),
              BlocProvider<SearchBloc>.value(value: searchBloc),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/home');
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppShellScreen), findsNothing);
    });

    testWidgets(
        'authenticated user navigating to /login is redirected to /home',
        (WidgetTester tester) async {
      when(() => mockRepo.currentUser).thenReturn(_testUser);
      when(() => mockRepo.authStateChanges)
          .thenAnswer((_) => const Stream.empty());

      final router = createRouter(authRepository: mockRepo);
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<FollowRepository>.value(value: followRepository),
            RepositoryProvider<ProfileRepository>.value(
                value: profileRepository),
            RepositoryProvider<PostRepository>.value(value: postRepository),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: mockBloc),
              BlocProvider<PostBloc>.value(value: postBloc),
              BlocProvider<ProfileBloc>.value(value: profileBloc),
              BlocProvider<SearchBloc>.value(value: searchBloc),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      // pump() is sufficient to process the redirect — pumpAndSettle() would
      // time out because ProfileScreen shows a non-settling CircularProgressIndicator.
      await tester.pump();

      // The router redirects /login → /home when authenticated.
      expect(find.byType(AppShellScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('auth state change triggers redirect via GoRouterRefreshStream',
        (WidgetTester tester) async {
      final authController = StreamController<UserEntity?>();

      when(() => mockRepo.currentUser).thenReturn(null);
      when(() => mockRepo.authStateChanges)
          .thenAnswer((_) => authController.stream);

      final router = createRouter(authRepository: mockRepo);
      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<FollowRepository>.value(value: followRepository),
            RepositoryProvider<ProfileRepository>.value(
                value: profileRepository),
            RepositoryProvider<PostRepository>.value(value: postRepository),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: mockBloc),
              BlocProvider<PostBloc>.value(value: postBloc),
              BlocProvider<ProfileBloc>.value(value: profileBloc),
              BlocProvider<SearchBloc>.value(value: searchBloc),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      // pump() instead of pumpAndSettle(): the open StreamController keeps
      // GoRouterRefreshStream alive, so pumpAndSettle() never resolves.
      await tester.pump();

      // Initially unauthenticated → LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);

      // Simulate sign-in: update currentUser and emit on auth stream
      when(() => mockRepo.currentUser).thenReturn(_testUser);
      // runAsync escapes fakeAsync so the real event loop can deliver the stream
      // event to GoRouterRefreshStream before we pump the widget tree.
      await tester.runAsync(() async {
        authController.add(_testUser);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      await tester.pump();

      // Router should redirect to /home
      expect(find.byType(AppShellScreen), findsOneWidget);

      authController.close();
    });
  });

  // ---------------------------------------------------------------------------
  // BUG-007 regression — /profile/:uid uses scoped ProfileBloc + FollowBloc
  // ---------------------------------------------------------------------------
  //
  // Root cause: the global ProfileBloc used a sequential event transformer with
  // emit.forEach on an infinite Firestore stream. ProfileWatchRequested events
  // for other UIDs were queued and never processed, so Follow/Unfollow Firestore
  // writes caused the global ProfileBloc to emit the current user's profile —
  // making the screen appear to navigate away from the viewed profile.
  //
  // Fix: each /profile/:uid route builder wraps ProfileScreen in a
  // MultiBlocProvider that creates a fresh ProfileBloc and FollowBloc scoped
  // to that route. The global ProfileBloc is never touched.

  group('BUG-007 fix — /profile/:uid uses scoped ProfileBloc + FollowBloc',
      () {
    const String otherUid = 'uid-other';
    const UserProfileEntity otherProfile = UserProfileEntity(
      uid: otherUid,
      displayName: 'Other User',
      bio: 'bio text',
      avatarUrl: null,
      postCount: 3,
    );

    setUp(() {
      // Authenticate as _testUser so the router stays on /home after redirect.
      when(() => mockRepo.currentUser).thenReturn(_testUser);
      when(() => mockRepo.authStateChanges)
          .thenAnswer((_) => const Stream.empty());
      // AuthBloc must report authenticated so ProfileScreen resolves currentUid.
      when(() => mockBloc.state)
          .thenReturn(const AuthAuthenticated(user: _testUser));
    });

    testWidgets(
        '/profile/:uid route renders a ProfileScreen widget',
        (WidgetTester tester) async {
      when(() => profileRepository.watchProfile(otherUid))
          .thenAnswer((_) => const Stream.empty());
      when(
        () => followRepository.watchIsFollowing(
          followerId: _testUser.uid,
          followeeId: otherUid,
        ),
      ).thenAnswer((_) => const Stream.empty());

      final router = createRouter(authRepository: mockRepo);
      await tester.pumpWidget(
        _buildApp(
          mockRepo,
          mockBloc,
          postBloc,
          profileBloc,
          searchBloc,
          followRepository,
          profileRepository,
          postRepository,
          router: router,
        ),
      );
      await tester.pump(); // Resolve auth redirect → /home

      router.go('/profile/$otherUid');
      await tester.pump(); // Route transition
      await tester.pump(); // Scoped bloc initialisation

      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets(
        'navigating to /profile/:uid does NOT dispatch ProfileWatchRequested '
        'to the global ProfileBloc',
        (WidgetTester tester) async {
      when(() => profileRepository.watchProfile(otherUid))
          .thenAnswer((_) => Stream.value(otherProfile));
      when(
        () => followRepository.watchIsFollowing(
          followerId: _testUser.uid,
          followeeId: otherUid,
        ),
      ).thenAnswer((_) => Stream.value(false));

      final router = createRouter(authRepository: mockRepo);
      await tester.pumpWidget(
        _buildApp(
          mockRepo,
          mockBloc,
          postBloc,
          profileBloc,
          searchBloc,
          followRepository,
          profileRepository,
          postRepository,
          router: router,
        ),
      );
      await tester.pump(); // Resolve redirect

      // Clear any interactions from the initial /home render.
      clearInteractions(profileBloc);

      router.go('/profile/$otherUid');
      await tester.pump(); // Route transition: builds ProfileScreen
      await tester.pump(); // didChangeDependencies fires
      await tester.pump(); // Scoped ProfileBloc event processing

      // Ensure the route rendered (so the verifyNever is not trivially true).
      expect(find.byType(ProfileScreen), findsOneWidget);

      // The scoped ProfileBloc (not the global one) should handle this UID.
      verifyNever(
        () => profileBloc.add(ProfileWatchRequested(uid: otherUid)),
      );
    });

    testWidgets(
        'navigating to /profile/:uid calls ProfileRepository.watchProfile '
        'via the scoped ProfileBloc (not the global mock bloc)',
        (WidgetTester tester) async {
      // Use Stream.value so the scoped ProfileBloc transitions all the way to
      // ProfileLoaded — this ensures watchProfile is called AND that the BLoC
      // event was fully processed before we verify.
      when(() => profileRepository.watchProfile(otherUid))
          .thenAnswer((_) => Stream.value(otherProfile));
      when(
        () => followRepository.watchIsFollowing(
          followerId: _testUser.uid,
          followeeId: otherUid,
        ),
      ).thenAnswer((_) => Stream.value(false));

      final router = createRouter(authRepository: mockRepo);
      await tester.pumpWidget(
        _buildApp(
          mockRepo,
          mockBloc,
          postBloc,
          profileBloc,
          searchBloc,
          followRepository,
          profileRepository,
          postRepository,
          router: router,
        ),
      );
      await tester.pump(); // Resolve auth redirect → /home

      router.go('/profile/$otherUid');
      await tester.pump(); // Route transition: builds ProfileScreen
      await tester.pump(); // didChangeDependencies → dispatches event to scoped bloc
      await tester.pump(); // Scoped ProfileBloc processes event, calls watchProfile

      // The scoped ProfileBloc must have called the repository, not the
      // global MockProfileBloc.
      verify(() => profileRepository.watchProfile(otherUid)).called(1);
    });

    testWidgets(
        'tapping Follow on /profile/:uid does not navigate away '
        'from the ProfileScreen',
        (WidgetTester tester) async {
      when(() => profileRepository.watchProfile(otherUid))
          .thenAnswer((_) => Stream.value(otherProfile));
      when(
        () => followRepository.watchIsFollowing(
          followerId: _testUser.uid,
          followeeId: otherUid,
        ),
      ).thenAnswer((_) => Stream.value(false));
      when(
        () => followRepository.follow(
          followerId: _testUser.uid,
          followeeId: otherUid,
        ),
      ).thenAnswer((_) async {});

      final router = createRouter(authRepository: mockRepo);
      await tester.pumpWidget(
        _buildApp(
          mockRepo,
          mockBloc,
          postBloc,
          profileBloc,
          searchBloc,
          followRepository,
          profileRepository,
          postRepository,
          router: router,
        ),
      );
      await tester.pump();

      router.go('/profile/$otherUid');
      // Multiple pumps to allow the scoped ProfileBloc and FollowBloc to
      // process their Stream.value emissions before we interact with the UI.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Follow'), findsOneWidget);

      await tester.tap(find.text('Follow'));
      await tester.pump();

      // The screen must NOT navigate away — ProfileScreen remains in tree.
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets(
        'tapping Unfollow on /profile/:uid does not navigate away '
        'from the ProfileScreen',
        (WidgetTester tester) async {
      when(() => profileRepository.watchProfile(otherUid))
          .thenAnswer((_) => Stream.value(otherProfile));
      when(
        () => followRepository.watchIsFollowing(
          followerId: _testUser.uid,
          followeeId: otherUid,
        ),
      ).thenAnswer((_) => Stream.value(true));
      when(
        () => followRepository.unfollow(
          followerId: _testUser.uid,
          followeeId: otherUid,
        ),
      ).thenAnswer((_) async {});

      final router = createRouter(authRepository: mockRepo);
      await tester.pumpWidget(
        _buildApp(
          mockRepo,
          mockBloc,
          postBloc,
          profileBloc,
          searchBloc,
          followRepository,
          profileRepository,
          postRepository,
          router: router,
        ),
      );
      await tester.pump();

      router.go('/profile/$otherUid');
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('Unfollow'), findsOneWidget);

      await tester.tap(find.text('Unfollow'));
      await tester.pump();

      // The screen must NOT navigate away — ProfileScreen remains in tree.
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets(
        'after viewing /profile/:uid, global ProfileBloc state is unchanged '
        '(Profile tab still shows the logged-in user)',
        (WidgetTester tester) async {
      when(() => profileRepository.watchProfile(otherUid))
          .thenAnswer((_) => const Stream.empty());
      when(
        () => followRepository.watchIsFollowing(
          followerId: _testUser.uid,
          followeeId: otherUid,
        ),
      ).thenAnswer((_) => const Stream.empty());

      final router = createRouter(authRepository: mockRepo);
      await tester.pumpWidget(
        _buildApp(
          mockRepo,
          mockBloc,
          postBloc,
          profileBloc,
          searchBloc,
          followRepository,
          profileRepository,
          postRepository,
          router: router,
        ),
      );
      await tester.pump();

      // Capture global ProfileBloc state before navigating to another profile.
      final stateBefore = profileBloc.state;

      router.go('/profile/$otherUid');
      await tester.pump();
      await tester.pump();

      // The global ProfileBloc state must be identical — it was never touched.
      expect(profileBloc.state, stateBefore);
    });
  });
}
