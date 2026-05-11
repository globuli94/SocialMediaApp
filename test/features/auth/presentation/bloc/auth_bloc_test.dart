// test/features/auth/presentation/bloc/auth_bloc_test.dart
//
// Unit tests for AuthBloc — covers every event handler with success and
// failure paths to satisfy the ≥ 90% bloc coverage threshold.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/auth/domain/entities/user_entity.dart';
import 'package:social_network/features/auth/domain/repositories/auth_repository.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepository;

  const UserEntity testUser = UserEntity(
    uid: 'uid-abc',
    email: 'test@example.com',
    displayName: 'test',
  );

  setUp(() {
    mockRepository = MockAuthRepository();
  });

  group('AuthBloc', () {
    // ------------------------------------------------------------------ //
    // AuthStarted
    // ------------------------------------------------------------------ //

    group('AuthStarted', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthAuthenticated] when auth stream emits a user',
        setUp: () {
          when(() => mockRepository.authStateChanges)
              .thenAnswer((_) => Stream.value(testUser));
        },
        build: () => AuthBloc(authRepository: mockRepository),
        act: (bloc) => bloc.add(const AuthStarted()),
        expect: () => [
          isA<AuthAuthenticated>()
              .having((s) => s.user.uid, 'uid', 'uid-abc')
              .having((s) => s.user.email, 'email', 'test@example.com'),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthUnauthenticated] when auth stream emits null',
        setUp: () {
          when(() => mockRepository.authStateChanges)
              .thenAnswer((_) => Stream.value(null));
        },
        build: () => AuthBloc(authRepository: mockRepository),
        act: (bloc) => bloc.add(const AuthStarted()),
        expect: () => [const AuthUnauthenticated()],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthUnauthenticated] when auth stream errors',
        setUp: () {
          when(() => mockRepository.authStateChanges).thenAnswer(
            (_) => Stream.error(Exception('stream error')),
          );
        },
        build: () => AuthBloc(authRepository: mockRepository),
        act: (bloc) => bloc.add(const AuthStarted()),
        expect: () => [const AuthUnauthenticated()],
      );
    });

    // ------------------------------------------------------------------ //
    // AuthSignInRequested
    // ------------------------------------------------------------------ //

    group('AuthSignInRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading] on successful sign-in',
        setUp: () {
          when(
            () => mockRepository.signIn(
              email: 'test@example.com',
              password: 'pass123',
            ),
          ).thenAnswer((_) async {});
        },
        build: () => AuthBloc(authRepository: mockRepository),
        act: (bloc) => bloc.add(
          const AuthSignInRequested(
            email: 'test@example.com',
            password: 'pass123',
          ),
        ),
        expect: () => [const AuthLoading()],
        verify: (_) => verify(
          () => mockRepository.signIn(
            email: 'test@example.com',
            password: 'pass123',
          ),
        ).called(1),
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthFailure] when sign-in throws',
        setUp: () {
          when(
            () => mockRepository.signIn(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenThrow('Wrong password.');
        },
        build: () => AuthBloc(authRepository: mockRepository),
        act: (bloc) => bloc.add(
          const AuthSignInRequested(
            email: 'test@example.com',
            password: 'bad',
          ),
        ),
        expect: () => [
          const AuthLoading(),
          const AuthFailure(error: 'Wrong password.'),
        ],
      );
    });

    // ------------------------------------------------------------------ //
    // AuthSignUpRequested
    // ------------------------------------------------------------------ //

    group('AuthSignUpRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading] on successful sign-up',
        setUp: () {
          when(
            () => mockRepository.signUp(
              email: 'new@example.com',
              password: 'pass123',
            ),
          ).thenAnswer((_) async {});
        },
        build: () => AuthBloc(authRepository: mockRepository),
        act: (bloc) => bloc.add(
          const AuthSignUpRequested(
            email: 'new@example.com',
            password: 'pass123',
          ),
        ),
        expect: () => [const AuthLoading()],
        verify: (_) => verify(
          () => mockRepository.signUp(
            email: 'new@example.com',
            password: 'pass123',
          ),
        ).called(1),
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthFailure] when sign-up throws',
        setUp: () {
          when(
            () => mockRepository.signUp(
              email: any(named: 'email'),
              password: any(named: 'password'),
            ),
          ).thenThrow('Email already in use.');
        },
        build: () => AuthBloc(authRepository: mockRepository),
        act: (bloc) => bloc.add(
          const AuthSignUpRequested(
            email: 'taken@example.com',
            password: 'pass123',
          ),
        ),
        expect: () => [
          const AuthLoading(),
          const AuthFailure(error: 'Email already in use.'),
        ],
      );
    });

    // ------------------------------------------------------------------ //
    // AuthForgotPasswordRequested
    // ------------------------------------------------------------------ //

    group('AuthForgotPasswordRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthPasswordResetEmailSent] on success',
        setUp: () {
          when(
            () => mockRepository.sendPasswordResetEmail(
              email: 'test@example.com',
            ),
          ).thenAnswer((_) async {});
        },
        build: () => AuthBloc(authRepository: mockRepository),
        act: (bloc) => bloc.add(
          const AuthForgotPasswordRequested(email: 'test@example.com'),
        ),
        expect: () => [
          const AuthLoading(),
          const AuthPasswordResetEmailSent(),
        ],
        verify: (_) => verify(
          () => mockRepository.sendPasswordResetEmail(
            email: 'test@example.com',
          ),
        ).called(1),
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthFailure] when password reset throws',
        setUp: () {
          when(
            () => mockRepository.sendPasswordResetEmail(
              email: any(named: 'email'),
            ),
          ).thenThrow('User not found.');
        },
        build: () => AuthBloc(authRepository: mockRepository),
        act: (bloc) => bloc.add(
          const AuthForgotPasswordRequested(email: 'missing@example.com'),
        ),
        expect: () => [
          const AuthLoading(),
          const AuthFailure(error: 'User not found.'),
        ],
      );
    });

    // ------------------------------------------------------------------ //
    // AuthSignOutRequested
    // ------------------------------------------------------------------ //

    group('AuthSignOutRequested', () {
      blocTest<AuthBloc, AuthState>(
        'calls signOut and emits nothing (auth stream handles state)',
        setUp: () {
          when(() => mockRepository.signOut()).thenAnswer((_) async {});
        },
        build: () => AuthBloc(authRepository: mockRepository),
        act: (bloc) => bloc.add(const AuthSignOutRequested()),
        expect: () => <AuthState>[],
        verify: (_) => verify(() => mockRepository.signOut()).called(1),
      );

      blocTest<AuthBloc, AuthState>(
        'propagates error when signOut throws',
        setUp: () {
          when(() => mockRepository.signOut())
              .thenThrow(Exception('network error'));
        },
        build: () => AuthBloc(authRepository: mockRepository),
        act: (bloc) => bloc.add(const AuthSignOutRequested()),
        expect: () => <AuthState>[],
        errors: () => [isA<Exception>()],
      );
    });
  });
}
