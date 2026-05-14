// lib/features/search/presentation/bloc/search_event.dart
//
// SearchEvent — events for SearchBloc.

import 'package:equatable/equatable.dart';

/// Base class for all search events.
abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// Fired on every keystroke in the search bar.
///
/// The BLoC debounces this event by 300 ms before executing the query.
final class SearchQueryChanged extends SearchEvent {
  /// Creates a [SearchQueryChanged].
  const SearchQueryChanged({
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
final class SearchCleared extends SearchEvent {
  /// Creates a [SearchCleared].
  const SearchCleared();
}
