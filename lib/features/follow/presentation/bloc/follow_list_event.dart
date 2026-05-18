// lib/features/follow/presentation/bloc/follow_list_event.dart
//
// FollowListEvent — events for FollowListBloc.

import 'package:equatable/equatable.dart';

/// Base class for [FollowListBloc] events.
abstract class FollowListEvent extends Equatable {
  /// Creates a [FollowListEvent].
  const FollowListEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load followers or following for a user.
class FollowListLoadRequested extends FollowListEvent {
  /// Creates a [FollowListLoadRequested] event.
  const FollowListLoadRequested({
    required this.uid,
    required this.type,
  });

  /// The UID of the user to load followers/following for.
  final String uid;

  /// The type of list to load (followers or following).
  final FollowListType type;

  @override
  List<Object?> get props => [uid, type];
}

/// Type of follow list to load.
enum FollowListType {
  /// Followers list.
  followers,

  /// Following list.
  following,
}
