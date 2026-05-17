// lib/features/posts/presentation/bloc/like_bloc.dart
//
// LikeBloc — manages like/unlike state for a post.

import 'package:flutter_bloc/flutter_bloc.dart';
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
  })  : _postRepository = postRepository,
        super(const LikeInitial()) {
    on<LikeFetched>(_onLikeFetched);
    on<LikeToggled>(_onLikeToggled);
  }

  final PostRepository _postRepository;

  /// Fetches and streams the initial like state.
  Future<void> _onLikeFetched(
    LikeFetched event,
    Emitter<LikeState> emit,
  ) async {
    emit(const LikeLoading());
    try {
      await emit.forEach<bool>(
        _postRepository.watchPostLiked(event.postId, event.userId),
        onData: (isLiked) => LikeUpdated(isLiked: isLiked),
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
    emit(const LikeLoading());
    try {
      if (event.isLiked) {
        await _postRepository.unlikePost(event.postId, event.userId);
      } else {
        await _postRepository.likePost(event.postId, event.userId);
      }
      // State will update via the stream watcher in _onLikeFetched
    } catch (e) {
      emit(LikeError(message: e.toString()));
      // Re-emit the previous state after error
      rethrow;
    }
  }
}
