// test/features/posts/presentation/bloc/post_bloc_test.dart
//
// Unit tests for PostBloc — covers every event handler with success and
// failure paths to satisfy the ≥ 90% bloc coverage threshold.

import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPostRepository extends Mock implements PostRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final PostEntity testPost = PostEntity(
  id: 'post-1',
  authorUid: 'uid-alice',
  authorDisplayName: 'Alice',
  content: 'Hello world',
  createdAt: DateTime(2026, 1, 1),
  authorAvatarUrl: null,
  imageUrl: null,
);

final PostEntity testPost2 = PostEntity(
  id: 'post-2',
  authorUid: 'uid-bob',
  authorDisplayName: 'Bob',
  content: 'Second post',
  createdAt: DateTime(2026, 1, 2),
  authorAvatarUrl: 'https://example.com/bob.jpg',
  imageUrl: 'https://example.com/img.jpg',
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockPostRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockRepository = MockPostRepository();
  });

  // -------------------------------------------------------------------------
  // PostWatchStarted
  // -------------------------------------------------------------------------

  group('PostWatchStarted', () {
    blocTest<PostBloc, PostState>(
      'emits [PostLoading, PostLoaded] when stream emits posts',
      setUp: () {
        when(() => mockRepository.watchPosts()).thenAnswer(
          (_) => Stream.value([testPost, testPost2]),
        );
      },
      build: () => PostBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(const PostWatchStarted()),
      expect: () => [
        const PostLoading(),
        isA<PostLoaded>()
            .having((s) => s.posts.length, 'posts.length', 2)
            .having((s) => s.isSubmitting, 'isSubmitting', false),
      ],
      verify: (_) => verify(() => mockRepository.watchPosts()).called(1),
    );

    blocTest<PostBloc, PostState>(
      'emits [PostLoading, PostLoaded(empty)] when stream emits empty list',
      setUp: () {
        when(() => mockRepository.watchPosts())
            .thenAnswer((_) => Stream.value([]));
      },
      build: () => PostBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(const PostWatchStarted()),
      expect: () => [
        const PostLoading(),
        isA<PostLoaded>().having((s) => s.posts, 'posts', isEmpty),
      ],
    );

    blocTest<PostBloc, PostState>(
      'emits [PostLoading, PostFailure] when stream emits an error',
      setUp: () {
        when(() => mockRepository.watchPosts()).thenAnswer(
          (_) => Stream.error(Exception('firestore error')),
        );
      },
      build: () => PostBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(const PostWatchStarted()),
      expect: () => [
        const PostLoading(),
        isA<PostFailure>(),
      ],
    );

    blocTest<PostBloc, PostState>(
      'emits multiple PostLoaded states as stream updates',
      setUp: () {
        final controller = StreamController<List<PostEntity>>();
        when(() => mockRepository.watchPosts())
            .thenAnswer((_) => controller.stream);
        // Schedule updates after bloc is started
        Future.microtask(() async {
          controller.add([testPost]);
          await Future<void>.delayed(Duration.zero);
          controller.add([testPost, testPost2]);
          await Future<void>.delayed(Duration.zero);
          await controller.close();
        });
      },
      build: () => PostBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(const PostWatchStarted()),
      expect: () => [
        const PostLoading(),
        isA<PostLoaded>().having((s) => s.posts.length, 'length', 1),
        isA<PostLoaded>().having((s) => s.posts.length, 'length', 2),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // PostsUpdated (internal event)
  // -------------------------------------------------------------------------

  group('PostsUpdated', () {
    blocTest<PostBloc, PostState>(
      'emits PostLoaded with updated posts list',
      build: () => PostBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(PostsUpdated([testPost])),
      expect: () => [
        isA<PostLoaded>().having((s) => s.posts, 'posts', [testPost]),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // PostsByAuthorWatchStarted
  // -------------------------------------------------------------------------

  group('PostsByAuthorWatchStarted', () {
    blocTest<PostBloc, PostState>(
      'emits [PostLoading, PostLoaded] when watchPostsByAuthorUid emits posts',
      setUp: () {
        when(() => mockRepository.watchPostsByAuthorUid('uid-alice'))
            .thenAnswer((_) => Stream.value([testPost]));
      },
      build: () => PostBloc(postRepository: mockRepository),
      act: (bloc) =>
          bloc.add(const PostsByAuthorWatchStarted(authorUid: 'uid-alice')),
      expect: () => [
        const PostLoading(),
        isA<PostLoaded>()
            .having((s) => s.posts.length, 'posts.length', 1)
            .having(
              (s) => s.posts.first.authorUid,
              'posts.first.authorUid',
              'uid-alice',
            ),
      ],
      verify: (_) => verify(
        () => mockRepository.watchPostsByAuthorUid('uid-alice'),
      ).called(1),
    );

    blocTest<PostBloc, PostState>(
      'emits [PostLoading, PostLoaded(empty)] when watchPostsByAuthorUid emits empty list',
      setUp: () {
        when(() => mockRepository.watchPostsByAuthorUid('uid-alice'))
            .thenAnswer((_) => Stream.value([]));
      },
      build: () => PostBloc(postRepository: mockRepository),
      act: (bloc) =>
          bloc.add(const PostsByAuthorWatchStarted(authorUid: 'uid-alice')),
      expect: () => [
        const PostLoading(),
        isA<PostLoaded>().having((s) => s.posts, 'posts', isEmpty),
      ],
    );

    blocTest<PostBloc, PostState>(
      'emits [PostLoading, PostFailure] when watchPostsByAuthorUid emits an error',
      setUp: () {
        when(() => mockRepository.watchPostsByAuthorUid('uid-alice'))
            .thenAnswer((_) => Stream.error(Exception('index not ready')));
      },
      build: () => PostBloc(postRepository: mockRepository),
      act: (bloc) =>
          bloc.add(const PostsByAuthorWatchStarted(authorUid: 'uid-alice')),
      expect: () => [
        const PostLoading(),
        isA<PostFailure>(),
      ],
    );

    blocTest<PostBloc, PostState>(
      'PostsByAuthorWatchStarted props contains authorUid',
      build: () => PostBloc(postRepository: mockRepository),
      act: (bloc) {},
      verify: (_) {
        const event = PostsByAuthorWatchStarted(authorUid: 'uid-1');
        expect(event.props, equals(['uid-1']));
      },
    );

    test('PostsByAuthorWatchStarted supports value equality', () {
      const a = PostsByAuthorWatchStarted(authorUid: 'uid-1');
      const b = PostsByAuthorWatchStarted(authorUid: 'uid-1');
      expect(a, equals(b));
    });
  });

  // -------------------------------------------------------------------------
  // PostCreateRequested
  // -------------------------------------------------------------------------

  group('PostCreateRequested', () {
    const createEvent = PostCreateRequested(
      authorUid: 'uid-alice',
      authorDisplayName: 'Alice',
      content: 'Hello world',
    );

    blocTest<PostBloc, PostState>(
      'from PostLoaded: emits [isSubmitting=true, isSubmitting=false] on success',
      setUp: () {
        when(
          () => mockRepository.createPost(
            authorUid: any(named: 'authorUid'),
            authorDisplayName: any(named: 'authorDisplayName'),
            authorAvatarUrl: any(named: 'authorAvatarUrl'),
            content: any(named: 'content'),
            imageBytes: any(named: 'imageBytes'),
            imageExtension: any(named: 'imageExtension'),
          ),
        ).thenAnswer((_) async => testPost);
      },
      build: () => PostBloc(postRepository: mockRepository),
      seed: () => PostLoaded(posts: [testPost]),
      act: (bloc) => bloc.add(createEvent),
      expect: () => [
        isA<PostLoaded>()
            .having((s) => s.isSubmitting, 'isSubmitting', true),
        isA<PostLoaded>()
            .having((s) => s.isSubmitting, 'isSubmitting', false),
      ],
      verify: (_) => verify(
        () => mockRepository.createPost(
          authorUid: 'uid-alice',
          authorDisplayName: 'Alice',
          authorAvatarUrl: null,
          content: 'Hello world',
          imageBytes: null,
          imageExtension: null,
        ),
      ).called(1),
    );

    blocTest<PostBloc, PostState>(
      'from PostLoaded: emits PostFailure when createPost throws',
      setUp: () {
        when(
          () => mockRepository.createPost(
            authorUid: any(named: 'authorUid'),
            authorDisplayName: any(named: 'authorDisplayName'),
            authorAvatarUrl: any(named: 'authorAvatarUrl'),
            content: any(named: 'content'),
            imageBytes: any(named: 'imageBytes'),
            imageExtension: any(named: 'imageExtension'),
          ),
        ).thenThrow(Exception('upload failed'));
      },
      build: () => PostBloc(postRepository: mockRepository),
      seed: () => PostLoaded(posts: [testPost]),
      act: (bloc) => bloc.add(createEvent),
      expect: () => [
        isA<PostLoaded>().having((s) => s.isSubmitting, 'isSubmitting', true),
        isA<PostFailure>(),
      ],
    );

    blocTest<PostBloc, PostState>(
      'from PostInitial: emits PostFailure when createPost throws '
      '(no isSubmitting transition)',
      setUp: () {
        when(
          () => mockRepository.createPost(
            authorUid: any(named: 'authorUid'),
            authorDisplayName: any(named: 'authorDisplayName'),
            authorAvatarUrl: any(named: 'authorAvatarUrl'),
            content: any(named: 'content'),
            imageBytes: any(named: 'imageBytes'),
            imageExtension: any(named: 'imageExtension'),
          ),
        ).thenThrow(Exception('network error'));
      },
      build: () => PostBloc(postRepository: mockRepository),
      // default initial state is PostInitial — no isSubmitting change
      act: (bloc) => bloc.add(createEvent),
      expect: () => [isA<PostFailure>()],
    );

    blocTest<PostBloc, PostState>(
      'with imageBytes: passes imageBytes and imageExtension to repository',
      setUp: () {
        when(
          () => mockRepository.createPost(
            authorUid: any(named: 'authorUid'),
            authorDisplayName: any(named: 'authorDisplayName'),
            authorAvatarUrl: any(named: 'authorAvatarUrl'),
            content: any(named: 'content'),
            imageBytes: any(named: 'imageBytes'),
            imageExtension: any(named: 'imageExtension'),
          ),
        ).thenAnswer((_) async => testPost2);
      },
      build: () => PostBloc(postRepository: mockRepository),
      seed: () => PostLoaded(posts: []),
      act: (bloc) => bloc.add(
        PostCreateRequested(
          authorUid: 'uid-alice',
          authorDisplayName: 'Alice',
          content: 'With image',
          imageBytes: Uint8List.fromList([1, 2, 3]),
          imageExtension: '.jpg',
        ),
      ),
      expect: () => [
        isA<PostLoaded>().having((s) => s.isSubmitting, 'isSubmitting', true),
        isA<PostLoaded>().having((s) => s.isSubmitting, 'isSubmitting', false),
      ],
      verify: (_) => verify(
        () => mockRepository.createPost(
          authorUid: 'uid-alice',
          authorDisplayName: 'Alice',
          authorAvatarUrl: null,
          content: 'With image',
          imageBytes: any(named: 'imageBytes'),
          imageExtension: '.jpg',
        ),
      ).called(1),
    );
  });

  // -------------------------------------------------------------------------
  // PostCreateRequested — BUG-011 regression (SOCAA-259)
  // Verifies that stream-delivered posts received while isSubmitting=true are
  // NOT overwritten when createPost() completes and isSubmitting clears.
  // -------------------------------------------------------------------------

  group('PostCreateRequested — BUG-011 regression', () {
    test(
      'AC1: stream-delivered posts during submission are preserved when '
      'isSubmitting clears',
      () async {
        // Use a broadcast stream so the BLoC can re-subscribe if needed and
        // so we can push items at any point without single-subscription errors.
        final streamController =
            StreamController<List<PostEntity>>.broadcast();
        final createCompleter = Completer<PostEntity>();

        when(() => mockRepository.watchPosts())
            .thenAnswer((_) => streamController.stream);
        when(
          () => mockRepository.createPost(
            authorUid: any(named: 'authorUid'),
            authorDisplayName: any(named: 'authorDisplayName'),
            authorAvatarUrl: any(named: 'authorAvatarUrl'),
            content: any(named: 'content'),
            imageBytes: any(named: 'imageBytes'),
            imageExtension: any(named: 'imageExtension'),
          ),
        ).thenAnswer((_) => createCompleter.future);

        final bloc = PostBloc(postRepository: mockRepository);

        // Step 1: Start watching the feed stream.
        bloc.add(const PostWatchStarted());
        await Future<void>.delayed(Duration.zero);

        // Step 2: Stream delivers the initial feed (1 post).
        streamController.add([testPost]);
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state, isA<PostLoaded>());
        expect((bloc.state as PostLoaded).posts, [testPost]);

        // Step 3: User submits a new post.
        // createPost is pending — the Completer has not been completed yet.
        bloc.add(
          const PostCreateRequested(
            authorUid: 'uid-alice',
            authorDisplayName: 'Alice',
            content: 'Brand new post',
          ),
        );
        // Allow the BLoC event handler to run up to the
        // `await createCompleter.future` suspension point.
        await Future<void>.delayed(Duration.zero);

        // Step 4: WHILE createPost is pending, the Firestore stream delivers
        // the updated list that includes the brand-new post.
        final brandNewPost = PostEntity(
          id: 'post-brand-new',
          authorUid: 'uid-alice',
          authorDisplayName: 'Alice',
          content: 'Brand new post',
          createdAt: DateTime(2026, 1, 3),
          authorAvatarUrl: null,
          imageUrl: null,
        );
        streamController.add([brandNewPost, testPost]);
        await Future<void>.delayed(Duration.zero);

        // Step 5: createPost() completes.
        createCompleter.complete(brandNewPost);
        await Future<void>.delayed(Duration.zero);

        // AC1 assertion: the fix uses `state.copyWith(isSubmitting: false)`
        // so the stream-delivered posts must not be overwritten.
        expect(bloc.state, isA<PostLoaded>());
        final finalState = bloc.state as PostLoaded;
        expect(
          finalState.isSubmitting,
          isFalse,
          reason: 'isSubmitting must clear after createPost completes',
        );
        expect(
          finalState.posts,
          containsAll([brandNewPost, testPost]),
          reason:
              'stream-delivered posts must not be overwritten when '
              'isSubmitting clears (BUG-011 / SOCAA-259)',
        );
        expect(
          finalState.posts.length,
          2,
          reason: 'no posts must be lost or duplicated',
        );

        await bloc.close();
        await streamController.close();
      },
    );

    test(
      'AC2: pull-to-refresh after creation does not duplicate posts',
      () async {
        // Return a fresh Stream on every watchPosts() call so that the BLoC
        // can re-subscribe when PostWatchStarted is dispatched again without
        // hitting "stream has already been listened to".
        when(() => mockRepository.watchPosts())
            .thenAnswer((_) => Stream.value([testPost, testPost2]));

        final bloc = PostBloc(postRepository: mockRepository);

        // First watch — loads 2 posts.
        bloc.add(const PostWatchStarted());
        await Future<void>.delayed(Duration.zero);

        expect(
          (bloc.state as PostLoaded).posts.length,
          2,
          reason: 'initial load must show 2 posts',
        );

        // Pull-to-refresh fires PostWatchStarted again.
        // The BLoC cancels its old subscription and creates a fresh one.
        bloc.add(const PostWatchStarted());
        await Future<void>.delayed(Duration.zero);

        // AC2 assertion: exactly 2 posts, none duplicated.
        final refreshedState = bloc.state as PostLoaded;
        expect(
          refreshedState.posts.length,
          2,
          reason: 'pull-to-refresh must not duplicate posts',
        );
        expect(refreshedState.isSubmitting, isFalse);

        await bloc.close();
      },
    );
  });

  // -------------------------------------------------------------------------
  // PostDeleteRequested
  // -------------------------------------------------------------------------

  group('PostDeleteRequested', () {
    blocTest<PostBloc, PostState>(
      'calls deletePost and emits no extra states on success',
      setUp: () {
        when(() => mockRepository.deletePost(any()))
            .thenAnswer((_) async {});
      },
      build: () => PostBloc(postRepository: mockRepository),
      seed: () => PostLoaded(posts: [testPost]),
      act: (bloc) =>
          bloc.add(const PostDeleteRequested(postId: 'post-1')),
      expect: () => <PostState>[],
      verify: (_) =>
          verify(() => mockRepository.deletePost('post-1')).called(1),
    );

    blocTest<PostBloc, PostState>(
      'emits PostFailure when deletePost throws',
      setUp: () {
        when(() => mockRepository.deletePost(any()))
            .thenThrow(Exception('permission denied'));
      },
      build: () => PostBloc(postRepository: mockRepository),
      seed: () => PostLoaded(posts: [testPost]),
      act: (bloc) =>
          bloc.add(const PostDeleteRequested(postId: 'post-1')),
      expect: () => [isA<PostFailure>()],
    );
  });

  // -------------------------------------------------------------------------
  // Event props / equality — exercises Equatable props for coverage
  // -------------------------------------------------------------------------

  group('PostEvent props and equality', () {
    test('PostWatchStarted props is empty', () {
      const event = PostWatchStarted();
      expect(event.props, isEmpty);
    });

    test('PostWatchStarted supports value equality', () {
      const a = PostWatchStarted();
      const b = PostWatchStarted();
      expect(a, equals(b));
    });

    test('PostCreateRequested props contains authorUid, content, imageBytes',
        () {
      final bytes = Uint8List.fromList([1, 2]);
      final event = PostCreateRequested(
        authorUid: 'uid-1',
        authorDisplayName: 'Alice',
        content: 'Hello',
        imageBytes: bytes,
      );
      expect(event.props, equals(['uid-1', 'Hello', bytes]));
    });

    test('PostCreateRequested supports value equality', () {
      const a = PostCreateRequested(
        authorUid: 'uid-1',
        authorDisplayName: 'Alice',
        content: 'Hello',
      );
      const b = PostCreateRequested(
        authorUid: 'uid-1',
        authorDisplayName: 'Alice',
        content: 'Hello',
      );
      expect(a, equals(b));
    });

    test('PostDeleteRequested props contains postId', () {
      const event = PostDeleteRequested(postId: 'post-42');
      expect(event.props, equals(['post-42']));
    });

    test('PostDeleteRequested supports value equality', () {
      const a = PostDeleteRequested(postId: 'post-42');
      const b = PostDeleteRequested(postId: 'post-42');
      expect(a, equals(b));
    });

    test('PostsUpdated props contains posts', () {
      final event = PostsUpdated([testPost]);
      expect(event.props, equals([[testPost]]));
    });
  });

  // -------------------------------------------------------------------------
  // PostState props / equality
  // -------------------------------------------------------------------------

  group('PostState props and equality', () {
    test('PostInitial props is empty', () {
      expect(const PostInitial().props, isEmpty);
    });

    test('PostLoading props is empty', () {
      expect(const PostLoading().props, isEmpty);
    });

    test('PostLoaded props contains posts and isSubmitting', () {
      final state = PostLoaded(posts: [testPost], isSubmitting: true);
      expect(state.props, equals([[testPost], true]));
    });

    test('PostLoaded copyWith changes isSubmitting', () {
      final original = PostLoaded(posts: [testPost]);
      final copy = original.copyWith(isSubmitting: true);
      expect(copy.isSubmitting, isTrue);
      expect(copy.posts, equals([testPost]));
    });

    test('PostLoaded copyWith changes posts', () {
      final original = PostLoaded(posts: [testPost]);
      final copy = original.copyWith(posts: [testPost, testPost2]);
      expect(copy.posts.length, 2);
      expect(copy.isSubmitting, isFalse);
    });

    test('PostFailure props contains error string', () {
      const state = PostFailure(error: 'oops');
      expect(state.props, equals(['oops']));
    });

    test('PostFailure supports value equality', () {
      const a = PostFailure(error: 'oops');
      const b = PostFailure(error: 'oops');
      expect(a, equals(b));
    });
  });
}
