// test/features/follow/bloc/follow_bloc_test.dart
//
// Unit tests for FollowBloc — covers FollowWatchStarted, FollowToggleRequested
// (follow and unfollow paths), and FollowFailure to satisfy the ≥ 90% bloc
// coverage threshold.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_bloc.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFollowRepository extends Mock implements FollowRepository {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockFollowRepository mockRepository;

  setUp(() {
    mockRepository = MockFollowRepository();
  });

  // -------------------------------------------------------------------------
  // FollowWatchStarted
  // -------------------------------------------------------------------------

  group('FollowWatchStarted', () {
    blocTest<FollowBloc, FollowState>(
      'emits [FollowLoading, FollowLoaded(true)] when stream emits true',
      setUp: () {
        when(
          () => mockRepository.watchIsFollowing(
            followerId: any(named: 'followerId'),
            followeeId: any(named: 'followeeId'),
          ),
        ).thenAnswer((_) => Stream.value(true));
      },
      build: () => FollowBloc(followRepository: mockRepository),
      act: (bloc) => bloc.add(
        const FollowWatchStarted(followerId: 'uid-a', followeeId: 'uid-b'),
      ),
      expect: () => [
        const FollowLoading(),
        const FollowLoaded(isFollowing: true),
      ],
      verify: (_) {
        verify(
          () => mockRepository.watchIsFollowing(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        ).called(1);
      },
    );

    blocTest<FollowBloc, FollowState>(
      'emits [FollowLoading, FollowLoaded(false)] when stream emits false',
      setUp: () {
        when(
          () => mockRepository.watchIsFollowing(
            followerId: any(named: 'followerId'),
            followeeId: any(named: 'followeeId'),
          ),
        ).thenAnswer((_) => Stream.value(false));
      },
      build: () => FollowBloc(followRepository: mockRepository),
      act: (bloc) => bloc.add(
        const FollowWatchStarted(followerId: 'uid-a', followeeId: 'uid-b'),
      ),
      expect: () => [
        const FollowLoading(),
        const FollowLoaded(isFollowing: false),
      ],
    );

    blocTest<FollowBloc, FollowState>(
      'emits [FollowLoading, FollowFailure] when stream emits an error',
      setUp: () {
        when(
          () => mockRepository.watchIsFollowing(
            followerId: any(named: 'followerId'),
            followeeId: any(named: 'followeeId'),
          ),
        ).thenAnswer(
          (_) => Stream.error(Exception('watch error')),
        );
      },
      build: () => FollowBloc(followRepository: mockRepository),
      act: (bloc) => bloc.add(
        const FollowWatchStarted(followerId: 'uid-a', followeeId: 'uid-b'),
      ),
      expect: () => [
        const FollowLoading(),
        isA<FollowFailure>().having(
          (s) => s.error,
          'error',
          contains('watch error'),
        ),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // FollowToggleRequested — follow path (not currently following)
  // -------------------------------------------------------------------------

  group('FollowToggleRequested — follow path', () {
    late StreamController<bool> streamController;

    setUp(() {
      streamController = StreamController<bool>();
    });

    tearDown(() {
      streamController.close();
    });

    blocTest<FollowBloc, FollowState>(
      'calls follow() and state becomes FollowLoaded(isFollowing: true) via stream',
      setUp: () {
        when(
          () => mockRepository.watchIsFollowing(
            followerId: any(named: 'followerId'),
            followeeId: any(named: 'followeeId'),
          ),
        ).thenAnswer((_) => streamController.stream);
        when(
          () => mockRepository.follow(
            followerId: any(named: 'followerId'),
            followeeId: any(named: 'followeeId'),
          ),
        ).thenAnswer((_) async => streamController.add(true));
      },
      build: () => FollowBloc(followRepository: mockRepository),
      act: (bloc) async {
        bloc.add(
          const FollowWatchStarted(followerId: 'uid-a', followeeId: 'uid-b'),
        );
        await Future<void>.delayed(Duration.zero);
        streamController.add(false);
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const FollowToggleRequested(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      expect: () => [
        const FollowLoading(),
        const FollowLoaded(isFollowing: false),
        const FollowLoading(),
        const FollowLoaded(isFollowing: true),
      ],
      verify: (_) {
        verify(
          () => mockRepository.follow(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        ).called(1);
        verifyNever(
          () => mockRepository.unfollow(
            followerId: any(named: 'followerId'),
            followeeId: any(named: 'followeeId'),
          ),
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // FollowToggleRequested — unfollow path (currently following)
  // -------------------------------------------------------------------------

  group('FollowToggleRequested — unfollow path', () {
    late StreamController<bool> streamController;

    setUp(() {
      streamController = StreamController<bool>();
    });

    tearDown(() {
      streamController.close();
    });

    blocTest<FollowBloc, FollowState>(
      'calls unfollow() and state becomes FollowLoaded(isFollowing: false) via stream',
      setUp: () {
        when(
          () => mockRepository.watchIsFollowing(
            followerId: any(named: 'followerId'),
            followeeId: any(named: 'followeeId'),
          ),
        ).thenAnswer((_) => streamController.stream);
        when(
          () => mockRepository.unfollow(
            followerId: any(named: 'followerId'),
            followeeId: any(named: 'followeeId'),
          ),
        ).thenAnswer((_) async => streamController.add(false));
      },
      build: () => FollowBloc(followRepository: mockRepository),
      act: (bloc) async {
        bloc.add(
          const FollowWatchStarted(followerId: 'uid-a', followeeId: 'uid-b'),
        );
        await Future<void>.delayed(Duration.zero);
        streamController.add(true);
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const FollowToggleRequested(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      expect: () => [
        const FollowLoading(),
        const FollowLoaded(isFollowing: true),
        const FollowLoading(),
        const FollowLoaded(isFollowing: false),
      ],
      verify: (_) {
        verify(
          () => mockRepository.unfollow(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        ).called(1);
        verifyNever(
          () => mockRepository.follow(
            followerId: any(named: 'followerId'),
            followeeId: any(named: 'followeeId'),
          ),
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // FollowToggleRequested — failure path
  // -------------------------------------------------------------------------

  group('FollowToggleRequested — failure path', () {
    blocTest<FollowBloc, FollowState>(
      'emits [FollowLoading, FollowFailure] when follow() throws',
      setUp: () {
        when(
          () => mockRepository.follow(
            followerId: any(named: 'followerId'),
            followeeId: any(named: 'followeeId'),
          ),
        ).thenThrow(Exception('follow failed'));
      },
      build: () => FollowBloc(followRepository: mockRepository),
      seed: () => const FollowLoaded(isFollowing: false),
      act: (bloc) => bloc.add(
        const FollowToggleRequested(
          followerId: 'uid-a',
          followeeId: 'uid-b',
        ),
      ),
      expect: () => [
        const FollowLoading(),
        isA<FollowFailure>().having(
          (s) => s.error,
          'error',
          contains('follow failed'),
        ),
      ],
    );

    blocTest<FollowBloc, FollowState>(
      'emits [FollowLoading, FollowFailure] when unfollow() throws',
      setUp: () {
        when(
          () => mockRepository.unfollow(
            followerId: any(named: 'followerId'),
            followeeId: any(named: 'followeeId'),
          ),
        ).thenThrow(Exception('unfollow failed'));
      },
      build: () => FollowBloc(followRepository: mockRepository),
      seed: () => const FollowLoaded(isFollowing: true),
      act: (bloc) => bloc.add(
        const FollowToggleRequested(
          followerId: 'uid-a',
          followeeId: 'uid-b',
        ),
      ),
      expect: () => [
        const FollowLoading(),
        isA<FollowFailure>().having(
          (s) => s.error,
          'error',
          contains('unfollow failed'),
        ),
      ],
    );

    blocTest<FollowBloc, FollowState>(
      'ignores FollowToggleRequested when state is not FollowLoaded',
      build: () => FollowBloc(followRepository: mockRepository),
      // initial state is FollowInitial (not FollowLoaded)
      act: (bloc) => bloc.add(
        const FollowToggleRequested(
          followerId: 'uid-a',
          followeeId: 'uid-b',
        ),
      ),
      expect: () => const <FollowState>[],
    );
  });

  // -------------------------------------------------------------------------
  // FollowStatusUpdated — internal event
  // -------------------------------------------------------------------------

  group('FollowStatusUpdated', () {
    blocTest<FollowBloc, FollowState>(
      'emits FollowLoaded with new isFollowing value',
      build: () => FollowBloc(followRepository: mockRepository),
      act: (bloc) =>
          bloc.add(const FollowStatusUpdated(isFollowing: true)),
      expect: () => [const FollowLoaded(isFollowing: true)],
    );
  });

  // -------------------------------------------------------------------------
  // Event equality — exercises Equatable props for coverage
  // -------------------------------------------------------------------------

  group('FollowEvent props and equality', () {
    test('FollowWatchStarted props contains followerId and followeeId', () {
      const event = FollowWatchStarted(
        followerId: 'uid-a',
        followeeId: 'uid-b',
      );
      expect(event.props, equals(['uid-a', 'uid-b']));
    });

    test('FollowWatchStarted supports value equality', () {
      const a = FollowWatchStarted(followerId: 'uid-x', followeeId: 'uid-y');
      const b = FollowWatchStarted(followerId: 'uid-x', followeeId: 'uid-y');
      expect(a, equals(b));
    });

    test('FollowToggleRequested props contains followerId and followeeId', () {
      const event = FollowToggleRequested(
        followerId: 'uid-a',
        followeeId: 'uid-b',
      );
      expect(event.props, equals(['uid-a', 'uid-b']));
    });

    test('FollowToggleRequested supports value equality', () {
      const a = FollowToggleRequested(
        followerId: 'uid-a',
        followeeId: 'uid-b',
      );
      const b = FollowToggleRequested(
        followerId: 'uid-a',
        followeeId: 'uid-b',
      );
      expect(a, equals(b));
    });

    test('FollowStatusUpdated props contains isFollowing', () {
      const event = FollowStatusUpdated(isFollowing: true);
      expect(event.props, equals([true]));
    });
  });

  // -------------------------------------------------------------------------
  // State equality — exercises Equatable props for coverage
  // -------------------------------------------------------------------------

  group('FollowState props and equality', () {
    test('FollowLoaded supports value equality', () {
      const a = FollowLoaded(isFollowing: true);
      const b = FollowLoaded(isFollowing: true);
      expect(a, equals(b));
    });

    test('FollowLoaded with different values are not equal', () {
      const a = FollowLoaded(isFollowing: true);
      const b = FollowLoaded(isFollowing: false);
      expect(a, isNot(equals(b)));
    });

    test('FollowFailure supports value equality', () {
      const a = FollowFailure(error: 'err');
      const b = FollowFailure(error: 'err');
      expect(a, equals(b));
    });

    test('FollowInitial and FollowLoading have empty props', () {
      expect(const FollowInitial().props, isEmpty);
      expect(const FollowLoading().props, isEmpty);
    });
  });
}
