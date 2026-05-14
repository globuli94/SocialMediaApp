// test/features/shell/presentation/widgets/app_shell_screen_test.dart
//
// Widget tests for AppShellScreen — verifies bottom navigation, tab switching,
// IndexedStack state preservation, and icon correctness.
//
// Updated to provide AuthBloc and ProfileBloc after FEAT-002 replaced the
// Profile tab placeholder with the real ProfileScreen.
//
// Updated to provide PostBloc after FEAT-003 replaced the Feed tab placeholder
// with the real FeedScreen (which uses BlocBuilder<PostBloc, PostState>).
//
// Updated to provide SearchBloc and FollowRepository after FEAT-006 added the
// Search tab (SearchScreen requires both in the widget tree even when offstage).
//
// Note: tests that navigate to the Profile tab use pump() instead of
// pumpAndSettle() because ProfileScreen shows a CircularProgressIndicator
// (in ProfileInitial state) whose animation never settles.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/auth/domain/entities/user_entity.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';
import 'package:social_network/features/search/presentation/bloc/search_bloc.dart';
import 'package:social_network/features/search/presentation/bloc/search_event.dart';
import 'package:social_network/features/search/presentation/bloc/search_state.dart';
import 'package:social_network/features/shell/presentation/screens/app_shell_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockPostBloc extends MockBloc<PostEvent, PostState> implements PostBloc {}

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

class MockSearchBloc extends MockBloc<SearchEvent, SearchState>
    implements SearchBloc {}

class MockFollowRepository extends Mock implements FollowRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockAuthBloc authBloc,
  required MockPostBloc postBloc,
  required MockProfileBloc profileBloc,
  required MockSearchBloc searchBloc,
  required MockFollowRepository followRepository,
}) {
  return RepositoryProvider<FollowRepository>.value(
    value: followRepository,
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<PostBloc>.value(value: postBloc),
        BlocProvider<ProfileBloc>.value(value: profileBloc),
        BlocProvider<SearchBloc>.value(value: searchBloc),
      ],
      child: const MaterialApp(
        home: AppShellScreen(),
      ),
    ),
  );
}

