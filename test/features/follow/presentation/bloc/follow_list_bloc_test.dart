// test/features/follow/presentation/bloc/follow_list_bloc_test.dart
//
// Unit tests for FollowListBloc — covers FollowListLoadRequested for both
// followers and following to satisfy the >= 90% BLoC coverage threshold.
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

const _alice = UserProfileEntity(
  uid: 'uid-alice',
  displayName: 'Alice',
  bio: 'Alice bio',
  postCount: 3,
);

const _bob = UserProfileEntity(
  uid: 'uid-bob',
  displayName: 'Bob',
  bio: '',
  postCount: 1,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockFollowRepository repository;

  setUp(() {
    repository = MockFollowRepository();
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  test('initial state is FollowListInitial', () {
    final bloc = FollowListBloc(followRepository: repository);
    expect(bloc.state, const FollowListInitial());
    bloc.close();
  });

  // -------------------------------------------------------------------------
  // FollowListLoadRequested — followers
  // -------------------------------------------------------------------------

  group('FollowListLoadRequested — followers', () {
    blocTest<FollowListBloc, FollowListState>(
      'emits [FollowListLoading, FollowListLoaded] when getFollowers returns a list',
      build: () {
        when(() => repository.getFollowers('uid-target'))
            .thenAnswer((_) async => [_alice, _bob]);
        return FollowListBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(const FollowListLoadRequested(
        uid: 'uid-target',
        type: FollowListType.followers,
      )),
      expect: () => [
        const FollowListLoading(),
        isA<FollowListLoaded>()
            .having((s) => s.users.length, 'users.length', 2)
            .having(
              (s) => s.users.first.displayName,
              'first.displayName',
              'Alice',
            ),
      ],
      verify: (_) =>
          verify(() => repository.getFollowers('uid-target')).called(1),
    );

    blocTest<FollowListBloc, FollowListState>(
      'emits [FollowListLoading, FollowListLoaded(empty)] when getFollowers returns empty',
      build: () {
        when(() => repository.getFollowers('uid-target'))
            .thenAnswer((_) async => []);
        return FollowListBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(const FollowListLoadRequested(
        uid: 'uid-target',
        type: FollowListType.followers,
      )),
      expect: () => [
        const FollowListLoading(),
        isA<FollowListLoaded>().having((s) => s.users, 'users', isEmpty),
      ],
    );

    blocTest<FollowListBloc, FollowListState>(
      'emits [FollowListLoading, FollowListFailure] when getFollowers throws',
      build: () {
        when(() => repository.getFollowers('uid-target'))
            .thenThrow(Exception('network error'));
        return FollowListBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(const FollowListLoadRequested(
        uid: 'uid-target',
        type: FollowListType.followers,
      )),
      expect: () => [
        const FollowListLoading(),
        isA<FollowListFailure>().having(
          (s) => s.error,
          'error',
          contains('network error'),
        ),
      ],
    );

    blocTest<FollowListBloc, FollowListState>(
      'calls getFollowers and never getFollowing when type is followers',
      build: () {
        when(() => repository.getFollowers('uid-target'))
            .thenAnswer((_) async => [_alice]);
        return FollowListBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(const FollowListLoadRequested(
        uid: 'uid-target',
        type: FollowListType.followers,
      )),
      verify: (_) {
        verify(() => repository.getFollowers('uid-target')).called(1);
        verifyNever(() => repository.getFollowing(any()));
      },
    );
  });

  // -------------------------------------------------------------------------
  // FollowListLoadRequested — following
  // -------------------------------------------------------------------------

  group('FollowListLoadRequested — following', () {
    blocTest<FollowListBloc, FollowListState>(
      'emits [FollowListLoading, FollowListLoaded] when getFollowing returns a list',
      build: () {
        when(() => repository.getFollowing('uid-target'))
            .thenAnswer((_) async => [_bob]);
        return FollowListBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(const FollowListLoadRequested(
        uid: 'uid-target',
        type: FollowListType.following,
      )),
      expect: () => [
        const FollowListLoading(),
        isA<FollowListLoaded>()
            .having((s) => s.users.length, 'users.length', 1)
            .having(
              (s) => s.users.first.displayName,
              'first.displayName',
              'Bob',
            ),
      ],
      verify: (_) =>
          verify(() => repository.getFollowing('uid-target')).called(1),
    );

    blocTest<FollowListBloc, FollowListState>(
      'emits [FollowListLoading, FollowListLoaded(empty)] when getFollowing returns empty',
      build: () {
        when(() => repository.getFollowing('uid-target'))
            .thenAnswer((_) async => []);
        return FollowListBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(const FollowListLoadRequested(
        uid: 'uid-target',
        type: FollowListType.following,
      )),
      expect: () => [
        const FollowListLoading(),
        isA<FollowListLoaded>().having((s) => s.users, 'users', isEmpty),
      ],
    );

    blocTest<FollowListBloc, FollowListState>(
      'emits [FollowListLoading, FollowListFailure] when getFollowing throws',
      build: () {
        when(() => repository.getFollowing('uid-target'))
            .thenThrow(Exception('server error'));
        return FollowListBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(const FollowListLoadRequested(
        uid: 'uid-target',
        type: FollowListType.following,
      )),
      expect: () => [
        const FollowListLoading(),
        isA<FollowListFailure>().having(
          (s) => s.error,
          'error',
          contains('server error'),
        ),
      ],
    );

    blocTest<FollowListBloc, FollowListState>(
      'calls getFollowing and never getFollowers when type is following',
      build: () {
        when(() => repository.getFollowing('uid-target'))
            .thenAnswer((_) async => [_bob]);
        return FollowListBloc(followRepository: repository);
      },
      act: (bloc) => bloc.add(const FollowListLoadRequested(
        uid: 'uid-target',
        type: FollowListType.following,
      )),
      verify: (_) {
        verify(() => repository.getFollowing('uid-target')).called(1);
        verifyNever(() => repository.getFollowers(any()));
      },
    );
  });

  // -------------------------------------------------------------------------
  // State equality
  // -------------------------------------------------------------------------

  group('FollowListState equality', () {
    test('FollowListInitial supports value equality', () {
      expect(const FollowListInitial(), equals(const FollowListInitial()));
    });

    test('FollowListLoading supports value equality', () {
      expect(const FollowListLoading(), equals(const FollowListLoading()));
    });

    test('FollowListLoaded props contains users list', () {
      final state = FollowListLoaded(users: [_alice]);
      expect(state.props, equals([[_alice]]));
    });

    test('FollowListLoaded supports value equality when users are the same', () {
      final a = FollowListLoaded(users: [_alice]);
      final b = FollowListLoaded(users: [_alice]);
      expect(a, equals(b));
    });

    test('FollowListFailure props contains error string', () {
      const state = FollowListFailure(error: 'oops');
      expect(state.props, equals(['oops']));
    });

    test('FollowListFailure supports value equality', () {
      const a = FollowListFailure(error: 'oops');
      const b = FollowListFailure(error: 'oops');
      expect(a, equals(b));
    });
  });

  // -------------------------------------------------------------------------
  // Event props
  // -------------------------------------------------------------------------

  group('FollowListEvent props', () {
    test('FollowListLoadRequested props contains uid and type', () {
      const event = FollowListLoadRequested(
        uid: 'uid-1',
        type: FollowListType.followers,
      );
      expect(event.props, equals(['uid-1', FollowListType.followers]));
    });

    test('FollowListLoadRequested supports value equality', () {
      const a = FollowListLoadRequested(
        uid: 'uid-1',
        type: FollowListType.followers,
      );
      const b = FollowListLoadRequested(
        uid: 'uid-1',
        type: FollowListType.followers,
      );
      expect(a, equals(b));
    });
  });
}
