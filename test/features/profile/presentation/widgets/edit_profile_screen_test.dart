// test/features/profile/presentation/widgets/edit_profile_screen_test.dart
//
// Widget tests for EditProfileScreen — covers form rendering, validation,
// save dispatch, updating state, and failure SnackBar listener.
//
// NOTE: Tests for the "not signed in" and null-profile (ProfileLoading /
// ProfileInitial) states are intentionally omitted.  Those paths share a
// bug tracked in BUG-001: dispose() unconditionally calls
// _displayNameController.dispose() even when _initFromProfile() was never
// invoked, causing a LateInitializationError.  Tests for those paths are
// added once BUG-001 is resolved by the Flutter Developer.

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
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';
import 'package:social_network/features/profile/presentation/screens/edit_profile_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const UserEntity testUser = UserEntity(
  uid: 'uid-me',
  email: 'me@example.com',
  displayName: 'Me',
);

const UserProfileEntity testProfile = UserProfileEntity(
  uid: 'uid-me',
  displayName: 'Alice',
  bio: 'Hello world',
  avatarUrl: null,
  postCount: 5,
);

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockAuthBloc authBloc,
  required MockProfileBloc profileBloc,
}) {
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(
        path: '/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const Scaffold(body: Text('Profile')),
      ),
    ],
  );

  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<ProfileBloc>.value(value: profileBloc),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

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
    when(() => authBloc.state)
        .thenReturn(const AuthAuthenticated(user: testUser));
  });

  // -------------------------------------------------------------------------
  // ProfileLoaded — form rendering
  // -------------------------------------------------------------------------

  group('EditProfileScreen — ProfileLoaded', () {
    setUp(() {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));
    });

    testWidgets('renders "Edit Profile" title', (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );
      await tester.pump();

      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('shows Save button in app bar', (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );
      await tester.pump();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows Save changes button in body', (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );
      await tester.pump();

      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('pre-fills display name field from profile', (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );
      await tester.pump();

      // 'Alice' appears as EditableText content inside the first TextFormField.
      expect(find.text('Alice'), findsWidgets);
    });

    testWidgets('pre-fills bio field from profile', (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );
      await tester.pump();

      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('renders two TextFormFields (display name + bio)',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );
      await tester.pump();

      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('shows validation error when display name cleared and Save tapped',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );
      await tester.pump();

      // Clear the first TextFormField (display name).
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Display name is required.'), findsOneWidget);
    });

    testWidgets('dispatches ProfileUpdateRequested when Save tapped with valid data',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );
      await tester.pump();

      // The display name is already pre-filled with 'Alice' — valid.
      await tester.tap(find.text('Save'));
      await tester.pump();

      verify(() => profileBloc.add(any())).called(greaterThan(0));
    });

    testWidgets('dispatches event when Save changes button tapped',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );
      await tester.pump();

      await tester.tap(find.text('Save changes'));
      await tester.pump();

      verify(() => profileBloc.add(any())).called(greaterThan(0));
    });
  });

  // -------------------------------------------------------------------------
  // ProfileUpdating state
  // -------------------------------------------------------------------------

  group('EditProfileScreen — ProfileUpdating', () {
    setUp(() {
      when(() => profileBloc.state)
          .thenReturn(const ProfileUpdating(profile: testProfile));
    });

    testWidgets('shows CircularProgressIndicator while saving', (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('hides Save button from app bar while saving', (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );
      await tester.pump();

      expect(find.text('Save'), findsNothing);
    });

    testWidgets('hides Save changes button while saving', (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );
      await tester.pump();

      expect(find.text('Save changes'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // ProfileFailure listener — SnackBar
  // -------------------------------------------------------------------------

  group('EditProfileScreen — ProfileFailure listener', () {
    testWidgets('shows SnackBar with error text on ProfileFailure', (tester) async {
      // Start loaded (controllers initialised by builder), then fail via stream.
      whenListen(
        profileBloc,
        Stream.fromIterable([
          const ProfileFailure(error: 'Upload failed'),
        ]),
        initialState: const ProfileLoaded(profile: testProfile),
      );

      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );
      await tester.pump(); // First frame: ProfileLoaded — initialises controllers.
      await tester.pump(const Duration(milliseconds: 100)); // Stream delivers failure.

      expect(find.text('Upload failed'), findsOneWidget);
    });
  });
}
