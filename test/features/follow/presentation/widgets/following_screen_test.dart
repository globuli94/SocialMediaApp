// test/features/follow/presentation/widgets/following_screen_test.dart
//
// Widget tests for FollowingScreen — verifies loading state, empty state,
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
import 'package:social_network/features/follow/presentation/screens/following_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFollowRepository extends Mock implements FollowRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const FollowUserEntity _carol = FollowUserEntity(
  uid: 'uid-carol',
  displayName: 'Carol',
  avatarUrl: null,
);

const FollowUserEntity _dave = FollowUserEntity(
  uid: 'uid-dave',
  displayName: 'Dave',
  avatarUrl: null,
);

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockFollowRepository followRepository,
  required String uid,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => FollowingScreen(uid: uid),
      ),
      GoRoute(
        path: '/profile/:uid',
        builder: (_, state) => Scaffold(
          body: Text('Profile ${state.pathParameters['uid']}'),
        ),
      ),
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
      final controller = StreamController<List<FollowUserEntity>>();
      when(() => followRepository.watchFollowing('uid-a'))
          .thenAnswer((_) => controller.stream);

      await tester.pumpWidget(
        _buildSubject(followRepository: followRepository, uid: 'uid-a'),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await controller.close();
    });
  });

  // -------------------------------------------------------------------------
  // Empty state
  // -------------------------------------------------------------------------

  group('Empty state', () {
    testWidgets('shows "Not following anyone yet." when list is empty',
        (tester) async {
      when(() => followRepository.watchFollowing('uid-a'))
          .thenAnswer((_) => Stream.value([]));

      await tester.pumpWidget(
        _buildSubject(followRepository: followRepository, uid: 'uid-a'),
      );
      await tester.pump();

      expect(find.text('Not following anyone yet.'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Error state
  // -------------------------------------------------------------------------

  group('Error state', () {
    testWidgets('shows error message when stream emits an error',
        (tester) async {
      when(() => followRepository.watchFollowing('uid-a'))
          .thenAnswer((_) => Stream.error(Exception('failed')));

      await tester.pumpWidget(
        _buildSubject(followRepository: followRepository, uid: 'uid-a'),
      );
      await tester.pump();

      expect(find.text('Could not load following.'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Populated list
  // -------------------------------------------------------------------------

  group('Populated list', () {
    testWidgets('renders a ListTile per following user with display name',
        (tester) async {
      when(() => followRepository.watchFollowing('uid-a'))
          .thenAnswer((_) => Stream.value([_carol, _dave]));

      await tester.pumpWidget(
        _buildSubject(followRepository: followRepository, uid: 'uid-a'),
      );
      await tester.pump();

      expect(find.text('Carol'), findsOneWidget);
      expect(find.text('Dave'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('renders AppBar with title "Following"', (tester) async {
      when(() => followRepository.watchFollowing('uid-a'))
          .thenAnswer((_) => Stream.value([_carol]));

      await tester.pumpWidget(
        _buildSubject(followRepository: followRepository, uid: 'uid-a'),
      );
      await tester.pump();

      expect(find.text('Following'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  group('Navigation', () {
    testWidgets('tapping a following user navigates to /profile/:uid',
        (tester) async {
      when(() => followRepository.watchFollowing('uid-a'))
          .thenAnswer((_) => Stream.value([_carol]));

      await tester.pumpWidget(
        _buildSubject(followRepository: followRepository, uid: 'uid-a'),
      );
      await tester.pump();

      await tester.tap(find.text('Carol'));
      await tester.pumpAndSettle();

      expect(find.text('Profile uid-carol'), findsOneWidget);
    });
  });
}
