// lib/features/follow/presentation/bloc/follow_list_bloc.dart
//
// FollowListBloc — manages followers/following list streams.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_state.dart';

/// BLoC that manages followers and following lists.
class FollowListBloc extends Bloc<FollowListEvent, FollowListState> {
  FollowListBloc({required FollowRepository followRepository})
      : _repository = followRepository,
        super(const FollowListInitial()) {
    on<FollowListWatchFollowersStarted>(_onWatchFollowersStarted);
    on<FollowListWatchFollowingStarted>(_onWatchFollowingStarted);
  }

  final FollowRepository _repository;

  Future<void> _onWatchFollowersStarted(
    FollowListWatchFollowersStarted event,
    Emitter<FollowListState> emit,
  ) async {
    emit(const FollowListLoading());
    await emit.forEach(
      _repository.watchFollowers(event.uid),
      onData: (users) => FollowListLoaded(users: users),
      onError: (error, _) => FollowListFailure(error: error.toString()),
    );
  }

  Future<void> _onWatchFollowingStarted(
    FollowListWatchFollowingStarted event,
    Emitter<FollowListState> emit,
  ) async {
    emit(const FollowListLoading());
    await emit.forEach(
      _repository.watchFollowing(event.uid),
      onData: (users) => FollowListLoaded(users: users),
      onError: (error, _) => FollowListFailure(error: error.toString()),
    );
  }
}
