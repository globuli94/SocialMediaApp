// test/features/auth/presentation/widgets/signup_screen_test.dart
//
// Widget tests for SignUpScreen — verifies rendering, form validation,
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
import 'package:social_network/features/auth/presentation/screens/signup_screen.dart';

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
      GoRoute(path: '/', builder: (_, __) => const SignUpScreen()),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Login')),
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
      const AuthSignUpRequested(email: '', password: ''),
    );
  });

  setUp(() {
    mockBloc = MockAuthBloc();
    when(() => mockBloc.state).thenReturn(const AuthInitial());
    when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  group('SignUpScreen', () {
    testWidgets('renders email field, password field, and Create Account button',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Create Account'),
        findsOneWidget,
      );
    });

    testWidgets('shows validation error when submitted with empty fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );
      await tester.pump();

      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter a password'), findsOneWidget);
    });

    testWidgets('shows validation error when password is too short',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'abc',
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );
      await tester.pump();

      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
    });

    testWidgets('adds AuthSignUpRequested when valid form is submitted',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'pass123',
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Create Account'),
      );
      await tester.pump();

      verify(
        () => mockBloc.add(
          const AuthSignUpRequested(
            email: 'new@example.com',
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
    });

    testWidgets('shows SnackBar when state is AuthFailure',
        (WidgetTester tester) async {
      when(() => mockBloc.stream).thenAnswer(
        (_) => Stream.value(const AuthFailure(error: 'Email already in use.')),
      );

      await tester.pumpWidget(_buildSubject(mockBloc));
      await tester.pump();

      expect(find.text('Email already in use.'), findsOneWidget);
    });

    testWidgets('renders Create Account app bar title',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      // AppBar title and button both say "Create Account"; target only AppBar.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Create Account'),
        ),
        findsOneWidget,
      );
    });
  });
}
