// lib/features/posts/presentation/bloc/like_event.dart
//
// LikeBloc events — user actions on a post's like button.

import 'package:equatable/equatable.dart';

/// Base class for like-related events.
abstract class LikeEvent extends Equatable {
  const LikeEvent();

  @override
  List<Object?> get props => [];
}

/// Fetches the initial like state for a post from the current user.
class LikeFetched extends LikeEvent {
  const LikeFetched({
    required this.postId,
    required this.userId,
  });

  final String postId;
  final String userId;

  @override
  List<Object?> get props => [postId, userId];
}

/// Toggles the like state (like if not liked, unlike if liked).
class LikeToggled extends LikeEvent {
  const LikeToggled({
    required this.postId,
    required this.userId,
    required this.isLiked,
  });

  final String postId;
  final String userId;
  final bool isLiked;

  @override
  List<Object?> get props => [postId, userId, isLiked];
}
