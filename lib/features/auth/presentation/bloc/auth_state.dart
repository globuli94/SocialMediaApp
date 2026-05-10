// lib/features/auth/presentation/bloc/auth_state.dart
//
// AuthState — sealed hierarchy of states for AuthBloc.

import 'package:equatable/equatable.dart';
import 'package:social_network/features/auth/domain/entities/user_entity.dart';

/// Base class for all authentication states.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before the auth stream has been observed.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// An authentication action is in progress.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// The user is authenticated.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.user});

  /// The currently authenticated user.
  final UserEntity user;

  @override
  List<Object?> get props => [user];
}

/// The user is not authenticated.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// An authentication action failed.
final class AuthFailure extends AuthState {
  const AuthFailure({required this.error});

  /// Human-readable error description.
  final String error;

  @override
  List<Object?> get props => [error];
}

/// A password reset email was sent successfully.
final class AuthPasswordResetEmailSent extends AuthState {
  const AuthPasswordResetEmailSent();
}
