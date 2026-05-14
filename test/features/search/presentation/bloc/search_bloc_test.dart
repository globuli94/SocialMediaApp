// test/features/search/presentation/bloc/search_bloc_test.dart
//
// Unit tests for SearchBloc — covers SearchQueryChanged (debounce),
// SearchCleared, and failure paths to satisfy the >= 90% BLoC coverage
// threshold.
//
// Uses mocktail to mock ProfileRepository — no real Firebase connections.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';
import 'package:social_network/features/profile/domain/repositories/profile_repository.dart';
import 'package:social_network/features/search/presentation/bloc/search_bloc.dart';
import 'package:social_network/features/search/presentation/bloc/search_event.dart';
import 'package:social_network/features/search/presentation/bloc/search_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockProfileRepository extends Mock implements ProfileRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const UserProfileEntity aliceProfile = UserProfileEntity(
  uid: 'uid-alice',
  displayName: 'Alice',
  bio: '',
  avatarUrl: null,
  postCount: 0,
);

const UserProfileEntity bobProfile = UserProfileEntity(
  uid: 'uid-bob',
  displayName: 'Bob',
  bio: 'Hello',
  avatarUrl: null,
  postCount: 2,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockProfileRepository repo;

  setUp(() {
    repo = MockProfileRepository();
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  test('initial state is SearchInitial', () {
    final bloc = SearchBloc(profileRepository: repo);
    expect(bloc.state, const SearchInitial());
    bloc.close();
  });

  // -------------------------------------------------------------------------
  // SearchQueryChanged — empty / whitespace query
  // -------------------------------------------------------------------------

  group('SearchQueryChanged — empty query', () {
    blocTest<SearchBloc, SearchState>(
      'emits [SearchInitial] when query is empty string',
      build: () => SearchBloc(profileRepository: repo),
      act: (bloc) => bloc.add(
        const SearchQueryChanged(query: '', currentUid: 'uid-me'),
      ),
      expect: () => [const SearchInitial()],
    );

    blocTest<SearchBloc, SearchState>(
      'emits [SearchInitial] when query is whitespace-only',
      build: () => SearchBloc(profileRepository: repo),
      act: (bloc) => bloc.add(
        const SearchQueryChanged(query: '   ', currentUid: 'uid-me'),
      ),
      expect: () => [const SearchInitial()],
    );

    blocTest<SearchBloc, SearchState>(
      'emits [SearchInitial] when query cleared after being in SearchLoading',
      build: () => SearchBloc(profileRepository: repo),
      act: (bloc) async {
        // First push a valid query to enter SearchLoading state.
        bloc.add(const SearchQueryChanged(query: 'foo', currentUid: 'uid-me'));
        // Immediately clear with empty query before debounce fires.
        bloc.add(const SearchQueryChanged(query: '', currentUid: 'uid-me'));
      },
      expect: () => [
        const SearchLoading(),
        const SearchInitial(),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // SearchQueryChanged — valid query, success path
  // -------------------------------------------------------------------------

  group('SearchQueryChanged — valid query', () {
    blocTest<SearchBloc, SearchState>(
      'emits [SearchLoading, SearchLoaded] after 300 ms debounce fires',
      build: () {
        when(
          () => repo.searchUsers(
            query: 'alice',
            excludeUid: 'uid-me',
          ),
        ).thenAnswer((_) async => [aliceProfile]);
        return SearchBloc(profileRepository: repo);
      },
      act: (bloc) => bloc.add(
        const SearchQueryChanged(query: 'alice', currentUid: 'uid-me'),
      ),
      wait: const Duration(milliseconds: 400),
      expect: () => [
        const SearchLoading(),
        SearchLoaded(results: [aliceProfile]),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'trims query before passing to repository',
      build: () {
        when(
          () => repo.searchUsers(
            query: 'alice',
            excludeUid: 'uid-me',
          ),
        ).thenAnswer((_) async => [aliceProfile]);
        return SearchBloc(profileRepository: repo);
      },
      act: (bloc) => bloc.add(
        const SearchQueryChanged(query: '  alice  ', currentUid: 'uid-me'),
      ),
      wait: const Duration(milliseconds: 400),
      verify: (_) {
        verify(
          () => repo.searchUsers(query: 'alice', excludeUid: 'uid-me'),
        ).called(1);
      },
      expect: () => [
        const SearchLoading(),
        SearchLoaded(results: [aliceProfile]),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'emits [SearchLoading, SearchLoaded(empty)] when repository returns no results',
      build: () {
        when(
          () => repo.searchUsers(
            query: any(named: 'query'),
            excludeUid: any(named: 'excludeUid'),
          ),
        ).thenAnswer((_) async => <UserProfileEntity>[]);
        return SearchBloc(profileRepository: repo);
      },
      act: (bloc) => bloc.add(
        const SearchQueryChanged(query: 'xyz', currentUid: 'uid-me'),
      ),
      wait: const Duration(milliseconds: 400),
      expect: () => [
        const SearchLoading(),
        const SearchLoaded(results: []),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'emits [SearchLoading, SearchLoaded] with multiple results',
      build: () {
        when(
          () => repo.searchUsers(
            query: any(named: 'query'),
            excludeUid: any(named: 'excludeUid'),
          ),
        ).thenAnswer((_) async => [aliceProfile, bobProfile]);
        return SearchBloc(profileRepository: repo);
      },
      act: (bloc) => bloc.add(
        const SearchQueryChanged(query: 'b', currentUid: 'uid-me'),
      ),
      wait: const Duration(milliseconds: 400),
      expect: () => [
        const SearchLoading(),
        SearchLoaded(results: [aliceProfile, bobProfile]),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // SearchQueryChanged — failure path
  // -------------------------------------------------------------------------

  group('SearchQueryChanged — failure', () {
    blocTest<SearchBloc, SearchState>(
      'emits [SearchLoading, SearchFailure] when repository throws',
      build: () {
        when(
          () => repo.searchUsers(
            query: any(named: 'query'),
            excludeUid: any(named: 'excludeUid'),
          ),
        ).thenThrow(Exception('network error'));
        return SearchBloc(profileRepository: repo);
      },
      act: (bloc) => bloc.add(
        const SearchQueryChanged(query: 'alice', currentUid: 'uid-me'),
      ),
      wait: const Duration(milliseconds: 400),
      expect: () => [
        const SearchLoading(),
        isA<SearchFailure>(),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'SearchFailure contains the exception message',
      build: () {
        when(
          () => repo.searchUsers(
            query: any(named: 'query'),
            excludeUid: any(named: 'excludeUid'),
          ),
        ).thenThrow(Exception('timeout'));
        return SearchBloc(profileRepository: repo);
      },
      act: (bloc) => bloc.add(
        const SearchQueryChanged(query: 'test', currentUid: 'uid-me'),
      ),
      wait: const Duration(milliseconds: 400),
      expect: () => [
        const SearchLoading(),
        isA<SearchFailure>().having(
          (s) => s.error,
          'error',
          contains('timeout'),
        ),
      ],
    );
  });

  // -------------------------------------------------------------------------
  // SearchCleared
  // -------------------------------------------------------------------------

  group('SearchCleared', () {
    blocTest<SearchBloc, SearchState>(
      'cancels debounce and emits [SearchInitial] when cleared during loading',
      build: () => SearchBloc(profileRepository: repo),
      act: (bloc) async {
        bloc.add(const SearchQueryChanged(query: 'foo', currentUid: 'uid-me'));
        bloc.add(const SearchCleared());
      },
      expect: () => [
        const SearchLoading(),
        const SearchInitial(),
      ],
      verify: (_) {
        // Repository must never be called when search is cancelled.
        verifyNever(
          () => repo.searchUsers(
            query: any(named: 'query'),
            excludeUid: any(named: 'excludeUid'),
          ),
        );
      },
    );
  });
}
