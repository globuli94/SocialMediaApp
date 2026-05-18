// test/features/follow/presentation/widgets/following_screen_test.dart
//
// Widget tests for FollowingScreen — verifies rendering for each
// FollowListState, the empty state, user list display (avatar + name), and
// navigation on item tap.
//
// Uses mocktail to mock FollowListBloc — no real Firebase connections.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_bloc.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_state.dart';
import 'package:social_network/features/follow/presentation/screens/following_screen.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFollowListBloc extends MockBloc<FollowListEvent, FollowListState>
    implements FollowListBloc {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _carol = UserProfileEntity(
  uid: 'uid-carol',
  displayName: 'Carol',
  bio: 'Dev',
  postCount: 6,
);

const _dave = UserProfileEntity(
  uid: 'uid-dave',
  displayName: 'Dave',
  bio: '',
  postCount: 0,
);

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockFollowListBloc followListBloc,
  String uid = 'uid-target',
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => BlocProvider<FollowListBloc>.value(
          value: followListBloc,
          child: FollowingScreen(uid: uid),
        ),
      ),
      GoRoute(
        path: '/profile/:uid',
        builder: (context, state) => Scaffold(
          body: Text('Profile:${state.pathParameters['uid']}'),
        ),
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
    registerFallbackValue(
      const FollowListLoadRequested(uid: '', type: FollowListType.following),
    );
  });

  setUp(() {
    followListBloc = MockFollowListBloc();
    when(() => followListBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  // -------------------------------------------------------------------------
  // AppBar title
  // -------------------------------------------------------------------------

  group('AppBar', () {
    testWidgets('shows "Following" as the AppBar title', (tester) async {
      when(() => followListBloc.state)
          .thenReturn(const FollowListLoaded(users: []));

      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));

      expect(find.text('Following'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // initState dispatches event
  // -------------------------------------------------------------------------

  group('initState', () {
    testWidgets(
        'dispatches FollowListLoadRequested(type: following) for the given uid',
        (tester) async {
      when(() => followListBloc.state).thenReturn(const FollowListInitial());

      await tester.pumpWidget(
        _buildSubject(followListBloc: followListBloc, uid: 'uid-target'),
      );

      verify(
        () => followListBloc.add(const FollowListLoadRequested(
          uid: 'uid-target',
          type: FollowListType.following,
        )),
      ).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // Loading / Initial states
  // -------------------------------------------------------------------------

  group('FollowListInitial', () {
    testWidgets('shows CircularProgressIndicator', (tester) async {
      when(() => followListBloc.state).thenReturn(const FollowListInitial());

      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('FollowListLoading', () {
    testWidgets('shows CircularProgressIndicator', (tester) async {
      when(() => followListBloc.state).thenReturn(const FollowListLoading());

      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Empty state
  // -------------------------------------------------------------------------

  group('FollowListLoaded — empty', () {
    testWidgets('shows "Not following anyone yet" empty state message',
        (tester) async {
      when(() => followListBloc.state)
          .thenReturn(const FollowListLoaded(users: []));

      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));

      expect(find.text('Not following anyone yet'), findsOneWidget);
    });

    testWidgets('does not show a ListView when list is empty', (tester) async {
      when(() => followListBloc.state)
          .thenReturn(const FollowListLoaded(users: []));

      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));

      expect(find.byType(ListView), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Populated list
  // -------------------------------------------------------------------------

  group('FollowListLoaded — with users', () {
    setUp(() {
      when(() => followListBloc.state)
          .thenReturn(const FollowListLoaded(users: [_carol, _dave]));
    });

    testWidgets('shows display name for each followed user', (tester) async {
      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));

      expect(find.text('Carol'), findsOneWidget);
      expect(find.text('Dave'), findsOneWidget);
    });

    testWidgets('renders one ListTile per followed user', (tester) async {
      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));

      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('tapping a followed user navigates to their profile',
        (tester) async {
      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));

      await tester.tap(find.text('Carol'));
      await tester.pumpAndSettle();

      expect(find.text('Profile:uid-carol'), findsOneWidget);
    });

    testWidgets('tapping second followed user navigates to their profile',
        (tester) async {
      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));

      await tester.tap(find.text('Dave'));
      await tester.pumpAndSettle();

      expect(find.text('Profile:uid-dave'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Failure state
  // -------------------------------------------------------------------------

  group('FollowListFailure', () {
    testWidgets('shows "Could not load following." error heading',
        (tester) async {
      when(() => followListBloc.state)
          .thenReturn(const FollowListFailure(error: 'server error'));

      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));

      expect(find.text('Could not load following.'), findsOneWidget);
    });

    testWidgets('shows the specific error message', (tester) async {
      when(() => followListBloc.state)
          .thenReturn(const FollowListFailure(error: 'server error'));

      await tester.pumpWidget(_buildSubject(followListBloc: followListBloc));

      expect(find.text('server error'), findsOneWidget);
    });
  });
}
