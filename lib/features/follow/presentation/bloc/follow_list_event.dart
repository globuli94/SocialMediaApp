// lib/features/follow/presentation/bloc/follow_list_event.dart
//
// FollowListEvent — events for FollowListBloc.

import 'package:equatable/equatable.dart';

/// Base event for FollowListBloc.
sealed class FollowListEvent extends Equatable {
  const FollowListEvent();

  @override
  List<Object?> get props => [];
}

/// Event to start watching followers for a user.
final class FollowListWatchFollowersStarted extends FollowListEvent {
  const FollowListWatchFollowersStarted(this.uid);

  /// UID of the user whose followers to watch.
  final String uid;

  @override
  List<Object?> get props => [uid];
}

/// Event to start watching following for a user.
final class FollowListWatchFollowingStarted extends FollowListEvent {
  const FollowListWatchFollowingStarted(this.uid);

  /// UID of the user whose following to watch.
  final String uid;

  @override
  List<Object?> get props => [uid];
}
