// test/features/profile/presentation/widgets/profile_screen_test.dart
//
// Widget tests for ProfileScreen — verifies rendering for each ProfileState,
// read-only / editable mode, posts list, and followers/following chip
// navigation. Does not touch real Firebase.

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
import 'package:social_network/features/follow/presentation/bloc/follow_bloc.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_state.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
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

class MockPostRepository extends Mock implements PostRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const UserEntity testUser = UserEntity(
  uid: 'uid-me',
  email: 'me@example.com',
  displayName: 'Me',
);

const UserProfileEntity testProfile = UserProfileEntity(
  uid: 'uid-me',
  displayName: 'Alice',
  bio: 'I love Flutter',
  avatarUrl: null,
  postCount: 7,
);

const UserProfileEntity otherProfile = UserProfileEntity(
  uid: 'uid-other',
  displayName: 'Bob',
  bio: '',
  avatarUrl: null,
  postCount: 2,
  followerCount: 42,
  followingCount: 17,
);

PostEntity _makePost(String id, String content) => PostEntity(
      id: id,
      authorUid: 'uid-me',
      authorDisplayName: 'Alice',
      content: content,
      createdAt: DateTime(2026, 1, 1),
    );

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockAuthBloc authBloc,
  required MockProfileBloc profileBloc,
  required MockFollowBloc followBloc,
  required MockPostRepository postRepository,
  String? uid,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => ProfileScreen(uid: uid),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const Scaffold(body: Text('Edit Profile')),
      ),
      GoRoute(
        path: '/profile/:uid/followers',
        builder: (_, state) => Scaffold(
          body: Text('Followers of ${state.pathParameters['uid']}'),
        ),
      ),
      GoRoute(
        path: '/profile/:uid/following',
        builder: (_, state) => Scaffold(
          body: Text('Following of ${state.pathParameters['uid']}'),
        ),
      ),
    ],
  );

  return RepositoryProvider<PostRepository>.value(
    value: postRepository,
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<ProfileBloc>.value(value: profileBloc),
        BlocProvider<FollowBloc>.value(value: followBloc),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthBloc authBloc;
  late MockProfileBloc profileBloc;
  late MockFollowBloc followBloc;
  late MockPostRepository postRepository;

  setUpAll(() {
    registerFallbackValue(const ProfileLoadRequested(uid: ''));
    registerFallbackValue(const AuthSignOutRequested());
    registerFallbackValue(
        const FollowWatchRequested(followerId: '', followeeId: ''));
    registerFallbackValue(
        const FollowRequested(followerId: '', followeeId: ''));
    registerFallbackValue(
        const UnfollowRequested(followerId: '', followeeId: ''));
  });

  setUp(() {
    authBloc = MockAuthBloc();
    profileBloc = MockProfileBloc();
    followBloc = MockFollowBloc();
    postRepository = MockPostRepository();

    // Default auth state: authenticated as testUser.
    when(() => authBloc.state)
        .thenReturn(const AuthAuthenticated(user: testUser));
    // Default follow state: initial (not watching).
    when(() => followBloc.state).thenReturn(const FollowInitial());
    // Default posts: empty stream so screen renders without posts section error.
    when(() => postRepository.watchPostsByUser(any()))
        .thenAnswer((_) => Stream.value([]));
  });

  // -------------------------------------------------------------------------
  // Loading state
  // -------------------------------------------------------------------------

  group('ProfileLoading', () {
    testWidgets('shows CircularProgressIndicator', (tester) async {
      when(() => profileBloc.state).thenReturn(const ProfileLoading());

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // ProfileInitial state
  // -------------------------------------------------------------------------

  group('ProfileInitial', () {
    testWidgets('shows CircularProgressIndicator', (tester) async {
      when(() => profileBloc.state).thenReturn(const ProfileInitial());

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // ProfileLoaded — own profile
  // -------------------------------------------------------------------------

  group('ProfileLoaded — own profile', () {
    setUp(() {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));
    });

    testWidgets('renders display name and bio', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
        ),
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('I love Flutter'), findsOneWidget);
    });

    testWidgets('shows Edit button for own profile (uid == null)',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
        ),
      );

      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('shows Edit button when uid matches current user',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
          uid: 'uid-me',
        ),
      );

      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('shows post count chip', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
        ),
      );

      // 'Posts' appears as both the StatChip label and the section header.
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Posts'), findsWidgets);
    });
  });

  // -------------------------------------------------------------------------
  // ProfileLoaded — other user's profile (read-only)
  // -------------------------------------------------------------------------

  group('ProfileLoaded — other user profile (read-only)', () {
    testWidgets('does not show Edit button', (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: otherProfile));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
          uid: 'uid-other',
        ),
      );

      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('renders other user display name', (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: otherProfile));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
          uid: 'uid-other',
        ),
      );

      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('does not render bio widget when bio is empty', (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: otherProfile));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
          uid: 'uid-other',
        ),
      );

      expect(find.text(''), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // ProfileUpdating state
  // -------------------------------------------------------------------------

  group('ProfileUpdating', () {
    testWidgets('shows profile data and a progress indicator', (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileUpdating(profile: testProfile));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
        ),
      );
      // Pump to let the posts stream resolve so only the ProfileUpdating
      // spinner remains (the posts waiting spinner resolves to empty list).
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // ProfileFailure state
  // -------------------------------------------------------------------------

  group('ProfileFailure', () {
    testWidgets('shows error message and Retry button', (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileFailure(error: 'Something went wrong'));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
        ),
      );

      expect(find.text('Could not load profile.'), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Logout button — own profile
  // -------------------------------------------------------------------------

  group('Logout button', () {
    setUp(() {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));
    });

    testWidgets('shows logout IconButton for own profile (uid == null)',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
        ),
      );

      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('shows logout IconButton when uid matches current user',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
          uid: 'uid-me',
        ),
      );

      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('does not show logout button for another user profile',
        (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: otherProfile));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
          uid: 'uid-other',
        ),
      );

      expect(find.byIcon(Icons.logout), findsNothing);
    });

    testWidgets('tapping logout button dispatches AuthSignOutRequested',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
        ),
      );

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pump();

      verify(() => authBloc.add(const AuthSignOutRequested())).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // Follow / Unfollow button — other user's profile
  // -------------------------------------------------------------------------

  group('Follow/Unfollow button', () {
    setUp(() {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: otherProfile));
    });

    testWidgets('shows Follow button when FollowLoaded(isFollowing: false)',
        (tester) async {
      when(() => followBloc.state)
          .thenReturn(const FollowLoaded(isFollowing: false));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
          uid: 'uid-other',
        ),
      );

      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Unfollow'), findsNothing);
    });

    testWidgets('shows Unfollow button when FollowLoaded(isFollowing: true)',
        (tester) async {
      when(() => followBloc.state)
          .thenReturn(const FollowLoaded(isFollowing: true));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
          uid: 'uid-other',
        ),
      );

      expect(find.text('Unfollow'), findsOneWidget);
      expect(find.text('Follow'), findsNothing);
    });

    testWidgets('shows CircularProgressIndicator when FollowLoading',
        (tester) async {
      when(() => followBloc.state).thenReturn(const FollowLoading());

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
          uid: 'uid-other',
        ),
      );
      // Pump to let the posts stream resolve — only the FollowLoading spinner
      // should remain after the posts waiting spinner resolves.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('tapping Follow button dispatches FollowRequested',
        (tester) async {
      when(() => followBloc.state)
          .thenReturn(const FollowLoaded(isFollowing: false));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
          uid: 'uid-other',
        ),
      );

      await tester.tap(find.text('Follow'));
      await tester.pump();

      verify(
        () => followBloc.add(
          const FollowRequested(followerId: 'uid-me', followeeId: 'uid-other'),
        ),
      ).called(1);
    });

    testWidgets('tapping Unfollow button dispatches UnfollowRequested',
        (tester) async {
      when(() => followBloc.state)
          .thenReturn(const FollowLoaded(isFollowing: true));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
          uid: 'uid-other',
        ),
      );

      await tester.tap(find.text('Unfollow'));
      await tester.pump();

      verify(
        () => followBloc.add(
          const UnfollowRequested(
              followerId: 'uid-me', followeeId: 'uid-other'),
        ),
      ).called(1);
    });

    testWidgets('Follow button is absent on own profile (uid == null)',
        (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));
      when(() => followBloc.state)
          .thenReturn(const FollowLoaded(isFollowing: false));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
        ),
      );

      expect(find.text('Follow'), findsNothing);
      expect(find.text('Unfollow'), findsNothing);
    });

    testWidgets('stats row shows followerCount and followingCount',
        (tester) async {
      when(() => followBloc.state)
          .thenReturn(const FollowLoaded(isFollowing: false));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
          uid: 'uid-other',
        ),
      );

      expect(find.text('42'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Posts list — FEAT-007
  // -------------------------------------------------------------------------

  group('Posts list', () {
    setUp(() {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));
    });

    testWidgets('shows "No posts yet." when posts stream is empty',
        (tester) async {
      when(() => postRepository.watchPostsByUser('uid-me'))
          .thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
        ),
      );
      // Let the StreamBuilder resolve.
      await tester.pump();

      expect(find.text('No posts yet.'), findsOneWidget);
    });

    testWidgets('shows post content when posts stream emits items',
        (tester) async {
      when(() => postRepository.watchPostsByUser('uid-me')).thenAnswer(
        (_) => Stream.value([
          _makePost('p1', 'Hello world'),
          _makePost('p2', 'Flutter rocks'),
        ]),
      );

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
        ),
      );
      await tester.pump();

      expect(find.text('Hello world'), findsOneWidget);
      expect(find.text('Flutter rocks'), findsOneWidget);
    });

    testWidgets('renders Posts section label when profile is loaded',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
        ),
      );
      await tester.pump();

      expect(find.text('Posts'), findsWidgets);
    });
  });

  // -------------------------------------------------------------------------
  // Followers / Following chip navigation — FEAT-007
  // -------------------------------------------------------------------------

  group('Followers chip navigation', () {
    setUp(() {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: otherProfile));
      when(() => followBloc.state)
          .thenReturn(const FollowLoaded(isFollowing: false));
    });

    testWidgets('tapping Followers chip navigates to followers screen',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
          uid: 'uid-other',
        ),
      );
      await tester.pump();

      // The Followers chip is an InkWell wrapping a Column with text 'Followers'.
      await tester.tap(find.text('Followers'));
      await tester.pumpAndSettle();

      expect(find.text('Followers of uid-other'), findsOneWidget);
    });

    testWidgets('tapping Following chip navigates to following screen',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postRepository: postRepository,
          uid: 'uid-other',
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Following'));
      await tester.pumpAndSettle();

      expect(find.text('Following of uid-other'), findsOneWidget);
    });
  });
}
