// test/features/posts/presentation/widgets/like_button_test.dart
//
// Widget tests for LikeButton — verifies rendering of heart icon in liked and
// unliked states, like count display, and toggle dispatch.
//
// Acceptance criteria verified (SOCAA-215):
//   AC1 — Like button appears on each post in the feed
//   AC2 — Tapping Like fills the heart icon
//   AC3 — Tapping Unlike outlines the heart icon
//   AC4 — likeCount is visible on each post card
//
// PostRepository is provided in main.dart MultiRepositoryProvider (SOCAA-219).
// All tests use _buildWithRepository to supply the mock into the widget tree.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/like_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/like_event.dart';
import 'package:social_network/features/posts/presentation/bloc/like_state.dart';
import 'package:social_network/features/posts/presentation/widgets/like_button.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPostRepository extends Mock implements PostRepository {}

class MockLikeBloc extends MockBloc<LikeEvent, LikeState>
    implements LikeBloc {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildWithRepository({
  required MockPostRepository mockRepository,
  required String postId,
  required int likeCount,
  required String currentUserUid,
}) {
  return RepositoryProvider<PostRepository>.value(
    value: mockRepository,
    child: MaterialApp(
      home: Scaffold(
        body: LikeButton(
          postId: postId,
          likeCount: likeCount,
          currentUserUid: currentUserUid,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockPostRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(const LikeFetched(postId: '', userId: ''));
    registerFallbackValue(
        const LikeToggled(postId: '', userId: '', isLiked: false));
  });

  setUp(() {
    mockRepository = MockPostRepository();
  });

  // -------------------------------------------------------------------------
  // AC1–AC4 — Verified with MockPostRepository
  // -------------------------------------------------------------------------

  group('AC1 — like button renders a heart icon', () {
    testWidgets('shows outlined heart when not liked (isLiked=false)',
        (tester) async {
      when(() => mockRepository.watchPostLiked('post-2', 'uid-me'))
          .thenAnswer((_) => Stream.value(false));

      await tester.pumpWidget(_buildWithRepository(
        mockRepository: mockRepository,
        postId: 'post-2',
        likeCount: 0,
        currentUserUid: 'uid-me',
      ));
      await tester.pump();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('shows filled heart when liked (isLiked=true)', (tester) async {
      when(() => mockRepository.watchPostLiked('post-3', 'uid-me'))
          .thenAnswer((_) => Stream.value(true));

      await tester.pumpWidget(_buildWithRepository(
        mockRepository: mockRepository,
        postId: 'post-3',
        likeCount: 5,
        currentUserUid: 'uid-me',
      ));
      await tester.pump();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // AC2 — Filled heart when liked
  // -------------------------------------------------------------------------

  group('AC2 — filled heart when liked', () {
    testWidgets('Icons.favorite shown when watchPostLiked emits true',
        (tester) async {
      when(() => mockRepository.watchPostLiked('post-liked', 'uid-me'))
          .thenAnswer((_) => Stream.value(true));

      await tester.pumpWidget(_buildWithRepository(
        mockRepository: mockRepository,
        postId: 'post-liked',
        likeCount: 3,
        currentUserUid: 'uid-me',
      ));
      await tester.pump();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // AC3 — Outlined heart when not liked
  // -------------------------------------------------------------------------

  group('AC3 — outlined heart when not liked', () {
    testWidgets('Icons.favorite_border shown when watchPostLiked emits false',
        (tester) async {
      when(() => mockRepository.watchPostLiked('post-not-liked', 'uid-me'))
          .thenAnswer((_) => Stream.value(false));

      await tester.pumpWidget(_buildWithRepository(
        mockRepository: mockRepository,
        postId: 'post-not-liked',
        likeCount: 0,
        currentUserUid: 'uid-me',
      ));
      await tester.pump();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // AC4 — likeCount visible
  // -------------------------------------------------------------------------

  group('AC4 — likeCount is visible next to heart icon', () {
    testWidgets('displays like count of 0', (tester) async {
      when(() => mockRepository.watchPostLiked('post-c0', 'uid-me'))
          .thenAnswer((_) => Stream.value(false));

      await tester.pumpWidget(_buildWithRepository(
        mockRepository: mockRepository,
        postId: 'post-c0',
        likeCount: 0,
        currentUserUid: 'uid-me',
      ));
      await tester.pump();

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('displays like count of 5', (tester) async {
      when(() => mockRepository.watchPostLiked('post-c5', 'uid-me'))
          .thenAnswer((_) => Stream.value(true));

      await tester.pumpWidget(_buildWithRepository(
        mockRepository: mockRepository,
        postId: 'post-c5',
        likeCount: 5,
        currentUserUid: 'uid-me',
      ));
      await tester.pump();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('displays like count of 10', (tester) async {
      when(() => mockRepository.watchPostLiked('post-c10', 'uid-me'))
          .thenAnswer((_) => Stream.value(false));

      await tester.pumpWidget(_buildWithRepository(
        mockRepository: mockRepository,
        postId: 'post-c10',
        likeCount: 10,
        currentUserUid: 'uid-me',
      ));
      await tester.pump();

      expect(find.text('10'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Tap to toggle — dispatches LikeToggled event
  // -------------------------------------------------------------------------

  group('tap interactions', () {
    testWidgets('tapping outlined heart dispatches LikeToggled(isLiked=false)',
        (tester) async {
      when(() => mockRepository.watchPostLiked('post-tap', 'uid-me'))
          .thenAnswer((_) => Stream.value(false));
      when(() => mockRepository.likePost(any(), any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(_buildWithRepository(
        mockRepository: mockRepository,
        postId: 'post-tap',
        likeCount: 0,
        currentUserUid: 'uid-me',
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      // Verify likePost was called with the correct arguments
      verify(() => mockRepository.likePost('post-tap', 'uid-me')).called(1);
    });

    testWidgets('tapping filled heart dispatches LikeToggled(isLiked=true)',
        (tester) async {
      when(() => mockRepository.watchPostLiked('post-unlike-tap', 'uid-me'))
          .thenAnswer((_) => Stream.value(true));
      when(() => mockRepository.unlikePost(any(), any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(_buildWithRepository(
        mockRepository: mockRepository,
        postId: 'post-unlike-tap',
        likeCount: 3,
        currentUserUid: 'uid-me',
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pump();

      verify(() => mockRepository.unlikePost('post-unlike-tap', 'uid-me'))
          .called(1);
    });
  });

  // -------------------------------------------------------------------------
  // AC2 — likeCount increments immediately after tap (SOCAA-220 optimistic UI)
  // -------------------------------------------------------------------------

  group('AC2 — likeCount increments immediately after tap', () {
    testWidgets(
        'likeCount shows 1 immediately after tapping like (optimistic update)',
        (tester) async {
      when(() => mockRepository.watchPostLiked('post-optimistic', 'uid-me'))
          .thenAnswer((_) => Stream.value(false));
      when(() => mockRepository.likePost(any(), any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(_buildWithRepository(
        mockRepository: mockRepository,
        postId: 'post-optimistic',
        likeCount: 0,
        currentUserUid: 'uid-me',
      ));
      await tester.pump();

      expect(find.text('0'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      // Optimistic update: count increments immediately without waiting for Firestore
      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets(
        'likeCount decrements immediately after tapping unlike (optimistic update)',
        (tester) async {
      when(() => mockRepository.watchPostLiked('post-optimistic-unlike', 'uid-me'))
          .thenAnswer((_) => Stream.value(true));
      when(() => mockRepository.unlikePost(any(), any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(_buildWithRepository(
        mockRepository: mockRepository,
        postId: 'post-optimistic-unlike',
        likeCount: 3,
        currentUserUid: 'uid-me',
      ));
      await tester.pump();

      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pump();

      // Optimistic update: count decrements immediately without waiting for Firestore
      expect(find.text('2'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });
  });
}
