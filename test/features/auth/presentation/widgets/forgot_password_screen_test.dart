// test/features/auth/presentation/widgets/forgot_password_screen_test.dart
//
// Widget tests for ForgotPasswordScreen — verifies rendering, form validation,
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
import 'package:social_network/features/auth/presentation/screens/forgot_password_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a subject with the ForgotPasswordScreen at initial location.
/// Navigation from `/` to `/forgot-password` is NOT included here.
/// For tests that trigger `context.pop()` use [_buildSubjectWithHistory].
Widget _buildSubject(MockAuthBloc bloc) {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const ForgotPasswordScreen()),
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
      const AuthForgotPasswordRequested(email: ''),
    );
  });

  setUp(() {
    mockBloc = MockAuthBloc();
    when(() => mockBloc.state).thenReturn(const AuthInitial());
    when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  group('ForgotPasswordScreen', () {
    testWidgets('renders email field and Send Reset Email button',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(
        find.widgetWithText(ElevatedButton, 'Send Reset Email'),
        findsOneWidget,
      );
    });

    testWidgets('shows validation error when submitted with empty email',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Send Reset Email'),
      );
      await tester.pump();

      expect(find.text('Enter your email'), findsOneWidget);
    });

    testWidgets('adds AuthForgotPasswordRequested when valid email submitted',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'user@example.com',
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Send Reset Email'),
      );
      await tester.pump();

      verify(
        () => mockBloc.add(
          const AuthForgotPasswordRequested(email: 'user@example.com'),
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

    testWidgets('renders instruction text', (WidgetTester tester) async {
      // Verifies the instructional body copy is present.
      // The SnackBar+pop flow on AuthPasswordResetEmailSent is covered by
      // auth_bloc_test.dart (state machine) and is intentionally not tested
      // here because ForgotPasswordScreen calls context.pop() in the same
      // frame the SnackBar is queued, making a reliable widget assertion
      // impossible without a full integration-test harness.
      await tester.pumpWidget(_buildSubject(mockBloc));

      expect(
        find.text(
          'Enter your email address and we will send you a link to reset your password.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows SnackBar when state is AuthFailure',
        (WidgetTester tester) async {
      when(() => mockBloc.stream).thenAnswer(
        (_) => Stream.value(const AuthFailure(error: 'User not found.')),
      );

      await tester.pumpWidget(_buildSubject(mockBloc));
      await tester.pump();

      expect(find.text('User not found.'), findsOneWidget);
    });

    testWidgets('renders Forgot Password app bar title',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      expect(find.text('Forgot Password'), findsOneWidget);
    });
  });
}
