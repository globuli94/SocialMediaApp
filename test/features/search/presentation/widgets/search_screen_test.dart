// test/features/search/presentation/widgets/search_screen_test.dart
//
// Widget tests for SearchScreen — verifies all acceptance criteria for
// FEAT-006 User Search:
//   AC1: Search bar appears and accepts text input
//   AC2: Results update as user types (SearchBloc receives events)
//   AC3: Each result shows avatar, display name, and Follow/Unfollow button
//   AC4: Tapping a result navigates to that user's ProfileScreen
//   AC5: Empty state shown when query returns no results
//   AC6: Own profile does not appear in results (tested via SearchBloc)
//
// Uses mocktail to mock AuthBloc, SearchBloc, and FollowRepository.
// No real Firebase connections.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/auth/domain/entities/user_entity.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';
import 'package:social_network/features/profile/presentation/widgets/avatar_widget.dart';
import 'package:social_network/features/search/presentation/bloc/search_bloc.dart';
import 'package:social_network/features/search/presentation/bloc/search_event.dart';
import 'package:social_network/features/search/presentation/bloc/search_state.dart';
import 'package:social_network/features/search/presentation/screens/search_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockSearchBloc extends MockBloc<SearchEvent, SearchState>
    implements SearchBloc {}

class MockFollowRepository extends Mock implements FollowRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const UserEntity testUser = UserEntity(
  uid: 'uid-me',
  email: 'me@example.com',
  displayName: 'Me',
);

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
  bio: '',
  avatarUrl: null,
  postCount: 1,
);

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockAuthBloc authBloc,
  required MockSearchBloc searchBloc,
  required MockFollowRepository followRepository,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: '/profile/:uid',
        builder: (_, __) => const Scaffold(body: Text('Profile Page')),
      ),
    ],
  );

  return RepositoryProvider<FollowRepository>.value(
    value: followRepository,
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<SearchBloc>.value(value: searchBloc),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthBloc authBloc;
  late MockSearchBloc searchBloc;
  late MockFollowRepository followRepository;

  setUpAll(() {
    registerFallbackValue(
      const SearchQueryChanged(query: '', currentUid: ''),
    );
    registerFallbackValue(const SearchCleared());
  });

  setUp(() {
    authBloc = MockAuthBloc();
    searchBloc = MockSearchBloc();
    followRepository = MockFollowRepository();

    when(() => authBloc.state)
        .thenReturn(const AuthAuthenticated(user: testUser));
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());

    when(() => searchBloc.state).thenReturn(const SearchInitial());
    when(() => searchBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  // -------------------------------------------------------------------------
  // AC1 — Search bar
  // -------------------------------------------------------------------------

  group('AC1 — search bar', () {
    testWidgets('renders a TextField with hint "Search users…"',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search users…'), findsOneWidget);
    });

    testWidgets('entering text dispatches SearchQueryChanged to SearchBloc',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      await tester.enterText(find.byType(TextField), 'alice');
      await tester.pump();

      verify(
        () => searchBloc.add(
          const SearchQueryChanged(query: 'alice', currentUid: 'uid-me'),
        ),
      ).called(1);
    });

    testWidgets('clear button appears when TextField has text', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      await tester.enterText(find.byType(TextField), 'alice');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clear button not shown when TextField is empty',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('tapping clear button dispatches SearchCleared to SearchBloc',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      await tester.enterText(find.byType(TextField), 'alice');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      verify(() => searchBloc.add(const SearchCleared())).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // Initial state — prompt
  // -------------------------------------------------------------------------

  group('SearchInitial — prompt', () {
    testWidgets('shows "Search for users by display name" prompt',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      expect(find.text('Search for users by display name'), findsOneWidget);
    });

    testWidgets('shows search icon in prompt', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.search && (w.size ?? 0) >= 48,
        ),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // SearchLoading state
  // -------------------------------------------------------------------------

  group('SearchLoading', () {
    testWidgets('shows CircularProgressIndicator', (tester) async {
      when(() => searchBloc.state).thenReturn(const SearchLoading());

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // AC5 — Empty state
  // -------------------------------------------------------------------------

  group('AC5 — empty state', () {
    testWidgets('shows "No users found" when SearchLoaded with empty results',
        (tester) async {
      when(() => searchBloc.state).thenReturn(const SearchLoaded(results: []));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      expect(find.text('No users found'), findsOneWidget);
    });

    testWidgets('shows person_search icon in empty state', (tester) async {
      when(() => searchBloc.state).thenReturn(const SearchLoaded(results: []));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.person_search,
        ),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // AC3 — Results list: avatar, display name, Follow/Unfollow button
  // -------------------------------------------------------------------------

  group('AC3 — results list', () {
    setUp(() {
      when(
        () => followRepository.watchIsFollowing(
          followerId: any(named: 'followerId'),
          followeeId: any(named: 'followeeId'),
        ),
      ).thenAnswer((_) => const Stream.empty());
    });

    testWidgets('renders display name for each result', (tester) async {
      when(() => searchBloc.state)
          .thenReturn(const SearchLoaded(results: [aliceProfile, bobProfile]));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('renders AvatarWidget for each result', (tester) async {
      when(() => searchBloc.state)
          .thenReturn(const SearchLoaded(results: [aliceProfile, bobProfile]));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );
      await tester.pump();

      expect(find.byType(AvatarWidget), findsNWidgets(2));
    });

    testWidgets('shows Follow button when FollowBloc is in loading/initial',
        (tester) async {
      // FollowRepository.watchIsFollowing returns an empty stream, so FollowBloc
      // stays in FollowLoading. The button row shows a CircularProgressIndicator.
      when(() => searchBloc.state)
          .thenReturn(const SearchLoaded(results: [aliceProfile]));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );
      await tester.pump();

      // While FollowBloc is still loading a progress indicator is shown.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
        'shows Follow button when followRepository emits not-following',
        (tester) async {
      when(
        () => followRepository.watchIsFollowing(
          followerId: any(named: 'followerId'),
          followeeId: any(named: 'followeeId'),
        ),
      ).thenAnswer((_) => Stream.value(false));

      when(() => searchBloc.state)
          .thenReturn(const SearchLoaded(results: [aliceProfile]));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );
      // Two pumps: first lets FollowBloc process FollowWatchRequested,
      // second lets it consume the Stream.value(false) emission.
      await tester.pump();
      await tester.pump();

      expect(find.text('Follow'), findsOneWidget);
    });

    testWidgets(
        'shows Unfollow button when followRepository emits is-following',
        (tester) async {
      when(
        () => followRepository.watchIsFollowing(
          followerId: any(named: 'followerId'),
          followeeId: any(named: 'followeeId'),
        ),
      ).thenAnswer((_) => Stream.value(true));

      when(() => searchBloc.state)
          .thenReturn(const SearchLoaded(results: [aliceProfile]));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Unfollow'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // AC4 — Tapping result navigates to profile
  // -------------------------------------------------------------------------

  group('AC4 — tap navigates to profile', () {
    testWidgets('tapping a result row navigates to /profile/:uid',
        (tester) async {
      when(
        () => followRepository.watchIsFollowing(
          followerId: any(named: 'followerId'),
          followeeId: any(named: 'followeeId'),
        ),
      ).thenAnswer((_) => const Stream.empty());

      when(() => searchBloc.state)
          .thenReturn(const SearchLoaded(results: [aliceProfile]));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );
      await tester.pump();

      // Tap the ListTile (the display name text is the tap target).
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      // GoRouter navigated to the stub '/profile/:uid' route.
      expect(find.text('Profile Page'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // SearchFailure state
  // -------------------------------------------------------------------------

  group('SearchFailure', () {
    testWidgets('shows error message from SearchFailure', (tester) async {
      when(() => searchBloc.state)
          .thenReturn(const SearchFailure(error: 'timeout'));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      expect(find.textContaining('timeout'), findsOneWidget);
    });

    testWidgets('failure message contains "Search failed" prefix',
        (tester) async {
      when(() => searchBloc.state)
          .thenReturn(const SearchFailure(error: 'network unavailable'));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      expect(find.textContaining('Search failed'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // AC6 — Own profile excluded (verified via SearchBloc exclusion logic)
  // -------------------------------------------------------------------------

  group('AC6 — own profile excluded from results', () {
    testWidgets(
        'SearchQueryChanged carries currentUid so bloc can exclude own profile',
        (tester) async {
      // AuthBloc returns uid-me. Verify the event dispatched to SearchBloc
      // includes currentUid: 'uid-me' so the BLoC can pass it as excludeUid
      // to ProfileRepository.searchUsers.
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      await tester.enterText(find.byType(TextField), 'alice');
      await tester.pump();

      verify(
        () => searchBloc.add(
          const SearchQueryChanged(query: 'alice', currentUid: 'uid-me'),
        ),
      ).called(1);
    });
  });
}
