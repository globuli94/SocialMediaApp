// test/features/auth/presentation/widgets/login_screen_test.dart
//
// Widget tests for LoginScreen — verifies rendering, form validation,
// and BLoC event dispatch without touching real Firebase.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/auth/presentation/screens/login_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildSubject(MockAuthBloc bloc) {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const Scaffold(body: Text('Sign Up')),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const Scaffold(body: Text('Forgot Password')),
      ),
    ],
  );

  return BlocProvider<AuthBloc>.value(
    value: bloc,
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthBloc mockBloc;

  setUpAll(() {
    registerFallbackValue(
      const AuthSignInRequested(email: '', password: ''),
    );
  });

  setUp(() {
    mockBloc = MockAuthBloc();
    when(() => mockBloc.state).thenReturn(const AuthInitial());
    when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  group('LoginScreen', () {
    testWidgets('renders email field, password field, and Sign In button',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    });

    testWidgets('shows validation error when submitted with empty fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('adds AuthSignInRequested when valid form is submitted',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'pass123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      verify(
        () => mockBloc.add(
          const AuthSignInRequested(
            email: 'user@example.com',
            password: 'pass123',
          ),
        ),
      ).called(1);
    });

    testWidgets('shows CircularProgressIndicator when state is AuthLoading',
        (WidgetTester tester) async {
      when(() => mockBloc.state).thenReturn(const AuthLoading());
      when(() => mockBloc.stream)
          .thenAnswer((_) => Stream.value(const AuthLoading()));

      await tester.pumpWidget(_buildSubject(mockBloc));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsNothing);
    });

    testWidgets('shows SnackBar when state is AuthFailure',
        (WidgetTester tester) async {
      when(() => mockBloc.stream).thenAnswer(
        (_) => Stream.value(const AuthFailure(error: 'Wrong password.')),
      );

      await tester.pumpWidget(_buildSubject(mockBloc));
      await tester.pump();

      expect(find.text('Wrong password.'), findsOneWidget);
    });

    testWidgets('renders Sign In app bar title', (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      // AppBar title and button both say "Sign In"; target only the AppBar.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Sign In'),
        ),
        findsOneWidget,
      );
    });
  });
}
