// lib/features/follow/presentation/bloc/follow_list_event.dart
//
// FollowListEvent — events for FollowListBloc.

import 'package:equatable/equatable.dart';

/// Base event for [FollowListBloc].
abstract class FollowListEvent extends Equatable {
  const FollowListEvent();

  @override
  List<Object?> get props => [];
}

/// Requests watching the followers list for a given [uid].
class FollowersWatchRequested extends FollowListEvent {
  const FollowersWatchRequested({required this.uid});

  final String uid;

  @override
  List<Object?> get props => [uid];
}

/// Requests watching the following list for a given [uid].
class FollowingWatchRequested extends FollowListEvent {
  const FollowingWatchRequested({required this.uid});

  final String uid;

  @override
  List<Object?> get props => [uid];
}
