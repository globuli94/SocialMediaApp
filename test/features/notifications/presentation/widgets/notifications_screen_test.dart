// test/features/notifications/presentation/widgets/notifications_screen_test.dart
//
// Widget tests for NotificationsScreen — verifies back button presence and
// functionality. The back button should pop the route when tapped.

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
import 'package:social_network/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_event.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_state.dart';
import 'package:social_network/features/notifications/presentation/screens/notifications_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockNotificationsBloc
    extends MockBloc<NotificationsEvent, NotificationsState>
    implements NotificationsBloc {}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockAuthBloc authBloc,
  required MockNotificationsBloc notificationsBloc,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('Home')),
          body: const Text('Home Screen'),
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<NotificationsBloc>.value(value: notificationsBloc),
          ],
          child: const NotificationsScreen(),
        ),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthBloc authBloc;
  late MockNotificationsBloc notificationsBloc;

  setUp(() {
    authBloc = MockAuthBloc();
    notificationsBloc = MockNotificationsBloc();

    // Default: authenticated user with empty notifications
    when(() => authBloc.state).thenReturn(
      const AuthAuthenticated(
        user: UserEntity(
          uid: 'test-uid',
          email: 'test@example.com',
          displayName: 'Test User',
        ),
      ),
    );
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());

    // Default: loaded notifications (empty list)
    when(() => notificationsBloc.state)
        .thenReturn(const NotificationsLoaded([]));
    when(() => notificationsBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  group('NotificationsScreen — Back Button', () {
    testWidgets('renders a back button in the AppBar', (tester) async {
      await tester.pumpWidget(_buildSubject(
        authBloc: authBloc,
        notificationsBloc: notificationsBloc,
      ));

      // Navigate to the notifications screen using push (like the bell icon does)
      final context = tester.element(find.text('Home Screen'));
      GoRouter.of(context).push('/notifications');
      await tester.pumpAndSettle();

      // Back button should be present
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('tapping the back button pops the route', (tester) async {
      // Custom GoRouter with two routes
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            name: 'home',
            path: '/',
            builder: (_, __) => Scaffold(
              appBar: AppBar(title: const Text('Home')),
              body: const Text('Home Screen'),
            ),
          ),
          GoRoute(
            name: 'notifications',
            path: '/notifications',
            builder: (context, state) => MultiBlocProvider(
              providers: [
                BlocProvider<AuthBloc>.value(value: authBloc),
                BlocProvider<NotificationsBloc>.value(
                    value: notificationsBloc),
              ],
              child: const NotificationsScreen(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      // Start at home screen
      expect(find.text('Home Screen'), findsOneWidget);

      // Navigate to notifications screen using push (like the bell icon does)
      final homeContext = tester.element(find.text('Home Screen'));
      GoRouter.of(homeContext).push('/notifications');
      await tester.pumpAndSettle();

      // Verify we're on notifications screen
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      // Tap the back button
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Verify the back button popped us off the notifications screen
      // The notifications AppBar should no longer be visible
      expect(find.text('Notifications'), findsNothing);
      // And we should be back at the home screen
      expect(find.text('Home Screen'), findsOneWidget);
    });
  });
}
