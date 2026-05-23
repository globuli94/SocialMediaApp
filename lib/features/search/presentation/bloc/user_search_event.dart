// lib/features/search/presentation/bloc/user_search_event.dart
//
// UserSearchEvent — events for UserSearchBloc.

import 'package:equatable/equatable.dart';

/// Base class for all user search events.
abstract class UserSearchEvent extends Equatable {
  const UserSearchEvent();

  @override
  List<Object?> get props => [];
}

/// Fired on every keystroke in the search bar.
final class UserSearchQueryChanged extends UserSearchEvent {
  /// Creates a [UserSearchQueryChanged].
  const UserSearchQueryChanged({
    required this.query,
    required this.currentUid,
  });

  /// The raw text entered by the user.
  final String query;

  /// UID of the signed-in user, used to filter them from results.
  final String currentUid;

  @override
  List<Object?> get props => [query, currentUid];
}

/// Clears search results and returns to the initial prompt state.
final class UserSearchCleared extends UserSearchEvent {
  /// Creates a [UserSearchCleared].
  const UserSearchCleared();
}
