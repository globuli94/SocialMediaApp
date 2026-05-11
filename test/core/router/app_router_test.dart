// test/core/router/app_router_test.dart
//
// Tests for createRouter — verifies auth redirect guard, GoRouterRefreshStream,
// and route-level rendering of AppShellScreen at /home.
//
// Updated to provide ProfileBloc after FEAT-002 replaced the Profile tab
// placeholder with the real ProfileScreen (which requires ProfileBloc).
//
// Tests that navigate to /home use pump() instead of pumpAndSettle() because
// ProfileScreen shows a CircularProgressIndicator whose animation never settles.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/core/router/app_router.dart';
import 'package:social_network/features/auth/domain/entities/user_entity.dart';
import 'package:social_network/features/auth/domain/repositories/auth_repository.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/auth/presentation/screens/login_screen.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';
import 'package:social_network/features/shell/presentation/screens/app_shell_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const UserEntity _testUser = UserEntity(
  uid: 'uid-abc',
  email: 'test@example.com',
  displayName: 'test',
);

Widget _buildApp(
  MockAuthRepository mockRepo,
  MockAuthBloc authBloc,
  MockProfileBloc profileBloc,
) {
  final router = createRouter(authRepository: mockRepo);
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
  late MockAuthRepository mockRepo;
  late MockAuthBloc mockBloc;
  late MockProfileBloc profileBloc;

  setUpAll(() {
    registerFallbackValue(const ProfileLoadRequested(uid: ''));
  });

  setUp(() {
    mockRepo = MockAuthRepository();
    mockBloc = MockAuthBloc();
    profileBloc = MockProfileBloc();
    when(() => mockBloc.state).thenReturn(const AuthInitial());
    when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => profileBloc.state).thenReturn(const ProfileInitial());
    when(() => profileBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  group('GoRouterRefreshStream', () {
    test('calls notifyListeners when stream emits', () async {
      final controller = StreamController<void>();
      final refreshStream = GoRouterRefreshStream(controller.stream);

      int notifyCount = 0;
      refreshStream.addListener(() => notifyCount++);

      controller.add(null);
      // Stream events are delivered asynchronously; yield to the event loop.
      await Future<void>.delayed(Duration.zero);
      expect(notifyCount, 1);

      controller.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(notifyCount, 2);

      refreshStream.dispose();
      await controller.close();
    });

    test('dispose cancels stream subscription', () async {
      final controller = StreamController<void>();
      final refreshStream = GoRouterRefreshStream(controller.stream);

      int notifyCount = 0;
      refreshStream.addListener(() => notifyCount++);

      refreshStream.dispose();

      // Emitting after dispose should not call listeners.
      controller.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(notifyCount, 0);

      await controller.close();
    });
  });

  group('createRouter — auth redirect', () {
    testWidgets('unauthenticated user on initial load lands on LoginScreen',
        (WidgetTester tester) async {
      when(() => mockRepo.currentUser).thenReturn(null);
      when(() => mockRepo.authStateChanges)
          .thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(_buildApp(mockRepo, mockBloc, profileBloc));
      await tester.pumpAndSettle(); // LoginScreen has no ongoing animations.

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets(
        'unauthenticated user navigating to /home is redirected to /login',
        (WidgetTester tester) async {
      when(() => mockRepo.currentUser).thenReturn(null);
      when(() => mockRepo.authStateChanges)
          .thenAnswer((_) => const Stream.empty());

      final router = createRouter(authRepository: mockRepo);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: mockBloc),
            BlocProvider<ProfileBloc>.value(value: profileBloc),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/home');
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppShellScreen), findsNothing);
    });

    testWidgets(
        'authenticated user navigating to /login is redirected to /home',
        (WidgetTester tester) async {
      when(() => mockRepo.currentUser).thenReturn(_testUser);
      when(() => mockRepo.authStateChanges)
          .thenAnswer((_) => const Stream.empty());

      final router = createRouter(authRepository: mockRepo);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: mockBloc),
            BlocProvider<ProfileBloc>.value(value: profileBloc),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      // pump() is sufficient to process the redirect — pumpAndSettle() would
      // time out because ProfileScreen shows a non-settling CircularProgressIndicator.
      await tester.pump();

      // The router redirects /login → /home when authenticated.
      expect(find.byType(AppShellScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('auth state change triggers redirect via GoRouterRefreshStream',
        (WidgetTester tester) async {
      final authController = StreamController<UserEntity?>();

      when(() => mockRepo.currentUser).thenReturn(null);
      when(() => mockRepo.authStateChanges)
          .thenAnswer((_) => authController.stream);

      final router = createRouter(authRepository: mockRepo);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: mockBloc),
            BlocProvider<ProfileBloc>.value(value: profileBloc),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      // pump() instead of pumpAndSettle(): the open StreamController keeps
      // GoRouterRefreshStream alive, so pumpAndSettle() never resolves.
      await tester.pump();

      // Initially unauthenticated → LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);

      // Simulate sign-in: update currentUser and emit on auth stream
      when(() => mockRepo.currentUser).thenReturn(_testUser);
      // runAsync escapes fakeAsync so the real event loop can deliver the stream
      // event to GoRouterRefreshStream before we pump the widget tree.
      await tester.runAsync(() async {
        authController.add(_testUser);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      await tester.pump();

      // Router should redirect to /home
      expect(find.byType(AppShellScreen), findsOneWidget);

      authController.close();
    });
  });
}
