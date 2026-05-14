// lib/features/follow/presentation/bloc/follow_state.dart
//
// FollowState — sealed state hierarchy for FollowBloc.

import 'package:equatable/equatable.dart';

/// Base class for all follow states.
sealed class FollowState extends Equatable {
  const FollowState();

  @override
  List<Object?> get props => [];
}

/// Initial state before watching any follow relationship.
final class FollowInitial extends FollowState {
  /// Creates a [FollowInitial].
  const FollowInitial();
}

/// Follow status is being determined.
final class FollowLoading extends FollowState {
  /// Creates a [FollowLoading].
  const FollowLoading();
}

/// Follow status is known and up to date.
final class FollowLoaded extends FollowState {
  /// Creates a [FollowLoaded].
  const FollowLoaded({required this.isFollowing});

  /// Whether the current user follows the viewed user.
  final bool isFollowing;

  @override
  List<Object?> get props => [isFollowing];
}

/// A follow or unfollow operation failed.
final class FollowFailure extends FollowState {
  /// Creates a [FollowFailure].
  const FollowFailure({required this.error});

  /// Human-readable error description.
  final String error;

  @override
  List<Object?> get props => [error];
}
