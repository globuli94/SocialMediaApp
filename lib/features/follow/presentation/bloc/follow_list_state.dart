// lib/features/follow/presentation/bloc/follow_list_state.dart
//
// FollowListState — states for FollowListBloc.

import 'package:equatable/equatable.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';

/// Base class for [FollowListBloc] states.
sealed class FollowListState extends Equatable {
  /// Creates a [FollowListState].
  const FollowListState();

  @override
  List<Object?> get props => [];
}

/// Initial state.
final class FollowListInitial extends FollowListState {
  /// Creates a [FollowListInitial].
  const FollowListInitial();
}

/// Loading state.
final class FollowListLoading extends FollowListState {
  /// Creates a [FollowListLoading].
  const FollowListLoading();
}

/// Loaded state with a list of users.
final class FollowListLoaded extends FollowListState {
  /// Creates a [FollowListLoaded].
  const FollowListLoaded({required this.users});

  /// The list of users (followers or following).
  final List<UserProfileEntity> users;

  @override
  List<Object?> get props => [users];
}

/// Failure state with an error message.
final class FollowListFailure extends FollowListState {
  /// Creates a [FollowListFailure].
  const FollowListFailure({required this.error});

  /// The error message.
  final String error;

  @override
  List<Object?> get props => [error];
}
