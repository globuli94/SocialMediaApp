// lib/features/auth/presentation/bloc/auth_bloc.dart
//
// AuthBloc — manages authentication state and delegates to AuthRepository.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/auth/domain/entities/user_entity.dart';
import 'package:social_network/features/auth/domain/repositories/auth_repository.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';

/// BLoC that manages authentication state for the entire application.
///
/// [AuthStarted] must be added once on app launch. It subscribes to
/// [AuthRepository.authStateChanges] via [emit.forEach], automatically
/// emitting [AuthAuthenticated] or [AuthUnauthenticated] whenever Firebase
/// reports an auth state change.
///
/// Action events ([AuthSignInRequested], [AuthSignUpRequested], etc.) run
/// concurrently and emit [AuthLoading] followed by either success
/// (handled by the stream) or [AuthFailure].
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// Creates an [AuthBloc] with the given [authRepository].
  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthForgotPasswordRequested>(_onForgotPasswordRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final AuthRepository _authRepository;

  /// Subscribes to [AuthRepository.authStateChanges] for the lifetime of
  /// the bloc, emitting [AuthAuthenticated] or [AuthUnauthenticated].
  Future<void> _onAuthStarted(
    AuthStarted event,
    Emitter<AuthState> emit,
  ) async {
    await emit.forEach<UserEntity?>(
      _authRepository.authStateChanges,
      onData: (UserEntity? user) {
        if (user != null) return AuthAuthenticated(user: user);
        return const AuthUnauthenticated();
      },
      onError: (_, __) => const AuthUnauthenticated(),
    );
  }

  /// Emits [AuthLoading], then delegates to the repository.
  ///
  /// On success the auth stream handled by [_onAuthStarted] emits
  /// [AuthAuthenticated]. On failure emits [AuthFailure].
  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.signIn(
        email: event.email,
        password: event.password,
      );
    } catch (e) {
      emit(AuthFailure(error: e.toString()));
    }
  }

  /// Emits [AuthLoading], then delegates to the repository.
  ///
  /// On success the auth stream handled by [_onAuthStarted] emits
  /// [AuthAuthenticated]. On failure emits [AuthFailure].
  Future<void> _onSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.signUp(
        email: event.email,
        password: event.password,
      );
    } catch (e) {
      emit(AuthFailure(error: e.toString()));
    }
  }

  /// Emits [AuthLoading], calls [AuthRepository.sendPasswordResetEmail],
  /// then emits [AuthPasswordResetEmailSent] on success or [AuthFailure].
  Future<void> _onForgotPasswordRequested(
    AuthForgotPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.sendPasswordResetEmail(email: event.email);
      emit(const AuthPasswordResetEmailSent());
    } catch (e) {
      emit(AuthFailure(error: e.toString()));
    }
  }

  /// Signs the current user out; the auth stream emits [AuthUnauthenticated].
  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.signOut();
  }
}
