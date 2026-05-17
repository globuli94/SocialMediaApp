// test/features/posts/presentation/bloc/like_bloc_test.dart
//
// Unit tests for LikeBloc — verifies every event handler with success and
// failure paths to satisfy the ≥ 90% bloc coverage threshold.
//
// Acceptance criteria verified (SOCAA-215):
//   AC2 — Tapping Like fills the heart icon (isLiked=true in state)
//   AC3 — Tapping Unlike outlines the heart icon (isLiked=false in state)
//   AC5 — Like state persists across app restarts (read from Firestore via stream)

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/like_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/like_event.dart';
import 'package:social_network/features/posts/presentation/bloc/like_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPostRepository extends Mock implements PostRepository {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockPostRepository mockRepository;

  setUp(() {
    mockRepository = MockPostRepository();
  });

  // -------------------------------------------------------------------------
  // LikeFetched — AC5: initial like state read from Firestore
  // -------------------------------------------------------------------------

  group('LikeFetched', () {
    blocTest<LikeBloc, LikeState>(
      'emits [LikeLoading, LikeUpdated(isLiked=false)] '
      'when user has not liked the post',
      setUp: () {
        when(() => mockRepository.watchPostLiked('post-1', 'uid-me'))
            .thenAnswer((_) => Stream.value(false));
      },
      build: () => LikeBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(const LikeFetched(
        postId: 'post-1',
        userId: 'uid-me',
      )),
      expect: () => [
        const LikeLoading(),
        isA<LikeUpdated>()
            .having((s) => s.isLiked, 'isLiked', false),
      ],
      verify: (_) => verify(
        () => mockRepository.watchPostLiked('post-1', 'uid-me'),
      ).called(1),
    );

    blocTest<LikeBloc, LikeState>(
      'emits [LikeLoading, LikeUpdated(isLiked=true)] '
      'when current user has already liked the post (AC5)',
      setUp: () {
        when(() => mockRepository.watchPostLiked('post-2', 'uid-me'))
            .thenAnswer((_) => Stream.value(true));
      },
      build: () => LikeBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(const LikeFetched(
        postId: 'post-2',
        userId: 'uid-me',
      )),
      expect: () => [
        const LikeLoading(),
        isA<LikeUpdated>().having((s) => s.isLiked, 'isLiked', true),
      ],
    );

    blocTest<LikeBloc, LikeState>(
      'emits [LikeLoading, LikeError] when watchPostLiked stream errors',
      setUp: () {
        when(() => mockRepository.watchPostLiked(any(), any()))
            .thenAnswer((_) => Stream.error(Exception('firestore error')));
      },
      build: () => LikeBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(const LikeFetched(
        postId: 'post-err',
        userId: 'uid-me',
      )),
      expect: () => [
        const LikeLoading(),
        isA<LikeError>(),
      ],
    );

    blocTest<LikeBloc, LikeState>(
      'emits multiple LikeUpdated states as watchPostLiked stream updates',
      setUp: () {
        final controller = StreamController<bool>();
        when(() => mockRepository.watchPostLiked('post-stream', 'uid-me'))
            .thenAnswer((_) => controller.stream);
        Future.microtask(() async {
          controller.add(false);
          await Future<void>.delayed(Duration.zero);
          controller.add(true);
          await Future<void>.delayed(Duration.zero);
          await controller.close();
        });
      },
      build: () => LikeBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(const LikeFetched(
        postId: 'post-stream',
        userId: 'uid-me',
      )),
      expect: () => [
        const LikeLoading(),
        isA<LikeUpdated>().having((s) => s.isLiked, 'isLiked', false),
        isA<LikeUpdated>().having((s) => s.isLiked, 'isLiked', true),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // LikeToggled — AC2: likePost called on tap when not liked
  //              AC3: unlikePost called on tap when liked
  // -------------------------------------------------------------------------

  group('LikeToggled (like — AC2)', () {
    blocTest<LikeBloc, LikeState>(
      'calls likePost and emits optimistic LikeUpdated(isLiked=true) when tapping to like',
      setUp: () {
        when(() => mockRepository.likePost('post-like', 'uid-me'))
            .thenAnswer((_) async {});
      },
      build: () => LikeBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(const LikeToggled(
        postId: 'post-like',
        userId: 'uid-me',
        isLiked: false,
      )),
      expect: () => [
        isA<LikeUpdated>()
            .having((s) => s.isLiked, 'isLiked', true)
            .having((s) => s.likeCount, 'likeCount', 1),
      ],
      verify: (_) =>
          verify(() => mockRepository.likePost('post-like', 'uid-me')).called(1),
    );

    blocTest<LikeBloc, LikeState>(
      'emits LikeError when likePost throws',
      setUp: () {
        when(() => mockRepository.likePost(any(), any()))
            .thenThrow(Exception('network error'));
      },
      build: () => LikeBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(const LikeToggled(
        postId: 'post-like-err',
        userId: 'uid-me',
        isLiked: false,
      )),
      expect: () => [isA<LikeUpdated>(), isA<LikeError>()],
      errors: () => [isA<Exception>()],
    );
  });

  group('LikeToggled (unlike — AC3)', () {
    blocTest<LikeBloc, LikeState>(
      'calls unlikePost and emits optimistic LikeUpdated(isLiked=false) when tapping to unlike',
      setUp: () {
        when(() => mockRepository.unlikePost('post-unlike', 'uid-me'))
            .thenAnswer((_) async {});
      },
      build: () => LikeBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(const LikeToggled(
        postId: 'post-unlike',
        userId: 'uid-me',
        isLiked: true,
      )),
      expect: () => [
        isA<LikeUpdated>().having((s) => s.isLiked, 'isLiked', false),
      ],
      verify: (_) => verify(
        () => mockRepository.unlikePost('post-unlike', 'uid-me'),
      ).called(1),
    );

    blocTest<LikeBloc, LikeState>(
      'emits LikeError when unlikePost throws',
      setUp: () {
        when(() => mockRepository.unlikePost(any(), any()))
            .thenThrow(Exception('permission denied'));
      },
      build: () => LikeBloc(postRepository: mockRepository),
      act: (bloc) => bloc.add(const LikeToggled(
        postId: 'post-unlike-err',
        userId: 'uid-me',
        isLiked: true,
      )),
      expect: () => [isA<LikeUpdated>(), isA<LikeError>()],
      errors: () => [isA<Exception>()],
    );
  });

  // -------------------------------------------------------------------------
  // Full flow: LikeFetched → LikeToggled → stream updates state
  // -------------------------------------------------------------------------

  group('Full flow — LikeFetched + LikeToggled', () {
    test(
        'after likePost succeeds the stream emits LikeUpdated(isLiked=true)',
        () async {
      final controller = StreamController<bool>();
      final emitted = <LikeState>[];

      when(() => mockRepository.watchPostLiked('post-full', 'uid-me'))
          .thenAnswer((_) => controller.stream);
      when(() => mockRepository.likePost('post-full', 'uid-me'))
          .thenAnswer((_) async {
        controller.add(true);
        await Future<void>.delayed(Duration.zero);
      });

      final bloc = LikeBloc(postRepository: mockRepository);
      final sub = bloc.stream.listen(emitted.add);

      // Start watching and let stream emit initial false value
      bloc.add(const LikeFetched(postId: 'post-full', userId: 'uid-me'));
      await Future<void>.delayed(Duration.zero);
      controller.add(false);
      await Future<void>.delayed(Duration.zero);

      // Toggle like — likePost will add true to the stream
      bloc.add(const LikeToggled(
        postId: 'post-full',
        userId: 'uid-me',
        isLiked: false,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await sub.cancel();
      await bloc.close();
      await controller.close();

      expect(
        emitted,
        containsAllInOrder([
          isA<LikeLoading>(),
          isA<LikeUpdated>().having((s) => s.isLiked, 'isLiked', false),
          isA<LikeUpdated>().having((s) => s.isLiked, 'isLiked', true),
        ]),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Event props / equality
  // -------------------------------------------------------------------------

  group('LikeEvent props and equality', () {
    test('LikeFetched props contains postId, userId, and initialLikeCount', () {
      const event = LikeFetched(postId: 'p1', userId: 'u1');
      expect(event.props, equals(['p1', 'u1', 0]));
    });

    test('LikeFetched supports value equality', () {
      const a = LikeFetched(postId: 'p1', userId: 'u1');
      const b = LikeFetched(postId: 'p1', userId: 'u1');
      expect(a, equals(b));
    });

    test('LikeToggled props contains postId, userId, isLiked, and currentLikeCount', () {
      const event = LikeToggled(postId: 'p1', userId: 'u1', isLiked: true);
      expect(event.props, equals(['p1', 'u1', true, 0]));
    });

    test('LikeToggled supports value equality', () {
      const a = LikeToggled(postId: 'p1', userId: 'u1', isLiked: false);
      const b = LikeToggled(postId: 'p1', userId: 'u1', isLiked: false);
      expect(a, equals(b));
    });
  });

  // -------------------------------------------------------------------------
  // State props / equality
  // -------------------------------------------------------------------------

  group('LikeState props and equality', () {
    test('LikeInitial props is empty', () {
      expect(const LikeInitial().props, isEmpty);
    });

    test('LikeLoading props is empty', () {
      expect(const LikeLoading().props, isEmpty);
    });

    test('LikeUpdated props contains isLiked and likeCount', () {
      const state = LikeUpdated(isLiked: true, likeCount: 3);
      expect(state.props, equals([true, 3]));
    });

    test('LikeUpdated supports value equality', () {
      const a = LikeUpdated(isLiked: false, likeCount: 0);
      const b = LikeUpdated(isLiked: false, likeCount: 0);
      expect(a, equals(b));
    });

    test('LikeError props contains message', () {
      const state = LikeError(message: 'Something went wrong');
      expect(state.props, equals(['Something went wrong']));
    });

    test('LikeError supports value equality', () {
      const a = LikeError(message: 'err');
      const b = LikeError(message: 'err');
      expect(a, equals(b));
    });
  });
}
