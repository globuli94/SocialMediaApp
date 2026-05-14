// lib/features/follow/presentation/bloc/follow_state.dart
//
// FollowState — sealed base and concrete states for FollowBloc.

import 'package:equatable/equatable.dart';

/// Base class for all follow-related BLoC states.
sealed class FollowState extends Equatable {
  const FollowState();
}

/// Initial state before any watch has been started.
class FollowInitial extends FollowState {
  const FollowInitial();

  @override
  List<Object?> get props => [];
}

/// Emitted while the stream subscription is being set up or while
/// a follow / unfollow operation is in flight.
class FollowLoading extends FollowState {
  const FollowLoading();

  @override
  List<Object?> get props => [];
}

/// Emitted when the follow relationship is known.
class FollowLoaded extends FollowState {
  const FollowLoaded({required this.isFollowing});

  /// Whether the current user is following the target user.
  final bool isFollowing;

  @override
  List<Object?> get props => [isFollowing];
}

/// Emitted when an error occurs during follow / unfollow or stream listen.
class FollowFailure extends FollowState {
  const FollowFailure({required this.error});

  /// Human-readable error description.
  final String error;

  @override
  List<Object?> get props => [error];
}
