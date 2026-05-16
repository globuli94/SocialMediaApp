// lib/features/likes/presentation/bloc/like_event.dart
//
// LikeEvent — sealed event hierarchy for LikeBloc.

import 'package:equatable/equatable.dart';

/// Base class for all like events.
abstract class LikeEvent extends Equatable {
  const LikeEvent();

  @override
  List<Object?> get props => [];
}

/// Requests to watch the like status and count for a specific post.
class LikeWatchRequested extends LikeEvent {
  const LikeWatchRequested({
    required this.postId,
    required this.userId,
  });

  final String postId;
  final String userId;

  @override
  List<Object?> get props => [postId, userId];
}

/// Requests to toggle the like status on a post.
class LikeToggleRequested extends LikeEvent {
  const LikeToggleRequested({
    required this.postId,
    required this.userId,
  });

  final String postId;
  final String userId;

  @override
  List<Object?> get props => [postId, userId];
}
