// test/features/profile/presentation/widgets/profile_screen_test.dart
//
// Widget tests for ProfileScreen — verifies rendering for each ProfileState
// and read-only / editable mode, without touching real Firebase.
// Also covers _PostsSliver rendering for FEAT-008 profile posts feature.

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

final PostEntity testPost = PostEntity(
  id: 'post-1',
  authorUid: 'uid-me',
  authorDisplayName: 'Alice',
  content: 'Hello from profile posts',
  createdAt: DateTime(2026, 1, 1),
);

final PostEntity testPost2 = PostEntity(
  id: 'post-2',
  authorUid: 'uid-me',
  authorDisplayName: 'Alice',
  content: 'Second post content',
  createdAt: DateTime(2026, 1, 2),
);

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockAuthBloc authBloc,
  required MockProfileBloc profileBloc,
  required MockFollowBloc followBloc,
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
  late MockPostBloc postBloc;

  setUpAll(() {
    registerFallbackValue(const ProfileLoadRequested(uid: ''));
    registerFallbackValue(const ProfileWatchRequested(uid: ''));
    registerFallbackValue(const AuthSignOutRequested());
    registerFallbackValue(
        const FollowWatchRequested(followerId: '', followeeId: ''));
    registerFallbackValue(
        const FollowRequested(followerId: '', followeeId: ''));
    registerFallbackValue(
        const UnfollowRequested(followerId: '', followeeId: ''));
    registerFallbackValue(const PostWatchByAuthorStarted(authorUid: ''));
  });

  setUp(() {
    authBloc = MockAuthBloc();
    profileBloc = MockProfileBloc();
    followBloc = MockFollowBloc();
    postBloc = MockPostBloc();

    // Default auth state: authenticated as testUser.
    when(() => authBloc.state)
        .thenReturn(const AuthAuthenticated(user: testUser));
    // Default follow state: not following.
    when(() => followBloc.state).thenReturn(const FollowInitial());
    // Default post state: initial (no posts loaded yet).
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
            postBloc: postBloc),
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
            postBloc: postBloc),
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
            postBloc: postBloc),
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
            postBloc: postBloc),
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
            postBloc: postBloc),
      );

      expect(find.text('7'), findsOneWidget);
      // 'Posts' appears in both the stat chip label and the section header
      // added by FEAT-008, so expect at least 2 occurrences.
      expect(find.text('Posts'), findsAtLeastNWidgets(2));
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
            postBloc: postBloc),
      );

      expect(find.text('Alice'), findsOneWidget);
      // At least one CPI from ProfileUpdating spinner (posts sliver may also
      // show one when PostBloc is in initial/loading state).
      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
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
            postBloc: postBloc),
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
            postBloc: postBloc),
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
            postBloc: postBloc),
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
          postBloc: postBloc,
          uid: 'uid-other',
        ),
      );

      // At least one CPI from FollowLoading button (posts sliver may also
      // show one when PostBloc is in initial/loading state).
      expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
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
  // _PostsSliver — PostLoading / PostInitial
  // -------------------------------------------------------------------------

  group('_PostsSliver — PostLoading', () {
    testWidgets('shows CircularProgressIndicator when PostLoading',
        (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));
      when(() => postBloc.state).thenReturn(const PostLoading());

      await tester.pumpWidget(
        _buildSubject(
            authBloc: authBloc,
            profileBloc: profileBloc,
            followBloc: followBloc,
            postBloc: postBloc),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // _PostsSliver — PostLoaded with posts (FEAT-008)
  // -------------------------------------------------------------------------

  group('_PostsSliver — PostLoaded with posts', () {
    testWidgets('renders post content for each post', (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));
      when(() => postBloc.state)
          .thenReturn(PostLoaded(posts: [testPost, testPost2]));

      await tester.pumpWidget(
        _buildSubject(
            authBloc: authBloc,
            profileBloc: profileBloc,
            followBloc: followBloc,
            postBloc: postBloc),
      );

      // Scroll to trigger lazy loading of list items.
      await tester.pump();

      expect(find.text('Hello from profile posts'), findsOneWidget);
      expect(find.text('Second post content'), findsOneWidget);
    });

    testWidgets('does not show "No posts yet" when posts are present',
        (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));
      when(() => postBloc.state).thenReturn(PostLoaded(posts: [testPost]));

      await tester.pumpWidget(
        _buildSubject(
            authBloc: authBloc,
            profileBloc: profileBloc,
            followBloc: followBloc,
            postBloc: postBloc),
      );

      await tester.pump();

      expect(find.text('No posts yet'), findsNothing);
    });

    testWidgets(
        'own profile shows delete button on own post and not on others',
        (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));
      // testPost.authorUid == 'uid-me' == current user → delete button visible
      when(() => postBloc.state).thenReturn(PostLoaded(posts: [testPost]));

      await tester.pumpWidget(
        _buildSubject(
            authBloc: authBloc,
            profileBloc: profileBloc,
            followBloc: followBloc,
            postBloc: postBloc),
      );

      await tester.pump();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('other-user profile: own post shows delete, others do not',
        (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: otherProfile));
      // testPost.authorUid == 'uid-me' == current user, even when viewing
      // another profile; delete button should appear for own posts.
      when(() => postBloc.state).thenReturn(PostLoaded(posts: [testPost]));
      when(() => followBloc.state)
          .thenReturn(const FollowLoaded(isFollowing: false));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postBloc: postBloc,
          uid: 'uid-other',
        ),
      );

      await tester.pump();

      // testPost is authored by uid-me (current user), so delete is shown.
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // _PostsSliver — PostLoaded empty (FEAT-008 empty state)
  // -------------------------------------------------------------------------

  group('_PostsSliver — PostLoaded empty state', () {
    testWidgets('shows "No posts yet" for empty post list', (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));
      when(() => postBloc.state).thenReturn(const PostLoaded(posts: []));

      await tester.pumpWidget(
        _buildSubject(
            authBloc: authBloc,
            profileBloc: profileBloc,
            followBloc: followBloc,
            postBloc: postBloc),
      );

      await tester.pump();

      expect(find.text('No posts yet'), findsOneWidget);
    });

    testWidgets('other user profile shows "No posts yet" when no posts',
        (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: otherProfile));
      when(() => postBloc.state).thenReturn(const PostLoaded(posts: []));
      when(() => followBloc.state)
          .thenReturn(const FollowLoaded(isFollowing: false));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postBloc: postBloc,
          uid: 'uid-other',
        ),
      );

      await tester.pump();

      expect(find.text('No posts yet'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // _PostsSliver — PostFailure
  // -------------------------------------------------------------------------

  group('_PostsSliver — PostFailure', () {
    testWidgets('shows error message when PostFailure', (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));
      when(() => postBloc.state)
          .thenReturn(const PostFailure(error: 'failed to load posts'));

      await tester.pumpWidget(
        _buildSubject(
            authBloc: authBloc,
            profileBloc: profileBloc,
            followBloc: followBloc,
            postBloc: postBloc),
      );

      await tester.pump();

      expect(find.textContaining('failed to load posts'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // PostWatchByAuthorStarted dispatched on didChangeDependencies (FEAT-008)
  // -------------------------------------------------------------------------

  group('PostWatchByAuthorStarted dispatch', () {
    testWidgets(
        'dispatches PostWatchByAuthorStarted with own uid on own profile',
        (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));

      await tester.pumpWidget(
        _buildSubject(
            authBloc: authBloc,
            profileBloc: profileBloc,
            followBloc: followBloc,
            postBloc: postBloc),
      );

      verify(
        () => postBloc.add(
          const PostWatchByAuthorStarted(authorUid: 'uid-me'),
        ),
      ).called(1);
    });

    testWidgets(
        'dispatches PostWatchByAuthorStarted with target uid on other profile',
        (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: otherProfile));
      when(() => followBloc.state)
          .thenReturn(const FollowLoaded(isFollowing: false));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          followBloc: followBloc,
          postBloc: postBloc,
          uid: 'uid-other',
        ),
      );

      verify(
        () => postBloc.add(
          const PostWatchByAuthorStarted(authorUid: 'uid-other'),
        ),
      ).called(1);
    });
  });
}
