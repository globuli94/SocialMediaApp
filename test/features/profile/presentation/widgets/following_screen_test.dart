// test/features/profile/presentation/widgets/following_screen_test.dart
//
// Widget tests for FollowingScreen — verifies loading, empty state, populated
// list with avatar + display name, error state, and profile navigation.
//
// Uses MockFollowListBloc (mocktail) so no real Firebase connections are made.
// FollowListBloc is provided at the /profile/:uid router level in production;
// we mirror that by wrapping FollowingScreen in a BlocProvider in tests.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_bloc.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_state.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';
import 'package:social_network/features/profile/presentation/screens/following_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFollowListBloc extends MockBloc<FollowListEvent, FollowListState>
    implements FollowListBloc {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _userAlice = UserProfileEntity(
  uid: 'uid-alice',
  displayName: 'Alice',
  bio: '',
  avatarUrl: null,
  postCount: 0,
  followerCount: 1,
  followingCount: 0,
);

const _userBob = UserProfileEntity(
  uid: 'uid-bob',
  displayName: 'Bob',
  bio: '',
  avatarUrl: null,
  postCount: 0,
  followerCount: 0,
  followingCount: 1,
);

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

/// Pumps FollowingScreen via a GoRouter so that context.push() works.
/// FollowListBloc is provided at the parent level, mirroring the production
/// router where it is scoped to /profile/:uid.
Widget _buildSubject({
  required MockFollowListBloc followListBloc,
  String uid = 'uid-me',
}) {
  final router = GoRouter(
    initialLocation: '/profile/$uid/following',
    routes: [
      GoRoute(
        path: '/profile/:uid',
        builder: (_, state) => BlocProvider<FollowListBloc>.value(
          value: followListBloc,
          child: FollowingScreen(uid: state.pathParameters['uid']!),
        ),
        routes: [
          GoRoute(
            path: 'followers',
            builder: (_, state) => Scaffold(
              body: Text('Followers ${state.pathParameters['uid']}'),
            ),
          ),
          GoRoute(
            path: 'following',
            builder: (_, state) => BlocProvider<FollowListBloc>.value(
              value: followListBloc,
              child: FollowingScreen(uid: state.pathParameters['uid']!),
            ),
          ),
        ],
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockFollowListBloc followListBloc;

  setUpAll(() {
    registerFallbackValue(const FollowListWatchFollowersStarted(''));
    registerFallbackValue(const FollowListWatchFollowingStarted(''));
  });

  setUp(() {
    followListBloc = MockFollowListBloc();
    when(() => followListBloc.stream)
        .thenAnswer((_) => const Stream.empty());
  });

  // -------------------------------------------------------------------------
  // Loading states
  // -------------------------------------------------------------------------

  group('Loading states', () {
    testWidgets('shows CircularProgressIndicator when FollowListInitial',
        (tester) async {
      when(() => followListBloc.state)
          .thenReturn(const FollowListInitial());

      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator when FollowListLoading',
        (tester) async {
      when(() => followListBloc.state)
          .thenReturn(const FollowListLoading());

      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Empty state (AC: empty state shown when list is empty)
  // -------------------------------------------------------------------------

  group('Empty state', () {
    testWidgets('shows "Not following anyone yet" when list is empty',
        (tester) async {
      when(() => followListBloc.state)
          .thenReturn(const FollowListLoaded(users: []));

      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));
      await tester.pump();

      expect(find.text('Not following anyone yet'), findsOneWidget);
    });

    testWidgets('does not show ListView when list is empty', (tester) async {
      when(() => followListBloc.state)
          .thenReturn(const FollowListLoaded(users: []));

      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));
      await tester.pump();

      expect(find.byType(ListView), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Populated list (AC: shows avatar and display name)
  // -------------------------------------------------------------------------

  group('Populated list', () {
    setUp(() {
      when(() => followListBloc.state).thenReturn(
        const FollowListLoaded(users: [_userAlice, _userBob]),
      );
    });

    testWidgets('shows a ListTile for each followed user', (tester) async {
      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));
      await tester.pump();

      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('shows display names of followed users', (tester) async {
      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('shows a leading widget (avatar) for each followed user',
        (tester) async {
      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));
      await tester.pump();

      final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
      for (final tile in tiles) {
        expect(tile.leading, isNotNull);
      }
    });
  });

  // -------------------------------------------------------------------------
  // Navigation (AC: tapping entry navigates to profile)
  // -------------------------------------------------------------------------

  group('Navigation', () {
    setUp(() {
      when(() => followListBloc.state).thenReturn(
        const FollowListLoaded(users: [_userAlice]),
      );
    });

    testWidgets('tapping a following entry navigates to their profile',
        (tester) async {
      // Single /profile/:uid route. For 'uid-me' it renders FollowingScreen;
      // for any other uid it renders a stub "Profile <uid>" so we can detect
      // navigation to the tapped user's profile.
      final router = GoRouter(
        initialLocation: '/profile/uid-me/following',
        routes: [
          GoRoute(
            path: '/profile/:uid',
            builder: (_, state) {
              final uid = state.pathParameters['uid']!;
              if (uid == 'uid-me') {
                return BlocProvider<FollowListBloc>.value(
                  value: followListBloc,
                  child: FollowingScreen(uid: uid),
                );
              }
              return Scaffold(body: Text('Profile $uid'));
            },
            routes: [
              GoRoute(
                path: 'following',
                builder: (_, state) => BlocProvider<FollowListBloc>.value(
                  value: followListBloc,
                  child: FollowingScreen(
                      uid: state.pathParameters['uid']!),
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(find.text('Profile uid-alice'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Error state
  // -------------------------------------------------------------------------

  group('Error state', () {
    testWidgets('shows "Could not load following" when FollowListFailure',
        (tester) async {
      when(() => followListBloc.state)
          .thenReturn(const FollowListFailure(error: 'timeout'));

      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));
      await tester.pump();

      expect(find.text('Could not load following'), findsOneWidget);
    });

    testWidgets('shows the error message details when FollowListFailure',
        (tester) async {
      when(() => followListBloc.state)
          .thenReturn(const FollowListFailure(error: 'timeout'));

      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));
      await tester.pump();

      expect(find.text('timeout'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // AppBar title
  // -------------------------------------------------------------------------

  testWidgets('shows "Following" in AppBar title', (tester) async {
    when(() => followListBloc.state)
        .thenReturn(const FollowListLoaded(users: []));

    await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));
    await tester.pump();

    expect(find.text('Following'), findsOneWidget);
  });
}