// Find an icon anywhere in the tree, including Offstage children.
Finder _findIcon(IconData icon) => find.byWidgetPredicate(
      (widget) => widget is Icon && widget.icon == icon,
      skipOffstage: false,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthBloc authBloc;
  late MockPostBloc postBloc;
  late MockProfileBloc profileBloc;
  late MockSearchBloc searchBloc;
  late MockFollowRepository followRepository;

  setUpAll(() {
    registerFallbackValue(const ProfileLoadRequested(uid: ''));
    registerFallbackValue(const ProfileWatchRequested(uid: ''));
    registerFallbackValue(const PostWatchStarted());
    registerFallbackValue(
      const SearchQueryChanged(query: '', currentUid: ''),
    );
    registerFallbackValue(const SearchCleared());
  });

  setUp(() {
    authBloc = MockAuthBloc();
    postBloc = MockPostBloc();
    profileBloc = MockProfileBloc();
    searchBloc = MockSearchBloc();
    followRepository = MockFollowRepository();

    // Default: not authenticated, feed with no posts, profile in initial state.
    when(() => authBloc.state).thenReturn(const AuthInitial());
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => postBloc.state).thenReturn(const PostLoaded(posts: []));
    when(() => postBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => profileBloc.state).thenReturn(const ProfileInitial());
    when(() => profileBloc.stream).thenAnswer((_) => const Stream.empty());
    // Default search: initial state (shows prompt, no FollowRepository needed).
    when(() => searchBloc.state).thenReturn(const SearchInitial());
    when(() => searchBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  group('AppShellScreen', () {
    testWidgets(
        'renders a NavigationBar with Feed, Search, and Profile destinations',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      // 'Feed' appears as both AppBar title and NavigationBar label.
      expect(find.text('Feed'), findsWidgets);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('shows FeedScreen by default (no posts → "No posts yet.")',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      expect(find.text('No posts yet.'), findsOneWidget);
    });

    testWidgets(
        'Feed selected icon (Icons.home) is rendered when Feed tab is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      // NavigationBar renders only the selected icon for each active destination.
      expect(_findIcon(Icons.home), findsOneWidget);
    });

    testWidgets(
        'Profile unselected icon (Icons.person_outline) is rendered when Feed tab is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      expect(_findIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets(
        'Profile selected icon (Icons.person) is rendered after tapping Profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      await tester.tap(find.text('Profile'));
      // Use pump() instead of pumpAndSettle() — ProfileScreen shows a
      // CircularProgressIndicator whose animation never settles.
      await tester.pump();

      expect(_findIcon(Icons.person), findsOneWidget);
    });

    testWidgets(
        'Feed unselected icon (Icons.home_outlined) is rendered after tapping Profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      await tester.tap(find.text('Profile'));
      await tester.pump();

      expect(_findIcon(Icons.home_outlined), findsOneWidget);
    });

    testWidgets('tapping Profile tab shows Profile screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      await tester.tap(find.text('Profile'));
      await tester.pump();

      // ProfileScreen shows a loading spinner when no UID is resolved
      // (AuthInitial → no UID → ProfileInitial → CircularProgressIndicator).
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('tapping Feed tab after Profile returns to Feed screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      await tester.tap(find.text('Profile'));
      await tester.pump();

      await tester.tap(find.text('Feed'));
      // Use pump() — the ProfileScreen is still offstage in the IndexedStack
      // and its CircularProgressIndicator animation prevents pumpAndSettle from settling.
      await tester.pump();

      expect(find.text('No posts yet.'), findsOneWidget);
    });

    testWidgets(
        'IndexedStack keeps all screens mounted — Feed is still in tree after switching to Profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      // Navigate to Profile so Feed is offstage.
      await tester.tap(find.text('Profile'));
      await tester.pump();

      // IndexedStack keeps non-visible children as Offstage (not destroyed).
      // Use skipOffstage: false to verify Feed is still in the tree.
      expect(
        find.text('No posts yet.', skipOffstage: false),
        findsOneWidget,
      );
      // Profile tab is active — CircularProgressIndicator from ProfileScreen.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('NavigationBar selectedIndex starts at 0 (Feed)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      final NavigationBar navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);
    });

    testWidgets(
        'NavigationBar selectedIndex updates to 2 after tapping Profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      await tester.tap(find.text('Profile'));
      await tester.pump();

      final NavigationBar navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      // Profile is now index 2 (Feed=0, Search=1, Profile=2).
      expect(navBar.selectedIndex, 2);
    });

    testWidgets('tapping Search tab shows SearchScreen prompt',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      await tester.tap(find.text('Search'));
      await tester.pump();

      expect(find.text('Search for users by display name'), findsOneWidget);
    });

    testWidgets(
        'NavigationBar selectedIndex updates to 1 after tapping Search',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
          searchBloc: searchBloc,
          followRepository: followRepository,
        ),
      );

      await tester.tap(find.text('Search'));
      await tester.pump();

      final NavigationBar navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);
    });

    // -------------------------------------------------------------------------
    // BUG-006 fix — Profile tab re-watches signed-in user's own profile
    // -------------------------------------------------------------------------
    //
    // Root cause: The global ProfileBloc watch was overwritten when viewing
    // another user's profile. Fix: _onDestinationSelected dispatches
    // ProfileWatchRequested(uid: currentUser.uid) every time the Profile tab
    // (index 2) is activated.

    group('BUG-006 fix — Profile tab re-watches own profile', () {
      const testUid = 'test-user-uid-123';
      const testUser = UserEntity(
        uid: testUid,
        email: 'test@example.com',
        displayName: 'Test User',
      );

      testWidgets(
          'tapping Profile tab when authenticated dispatches '
          'ProfileWatchRequested(uid: currentUser.uid)',
          (WidgetTester tester) async {
        when(() => authBloc.state).thenReturn(
          const AuthAuthenticated(user: testUser),
        );

        await tester.pumpWidget(
          _buildSubject(
            authBloc: authBloc,
            postBloc: postBloc,
            profileBloc: profileBloc,
            searchBloc: searchBloc,
            followRepository: followRepository,
          ),
        );

        // Clear interactions recorded during the initial build (ProfileScreen
        // dispatches ProfileWatchRequested in didChangeDependencies on first
        // render). We only want to count dispatches from _onDestinationSelected.
        clearInteractions(profileBloc);

        await tester.tap(find.text('Profile'));
        await tester.pump();

        verify(
          () => profileBloc.add(const ProfileWatchRequested(uid: testUid)),
        ).called(1);
      });

      testWidgets(
          'tapping Profile tab when not authenticated does NOT dispatch '
          'ProfileWatchRequested',
          (WidgetTester tester) async {
        when(() => authBloc.state).thenReturn(const AuthUnauthenticated());

        await tester.pumpWidget(
          _buildSubject(
            authBloc: authBloc,
            postBloc: postBloc,
            profileBloc: profileBloc,
            searchBloc: searchBloc,
            followRepository: followRepository,
          ),
        );

        // ProfileScreen.didChangeDependencies does not dispatch when auth state
        // is AuthUnauthenticated (no uid resolved), so no clearInteractions
        // needed.
        await tester.tap(find.text('Profile'));
        await tester.pump();

        verifyNever(
          () => profileBloc.add(any(that: isA<ProfileWatchRequested>())),
        );
      });

      testWidgets(
          'switching away and back to Profile tab dispatches '
          'ProfileWatchRequested again on each activation',
          (WidgetTester tester) async {
        when(() => authBloc.state).thenReturn(
          const AuthAuthenticated(user: testUser),
        );

        await tester.pumpWidget(
          _buildSubject(
            authBloc: authBloc,
            postBloc: postBloc,
            profileBloc: profileBloc,
            searchBloc: searchBloc,
            followRepository: followRepository,
          ),
        );

        // Clear initial-build dispatches from ProfileScreen.didChangeDependencies.
        clearInteractions(profileBloc);

        // First Profile tab activation via _onDestinationSelected.
        await tester.tap(find.text('Profile'));
        await tester.pump();

        // Switch away to Feed (Feed AppBar is now offstage → find.text('Feed')
        // is unambiguous, matching only the NavigationBar label).
        await tester.tap(find.text('Feed'));
        await tester.pump();

        // Second Profile tab activation — _onDestinationSelected dispatches again.
        await tester.tap(find.text('Profile'));
        await tester.pump();

        // Exactly 2 dispatches: one per Profile tab activation.
        verify(
          () => profileBloc.add(const ProfileWatchRequested(uid: testUid)),
        ).called(2);
      });

      testWidgets(
          'tapping Feed tab from Profile does NOT dispatch additional '
          'ProfileWatchRequested',
          (WidgetTester tester) async {
        when(() => authBloc.state).thenReturn(
          const AuthAuthenticated(user: testUser),
        );

        await tester.pumpWidget(
          _buildSubject(
            authBloc: authBloc,
            postBloc: postBloc,
            profileBloc: profileBloc,
            searchBloc: searchBloc,
            followRepository: followRepository,
          ),
        );

        // Navigate to Profile tab first so:
        //   (a) _onDestinationSelected dispatches ProfileWatchRequested, and
        //   (b) the FeedScreen AppBar goes offstage — making find.text('Feed')
        //       unambiguous (only the NavigationBar label is onstage).
        await tester.tap(find.text('Profile'));
        await tester.pump();

        // Clear all recorded interactions so that the verifyNever below only
        // checks interactions that happen AFTER this point.
        clearInteractions(profileBloc);

        // Tap Feed — _onDestinationSelected(0) should NOT dispatch because
        // index 0 is not the profile tab index.
        await tester.tap(find.text('Feed'));
        await tester.pump();

        verifyNever(
          () => profileBloc.add(any(that: isA<ProfileWatchRequested>())),
        );
      });

      testWidgets(
          'tapping Search tab from Profile does NOT dispatch additional '
          'ProfileWatchRequested',
          (WidgetTester tester) async {
        when(() => authBloc.state).thenReturn(
          const AuthAuthenticated(user: testUser),
        );

        await tester.pumpWidget(
          _buildSubject(
            authBloc: authBloc,
            postBloc: postBloc,
            profileBloc: profileBloc,
            searchBloc: searchBloc,
            followRepository: followRepository,
          ),
        );

        // Navigate to Profile tab first so _onDestinationSelected has fired.
        await tester.tap(find.text('Profile'));
        await tester.pump();

        // Clear all recorded interactions so that the verifyNever below only
        // checks interactions that happen AFTER this point.
        clearInteractions(profileBloc);

        // Tap Search — _onDestinationSelected(1) should NOT dispatch because
        // index 1 is not the profile tab index.
        await tester.tap(find.text('Search'));
        await tester.pump();

        verifyNever(
          () => profileBloc.add(any(that: isA<ProfileWatchRequested>())),
        );
      });
    });
  });
}
