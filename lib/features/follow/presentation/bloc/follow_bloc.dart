// lib/features/follow/presentation/bloc/follow_bloc.dart
//
// FollowBloc — manages follow/unfollow state and delegates to FollowRepository.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_state.dart';

/// BLoC that manages follow/unfollow state for a viewed user profile.
///
/// Listens for [FollowWatchRequested], [FollowRequested], and
/// [UnfollowRequested] events and delegates to [FollowRepository].
///
/// [FollowWatchRequested] uses [Emitter.forEach] so it subscribes to real-time
/// Firestore snapshots. [FollowRequested] and [UnfollowRequested] handlers run
/// in their own event-type pipeline and are not blocked by the watch stream.
class FollowBloc extends Bloc<FollowEvent, FollowState> {
  /// Creates a [FollowBloc] with the given [followRepository].
  FollowBloc({required FollowRepository followRepository})
      : _repository = followRepository,
        super(const FollowInitial()) {
    on<FollowWatchRequested>(_onWatchRequested);
    on<FollowRequested>(_onFollowRequested);
    on<UnfollowRequested>(_onUnfollowRequested);
  }

  final FollowRepository _repository;

  /// Subscribes to real-time follow-status snapshots via [Emitter.forEach].
  Future<void> _onWatchRequested(
    FollowWatchRequested event,
    Emitter<FollowState> emit,
  ) async {
    emit(const FollowLoading());
    await emit.forEach(
      _repository.watchIsFollowing(
        followerId: event.followerId,
        followeeId: event.followeeId,
      ),
      onData: (isFollowing) => FollowLoaded(isFollowing: isFollowing),
      onError: (e, _) => FollowFailure(error: e.toString()),
    );
  }

  /// Performs an atomic batch write to create the follow relationship.
  Future<void> _onFollowRequested(
    FollowRequested event,
    Emitter<FollowState> emit,
  ) async {
    try {
      await _repository.follow(
        followerId: event.followerId,
        followeeId: event.followeeId,
      );
    } catch (e) {
      emit(FollowFailure(error: e.toString()));
    }
  }

  /// Performs an atomic batch write to remove the follow relationship.
  Future<void> _onUnfollowRequested(
    UnfollowRequested event,
    Emitter<FollowState> emit,
  ) async {
    try {
      await _repository.unfollow(
        followerId: event.followerId,
        followeeId: event.followeeId,
      );
    } catch (e) {
      emit(FollowFailure(error: e.toString()));
    }
  }
}
