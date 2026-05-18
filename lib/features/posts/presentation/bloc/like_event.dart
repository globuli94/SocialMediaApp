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
    this.postAuthorUid,
    this.actorDisplayName,
    this.actorAvatarUrl,
  });

  final String postId;
  final String userId;
  final bool isLiked;
  final int currentLikeCount;

  /// UID of the post author — used to address the notification recipient.
  final String? postAuthorUid;

  /// Denormalised display name of the liker, for the notification payload.
  final String? actorDisplayName;

  /// Avatar URL of the liker, or `null` if not set.
  final String? actorAvatarUrl;

  @override
  List<Object?> get props => [
        postId,
        userId,
        isLiked,
        currentLikeCount,
        postAuthorUid,
        actorDisplayName,
        actorAvatarUrl,
      ];
}
