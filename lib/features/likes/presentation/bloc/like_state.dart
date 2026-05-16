// lib/features/likes/presentation/bloc/like_state.dart
//
// LikeState — state hierarchy for LikeBloc.

import 'package:equatable/equatable.dart';

/// Base class for all like states.
abstract class LikeState extends Equatable {
  const LikeState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any like data has been loaded.
class LikeInitial extends LikeState {
  const LikeInitial();
}

/// Like data is being loaded for the first time.
class LikeLoading extends LikeState {
  const LikeLoading();
}

/// Like data loaded successfully. [isLiked] indicates whether the current user
/// has liked the post. [likeCount] is the total number of likes on the post.
/// [isSubmitting] is true while a toggle operation is in flight.
class LikeLoaded extends LikeState {
  const LikeLoaded({
    required this.isLiked,
    required this.likeCount,
    this.isSubmitting = false,
  });

  final bool isLiked;
  final int likeCount;
  final bool isSubmitting;

  LikeLoaded copyWith({
    bool? isLiked,
    int? likeCount,
    bool? isSubmitting,
  }) =>
      LikeLoaded(
        isLiked: isLiked ?? this.isLiked,
        likeCount: likeCount ?? this.likeCount,
        isSubmitting: isSubmitting ?? this.isSubmitting,
      );

  @override
  List<Object?> get props => [isLiked, likeCount, isSubmitting];
}

/// A like operation failed.
class LikeFailure extends LikeState {
  const LikeFailure({required this.error});

  final String error;

  @override
  List<Object?> get props => [error];
}
