// test/features/posts/presentation/bloc/user_posts_bloc_test.dart
//
// Unit tests for UserPostsBloc — covers every event handler with success,
// empty, and failure paths to satisfy the ≥ 90% bloc coverage threshold.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/user_posts_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/user_posts_event.dart';
import 'package:social_network/features/posts/presentation/bloc/user_posts_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPostRepository extends Mock implements PostRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final PostEntity newerPost = PostEntity(
  id: 'post-2',
  authorUid: 'uid-alice',
  authorDisplayName: 'Alice',
  content: 'Newer post',
  createdAt: DateTime(2026, 2, 1),
  authorAvatarUrl: null,
  imageUrl: null,
);

final PostEntity olderPost = PostEntity(
  id: 'post-1',
  authorUid: 'uid-alice',
  authorDisplayName: 'Alice',
  content: 'Older post',
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

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  test('initial state is UserPostsInitial', () {
    final bloc = UserPostsBloc(postRepository: mockRepository);
    expect(bloc.state, isA<UserPostsInitial>());
    bloc.close();
  });

  // -------------------------------------------------------------------------
  // UserPostsWatchStarted
  // -------------------------------------------------------------------------

  group('UserPostsWatchStarted', () {
    blocTest<UserPostsBloc, UserPostsState>(
      'emits [UserPostsLoading, UserPostsLoaded] when stream emits posts',
      setUp: () {
        when(() => mockRepository.watchPostsByUser('uid-alice')).thenAnswer(
          (_) => Stream.value([newerPost, olderPost]),
        );
      },
      build: () => UserPostsBloc(postRepository: mockRepository),
      act: (bloc) =>
          bloc.add(const UserPostsWatchStarted(uid: 'uid-alice')),
      expect: () => [
        const UserPostsLoading(),
        isA<UserPostsLoaded>()
            .having((s) => s.posts.length, 'posts.length', 2),
      ],
      verify: (_) =>
          verify(() => mockRepository.watchPostsByUser('uid-alice'))
              .called(1),
    );

    blocTest<UserPostsBloc, UserPostsState>(
      'emits [UserPostsLoading, UserPostsLoaded(empty)] when user has no posts',
      setUp: () {
        when(() => mockRepository.watchPostsByUser('uid-alice'))
            .thenAnswer((_) => Stream.value([]));
      },
      build: () => UserPostsBloc(postRepository: mockRepository),
      act: (bloc) =>
          bloc.add(const UserPostsWatchStarted(uid: 'uid-alice')),
      expect: () => [
        const UserPostsLoading(),
        isA<UserPostsLoaded>()
            .having((s) => s.posts, 'posts', isEmpty),
      ],
    );

    blocTest<UserPostsBloc, UserPostsState>(
      'emits [UserPostsLoading, UserPostsFailure] when stream errors',
      setUp: () {
        when(() => mockRepository.watchPostsByUser('uid-alice'))
            .thenAnswer(
                (_) => Stream.error(Exception('firestore error')));
      },
      build: () => UserPostsBloc(postRepository: mockRepository),
      act: (bloc) =>
          bloc.add(const UserPostsWatchStarted(uid: 'uid-alice')),
      expect: () => [
        const UserPostsLoading(),
        isA<UserPostsFailure>(),
      ],
    );

    blocTest<UserPostsBloc, UserPostsState>(
      'loaded posts list preserves ordering received from stream (newest first)',
      setUp: () {
        when(() => mockRepository.watchPostsByUser('uid-alice'))
            .thenAnswer(
                (_) => Stream.value([newerPost, olderPost]));
      },
      build: () => UserPostsBloc(postRepository: mockRepository),
      act: (bloc) =>
          bloc.add(const UserPostsWatchStarted(uid: 'uid-alice')),
      expect: () => [
        const UserPostsLoading(),
        isA<UserPostsLoaded>().having(
          (s) => s.posts.map((p) => p.id).toList(),
          'post ids in order',
          ['post-2', 'post-1'],
        ),
      ],
    );

    blocTest<UserPostsBloc, UserPostsState>(
      'emits multiple UserPostsLoaded states as stream updates',
      setUp: () {
        final controller = StreamController<List<PostEntity>>();
        when(() => mockRepository.watchPostsByUser('uid-alice'))
            .thenAnswer((_) => controller.stream);
        Future.microtask(() async {
          controller.add([newerPost]);
          await Future<void>.delayed(Duration.zero);
          controller.add([newerPost, olderPost]);
          await Future<void>.delayed(Duration.zero);
          await controller.close();
        });
      },
      build: () => UserPostsBloc(postRepository: mockRepository),
      act: (bloc) =>
          bloc.add(const UserPostsWatchStarted(uid: 'uid-alice')),
      expect: () => [
        const UserPostsLoading(),
        isA<UserPostsLoaded>()
            .having((s) => s.posts.length, 'length', 1),
        isA<UserPostsLoaded>()
            .having((s) => s.posts.length, 'length', 2),
      ],
    );

    blocTest<UserPostsBloc, UserPostsState>(
      'uses uid from event when watching another user',
      setUp: () {
        when(() => mockRepository.watchPostsByUser('uid-bob'))
            .thenAnswer((_) => Stream.value([newerPost]));
      },
      build: () => UserPostsBloc(postRepository: mockRepository),
      act: (bloc) =>
          bloc.add(const UserPostsWatchStarted(uid: 'uid-bob')),
      verify: (_) =>
          verify(() => mockRepository.watchPostsByUser('uid-bob'))
              .called(1),
    );
  });

  // -------------------------------------------------------------------------
  // UserPostsUpdated (internal event)
  // -------------------------------------------------------------------------

  group('UserPostsUpdated', () {
    blocTest<UserPostsBloc, UserPostsState>(
      'emits UserPostsLoaded with the provided posts list',
      build: () => UserPostsBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(UserPostsUpdated([newerPost])),
      expect: () => [
        isA<UserPostsLoaded>()
            .having((s) => s.posts, 'posts', [newerPost]),
      ],
    );

    blocTest<UserPostsBloc, UserPostsState>(
      'emits UserPostsLoaded with empty list',
      build: () => UserPostsBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(UserPostsUpdated([])),
      expect: () => [
        isA<UserPostsLoaded>().having((s) => s.posts, 'posts', isEmpty),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // Event props / equality — exercises Equatable props for coverage
  // -------------------------------------------------------------------------

  group('UserPostsEvent props and equality', () {
    test('UserPostsWatchStarted props contains uid', () {
      const event = UserPostsWatchStarted(uid: 'uid-x');
      expect(event.props, equals(['uid-x']));
    });

    test('UserPostsWatchStarted supports value equality', () {
      const a = UserPostsWatchStarted(uid: 'uid-x');
      const b = UserPostsWatchStarted(uid: 'uid-x');
      expect(a, equals(b));
    });

    test('UserPostsWatchStarted with different uids are not equal', () {
      const a = UserPostsWatchStarted(uid: 'uid-x');
      const b = UserPostsWatchStarted(uid: 'uid-y');
      expect(a, isNot(equals(b)));
    });

    test('UserPostsUpdated props contains posts', () {
      final event = UserPostsUpdated([newerPost]);
      expect(event.props, equals([[newerPost]]));
    });
  });

  // -------------------------------------------------------------------------
  // State props / equality
  // -------------------------------------------------------------------------

  group('UserPostsState props and equality', () {
    test('UserPostsInitial props is empty', () {
      expect(const UserPostsInitial().props, isEmpty);
    });

    test('UserPostsInitial supports value equality', () {
      const a = UserPostsInitial();
      const b = UserPostsInitial();
      expect(a, equals(b));
    });

    test('UserPostsLoading props is empty', () {
      expect(const UserPostsLoading().props, isEmpty);
    });

    test('UserPostsLoading supports value equality', () {
      const a = UserPostsLoading();
      const b = UserPostsLoading();
      expect(a, equals(b));
    });

    test('UserPostsLoaded props contains posts', () {
      final state = UserPostsLoaded(posts: [newerPost]);
      expect(state.props, equals([[newerPost]]));
    });

    test('UserPostsLoaded supports value equality when posts are equal', () {
      final a = UserPostsLoaded(posts: [newerPost]);
      final b = UserPostsLoaded(posts: [newerPost]);
      expect(a, equals(b));
    });

    test('UserPostsFailure props contains error string', () {
      const state = UserPostsFailure(error: 'oops');
      expect(state.props, equals(['oops']));
    });

    test('UserPostsFailure supports value equality', () {
      const a = UserPostsFailure(error: 'oops');
      const b = UserPostsFailure(error: 'oops');
      expect(a, equals(b));
    });

    test('UserPostsFailure with different errors are not equal', () {
      const a = UserPostsFailure(error: 'error-a');
      const b = UserPostsFailure(error: 'error-b');
      expect(a, isNot(equals(b)));
    });
  });
}
