// test/features/profile/presentation/widgets/profile_screen_test.dart
//
// Widget tests for ProfileScreen — verifies rendering for each ProfileState
// and read-only / editable mode, without touching real Firebase.

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
import 'package:social_network/features/profile/presentation/screens/profile_screen.dart';

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
  bio: 'I love Flutter',
  avatarUrl: null,
  postCount: 7,
);

const UserProfileEntity otherProfile = UserProfileEntity(
  uid: 'uid-other',
  displayName: 'Bob',
  bio: '',
  avatarUrl: null,
  postCount: 2,
);

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockAuthBloc authBloc,
  required MockProfileBloc profileBloc,
  String? uid,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => ProfileScreen(uid: uid),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const Scaffold(body: Text('Edit Profile')),
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
    registerFallbackValue(const AuthSignOutRequested());
  });

  setUp(() {
    authBloc = MockAuthBloc();
    profileBloc = MockProfileBloc();

    // Default auth state: authenticated as testUser.
    when(() => authBloc.state)
        .thenReturn(const AuthAuthenticated(user: testUser));
  });

  // -------------------------------------------------------------------------
  // Loading state
  // -------------------------------------------------------------------------

  group('ProfileLoading', () {
    testWidgets('shows CircularProgressIndicator', (tester) async {
      when(() => profileBloc.state).thenReturn(const ProfileLoading());

      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // ProfileInitial state
  // -------------------------------------------------------------------------

  group('ProfileInitial', () {
    testWidgets('shows CircularProgressIndicator', (tester) async {
      when(() => profileBloc.state).thenReturn(const ProfileInitial());

      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // ProfileLoaded — own profile
  // -------------------------------------------------------------------------

  group('ProfileLoaded — own profile', () {
    setUp(() {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));
    });

    testWidgets('renders display name and bio', (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('I love Flutter'), findsOneWidget);
    });

    testWidgets('shows Edit button for own profile (uid == null)', (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('shows Edit button when uid matches current user', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          uid: 'uid-me',
        ),
      );

      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('shows post count chip', (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      expect(find.text('7'), findsOneWidget);
      expect(find.text('Posts'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // ProfileLoaded — other user's profile (read-only)
  // -------------------------------------------------------------------------

  group('ProfileLoaded — other user profile (read-only)', () {
    testWidgets('does not show Edit button', (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: otherProfile));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          uid: 'uid-other',
        ),
      );

      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('renders other user display name', (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: otherProfile));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          uid: 'uid-other',
        ),
      );

      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('does not render bio widget when bio is empty', (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: otherProfile));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          uid: 'uid-other',
        ),
      );

      // otherProfile.bio is empty — the bio Text should not appear.
      expect(find.text(''), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // ProfileUpdating state
  // -------------------------------------------------------------------------

  group('ProfileUpdating', () {
    testWidgets('shows profile data and a progress indicator', (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileUpdating(profile: testProfile));

      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // ProfileFailure state
  // -------------------------------------------------------------------------

  group('ProfileFailure', () {
    testWidgets('shows error message and Retry button', (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileFailure(error: 'Something went wrong'));

      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      expect(find.text('Could not load profile.'), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Logout button — own profile
  // -------------------------------------------------------------------------

  group('Logout button', () {
    setUp(() {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: testProfile));
    });

    testWidgets('shows logout IconButton for own profile (uid == null)',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('shows logout IconButton when uid matches current user',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          uid: 'uid-me',
        ),
      );

      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('does not show logout button for another user profile',
        (tester) async {
      when(() => profileBloc.state)
          .thenReturn(const ProfileLoaded(profile: otherProfile));

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          profileBloc: profileBloc,
          uid: 'uid-other',
        ),
      );

      expect(find.byIcon(Icons.logout), findsNothing);
    });

    testWidgets('tapping logout button dispatches AuthSignOutRequested',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(authBloc: authBloc, profileBloc: profileBloc),
      );

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pump();

      verify(() => authBloc.add(const AuthSignOutRequested())).called(1);
    });
  });
}
