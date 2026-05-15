// test/features/profile/presentation/widgets/profile_screen_test.dart
//
// Widget tests for ProfileScreen — verifies rendering for each ProfileState
// and read-only / editable mode, without touching real Firebase.
// Updated for FEAT-008: includes UserPostsBloc and PostBloc mocks so that
// the posts layer (UserPostsBloc) and PostCard delete button (PostBloc)
// work correctly in the widget tree.

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
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';
import 'package:social_network/features/posts/presentation/bloc/user_posts_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/user_posts_event.dart';
import 'package:social_network/features/posts/presentation/bloc/user_posts_state.dart';
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

class MockUserPostsBloc extends MockBloc<UserPostsEvent, UserPostsState>
    implements UserPostsBloc {}

class MockPostBloc extends MockBloc<PostEvent, PostState>
    implements PostBloc {}

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
);

final PostEntity alicePost1 = PostEntity(
  id: 'post-newer',
  authorUid: 'uid-me',
  authorDisplayName: 'Alice',
  content: 'My newer post',
  createdAt: DateTime(2026, 2, 1),
);

final PostEntity alicePost2 = PostEntity(
  id: 'post-older',
  authorUid: 'uid-me',
  authorDisplayName: 'Alice',
  content: 'My older post',
  createdAt: DateTime(2026, 1, 1),
);

