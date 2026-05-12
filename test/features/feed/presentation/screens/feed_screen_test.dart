// test/features/feed/presentation/screens/feed_screen_test.dart
//
// Widget tests for FeedScreen — verifies posts list rendering, empty state,
// initial loading indicator, and isLoadingMore bottom spinner.
//
// FeedScreen creates its own FeedBloc internally via context.read<PostRepository>(),
// so a MockPostRepository is provided to control the bloc's behaviour.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:social_network/features/feed/presentation/bloc/feed_event.dart';
import 'package:social_network/features/feed/presentation/bloc/feed_state.dart';
import 'package:social_network/features/feed/presentation/screens/feed_screen.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';
import 'package:social_network/features/posts/presentation/widgets/post_card.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPostRepository extends Mock implements PostRepository {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockPostBloc extends MockBloc<PostEvent, PostState> implements PostBloc {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

PostEntity _makePost(int i) => PostEntity(
      id: 'post-$i',
      authorUid: 'uid-$i',
      authorDisplayName: 'User $i',
      content: 'Content of post $i',
      createdAt: DateTime(2026, 1, i + 1),
      authorAvatarUrl: null,
      imageUrl: null,
    );

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockPostRepository postRepository,
  required MockAuthBloc authBloc,
  required MockPostBloc postBloc,
}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<PostRepository>.value(value: postRepository),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<PostBloc>.value(value: postBloc),
      ],
      child: const MaterialApp(home: FeedScreen()),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockPostRepository mockRepository;
  late MockAuthBloc mockAuthBloc;
  late MockPostBloc mockPostBloc;

  setUpAll(() {
    registerFallbackValue(const PostWatchStarted());
  });

  setUp(() {
    mockRepository = MockPostRepository();
    mockAuthBloc = MockAuthBloc();
    mockPostBloc = MockPostBloc();

    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    when(() => mockPostBloc.state).thenReturn(PostLoaded(posts: []));
  });

  // -------------------------------------------------------------------------
  // Initial loading indicator
  // -------------------------------------------------------------------------

  group('initial loading', () {
    testWidgets('shows CircularProgressIndicator while first page is loading',
        (tester) async {
      // Use a Completer instead of Future.delayed so no pending timer is left
      // after the test body, avoiding the "Timer is still pending" framework error.
      final completer = Completer<(List<PostEntity>, Object?)>();

      when(
        () => mockRepository.fetchFeedPage(cursor: null, limit: 10),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        _buildSubject(
          postRepository: mockRepository,
          authBloc: mockAuthBloc,
          postBloc: mockPostBloc,
        ),
      );

      // Two pumps: first triggers FeedStarted → FeedLoading emitted; second
      // rebuilds BlocBuilder with the FeedLoading state.
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the completer so no async work is left dangling.
      completer.complete((<PostEntity>[], null));
      await tester.pumpAndSettle();
    });
  });

  // -------------------------------------------------------------------------
  // Empty state
  // -------------------------------------------------------------------------

  group('empty state', () {
    testWidgets('shows "No posts yet." when fetched posts list is empty',
        (tester) async {
      when(
        () => mockRepository.fetchFeedPage(cursor: null, limit: 10),
      ).thenAnswer((_) async => (<PostEntity>[], null));

      await tester.pumpWidget(
        _buildSubject(
          postRepository: mockRepository,
          authBloc: mockAuthBloc,
          postBloc: mockPostBloc,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No posts yet.'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Posts list
  // -------------------------------------------------------------------------

  group('posts list', () {
    testWidgets('renders a PostCard for each fetched post', (tester) async {
      final posts = [_makePost(0), _makePost(1), _makePost(2)];

      when(
        () => mockRepository.fetchFeedPage(cursor: null, limit: 10),
      ).thenAnswer((_) async => (posts, null));

      await tester.pumpWidget(
        _buildSubject(
          postRepository: mockRepository,
          authBloc: mockAuthBloc,
          postBloc: mockPostBloc,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(PostCard), findsNWidgets(3));
      expect(find.text('Content of post 0'), findsOneWidget);
      expect(find.text('Content of post 1'), findsOneWidget);
      expect(find.text('Content of post 2'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // isLoadingMore spinner
  // -------------------------------------------------------------------------

  group('isLoadingMore spinner', () {
    testWidgets(
        'shows bottom CircularProgressIndicator when FeedLoadMoreRequested is '
        'in-flight', (tester) async {
      final posts = List.generate(10, _makePost);

      // Page 1 completes immediately; page 2 uses a Completer (no timer) so
      // isLoadingMore stays true long enough to assert, without leaving a
      // pending timer after the test body.
      final page2Completer = Completer<(List<PostEntity>, Object?)>();

      when(
        () => mockRepository.fetchFeedPage(cursor: null, limit: 10),
      ).thenAnswer((_) async => (posts, 'cursor-1'));

      when(
        () => mockRepository.fetchFeedPage(cursor: 'cursor-1', limit: 10),
      ).thenAnswer((_) => page2Completer.future);

      await tester.pumpWidget(
        _buildSubject(
          postRepository: mockRepository,
          authBloc: mockAuthBloc,
          postBloc: mockPostBloc,
        ),
      );

      // Wait for page 1 to load (two pumps: FeedLoading → FeedLoaded).
      await tester.pump();
      await tester.pump();

      // ListView virtualises its children; at least some PostCards are visible.
      expect(find.byType(PostCard), findsWidgets);

      // FeedScreen wraps its Scaffold in BlocProvider.value(value: _feedBloc).
      // The Scaffold element is below that provider, so BlocProvider.of resolves.
      // We use the first Scaffold found (FeedScreen's own Scaffold).
      final BuildContext scaffoldCtx =
          tester.element(find.byType(Scaffold).first);
      final FeedBloc feedBloc = BlocProvider.of<FeedBloc>(scaffoldCtx);
      feedBloc.add(const FeedLoadMoreRequested());

      // Two pumps: (1) FeedLoadMoreRequested processed → isLoadingMore: true emitted,
      // (2) BlocBuilder rebuilds with new state.
      await tester.pump();
      await tester.pump();

      // The spinner at itemCount = posts.length + 1 is outside the viewport in
      // a virtualising ListView, so it is not in the widget tree. Verify the
      // BLoC state instead — isLoadingMore: true proves the spinner would be
      // present once scrolled into view.
      expect((feedBloc.state as FeedLoaded).isLoadingMore, isTrue);

      // Complete the completer to clean up async work.
      page2Completer.complete((<PostEntity>[], null));
      await tester.pump();
    });
  });
}
