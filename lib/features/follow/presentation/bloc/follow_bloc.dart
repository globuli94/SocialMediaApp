// lib/features/follow/presentation/bloc/follow_bloc.dart
//
// FollowBloc — manages follow/unfollow state and Firestore stream.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_state.dart';

/// BLoC that manages the follow / unfollow relationship between two users.
///
/// Subscribes to a Firestore real-time stream via [FollowRepository] and
/// exposes follow / unfollow actions.
class FollowBloc extends Bloc<FollowEvent, FollowState> {
  /// Creates a [FollowBloc].
  FollowBloc({required FollowRepository followRepository})
      : _repository = followRepository,
        super(const FollowInitial()) {
    on<FollowWatchStarted>(_onWatchStarted);
    on<FollowToggleRequested>(_onToggleRequested);
    on<FollowStatusUpdated>(_onStatusUpdated);
  }

  final FollowRepository _repository;

  /// Subscribes to the follow status stream and emits states as it updates.
  Future<void> _onWatchStarted(
    FollowWatchStarted event,
    Emitter<FollowState> emit,
  ) async {
    emit(const FollowLoading());
    await emit.forEach(
      _repository.watchIsFollowing(
        followerId: event.followerId,
        followeeId: event.followeeId,
      ),
      onData: (value) => FollowLoaded(isFollowing: value),
      onError: (e, _) => FollowFailure(error: e.toString()),
    );
  }

  /// Calls follow or unfollow based on the current [FollowLoaded] state.
  ///
  /// No-ops if the current state is not [FollowLoaded].
  Future<void> _onToggleRequested(
    FollowToggleRequested event,
    Emitter<FollowState> emit,
  ) async {
    if (state is! FollowLoaded) return;
    final isFollowing = (state as FollowLoaded).isFollowing;
    emit(const FollowLoading());
    try {
      if (!isFollowing) {
        await _repository.follow(
          followerId: event.followerId,
          followeeId: event.followeeId,
        );
      } else {
        await _repository.unfollow(
          followerId: event.followerId,
          followeeId: event.followeeId,
        );
      }
    } catch (e) {
      emit(FollowFailure(error: e.toString()));
    }
  }

  /// Emits [FollowLoaded] with the updated [isFollowing] value.
  Future<void> _onStatusUpdated(
    FollowStatusUpdated event,
    Emitter<FollowState> emit,
  ) async {
    emit(FollowLoaded(isFollowing: event.isFollowing));
  }
}
