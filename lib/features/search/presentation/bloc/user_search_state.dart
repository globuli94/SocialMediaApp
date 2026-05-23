// lib/features/search/presentation/bloc/user_search_state.dart
//
// UserSearchState — sealed state hierarchy for UserSearchBloc.

import 'package:equatable/equatable.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';

/// Base class for all user search states.
sealed class UserSearchState extends Equatable {
  const UserSearchState();

  @override
  List<Object?> get props => [];
}

/// Initial state — no query entered yet. Shows a prompt to the user.
final class UserSearchInitial extends UserSearchState {
  /// Creates a [UserSearchInitial].
  const UserSearchInitial();
}

/// A search is in progress (awaiting Firestore response).
final class UserSearchLoading extends UserSearchState {
  /// Creates a [UserSearchLoading].
  const UserSearchLoading();
}

/// Search completed with at least one result.
final class UserSearchLoaded extends UserSearchState {
  /// Creates a [UserSearchLoaded].
  const UserSearchLoaded({required this.results});

  /// Ordered list of matching user profiles (current user excluded).
  final List<UserProfileEntity> results;

  @override
  List<Object?> get props => [results];
}

/// Search completed but returned no results.
final class UserSearchEmpty extends UserSearchState {
  /// Creates a [UserSearchEmpty].
  const UserSearchEmpty();
}

/// Search failed with an error.
final class UserSearchFailure extends UserSearchState {
  /// Creates a [UserSearchFailure].
  const UserSearchFailure({required this.error});

  /// Human-readable error description.
  final String error;

  @override
  List<Object?> get props => [error];
}
