// lib/features/follow/presentation/bloc/follow_list_bloc.dart
//
// FollowListBloc — manages followers/following list state.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_state.dart';

/// BLoC that manages followers/following list state.
///
/// Listens for [FollowersWatchRequested] and [FollowingWatchRequested] events
/// and delegates to [FollowRepository].
class FollowListBloc extends Bloc<FollowListEvent, FollowListState> {
  /// Creates a [FollowListBloc] with the given [followRepository].
  FollowListBloc({required FollowRepository followRepository})
      : _repository = followRepository,
        super(const FollowListInitial()) {
    on<FollowersWatchRequested>(_onFollowersWatchRequested);
    on<FollowingWatchRequested>(_onFollowingWatchRequested);
  }

  final FollowRepository _repository;

  /// Subscribes to real-time followers list snapshots.
  Future<void> _onFollowersWatchRequested(
    FollowersWatchRequested event,
    Emitter<FollowListState> emit,
  ) async {
    emit(const FollowListLoading());
    await emit.forEach(
      _repository.watchFollowers(event.uid),
      onData: (users) => FollowListLoaded(users: users),
      onError: (e, _) => FollowListFailure(error: e.toString()),
    );
  }

  /// Subscribes to real-time following list snapshots.
  Future<void> _onFollowingWatchRequested(
    FollowingWatchRequested event,
    Emitter<FollowListState> emit,
  ) async {
    emit(const FollowListLoading());
    await emit.forEach(
      _repository.watchFollowing(event.uid),
      onData: (users) => FollowListLoaded(users: users),
      onError: (e, _) => FollowListFailure(error: e.toString()),
    );
  }
}
