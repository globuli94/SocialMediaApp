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
// Updated to provide PostRepository after FEAT-004 changed FeedScreen to
// create its own FeedBloc internally via context.read<PostRepository>().
//
// Note: tests that navigate to the Profile tab use pump() instead of
// pumpAndSettle() because ProfileScreen shows a CircularProgressIndicator
// (in ProfileInitial state) whose animation never settles.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';
import 'package:social_network/features/shell/presentation/screens/app_shell_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockPostBloc extends MockBloc<PostEvent, PostState> implements PostBloc {}

class MockPostRepository extends Mock implements PostRepository {}

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockAuthBloc authBloc,
  required MockPostBloc postBloc,
  required MockPostRepository postRepository,
  required MockProfileBloc profileBloc,
}) {
  return RepositoryProvider<PostRepository>.value(
    value: postRepository,
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<PostBloc>.value(value: postBloc),
        BlocProvider<ProfileBloc>.value(value: profileBloc),
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
  late MockPostRepository postRepository;
  late MockProfileBloc profileBloc;

  setUpAll(() {
    registerFallbackValue(const ProfileLoadRequested(uid: ''));
    registerFallbackValue(const PostWatchStarted());
  });

  setUp(() {
    authBloc = MockAuthBloc();
    postBloc = MockPostBloc();
    postRepository = MockPostRepository();
    profileBloc = MockProfileBloc();

    // Default: not authenticated, profile in initial state, posts empty.
    when(() => authBloc.state).thenReturn(const AuthInitial());
    when(() => postBloc.state).thenReturn(PostLoaded(posts: []));
    when(() => profileBloc.state).thenReturn(const ProfileInitial());

    // FeedScreen creates a FeedBloc internally via context.read<PostRepository>().
    // Return an empty page so FeedScreen shows "No posts yet." after loading.
    when(
      () => postRepository.fetchFeedPage(cursor: null, limit: 10),
    ).thenAnswer((_) async => (<PostEntity>[], null));
  });

  group('AppShellScreen', () {
    testWidgets('renders a NavigationBar with Feed and Profile destinations',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          postRepository: postRepository,
          profileBloc: profileBloc,
        ),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      // 'Feed' appears as both AppBar title and NavigationBar label.
      expect(find.text('Feed'), findsWidgets);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('shows FeedScreen by default (no posts → "No posts yet.")',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          postRepository: postRepository,
          profileBloc: profileBloc,
        ),
      );

      // FeedScreen creates a FeedBloc internally; two pumps let the async
      // fetchFeedPage call complete so FeedLoaded(posts: []) is emitted and
      // BlocBuilder rebuilds to show "No posts yet.".
      // We use pump() rather than pumpAndSettle() because the FeedScreen's
      // FloatingActionButton entrance animation may take multiple frames.
      await tester.pump();
      await tester.pump();

      expect(find.text('No posts yet.'), findsOneWidget);
    });

    testWidgets(
        'Feed selected icon (Icons.home) is rendered when Feed tab is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          postRepository: postRepository,
          profileBloc: profileBloc,
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
          postRepository: postRepository,
          profileBloc: profileBloc,
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
          postRepository: postRepository,
          profileBloc: profileBloc,
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
          postRepository: postRepository,
          profileBloc: profileBloc,
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
          postRepository: postRepository,
          profileBloc: profileBloc,
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
          postRepository: postRepository,
          profileBloc: profileBloc,
        ),
      );

      // Two pumps let FeedBloc complete its initial load to FeedLoaded.
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Profile'));
      await tester.pump();

      await tester.tap(find.text('Feed'));
      await tester.pump();

      expect(find.text('No posts yet.'), findsOneWidget);
    });

    testWidgets(
        'IndexedStack keeps both screens mounted — Feed is still in tree after switching to Profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          postRepository: postRepository,
          profileBloc: profileBloc,
        ),
      );

      // Two pumps let Feed load fully to FeedLoaded before navigating away.
      await tester.pump();
      await tester.pump();

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
          postRepository: postRepository,
          profileBloc: profileBloc,
        ),
      );

      final NavigationBar navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);
    });

    testWidgets(
        'NavigationBar selectedIndex updates to 1 after tapping Profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          postRepository: postRepository,
          profileBloc: profileBloc,
        ),
      );

      await tester.tap(find.text('Profile'));
      await tester.pump();

      final NavigationBar navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);
    });
  });
}
