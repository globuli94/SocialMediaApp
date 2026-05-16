// lib/features/likes/presentation/bloc/like_bloc.dart
//
// LikeBloc — manages like/unlike state and delegates to LikeRepository.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/likes/domain/repositories/like_repository.dart';
import 'package:social_network/features/likes/presentation/bloc/like_event.dart';
import 'package:social_network/features/likes/presentation/bloc/like_state.dart';

/// BLoC that manages like state for a post.
///
/// Listens for [LikeWatchRequested] and [LikeToggleRequested] events and
/// delegates to [LikeRepository].
class LikeBloc extends Bloc<LikeEvent, LikeState> {
  /// Creates a [LikeBloc] with the given [likeRepository].
  LikeBloc({required LikeRepository likeRepository})
      : _repository = likeRepository,
        super(const LikeInitial()) {
    on<LikeWatchRequested>(_onWatchRequested);
    on<LikeToggleRequested>(_onToggleRequested);
  }

  final LikeRepository _repository;

  /// Subscribes to real-time like status and count via streaming.
  /// Uses emit.forEach to listen to likeCount updates and updates isLiked
  /// separately as it changes.
  Future<void> _onWatchRequested(
    LikeWatchRequested event,
    Emitter<LikeState> emit,
  ) async {
    emit(const LikeLoading());

    try {
      // First, set up a listener for isLiked changes
      final isLikedStream = _repository.watchIsLiked(
        postId: event.postId,
        userId: event.userId,
      );
      final likeCountStream = _repository.watchLikeCount(postId: event.postId);

      // Track current isLiked state
      bool currentIsLiked = false;
      final isLikedSubscription = isLikedStream.listen((isLiked) {
        currentIsLiked = isLiked;
        final current = state;
        if (current is LikeLoaded) {
          emit(current.copyWith(isLiked: isLiked));
        }
      });

      // Use emit.forEach for likeCount stream (keeps watch active)
      await emit.forEach<int>(
        likeCountStream,
        onData: (likeCount) {
          final current = state;
          if (current is LikeLoaded) {
            return current.copyWith(likeCount: likeCount);
          }
          return LikeLoaded(isLiked: currentIsLiked, likeCount: likeCount);
        },
        onError: (e, _) {
          isLikedSubscription.cancel();
          return LikeFailure(error: e.toString());
        },
      );
      isLikedSubscription.cancel();
    } catch (e) {
      emit(LikeFailure(error: e.toString()));
    }
  }

  /// Performs an atomic batch write to toggle the like state.
  Future<void> _onToggleRequested(
    LikeToggleRequested event,
    Emitter<LikeState> emit,
  ) async {
    final current = state;
    if (current is LikeLoaded) {
      emit(current.copyWith(isSubmitting: true));
    }

    try {
      await _repository.toggleLike(
        postId: event.postId,
        userId: event.userId,
      );
      // Stream updates will deliver the new state via watchIsLiked/watchLikeCount
      if (current is LikeLoaded) {
        emit(current.copyWith(isSubmitting: false));
      }
    } catch (e) {
      emit(LikeFailure(error: e.toString()));
    }
  }
}
