// lib/features/follow/presentation/bloc/follow_event.dart
//
// FollowEvent — sealed base and concrete events for FollowBloc.

import 'package:equatable/equatable.dart';

/// Base class for all follow-related BLoC events.
sealed class FollowEvent extends Equatable {
  const FollowEvent();
}

/// Dispatched when [ProfileScreen] loads a non-own profile.
///
/// Starts a Firestore stream that tracks whether [followerId] is following
/// [followeeId].
class FollowWatchStarted extends FollowEvent {
  const FollowWatchStarted({
    required this.followerId,
    required this.followeeId,
  });

  final String followerId;
  final String followeeId;

  @override
  List<Object?> get props => [followerId, followeeId];
}

/// Dispatched when the Follow / Unfollow button is tapped.
///
/// [FollowBloc] reads the current [FollowLoaded] state to determine
/// whether to call `follow` or `unfollow`.
class FollowToggleRequested extends FollowEvent {
  const FollowToggleRequested({
    required this.followerId,
    required this.followeeId,
  });

  final String followerId;
  final String followeeId;

  @override
  List<Object?> get props => [followerId, followeeId];
}

/// Internal event emitted from the Firestore stream listener.
///
/// Not dispatched by UI code directly.
class FollowStatusUpdated extends FollowEvent {
  const FollowStatusUpdated({required this.isFollowing});

  final bool isFollowing;

  @override
  List<Object?> get props => [isFollowing];
}
