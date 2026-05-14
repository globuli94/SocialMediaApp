// test/features/follow/presentation/widgets/followers_screen_test.dart
//
// Widget tests for FollowersScreen — verifies loading state, empty state,
// populated list, and tap-to-navigate behaviour.
//
// Uses mocktail to mock FollowRepository — no real Firebase connections.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/follow/domain/entities/follow_user_entity.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/follow/presentation/screens/followers_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFollowRepository extends Mock implements FollowRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const FollowUserEntity _alice = FollowUserEntity(
  uid: 'uid-alice',
  displayName: 'Alice',
  avatarUrl: null,
);

const FollowUserEntity _bob = FollowUserEntity(
  uid: 'uid-bob',
  displayName: 'Bob',
  avatarUrl: null,
);

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockFollowRepository followRepository,
  required String uid,
  List<GoRoute> extraRoutes = const [],
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => FollowersScreen(uid: uid),
      ),
      GoRoute(
        path: '/profile/:uid',
        builder: (_, state) => Scaffold(
          body: Text('Profile ${state.pathParameters['uid']}'),
        ),
      ),
      ...extraRoutes,
    ],
  );

  return RepositoryProvider<FollowRepository>.value(
    value: followRepository,
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockFollowRepository followRepository;

  setUp(() {
    followRepository = MockFollowRepository();
  });

  // -------------------------------------------------------------------------
  // Loading state
  // -------------------------------------------------------------------------

  group('Loading state', () {
    testWidgets('shows CircularProgressIndicator while stream is waiting',
        (tester) async {
      // A StreamController that never emits keeps connectionState == waiting.
      final controller = StreamController<List<FollowUserEntity>>();
      when(() => followRepository.watchFollowers('uid-a'))
          .thenAnswer((_) => controller.stream);

      await tester.pumpWidget(
        _buildSubject(followRepository: followRepository, uid: 'uid-a'),
      );
      // pumpWidget triggers build; the stream hasn't emitted → waiting state.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await controller.close();
    });
  });

  // -------------------------------------------------------------------------
  // Empty state
  // -------------------------------------------------------------------------

  group('Empty state', () {
    testWidgets('shows "No followers yet." when list is empty', (tester) async {
      when(() => followRepository.watchFollowers('uid-a'))
          .thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(
        _buildSubject(followRepository: followRepository, uid: 'uid-a'),
      );
      await tester.pump();

      expect(find.text('No followers yet.'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Error state
  // -------------------------------------------------------------------------

  group('Error state', () {
    testWidgets('shows error message when stream emits an error',
        (tester) async {
      when(() => followRepository.watchFollowers('uid-a'))
          .thenAnswer((_) => Stream.error(Exception('failed')));

      await tester.pumpWidget(
        _buildSubject(followRepository: followRepository, uid: 'uid-a'),
      );
      await tester.pump();

      expect(find.text('Could not load followers.'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Populated list
  // -------------------------------------------------------------------------

  group('Populated list', () {
    testWidgets('renders a ListTile per follower with display name',
        (tester) async {
      when(() => followRepository.watchFollowers('uid-a'))
          .thenAnswer((_) => Stream.value([_alice, _bob]));

      await tester.pumpWidget(
        _buildSubject(followRepository: followRepository, uid: 'uid-a'),
      );
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('renders AppBar with title "Followers"', (tester) async {
      when(() => followRepository.watchFollowers('uid-a'))
          .thenAnswer((_) => Stream.value([_alice]));

      await tester.pumpWidget(
        _buildSubject(followRepository: followRepository, uid: 'uid-a'),
      );
      await tester.pump();

      expect(find.text('Followers'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  group('Navigation', () {
    testWidgets('tapping a follower navigates to /profile/:uid', (tester) async {
      when(() => followRepository.watchFollowers('uid-a'))
          .thenAnswer((_) => Stream.value([_alice]));

      await tester.pumpWidget(
        _buildSubject(followRepository: followRepository, uid: 'uid-a'),
      );
      await tester.pump();

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(find.text('Profile uid-alice'), findsOneWidget);
    });
  });
}
