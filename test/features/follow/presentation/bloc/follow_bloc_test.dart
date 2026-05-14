// test/features/follow/presentation/bloc/follow_bloc_test.dart
//
// Unit tests for FollowBloc — covers FollowWatchRequested, FollowRequested,
// and UnfollowRequested to satisfy the >= 90% BLoC coverage threshold.
//
// Uses mocktail to mock FollowRepository — no real Firebase connections.

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
  late MockFollowRepository repository;

  setUp(() {
    repository = MockFollowRepository();
  });

  // -------------------------------------------------------------------------
  // FollowWatchRequested
  // -------------------------------------------------------------------------

  group('FollowWatchRequested', () {
    blocTest<FollowBloc, FollowState>(
      'emits [FollowLoading, FollowLoaded(false)] when stream emits false',
      build: () {
        when(
          () => repository.watchIsFollowing(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        ).thenAnswer((_) => Stream.value(false));
        return FollowBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(
        const FollowWatchRequested(followerId: 'uid-a', followeeId: 'uid-b'),
      ),
      expect: () => [
        const FollowLoading(),
        const FollowLoaded(isFollowing: false),
      ],
    );

    blocTest<FollowBloc, FollowState>(
      'emits [FollowLoading, FollowLoaded(true)] when stream emits true',
      build: () {
        when(
          () => repository.watchIsFollowing(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        ).thenAnswer((_) => Stream.value(true));
        return FollowBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(
        const FollowWatchRequested(followerId: 'uid-a', followeeId: 'uid-b'),
      ),
      expect: () => [
        const FollowLoading(),
        const FollowLoaded(isFollowing: true),
      ],
    );

    blocTest<FollowBloc, FollowState>(
      'emits [FollowLoading, FollowFailure] when stream emits an error',
      build: () {
        when(
          () => repository.watchIsFollowing(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        ).thenAnswer((_) => Stream.error(Exception('watch failed')));
        return FollowBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(
        const FollowWatchRequested(followerId: 'uid-a', followeeId: 'uid-b'),
      ),
      expect: () => [
        const FollowLoading(),
        isA<FollowFailure>(),
      ],
    );

    blocTest<FollowBloc, FollowState>(
      'emits multiple FollowLoaded states for each stream event',
      build: () {
        when(
          () => repository.watchIsFollowing(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        ).thenAnswer((_) => Stream.fromIterable([false, true, false]));
        return FollowBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(
        const FollowWatchRequested(followerId: 'uid-a', followeeId: 'uid-b'),
      ),
      expect: () => [
        const FollowLoading(),
        const FollowLoaded(isFollowing: false),
        const FollowLoaded(isFollowing: true),
        const FollowLoaded(isFollowing: false),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // FollowRequested
  // -------------------------------------------------------------------------

  group('FollowRequested', () {
    blocTest<FollowBloc, FollowState>(
      'calls repository.follow and emits no new states on success',
      build: () {
        when(
          () => repository.follow(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        ).thenAnswer((_) async {});
        return FollowBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(
        const FollowRequested(followerId: 'uid-a', followeeId: 'uid-b'),
      ),
      expect: () => <FollowState>[],
      verify: (_) {
        verify(
          () => repository.follow(followerId: 'uid-a', followeeId: 'uid-b'),
        ).called(1);
      },
    );

    blocTest<FollowBloc, FollowState>(
      'emits FollowFailure when repository.follow throws',
      build: () {
        when(
          () => repository.follow(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        ).thenThrow(Exception('network error'));
        return FollowBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(
        const FollowRequested(followerId: 'uid-a', followeeId: 'uid-b'),
      ),
      expect: () => [isA<FollowFailure>()],
    );

    blocTest<FollowBloc, FollowState>(
      'FollowFailure contains error message when repository.follow throws',
      build: () {
        when(
          () => repository.follow(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        ).thenThrow(Exception('permission denied'));
        return FollowBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(
        const FollowRequested(followerId: 'uid-a', followeeId: 'uid-b'),
      ),
      expect: () => [
        isA<FollowFailure>().having(
          (s) => s.error,
          'error',
          contains('permission denied'),
        ),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // UnfollowRequested
  // -------------------------------------------------------------------------

  group('UnfollowRequested', () {
    blocTest<FollowBloc, FollowState>(
      'calls repository.unfollow and emits no new states on success',
      build: () {
        when(
          () => repository.unfollow(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        ).thenAnswer((_) async {});
        return FollowBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(
        const UnfollowRequested(followerId: 'uid-a', followeeId: 'uid-b'),
      ),
      expect: () => <FollowState>[],
      verify: (_) {
        verify(
          () => repository.unfollow(followerId: 'uid-a', followeeId: 'uid-b'),
        ).called(1);
      },
    );

    blocTest<FollowBloc, FollowState>(
      'emits FollowFailure when repository.unfollow throws',
      build: () {
        when(
          () => repository.unfollow(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        ).thenThrow(Exception('network error'));
        return FollowBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(
        const UnfollowRequested(followerId: 'uid-a', followeeId: 'uid-b'),
      ),
      expect: () => [isA<FollowFailure>()],
    );

    blocTest<FollowBloc, FollowState>(
      'FollowFailure contains error message when repository.unfollow throws',
      build: () {
        when(
          () => repository.unfollow(
            followerId: 'uid-a',
            followeeId: 'uid-b',
          ),
        ).thenThrow(Exception('permission denied'));
        return FollowBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(
        const UnfollowRequested(followerId: 'uid-a', followeeId: 'uid-b'),
      ),
      expect: () => [
        isA<FollowFailure>().having(
          (s) => s.error,
          'error',
          contains('permission denied'),
        ),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  test('initial state is FollowInitial', () {
    final bloc = FollowBloc(followRepository: repository);
    expect(bloc.state, const FollowInitial());
    bloc.close();
  });
}
