// lib/features/feed/presentation/bloc/feed_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/feed/presentation/bloc/feed_event.dart';
import 'package:social_network/features/feed/presentation/bloc/feed_state.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  FeedBloc({required PostRepository postRepository})
      : _postRepository = postRepository,
        super(const FeedInitial()) {
    on<FeedStarted>(_onFeedStarted);
    on<FeedRefreshRequested>(_onFeedRefreshRequested);
    on<FeedLoadMoreRequested>(_onFeedLoadMoreRequested);
  }

  final PostRepository _postRepository;
  static const int _pageSize = 10;

  Future<void> _onFeedStarted(
    FeedStarted event,
    Emitter<FeedState> emit,
  ) async {
    emit(const FeedLoading());
    try {
      final (posts, cursor) = await _postRepository.fetchFeedPage(
        cursor: null,
        limit: _pageSize,
      );
      emit(FeedLoaded(
        posts: posts,
        hasMore: cursor != null,
        cursor: cursor,
      ));
    } catch (e) {
      emit(FeedFailure(error: e.toString()));
    }
  }

  Future<void> _onFeedRefreshRequested(
    FeedRefreshRequested event,
    Emitter<FeedState> emit,
  ) async {
    emit(const FeedLoading());
    try {
      final (posts, cursor) = await _postRepository.fetchFeedPage(
        cursor: null,
        limit: _pageSize,
      );
      emit(FeedLoaded(
        posts: posts,
        hasMore: cursor != null,
        cursor: cursor,
      ));
    } catch (e) {
      emit(FeedFailure(error: e.toString()));
    }
  }

  Future<void> _onFeedLoadMoreRequested(
    FeedLoadMoreRequested event,
    Emitter<FeedState> emit,
  ) async {
    final current = state;
    if (current is! FeedLoaded) return;
    if (!current.hasMore || current.isLoadingMore) return;

    emit(current.copyWith(isLoadingMore: true));
    try {
      final (newPosts, nextCursor) = await _postRepository.fetchFeedPage(
        cursor: current.cursor,
        limit: _pageSize,
      );
      emit(FeedLoaded(
        posts: [...current.posts, ...newPosts],
        hasMore: nextCursor != null,
        cursor: nextCursor,
      ));
    } catch (e) {
      emit(FeedFailure(error: e.toString()));
    }
  }
}
