// lib/features/posts/presentation/bloc/like_state.dart
//
// LikeBloc states — like status and loading indicators.

import 'package:equatable/equatable.dart';

/// Base class for like-related states.
abstract class LikeState extends Equatable {
  const LikeState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any like action.
class LikeInitial extends LikeState {
  const LikeInitial();
}

/// Loading state during like/unlike operation.
class LikeLoading extends LikeState {
  const LikeLoading();
}

/// Successfully fetched or toggled like state.
class LikeUpdated extends LikeState {
  const LikeUpdated({
    required this.isLiked,
  });

  final bool isLiked;

  @override
  List<Object?> get props => [isLiked];
}

/// Error occurred during like/unlike operation.
class LikeError extends LikeState {
  const LikeError({
    required this.message,
  });

  final String message;

  @override
  List<Object?> get props => [message];
}
