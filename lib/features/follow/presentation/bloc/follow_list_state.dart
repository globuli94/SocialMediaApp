// lib/features/follow/presentation/bloc/follow_list_state.dart
//
// FollowListState — states for FollowListBloc.

import 'package:equatable/equatable.dart';
import 'package:social_network/features/follow/domain/entities/user_follow_entity.dart';

/// Base state for [FollowListBloc].
abstract class FollowListState extends Equatable {
  const FollowListState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any watch request.
class FollowListInitial extends FollowListState {
  const FollowListInitial();
}

/// Loading state while fetching follower/following data.
class FollowListLoading extends FollowListState {
  const FollowListLoading();
}

/// Loaded state with the list of followers or following.
class FollowListLoaded extends FollowListState {
  const FollowListLoaded({required this.users});

  final List<UserFollowEntity> users;

  @override
  List<Object?> get props => [users];
}

/// Failure state with error message.
class FollowListFailure extends FollowListState {
  const FollowListFailure({required this.error});

  final String error;

  @override
  List<Object?> get props => [error];
}
