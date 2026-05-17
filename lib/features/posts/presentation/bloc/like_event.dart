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
    this.initialLikeCount = 0,
  });

  final String postId;
  final String userId;
  final int initialLikeCount;

  @override
  List<Object?> get props => [postId, userId, initialLikeCount];
}

/// Toggles the like state (like if not liked, unlike if liked).
class LikeToggled extends LikeEvent {
  const LikeToggled({
    required this.postId,
    required this.userId,
    required this.isLiked,
    this.currentLikeCount = 0,
  });

  final String postId;
  final String userId;
  final bool isLiked;
  final int currentLikeCount;

  @override
  List<Object?> get props => [postId, userId, isLiked, currentLikeCount];
}
