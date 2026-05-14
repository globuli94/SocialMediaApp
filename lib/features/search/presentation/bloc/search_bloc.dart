// lib/features/search/presentation/bloc/search_bloc.dart
//
// SearchBloc — debounced user search backed by ProfileRepository.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/profile/domain/repositories/profile_repository.dart';
import 'package:social_network/features/search/presentation/bloc/search_event.dart';
import 'package:social_network/features/search/presentation/bloc/search_state.dart';

/// Internal event dispatched after the 300 ms debounce timer fires.
final class _SearchExecuted extends SearchEvent {
  const _SearchExecuted({required this.query, required this.currentUid});

  final String query;
  final String currentUid;

  @override
  List<Object?> get props => [query, currentUid];
}

/// BLoC that manages user search state.
///
/// [SearchQueryChanged] events are debounced by 300 ms. After the debounce
/// window, a [_SearchExecuted] event is dispatched internally which performs
/// the Firestore prefix query via [ProfileRepository.searchUsers].
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  /// Creates a [SearchBloc].
  SearchBloc({required ProfileRepository profileRepository})
      : _profileRepository = profileRepository,
        super(const SearchInitial()) {
    on<SearchQueryChanged>(_onQueryChanged);
    on<_SearchExecuted>(_onSearchExecuted);
    on<SearchCleared>(_onCleared);
  }

  final ProfileRepository _profileRepository;
  Timer? _debounce;

  void _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) {
    _debounce?.cancel();

    if (event.query.trim().isEmpty) {
      emit(const SearchInitial());
      return;
    }

    emit(const SearchLoading());

    _debounce = Timer(const Duration(milliseconds: 300), () {
      add(_SearchExecuted(
        query: event.query.trim(),
        currentUid: event.currentUid,
      ));
    });
  }

  Future<void> _onSearchExecuted(
    _SearchExecuted event,
    Emitter<SearchState> emit,
  ) async {
    try {
      final results = await _profileRepository.searchUsers(
        query: event.query,
        excludeUid: event.currentUid,
      );
      emit(SearchLoaded(results: results));
    } catch (e) {
      emit(SearchFailure(error: e.toString()));
    }
  }

  void _onCleared(
    SearchCleared event,
    Emitter<SearchState> emit,
  ) {
    _debounce?.cancel();
    emit(const SearchInitial());
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
