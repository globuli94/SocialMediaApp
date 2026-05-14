// lib/features/search/presentation/bloc/search_state.dart
//
// SearchState — sealed state hierarchy for SearchBloc.

import 'package:equatable/equatable.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';

/// Base class for all search states.
sealed class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

/// Initial state — no query entered yet. Shows a prompt to the user.
final class SearchInitial extends SearchState {
  /// Creates a [SearchInitial].
  const SearchInitial();
}

/// A search is in progress (debounce timer fired, awaiting Firestore response).
final class SearchLoading extends SearchState {
  /// Creates a [SearchLoading].
  const SearchLoading();
}

/// Search completed successfully.
final class SearchLoaded extends SearchState {
  /// Creates a [SearchLoaded].
  const SearchLoaded({required this.results});

  /// Ordered list of matching user profiles (current user excluded).
  final List<UserProfileEntity> results;

  @override
  List<Object?> get props => [results];
}

/// Search failed with an error.
final class SearchFailure extends SearchState {
  /// Creates a [SearchFailure].
  const SearchFailure({required this.error});

  /// Human-readable error description.
  final String error;

  @override
  List<Object?> get props => [error];
}
