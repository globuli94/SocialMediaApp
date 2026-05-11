// lib/features/posts/presentation/bloc/post_state.dart
//
// PostState — state hierarchy for PostBloc.

import 'package:equatable/equatable.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';

/// Base class for all post states.
abstract class PostState extends Equatable {
  const PostState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any post data has been loaded.
class PostInitial extends PostState {
  const PostInitial();
}

/// Posts are being fetched for the first time.
class PostLoading extends PostState {
  const PostLoading();
}

/// Posts loaded successfully. [isSubmitting] is true while a create/delete is
/// in flight.
class PostLoaded extends PostState {
  const PostLoaded({required this.posts, this.isSubmitting = false});

  final List<PostEntity> posts;
  final bool isSubmitting;

  PostLoaded copyWith({List<PostEntity>? posts, bool? isSubmitting}) =>
      PostLoaded(
        posts: posts ?? this.posts,
        isSubmitting: isSubmitting ?? this.isSubmitting,
      );

  @override
  List<Object?> get props => [posts, isSubmitting];
}

/// A post operation failed.
class PostFailure extends PostState {
  const PostFailure({required this.error});

  final String error;

  @override
  List<Object?> get props => [error];
}
