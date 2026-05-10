// lib/features/auth/presentation/bloc/auth_event.dart
//
// AuthEvent — sealed hierarchy of events for AuthBloc.

import 'package:equatable/equatable.dart';

/// Base class for all authentication events.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Fired on application start to subscribe to the auth state stream.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// Requests sign-in with [email] and [password].
final class AuthSignInRequested extends AuthEvent {
  const AuthSignInRequested({required this.email, required this.password});

  /// The user's email address.
  final String email;

  /// The user's password.
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// Requests account creation with [email] and [password].
final class AuthSignUpRequested extends AuthEvent {
  const AuthSignUpRequested({required this.email, required this.password});

  /// The user's email address.
  final String email;

  /// The user's chosen password.
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// Requests a password-reset email for [email].
final class AuthForgotPasswordRequested extends AuthEvent {
  const AuthForgotPasswordRequested({required this.email});

  /// The email address to receive the reset link.
  final String email;

  @override
  List<Object?> get props => [email];
}

/// Requests sign-out for the current user.
final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}
