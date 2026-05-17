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
// ⚠️  SCAFFOLDING GAP NOTE:
// LikeButton.initState() calls context.read<PostRepository>() to create its
// internal LikeBloc. PostRepository is NOT provided in the production widget
// tree (main.dart MultiRepositoryProvider only provides ProfileRepository and
// FollowRepository). These tests pump LikeButton WITHOUT PostRepository to
// expose that production gap — they are expected to fail with
// ProviderNotFoundException until the production code is fixed.
//
// See also: post_card_test.dart — PostCard now embeds LikeButton and will
// also fail with the same ProviderNotFoundException.

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

/// Builds the widget tree WITHOUT PostRepository in the tree.
/// Per Scaffolding Gap Rule: we do NOT add RepositoryProvider of PostRepository
/// because it is absent from the production widget tree (main.dart).
/// These tests verify AC1-AC4 and are expected to fail with
/// ProviderNotFoundException until production is fixed.
Widget _buildWithoutRepository({
  required String postId,
  required int likeCount,
  required String currentUserUid,
}) {
  return MaterialApp(
    home: Scaffold(
      body: LikeButton(
        postId: postId,
        likeCount: likeCount,
        currentUserUid: currentUserUid,
      ),
    ),
  );
}

/// Builds the widget tree WITH a mock PostRepository so that individual
/// acceptance-criteria checks can be verified once the production gap is
/// resolved. Uses this helper only in "with repository" tests below.
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
  // AC1 — Like button is visible on post cards
  //
  // These tests pump WITHOUT PostRepository to expose the production gap.
  // They are expected to throw ProviderNotFoundException.
  // -------------------------------------------------------------------------

  group('AC1 — like button visibility (exposes production gap)', () {
    testWidgets(
        'FAILS: LikeButton throws ProviderNotFoundException because '
        'PostRepository is absent from production widget tree',
        (tester) async {
      // This test MUST fail with ProviderNotFoundException.
      // It documents: PostRepository is missing from main.dart
      // MultiRepositoryProvider, causing LikeButton to crash in production.
      // FIX: add RepositoryProvider<PostRepository> to main.dart before
      // MultiBlocProvider.
      await tester.pumpWidget(_buildWithoutRepository(
        postId: 'post-1',
        likeCount: 0,
        currentUserUid: 'uid-me',
      ));
      // If the production gap is fixed, this assertion will verify AC1:
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Icon &&
              (w.icon == Icons.favorite || w.icon == Icons.favorite_border),
        ),
        findsAtLeast(1),
      );
    });
  });

  // -------------------------------------------------------------------------
  // AC1–AC4 — Verified with MockPostRepository
  // These tests pass once RepositoryProvider<PostRepository> is in the tree.
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
  // AC4 defect check — likeCount does not update immediately after toggle
  //
  // AC2 requires "Change appears immediately in UI" for likeCount.
  // LikeUpdated state has only isLiked (no likeCount), so LikeButton reads
  // widget.likeCount (PostEntity value) which does NOT update until PostBloc
  // receives a new Firestore snapshot. This test documents that defect.
  // -------------------------------------------------------------------------

  group('AC2/AC3 defect — likeCount not immediately updated', () {
    testWidgets(
        'DEFECT: likeCount still shows 0 immediately after tapping like '
        '(likeCount in widget param is not updated until PostBloc stream fires)',
        (tester) async {
      when(() => mockRepository.watchPostLiked('post-defect', 'uid-me'))
          .thenAnswer((_) => Stream.value(false));
      when(() => mockRepository.likePost(any(), any()))
          .thenAnswer((_) async {});

      await tester.pumpWidget(_buildWithRepository(
        mockRepository: mockRepository,
        postId: 'post-defect',
        likeCount: 0,
        currentUserUid: 'uid-me',
      ));
      await tester.pump();

      // Before tap: count is 0, heart is outlined
      expect(find.text('0'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      // Tap to like
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      // AC2 says count should immediately increment to 1.
      // DEFECT: it still shows 0 because widget.likeCount is unchanged.
      // When this test passes (count == '1'), the defect is fixed.
      expect(find.text('1'), findsOneWidget);
    });
  });
}
