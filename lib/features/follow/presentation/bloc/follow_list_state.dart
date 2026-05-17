// lib/features/follow/presentation/bloc/follow_list_state.dart
//
// FollowListState — states for FollowListBloc.

import 'package:equatable/equatable.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';

/// Base state for FollowListBloc.
sealed class FollowListState extends Equatable {
  const FollowListState();

  @override
  List<Object?> get props => [];
}

/// Initial state before watching starts.
final class FollowListInitial extends FollowListState {
  const FollowListInitial();
}

/// State while loading the followers/following list.
final class FollowListLoading extends FollowListState {
  const FollowListLoading();
}

/// State when followers/following list is loaded successfully.
final class FollowListLoaded extends FollowListState {
  const FollowListLoaded({required this.users});

  /// List of users (followers or following).
  final List<UserProfileEntity> users;

  @override
  List<Object?> get props => [users];

  /// Copies this state with [users] optionally updated.
  FollowListLoaded copyWith({
    List<UserProfileEntity>? users,
  }) {
    return FollowListLoaded(
      users: users ?? this.users,
    );
  }
}

/// State when loading the list fails.
final class FollowListFailure extends FollowListState {
  const FollowListFailure({required this.error});

  /// Error message.
  final String error;

  @override
  List<Object?> get props => [error];
}
