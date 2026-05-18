// lib/features/follow/presentation/bloc/follow_list_bloc.dart
//
// FollowListBloc — manages loading followers/following lists.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_state.dart';

/// BLoC that manages loading followers or following lists for a user.
class FollowListBloc extends Bloc<FollowListEvent, FollowListState> {
  /// Creates a [FollowListBloc].
  FollowListBloc({required FollowRepository followRepository})
      : _repository = followRepository,
        super(const FollowListInitial()) {
    on<FollowListLoadRequested>(_onLoadRequested);
  }

  final FollowRepository _repository;

  /// Loads the followers or following list for the requested UID.
  Future<void> _onLoadRequested(
    FollowListLoadRequested event,
    Emitter<FollowListState> emit,
  ) async {
    emit(const FollowListLoading());
    try {
      final users = event.type == FollowListType.followers
          ? await _repository.getFollowers(event.uid)
          : await _repository.getFollowing(event.uid);
      emit(FollowListLoaded(users: users));
    } catch (e) {
      emit(FollowListFailure(error: e.toString()));
    }
  }
}
