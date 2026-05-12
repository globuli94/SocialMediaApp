// test/features/feed/presentation/bloc/feed_bloc_test.dart
//
// Unit tests for FeedBloc — covers FeedStarted, FeedRefreshRequested, and
// FeedLoadMoreRequested event handlers with success, failure, and no-op
// paths to satisfy the ≥ 90% bloc coverage threshold.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:social_network/features/feed/presentation/bloc/feed_event.dart';
import 'package:social_network/features/feed/presentation/bloc/feed_state.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPostRepository extends Mock implements PostRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final PostEntity _post1 = PostEntity(
  id: 'post-1',
  authorUid: 'uid-alice',
  authorDisplayName: 'Alice',
  content: 'First post',
  createdAt: DateTime(2026, 1, 2),
  authorAvatarUrl: null,
  imageUrl: null,
);

final PostEntity _post2 = PostEntity(
  id: 'post-2',
  authorUid: 'uid-bob',
  authorDisplayName: 'Bob',
  content: 'Second post',
  createdAt: DateTime(2026, 1, 1),
  authorAvatarUrl: null,
  imageUrl: null,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockPostRepository mockRepository;

  setUp(() {
    mockRepository = MockPostRepository();
  });

  group('FeedBloc', () {
    // -----------------------------------------------------------------------
    // FeedStarted
    // -----------------------------------------------------------------------

    group('FeedStarted', () {
      blocTest<FeedBloc, FeedState>(
        'emits [FeedLoading, FeedLoaded(hasMore: true)] when repository returns '
        'a cursor',
        setUp: () {
          when(
            () => mockRepository.fetchFeedPage(
              cursor: null,
              limit: 10,
            ),
          ).thenAnswer((_) async => ([_post1, _post2], 'cursor-1'));
        },
        build: () => FeedBloc(postRepository: mockRepository),
        act: (bloc) => bloc.add(const FeedStarted()),
        expect: () => [
          const FeedLoading(),
          FeedLoaded(
            posts: [_post1, _post2],
            hasMore: true,
            cursor: 'cursor-1',
          ),
        ],
      );

      blocTest<FeedBloc, FeedState>(
        'emits [FeedLoading, FeedLoaded(hasMore: false)] when repository returns '
        'null cursor',
        setUp: () {
          when(
            () => mockRepository.fetchFeedPage(
              cursor: null,
              limit: 10,
            ),
          ).thenAnswer((_) async => ([_post1], null));
        },
        build: () => FeedBloc(postRepository: mockRepository),
        act: (bloc) => bloc.add(const FeedStarted()),
        expect: () => [
          const FeedLoading(),
          FeedLoaded(
            posts: [_post1],
            hasMore: false,
            cursor: null,
          ),
        ],
      );

      blocTest<FeedBloc, FeedState>(
        'emits [FeedLoading, FeedFailure] when repository throws',
        setUp: () {
          when(
            () => mockRepository.fetchFeedPage(
              cursor: null,
              limit: 10,
            ),
          ).thenThrow(Exception('network error'));
        },
        build: () => FeedBloc(postRepository: mockRepository),
        act: (bloc) => bloc.add(const FeedStarted()),
        expect: () => [
          const FeedLoading(),
          isA<FeedFailure>(),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // FeedRefreshRequested
    // -----------------------------------------------------------------------

    group('FeedRefreshRequested', () {
      blocTest<FeedBloc, FeedState>(
        'resets to page 1: emits [FeedLoading, FeedLoaded] from cursor=null',
        setUp: () {
          when(
            () => mockRepository.fetchFeedPage(
              cursor: null,
              limit: 10,
            ),
          ).thenAnswer((_) async => ([_post1], 'cursor-2'));
        },
        build: () => FeedBloc(postRepository: mockRepository),
        act: (bloc) => bloc.add(const FeedRefreshRequested()),
        expect: () => [
          const FeedLoading(),
          FeedLoaded(
            posts: [_post1],
            hasMore: true,
            cursor: 'cursor-2',
          ),
        ],
      );

      blocTest<FeedBloc, FeedState>(
        'emits [FeedLoading, FeedFailure] when repository throws on refresh',
        setUp: () {
          when(
            () => mockRepository.fetchFeedPage(
              cursor: null,
              limit: 10,
            ),
          ).thenThrow(Exception('refresh failed'));
        },
        build: () => FeedBloc(postRepository: mockRepository),
        act: (bloc) => bloc.add(const FeedRefreshRequested()),
        expect: () => [
          const FeedLoading(),
          isA<FeedFailure>(),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // FeedLoadMoreRequested
    // -----------------------------------------------------------------------

    group('FeedLoadMoreRequested', () {
      blocTest<FeedBloc, FeedState>(
        'appends next page and updates cursor when hasMore=true and '
        'isLoadingMore=false',
        setUp: () {
          when(
            () => mockRepository.fetchFeedPage(
              cursor: 'cursor-1',
              limit: 10,
            ),
          ).thenAnswer((_) async => ([_post2], 'cursor-2'));
        },
        build: () => FeedBloc(postRepository: mockRepository),
        seed: () => FeedLoaded(
          posts: [_post1],
          hasMore: true,
          cursor: 'cursor-1',
        ),
        act: (bloc) => bloc.add(const FeedLoadMoreRequested()),
        expect: () => [
          FeedLoaded(
            posts: [_post1],
            hasMore: true,
            isLoadingMore: true,
            cursor: 'cursor-1',
          ),
          FeedLoaded(
            posts: [_post1, _post2],
            hasMore: true,
            cursor: 'cursor-2',
          ),
        ],
      );

      blocTest<FeedBloc, FeedState>(
        'sets hasMore=false when nextCursor is null',
        setUp: () {
          when(
            () => mockRepository.fetchFeedPage(
              cursor: 'cursor-1',
              limit: 10,
            ),
          ).thenAnswer((_) async => ([_post2], null));
        },
        build: () => FeedBloc(postRepository: mockRepository),
        seed: () => FeedLoaded(
          posts: [_post1],
          hasMore: true,
          cursor: 'cursor-1',
        ),
        act: (bloc) => bloc.add(const FeedLoadMoreRequested()),
        expect: () => [
          FeedLoaded(
            posts: [_post1],
            hasMore: true,
            isLoadingMore: true,
            cursor: 'cursor-1',
          ),
          FeedLoaded(
            posts: [_post1, _post2],
            hasMore: false,
            cursor: null,
          ),
        ],
      );

      blocTest<FeedBloc, FeedState>(
        'is a no-op when hasMore=false — emits nothing',
        build: () => FeedBloc(postRepository: mockRepository),
        seed: () => FeedLoaded(
          posts: [_post1],
          hasMore: false,
          cursor: null,
        ),
        act: (bloc) => bloc.add(const FeedLoadMoreRequested()),
        expect: () => [],
      );

      blocTest<FeedBloc, FeedState>(
        'is a no-op when isLoadingMore=true — emits nothing',
        build: () => FeedBloc(postRepository: mockRepository),
        seed: () => FeedLoaded(
          posts: [_post1],
          hasMore: true,
          isLoadingMore: true,
          cursor: 'cursor-1',
        ),
        act: (bloc) => bloc.add(const FeedLoadMoreRequested()),
        expect: () => [],
      );

      blocTest<FeedBloc, FeedState>(
        'is a no-op when state is not FeedLoaded — emits nothing',
        build: () => FeedBloc(postRepository: mockRepository),
        seed: () => const FeedInitial(),
        act: (bloc) => bloc.add(const FeedLoadMoreRequested()),
        expect: () => [],
      );

      blocTest<FeedBloc, FeedState>(
        'emits [FeedLoaded(isLoadingMore: true), FeedFailure] when repository '
        'throws on load more',
        setUp: () {
          when(
            () => mockRepository.fetchFeedPage(
              cursor: 'cursor-1',
              limit: 10,
            ),
          ).thenThrow(Exception('load more failed'));
        },
        build: () => FeedBloc(postRepository: mockRepository),
        seed: () => FeedLoaded(
          posts: [_post1],
          hasMore: true,
          cursor: 'cursor-1',
        ),
        act: (bloc) => bloc.add(const FeedLoadMoreRequested()),
        expect: () => [
          FeedLoaded(
            posts: [_post1],
            hasMore: true,
            isLoadingMore: true,
            cursor: 'cursor-1',
          ),
          isA<FeedFailure>(),
        ],
      );
    });
  });
}
