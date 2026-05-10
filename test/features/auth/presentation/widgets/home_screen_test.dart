// test/features/auth/presentation/widgets/home_screen_test.dart
//
// Widget tests for HomeScreen — verifies rendering and sign-out event dispatch.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/auth/presentation/screens/home_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildSubject(MockAuthBloc bloc) {
  return BlocProvider<AuthBloc>.value(
    value: bloc,
    child: const MaterialApp(home: HomeScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthBloc mockBloc;

  setUpAll(() {
    registerFallbackValue(const AuthSignOutRequested());
  });

  setUp(() {
    mockBloc = MockAuthBloc();
    when(() => mockBloc.state).thenReturn(const AuthInitial());
    when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  group('HomeScreen', () {
    testWidgets('renders Home app bar title', (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('renders welcome body text', (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      expect(find.text('Welcome to Social Network!'), findsOneWidget);
    });

    testWidgets('renders logout icon button in app bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('adds AuthSignOutRequested when logout button tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSubject(mockBloc));

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pump();

      verify(() => mockBloc.add(const AuthSignOutRequested())).called(1);
    });
  });
}
