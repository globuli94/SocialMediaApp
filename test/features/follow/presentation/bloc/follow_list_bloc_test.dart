// test/features/follow/presentation/bloc/follow_list_bloc_test.dart
//
// Unit tests for FollowListBloc — covers FollowListWatchFollowersStarted and
// FollowListWatchFollowingStarted to satisfy the >= 90% BLoC coverage threshold.
//
// Uses mocktail to mock FollowRepository — no real Firebase connections.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_bloc.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_state.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFollowRepository extends Mock implements FollowRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _userAlice = UserProfileEntity(
  uid: 'uid-alice',
  displayName: 'Alice',
  bio: '',
  avatarUrl: null,
  postCount: 0,
  followerCount: 1,
  followingCount: 0,
);

const _userBob = UserProfileEntity(
  uid: 'uid-bob',
  displayName: 'Bob',
  bio: '',
  avatarUrl: null,
  postCount: 0,
  followerCount: 0,
  followingCount: 1,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockFollowRepository repository;

  setUp(() {
    repository = MockFollowRepository();
    registerFallbackValue('');
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  test('initial state is FollowListInitial', () {
    when(() => repository.watchFollowers(any()))
        .thenAnswer((_) => const Stream.empty());
    final bloc = FollowListBloc(followRepository: repository);
    expect(bloc.state, const FollowListInitial());
    bloc.close();
  });

  // -------------------------------------------------------------------------
  // FollowListWatchFollowersStarted
  // -------------------------------------------------------------------------

  group('FollowListWatchFollowersStarted', () {
    blocTest<FollowListBloc, FollowListState>(
      'emits [FollowListLoading, FollowListLoaded(users)] when stream emits a list',
      build: () {
        when(() => repository.watchFollowers('uid-me'))
            .thenAnswer((_) => Stream.value([_userAlice, _userBob]));
        return FollowListBloc(followRepository: repository);
      },
      act: (bloc) =>
          bloc.add(const FollowListWatchFollowersStarted('uid-me')),
      expect: () => [
        const FollowListLoading(),
        const FollowListLoaded(users: [_userAlice, _userBob]),
      ],
    );

    blocTest<FollowListBloc, FollowListState>(
      'emits [FollowListLoading, FollowListLoaded([])] when stream emits empty list',
      build: () {
        when(() => repository.watchFollowers('uid-me'))
            .thenAnswer((_) => Stream.value([]));
        return FollowListBloc(followRepository: repository);
      },
      act: (bloc) =>
          bloc.add(const FollowListWatchFollowersStarted('uid-me')),
      expect: () => [
        const FollowListLoading(),
        const FollowListLoaded(users: []),
      ],
    );

    blocTest<FollowListBloc, FollowListState>(
      'emits [FollowListLoading, FollowListFailure] when stream errors',
      build: () {
        when(() => repository.watchFollowers('uid-me'))
            .thenAnswer((_) => Stream.error(Exception('network error')));
        return FollowListBloc(followRepository: repository);
      },
      act: (bloc) =>
          bloc.add(const FollowListWatchFollowersStarted('uid-me')),
      expect: () => [
        const FollowListLoading(),
        isA<FollowListFailure>(),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // FollowListWatchFollowingStarted
  // -------------------------------------------------------------------------

  group('FollowListWatchFollowingStarted', () {
    blocTest<FollowListBloc, FollowListState>(
      'emits [FollowListLoading, FollowListLoaded(users)] when stream emits a list',
      build: () {
        when(() => repository.watchFollowing('uid-me'))
            .thenAnswer((_) => Stream.value([_userBob]));
        return FollowListBloc(followRepository: repository);
      },
      act: (bloc) =>
          bloc.add(const FollowListWatchFollowingStarted('uid-me')),
      expect: () => [
        const FollowListLoading(),
        const FollowListLoaded(users: [_userBob]),
      ],
    );

    blocTest<FollowListBloc, FollowListState>(
      'emits [FollowListLoading, FollowListLoaded([])] when stream emits empty list',
      build: () {
        when(() => repository.watchFollowing('uid-me'))
            .thenAnswer((_) => Stream.value([]));
        return FollowListBloc(followRepository: repository);
      },
      act: (bloc) =>
          bloc.add(const FollowListWatchFollowingStarted('uid-me')),
      expect: () => [
        const FollowListLoading(),
        const FollowListLoaded(users: []),
      ],
    );

    blocTest<FollowListBloc, FollowListState>(
      'emits [FollowListLoading, FollowListFailure] when stream errors',
      build: () {
        when(() => repository.watchFollowing('uid-me'))
            .thenAnswer((_) => Stream.error(Exception('network error')));
        return FollowListBloc(followRepository: repository);
      },
      act: (bloc) =>
          bloc.add(const FollowListWatchFollowingStarted('uid-me')),
      expect: () => [
        const FollowListLoading(),
        isA<FollowListFailure>(),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // State equality
  // -------------------------------------------------------------------------

  group('FollowListLoaded equality', () {
    test('equal when users list is identical', () {
      const a = FollowListLoaded(users: [_userAlice]);
      const b = FollowListLoaded(users: [_userAlice]);
      expect(a, equals(b));
    });

    test('not equal when users list differs', () {
      const a = FollowListLoaded(users: [_userAlice]);
      const b = FollowListLoaded(users: [_userBob]);
      expect(a, isNot(equals(b)));
    });
  });

  group('FollowListFailure equality', () {
    test('equal when error messages match', () {
      const a = FollowListFailure(error: 'oops');
      const b = FollowListFailure(error: 'oops');
      expect(a, equals(b));
    });

    test('not equal when error messages differ', () {
      const a = FollowListFailure(error: 'oops');
      const b = FollowListFailure(error: 'other');
      expect(a, isNot(equals(b)));
    });
  });

  // -------------------------------------------------------------------------
  // Event equality
  // -------------------------------------------------------------------------

  group('FollowListWatchFollowersStarted equality', () {
    test('equal when uid matches', () {
      const a = FollowListWatchFollowersStarted('uid-a');
      const b = FollowListWatchFollowersStarted('uid-a');
      expect(a, equals(b));
    });

    test('not equal when uid differs', () {
      const a = FollowListWatchFollowersStarted('uid-a');
      const b = FollowListWatchFollowersStarted('uid-b');
      expect(a, isNot(equals(b)));
    });
  });

  group('FollowListWatchFollowingStarted equality', () {
    test('equal when uid matches', () {
      const a = FollowListWatchFollowingStarted('uid-a');
      const b = FollowListWatchFollowingStarted('uid-a');
      expect(a, equals(b));
    });

    test('not equal when uid differs', () {
      const a = FollowListWatchFollowingStarted('uid-a');
      const b = FollowListWatchFollowingStarted('uid-b');
      expect(a, isNot(equals(b)));
    });
  });
}
