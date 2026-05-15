// lib/features/posts/presentation/bloc/user_posts_state.dart
//
// UserPostsState — state hierarchy for UserPostsBloc.

import 'package:equatable/equatable.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';

/// Base class for all user-posts states.
abstract class UserPostsState extends Equatable {
  const UserPostsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any user posts data has been loaded.
class UserPostsInitial extends UserPostsState {
  const UserPostsInitial();
}

/// User posts are being fetched for the first time.
class UserPostsLoading extends UserPostsState {
  const UserPostsLoading();
}

/// User posts loaded successfully.
class UserPostsLoaded extends UserPostsState {
  const UserPostsLoaded({required this.posts});

  final List<PostEntity> posts;

  @override
  List<Object?> get props => [posts];
}

/// A user-posts operation failed.
class UserPostsFailure extends UserPostsState {
  const UserPostsFailure({required this.error});

  final String error;

  @override
  List<Object?> get props => [error];
}