final PostEntity bobPost = PostEntity(
  id: 'bob-post-1',
  authorUid: 'uid-other',
  authorDisplayName: 'Bob',
  content: 'Bob wrote this',
  createdAt: DateTime(2026, 1, 15),
);

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockAuthBloc authBloc,
  required MockProfileBloc profileBloc,
  required MockFollowBloc followBloc,
  required MockUserPostsBloc userPostsBloc,
  required MockPostBloc postBloc,
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
    ],
  );

  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<ProfileBloc>.value(value: profileBloc),
      BlocProvider<FollowBloc>.value(value: followBloc),
      BlocProvider<UserPostsBloc>.value(value: userPostsBloc),
      BlocProvider<PostBloc>.value(value: postBloc),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthBloc authBloc;
  late MockProfileBloc profileBloc;
  late MockFollowBloc followBloc;
  late MockUserPostsBloc userPostsBloc;
  late MockPostBloc postBloc;

  setUpAll(() {
    registerFallbackValue(const ProfileLoadRequested(uid: ''));
    registerFallbackValue(const AuthSignOutRequested());
    registerFallbackValue(
        const FollowWatchRequested(followerId: '', followeeId: ''));
    registerFallbackValue(
        const FollowRequested(followerId: '', followeeId: ''));
    registerFallbackValue(
        const UnfollowRequested(followerId: '', followeeId: ''));
    registerFallbackValue(const UserPostsWatchStarted(uid: ''));
  });

  setUp(() {
    authBloc = MockAuthBloc();
    profileBloc = MockProfileBloc();
    followBloc = MockFollowBloc();
    userPostsBloc = MockUserPostsBloc();
    postBloc = MockPostBloc();

    // Default auth state: authenticated as testUser.
    when(() => authBloc.state)
        .thenReturn(const AuthAuthenticated(user: testUser));
    // Default follow state: not following.
    when(() => followBloc.state).thenReturn(const FollowInitial());
    // Default user posts state: initial (no posts loaded yet).
    when(() => userPostsBloc.state).thenReturn(const UserPostsInitial());
    // Default post bloc state: initial.
    when(() => postBloc.state).thenReturn(const PostInitial());
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
        ),
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('I love Flutter'), findsOneWidget);
    });

    testWidgets('shows Edit button for own profile (uid == null)', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
        ),
      );

      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('shows Edit button when uid matches current user', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
        ),
      );

      expect(find.text('7'), findsOneWidget);
      expect(find.text('Posts'), findsOneWidget);
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
          uid: 'uid-other',
        ),
      );

      // otherProfile.bio is empty — the bio Text should not appear.
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
        ),
      );

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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
          uid: 'uid-other',
        ),
      );

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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
        ),
      );

      expect(find.text('Follow'), findsNothing);
      expect(find.text('Unfollow'), findsNothing);
    });

    testWidgets('stats row shows followerCount and followingCount',
        (tester) async {
      const profileWithCounts = UserProfileEntity(
        uid: 'uid-other',
        displayName: 'Bob',
        bio: '',
        avatarUrl: null,
        postCount: 2,
        followerCount: 42,
        followingCount: 17,
      );
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: profileWithCounts));
      when(() => followBloc.state)
          .thenReturn(const FollowLoaded(isFollowing: false));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
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
  // FEAT-008 — UserPostsBloc integration in ProfileScreen
  // -------------------------------------------------------------------------

  group('FEAT-008 — posts list on profile screen', () {
    setUp(() {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));
    });

    // AC-3: empty state shown when user has no posts
    testWidgets('shows "No posts yet." when UserPostsLoaded with empty list',
        (tester) async {
      when(() => userPostsBloc.state)
          .thenReturn(UserPostsLoaded(posts: []));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
        ),
      );

      expect(find.text('No posts yet.'), findsOneWidget);
    });

    // AC-1: posts shown below profile info
    testWidgets('shows authored post content when UserPostsLoaded has posts',
        (tester) async {
      when(() => userPostsBloc.state)
          .thenReturn(UserPostsLoaded(posts: [alicePost1]));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
        ),
      );

      expect(find.text('My newer post'), findsOneWidget);
    });

    // AC-2: posts ordered newest first — order preserved from bloc
    testWidgets('renders posts in bloc-provided order (newest first)',
        (tester) async {
      when(() => userPostsBloc.state)
          .thenReturn(UserPostsLoaded(posts: [alicePost1, alicePost2]));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
        ),
      );

      // Both posts rendered
      expect(find.text('My newer post'), findsOneWidget);
      expect(find.text('My older post'), findsOneWidget);

      // The newer post widget appears before the older one in the tree.
      final newerOffset =
          tester.getTopLeft(find.text('My newer post')).dy;
      final olderOffset =
          tester.getTopLeft(find.text('My older post')).dy;
      expect(newerOffset, lessThan(olderOffset));
    });

    // AC-1: profile header rendered above the posts list
    testWidgets('profile header is above posts list in CustomScrollView',
        (tester) async {
      when(() => userPostsBloc.state)
          .thenReturn(UserPostsLoaded(posts: [alicePost1]));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
        ),
      );

      // 'Alice' appears in both the profile header (headlineSmall) and the
      // PostCard author name. Use .first — the header comes first in the tree.
      final nameOffset =
          tester.getTopLeft(find.text('Alice').first).dy;
      final postOffset =
          tester.getTopLeft(find.text('My newer post')).dy;
      expect(nameOffset, lessThan(postOffset));
    });

    // AC-3: loading indicator while posts are being fetched
    testWidgets('shows loading indicator when UserPostsLoading',
        (tester) async {
      when(() => userPostsBloc.state)
          .thenReturn(const UserPostsLoading());

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // AC-4: own profile shows own posts
    testWidgets('own profile (uid == null) shows own posts correctly',
        (tester) async {
      when(() => userPostsBloc.state)
          .thenReturn(UserPostsLoaded(posts: [alicePost1, alicePost2]));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
          // uid == null → own profile
        ),
      );

      expect(find.text('My newer post'), findsOneWidget);
      expect(find.text('My older post'), findsOneWidget);
    });

    // AC-4: another user's profile shows their posts correctly
    testWidgets('another user profile (uid supplied) shows their posts',
        (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: otherProfile));
      when(() => userPostsBloc.state)
          .thenReturn(UserPostsLoaded(posts: [bobPost]));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
          uid: 'uid-other',
        ),
      );

      expect(find.text('Bob wrote this'), findsOneWidget);
    });

    // AC-1: posts are not shown when ProfileState is not loaded
    testWidgets(
        'does not show posts when profile is still loading',
        (tester) async {
      when(() => profileBloc.state).thenReturn(const ProfileLoading());
      when(() => userPostsBloc.state)
          .thenReturn(UserPostsLoaded(posts: [alicePost1]));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          userPostsBloc: userPostsBloc,
          postBloc: postBloc,
        ),
      );

      // ProfileLoading shows a spinner — the post content is not visible.
      expect(find.text('My newer post'), findsNothing);
    });
  });
}
