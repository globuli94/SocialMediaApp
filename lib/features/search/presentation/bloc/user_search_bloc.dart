// lib/features/search/presentation/bloc/user_search_bloc.dart
//
// UserSearchBloc — manages user search state.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/search/domain/repositories/user_search_repository.dart';
import 'package:social_network/features/search/presentation/bloc/user_search_event.dart';
import 'package:social_network/features/search/presentation/bloc/user_search_state.dart';

/// BLoC that manages user search state.
///
/// The screen is responsible for debouncing [UserSearchQueryChanged] events.
/// This BLoC calls the repository immediately when an event arrives, so
/// queries shorter than 2 characters are silently dropped before any
/// repository interaction.
class UserSearchBloc extends Bloc<UserSearchEvent, UserSearchState> {
  /// Creates a [UserSearchBloc].
  UserSearchBloc({required UserSearchRepository userSearchRepository})
      : _userSearchRepository = userSearchRepository,
        super(const UserSearchInitial()) {
    on<UserSearchQueryChanged>(_onQueryChanged);
    on<UserSearchCleared>(_onCleared);
  }

  final UserSearchRepository _userSearchRepository;

  Future<void> _onQueryChanged(
    UserSearchQueryChanged event,
    Emitter<UserSearchState> emit,
  ) async {
    final query = event.query.trim();

    if (query.length < 2) return; // Don't call repository

    emit(const UserSearchLoading());

    try {
      final results = await _userSearchRepository.searchUsers(
        query: query,
        excludeUid: event.currentUid,
      );

      if (results.isEmpty) {
        emit(const UserSearchEmpty());
      } else {
        emit(UserSearchLoaded(results: results));
      }
    } catch (e) {
      emit(UserSearchFailure(error: e.toString()));
    }
  }

  void _onCleared(
    UserSearchCleared event,
    Emitter<UserSearchState> emit,
  ) {
    emit(const UserSearchInitial());
  }
}
