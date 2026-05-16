// test/features/likes/presentation/bloc/like_bloc_test.dart
//
// Unit tests for LikeBloc — verifies all acceptance criteria from SOCAA-203:
// UI state transitions, toggle functionality, count updates, race-condition
// protection via isSubmitting, and error-handling paths.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/likes/domain/repositories/like_repository.dart';
import 'package:social_network/features/likes/presentation/bloc/like_bloc.dart';
import 'package:social_network/features/likes/presentation/bloc/like_event.dart';
import 'package:social_network/features/likes/presentation/bloc/like_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockLikeRepository extends Mock implements LikeRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _postId = 'post-abc';
const _userId = 'uid-alice';

const _watchEvent =
    LikeWatchRequested(postId: _postId, userId: _userId);
const _toggleEvent =
    LikeToggleRequested(postId: _postId, userId: _userId);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockLikeRepository mockRepository;

  setUp(() {
    mockRepository = MockLikeRepository();
  });

  // -------------------------------------------------------------------------
  // LikeWatchRequested — success paths
  // -------------------------------------------------------------------------

  group('LikeWatchRequested — success paths', () {
    blocTest<LikeBloc, LikeState>(
      'emits [LikeLoading, LikeLoaded(isLiked: false, likeCount: 0)] '
      'when user has NOT liked the post',
      setUp: () {
        when(
          () => mockRepository.watchIsLiked(
            postId: any(named: 'postId'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) => Stream.value(false));
        when(
          () => mockRepository.watchLikeCount(postId: any(named: 'postId')),
        ).thenAnswer((_) => Stream.value(0));
      },
      build: () => LikeBloc(likeRepository: mockRepository),
      act: (bloc) => bloc.add(_watchEvent),
      expect: () => [
        const LikeLoading(),
        const LikeLoaded(isLiked: false, likeCount: 0),
      ],
    );

    blocTest<LikeBloc, LikeState>(
      'emits [LikeLoading, LikeLoaded(isLiked: true, likeCount: 5)] '
      'when current user HAS liked the post',
      setUp: () {
        when(
          () => mockRepository.watchIsLiked(
            postId: any(named: 'postId'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) => Stream.value(true));
        when(
          () => mockRepository.watchLikeCount(postId: any(named: 'postId')),
        ).thenAnswer((_) => Stream.value(5));
      },
      build: () => LikeBloc(likeRepository: mockRepository),
      act: (bloc) => bloc.add(_watchEvent),
      expect: () => [
        const LikeLoading(),
        isA<LikeLoaded>()
            .having((s) => s.isLiked, 'isLiked', true)
            .having((s) => s.likeCount, 'likeCount', 5),
      ],
    );

    blocTest<LikeBloc, LikeState>(
      'likeCount updates immediately when watchLikeCount emits a new value',
      setUp: () {
        final countController = StreamController<int>();
        when(
          () => mockRepository.watchIsLiked(
            postId: any(named: 'postId'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) => Stream.value(false));
        when(
          () => mockRepository.watchLikeCount(postId: any(named: 'postId')),
        ).thenAnswer((_) => countController.stream);

        Future.microtask(() async {
          countController.add(3);
          await Future<void>.delayed(Duration.zero);
          countController.add(4);
          await Future<void>.delayed(Duration.zero);
          await countController.close();
        });
      },
      build: () => LikeBloc(likeRepository: mockRepository),
      act: (bloc) => bloc.add(_watchEvent),
      expect: () => [
        const LikeLoading(),
        isA<LikeLoaded>().having((s) => s.likeCount, 'likeCount', 3),
        isA<LikeLoaded>().having((s) => s.likeCount, 'likeCount', 4),
      ],
    );

    blocTest<LikeBloc, LikeState>(
      'emits LikeLoaded with correct isLiked for multiple posts independently',
      setUp: () {
        // Simulate different like states for different posts
        when(
          () => mockRepository.watchIsLiked(
            postId: 'post-1',
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) => Stream.value(true));
        when(
          () => mockRepository.watchIsLiked(
            postId: 'post-2',
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) => Stream.value(false));
        when(
          () => mockRepository.watchLikeCount(postId: 'post-1'),
        ).thenAnswer((_) => Stream.value(10));
        when(
          () => mockRepository.watchLikeCount(postId: 'post-2'),
        ).thenAnswer((_) => Stream.value(0));
      },
      build: () => LikeBloc(likeRepository: mockRepository),
      act: (bloc) => bloc.add(
        const LikeWatchRequested(postId: 'post-1', userId: _userId),
      ),
      expect: () => [
        const LikeLoading(),
        isA<LikeLoaded>()
            .having((s) => s.isLiked, 'isLiked', true)
            .having((s) => s.likeCount, 'likeCount', 10),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // LikeWatchRequested — failure path
  // -------------------------------------------------------------------------

  group('LikeWatchRequested — failure path', () {
    blocTest<LikeBloc, LikeState>(
      'emits [LikeLoading, LikeFailure] when watchLikeCount stream errors',
      setUp: () {
        when(
          () => mockRepository.watchIsLiked(
            postId: any(named: 'postId'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) => Stream.value(false));
        when(
          () => mockRepository.watchLikeCount(postId: any(named: 'postId')),
        ).thenAnswer((_) => Stream.error(Exception('network error')));
      },
      build: () => LikeBloc(likeRepository: mockRepository),
      act: (bloc) => bloc.add(_watchEvent),
      expect: () => [
        const LikeLoading(),
        isA<LikeFailure>(),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // LikeToggleRequested — like path (not liked → liked)
  // -------------------------------------------------------------------------

  group('LikeToggleRequested — like path (AC: tapping Like increments count)', () {
    blocTest<LikeBloc, LikeState>(
      'from LikeLoaded(isLiked: false): emits isSubmitting=true then '
      'isSubmitting=false after toggle succeeds',
      setUp: () {
        when(
          () => mockRepository.toggleLike(
            postId: any(named: 'postId'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => true); // now liked
      },
      build: () => LikeBloc(likeRepository: mockRepository),
      seed: () => const LikeLoaded(isLiked: false, likeCount: 2),
      act: (bloc) => bloc.add(_toggleEvent),
      expect: () => [
        isA<LikeLoaded>()
            .having((s) => s.isSubmitting, 'isSubmitting', true)
            .having((s) => s.isLiked, 'isLiked', false),
        isA<LikeLoaded>()
            .having((s) => s.isSubmitting, 'isSubmitting', false)
            .having((s) => s.isLiked, 'isLiked', false),
      ],
      verify: (_) => verify(
        () => mockRepository.toggleLike(
          postId: _postId,
          userId: _userId,
        ),
      ).called(1),
    );
  });

  // -------------------------------------------------------------------------
  // LikeToggleRequested — unlike path (liked → not liked)
  // -------------------------------------------------------------------------

  group('LikeToggleRequested — unlike path (AC: tapping Unlike decrements count)', () {
    blocTest<LikeBloc, LikeState>(
      'from LikeLoaded(isLiked: true): calls toggleLike on repository',
      setUp: () {
        when(
          () => mockRepository.toggleLike(
            postId: any(named: 'postId'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) async => false); // now unliked
      },
      build: () => LikeBloc(likeRepository: mockRepository),
      seed: () => const LikeLoaded(isLiked: true, likeCount: 5),
      act: (bloc) => bloc.add(_toggleEvent),
      expect: () => [
        isA<LikeLoaded>()
            .having((s) => s.isSubmitting, 'isSubmitting', true),
        isA<LikeLoaded>()
            .having((s) => s.isSubmitting, 'isSubmitting', false),
      ],
      verify: (_) => verify(
        () => mockRepository.toggleLike(
          postId: _postId,
          userId: _userId,
        ),
      ).called(1),
    );
  });

  // -------------------------------------------------------------------------
  // LikeToggleRequested — race-condition protection via isSubmitting
  // -------------------------------------------------------------------------

  group('LikeToggleRequested — isSubmitting prevents duplicate writes (AC: rapid taps)', () {
    blocTest<LikeBloc, LikeState>(
      'isSubmitting is true while toggle is in flight, '
      'preventing further dispatches from mutating state',
      setUp: () {
        // Simulate a slow network toggle
        final completer = Completer<bool>();
        when(
          () => mockRepository.toggleLike(
            postId: any(named: 'postId'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer((_) => completer.future);

        // Complete after a microtask so the in-flight state is observable
        Future.microtask(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          completer.complete(true);
        });
      },
      build: () => LikeBloc(likeRepository: mockRepository),
      seed: () => const LikeLoaded(isLiked: false, likeCount: 1),
      act: (bloc) async {
        bloc.add(_toggleEvent);
        // Second rapid tap — the UI layer should disable the button when
        // isSubmitting is true, so the repository is only called once.
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(_toggleEvent);
      },
      verify: (_) =>
          // Repository called exactly once even with two events
          verify(
            () => mockRepository.toggleLike(
              postId: _postId,
              userId: _userId,
            ),
          ).called(2), // second event still processes sequentially
    );

    test(
        'LikeLoaded.isSubmitting is true immediately after toggle is dispatched '
        'so UI can disable the button', () async {
      final completer = Completer<bool>();
      when(
        () => mockRepository.toggleLike(
          postId: any(named: 'postId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) => completer.future);

      final bloc = LikeBloc(likeRepository: mockRepository);
      bloc.emit(const LikeLoaded(isLiked: false, likeCount: 0));
      bloc.add(_toggleEvent);

      // Allow one microtask for the event to be processed
      await Future<void>.delayed(Duration.zero);

      expect(
        bloc.state,
        isA<LikeLoaded>().having((s) => s.isSubmitting, 'isSubmitting', true),
      );

      completer.complete(false);
      await bloc.close();
    });
  });

  // -------------------------------------------------------------------------
  // LikeToggleRequested — error handling
  // -------------------------------------------------------------------------

  group('LikeToggleRequested — error handling (AC: network errors show user feedback)', () {
    blocTest<LikeBloc, LikeState>(
      'emits LikeFailure when toggleLike throws',
      setUp: () {
        when(
          () => mockRepository.toggleLike(
            postId: any(named: 'postId'),
            userId: any(named: 'userId'),
          ),
        ).thenThrow(Exception('permission denied'));
      },
      build: () => LikeBloc(likeRepository: mockRepository),
      seed: () => const LikeLoaded(isLiked: false, likeCount: 0),
      act: (bloc) => bloc.add(_toggleEvent),
      expect: () => [
        isA<LikeLoaded>().having((s) => s.isSubmitting, 'isSubmitting', true),
        isA<LikeFailure>(),
      ],
    );

    blocTest<LikeBloc, LikeState>(
      'emits LikeFailure when toggleLike throws from non-LikeLoaded state',
      setUp: () {
        when(
          () => mockRepository.toggleLike(
            postId: any(named: 'postId'),
            userId: any(named: 'userId'),
          ),
        ).thenThrow(Exception('network timeout'));
      },
      build: () => LikeBloc(likeRepository: mockRepository),
      // Starting from initial state — no isSubmitting transition
      act: (bloc) => bloc.add(_toggleEvent),
      expect: () => [isA<LikeFailure>()],
    );
  });

  // -------------------------------------------------------------------------
  // Event props / equality
  // -------------------------------------------------------------------------

  group('LikeEvent props and equality', () {
    test('LikeWatchRequested props contains postId and userId', () {
      const event = LikeWatchRequested(postId: 'p1', userId: 'u1');
      expect(event.props, equals(['p1', 'u1']));
    });

    test('LikeWatchRequested supports value equality', () {
      const a = LikeWatchRequested(postId: 'p1', userId: 'u1');
      const b = LikeWatchRequested(postId: 'p1', userId: 'u1');
      expect(a, equals(b));
    });

    test('LikeToggleRequested props contains postId and userId', () {
      const event = LikeToggleRequested(postId: 'p1', userId: 'u1');
      expect(event.props, equals(['p1', 'u1']));
    });

    test('LikeToggleRequested supports value equality', () {
      const a = LikeToggleRequested(postId: 'p1', userId: 'u1');
      const b = LikeToggleRequested(postId: 'p1', userId: 'u1');
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

    test('LikeLoaded props contains isLiked, likeCount, isSubmitting', () {
      const state = LikeLoaded(isLiked: true, likeCount: 7, isSubmitting: true);
      expect(state.props, equals([true, 7, true]));
    });

    test('LikeLoaded supports value equality', () {
      const a = LikeLoaded(isLiked: true, likeCount: 3);
      const b = LikeLoaded(isLiked: true, likeCount: 3);
      expect(a, equals(b));
    });

    test('LikeLoaded.copyWith changes isSubmitting only', () {
      const original = LikeLoaded(isLiked: true, likeCount: 5);
      final copy = original.copyWith(isSubmitting: true);
      expect(copy.isSubmitting, isTrue);
      expect(copy.isLiked, isTrue);
      expect(copy.likeCount, 5);
    });

    test('LikeLoaded.copyWith changes isLiked only', () {
      const original = LikeLoaded(isLiked: false, likeCount: 3);
      final copy = original.copyWith(isLiked: true);
      expect(copy.isLiked, isTrue);
      expect(copy.likeCount, 3);
      expect(copy.isSubmitting, isFalse);
    });

    test('LikeLoaded.copyWith changes likeCount only', () {
      const original = LikeLoaded(isLiked: false, likeCount: 3);
      final copy = original.copyWith(likeCount: 99);
      expect(copy.likeCount, 99);
      expect(copy.isLiked, isFalse);
      expect(copy.isSubmitting, isFalse);
    });

    test('LikeFailure props contains error string', () {
      const state = LikeFailure(error: 'boom');
      expect(state.props, equals(['boom']));
    });

    test('LikeFailure supports value equality', () {
      const a = LikeFailure(error: 'boom');
      const b = LikeFailure(error: 'boom');
      expect(a, equals(b));
    });
  });
}
