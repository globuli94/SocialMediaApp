// test/features/shell/presentation/widgets/app_shell_screen_test.dart
//
// Widget tests for AppShellScreen — verifies bottom navigation, tab switching,
// IndexedStack state preservation, and icon correctness.
//
// Updated to provide AuthBloc and ProfileBloc after FEAT-002 replaced the
// Profile tab placeholder with the real ProfileScreen.
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
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';
import 'package:social_network/features/shell/presentation/screens/app_shell_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockAuthBloc authBloc,
  required MockProfileBloc profileBloc,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<ProfileBloc>.value(value: profileBloc),
    ],
    child: const MaterialApp(
      home: AppShellScreen(),
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
  late MockProfileBloc profileBloc;

  setUpAll(() {
    registerFallbackValue(const ProfileLoadRequested(uid: ''));
  });

  setUp(() {
    authBloc = MockAuthBloc();
    profileBloc = MockProfileBloc();

    // Default: not authenticated, profile in initial state.
    when(() => authBloc.state).thenReturn(const AuthInitial());
    when(() => profileBloc.state).thenReturn(const ProfileInitial());
  });

  group('AppShellScreen', () {
    testWidgets('renders a NavigationBar with Feed and Profile destinations',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('shows Feed screen by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      expect(find.text('Feed — coming soon'), findsOneWidget);
    });

    testWidgets(
        'Feed selected icon (Icons.home) is rendered when Feed tab is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      // NavigationBar renders only the selected icon for each active destination.
      expect(_findIcon(Icons.home), findsOneWidget);
    });

    testWidgets(
        'Profile unselected icon (Icons.person_outline) is rendered when Feed tab is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      expect(_findIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets(
        'Profile selected icon (Icons.person) is rendered after tapping Profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
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
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      await tester.tap(find.text('Profile'));
      await tester.pump();

      expect(_findIcon(Icons.home_outlined), findsOneWidget);
    });

    testWidgets('tapping Profile tab shows Profile screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
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
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      await tester.tap(find.text('Profile'));
      await tester.pump();

      await tester.tap(find.text('Feed'));
      // Use pump() — the ProfileScreen is still offstage in the IndexedStack
      // and its CircularProgressIndicator animation prevents pumpAndSettle from settling.
      await tester.pump();

      expect(find.text('Feed — coming soon'), findsOneWidget);
    });

    testWidgets(
        'IndexedStack keeps both screens mounted — Feed is still in tree after switching to Profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      // Navigate to Profile so Feed is offstage.
      await tester.tap(find.text('Profile'));
      await tester.pump();

      // IndexedStack keeps non-visible children as Offstage (not destroyed).
      // Use skipOffstage: false to verify Feed is still in the tree.
      expect(
        find.text('Feed — coming soon', skipOffstage: false),
        findsOneWidget,
      );
      // Profile tab is active — CircularProgressIndicator from ProfileScreen.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('NavigationBar selectedIndex starts at 0 (Feed)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      final NavigationBar navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);
    });

    testWidgets(
        'NavigationBar selectedIndex updates to 1 after tapping Profile',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      await tester.tap(find.text('Profile'));
      await tester.pump();

      final NavigationBar navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);
    });
  });
}
