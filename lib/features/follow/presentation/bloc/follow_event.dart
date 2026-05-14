// lib/features/follow/presentation/bloc/follow_event.dart
//
// FollowEvent — sealed event hierarchy for FollowBloc.

import 'package:equatable/equatable.dart';

/// Base class for all follow events.
sealed class FollowEvent extends Equatable {
  const FollowEvent();

  @override
  List<Object?> get props => [];
}

/// Starts watching whether [followerId] follows [followeeId] in real time.
final class FollowWatchRequested extends FollowEvent {
  /// Creates a [FollowWatchRequested].
  const FollowWatchRequested({
    required this.followerId,
    required this.followeeId,
  });

  /// The UID of the user who may be following.
  final String followerId;

  /// The UID of the user who may be followed.
  final String followeeId;

  @override
  List<Object?> get props => [followerId, followeeId];
}

/// Requests that [followerId] follows [followeeId].
final class FollowRequested extends FollowEvent {
  /// Creates a [FollowRequested].
  const FollowRequested({
    required this.followerId,
    required this.followeeId,
  });

  /// The UID of the user who wants to follow.
  final String followerId;

  /// The UID of the user to be followed.
  final String followeeId;

  @override
  List<Object?> get props => [followerId, followeeId];
}

/// Requests that [followerId] unfollows [followeeId].
final class UnfollowRequested extends FollowEvent {
  /// Creates an [UnfollowRequested].
  const UnfollowRequested({
    required this.followerId,
    required this.followeeId,
  });

  /// The UID of the user who wants to unfollow.
  final String followerId;

  /// The UID of the user to be unfollowed.
  final String followeeId;

  @override
  List<Object?> get props => [followerId, followeeId];
}
