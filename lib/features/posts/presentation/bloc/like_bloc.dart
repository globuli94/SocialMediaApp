// lib/features/posts/presentation/bloc/like_bloc.dart
//
// LikeBloc — manages like/unlike state for a post.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/notifications/domain/repositories/notification_repository.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/like_event.dart';
import 'package:social_network/features/posts/presentation/bloc/like_state.dart';

/// BLoC that manages the like state for a single post.
///
/// Per-post BLoCs are instantiated in the LikeButton widget to handle
/// concurrent like/unlike operations across multiple posts in a list.
class LikeBloc extends Bloc<LikeEvent, LikeState> {
  /// Creates a [LikeBloc].
  LikeBloc({
    required PostRepository postRepository,
    NotificationRepository? notificationRepository,
  })  : _postRepository = postRepository,
        _notificationRepository = notificationRepository,
        super(const LikeInitial()) {
    on<LikeFetched>(_onLikeFetched);
    on<LikeToggled>(_onLikeToggled);
  }

  final PostRepository _postRepository;
  final NotificationRepository? _notificationRepository;
  int _currentLikeCount = 0;

  /// Fetches and streams the initial like state.
  Future<void> _onLikeFetched(
    LikeFetched event,
    Emitter<LikeState> emit,
  ) async {
    emit(const LikeLoading());
    try {
      _currentLikeCount = event.initialLikeCount;

      await emit.forEach<bool>(
        _postRepository.watchPostLiked(event.postId, event.userId),
        onData: (isLiked) => LikeUpdated(
          isLiked: isLiked,
          likeCount: _currentLikeCount,
        ),
        onError: (error, stackTrace) => LikeError(
          message: error.toString(),
        ),
      );
    } catch (e) {
      emit(LikeError(message: e.toString()));
    }
  }

  /// Toggles the like state (like or unlike).
  Future<void> _onLikeToggled(
    LikeToggled event,
    Emitter<LikeState> emit,
  ) async {
    try {
      // Emit optimistic state immediately
      final newLikeCount = event.isLiked
          ? _currentLikeCount - 1
          : _currentLikeCount + 1;
      _currentLikeCount = newLikeCount;
      emit(LikeUpdated(
        isLiked: !event.isLiked,
        likeCount: newLikeCount,
      ));

      // Perform the Firestore operation
      if (event.isLiked) {
        await _postRepository.unlikePost(event.postId, event.userId);
      } else {
        await _postRepository.likePost(event.postId, event.userId);
        // Fire a like notification when all guard conditions pass.
        if (_notificationRepository != null &&
            event.postAuthorUid != null &&
            event.actorDisplayName != null &&
            event.postAuthorUid != event.userId) {
          await _notificationRepository.createLikeNotification(
            recipientUid: event.postAuthorUid!,
            actorUid: event.userId,
            actorDisplayName: event.actorDisplayName!,
            actorAvatarUrl: event.actorAvatarUrl,
            postId: event.postId,
          );
        }
      }
      // Stream will update via the watchPostLiked listener in _onLikeFetched
    } catch (e) {
      emit(LikeError(message: e.toString()));
      // Revert optimistic update on error
      _currentLikeCount = event.currentLikeCount;
      rethrow;
    }
  }
}
