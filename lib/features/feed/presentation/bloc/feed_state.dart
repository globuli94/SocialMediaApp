// lib/features/feed/presentation/bloc/feed_state.dart

import 'package:equatable/equatable.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';

abstract class FeedState extends Equatable {
  const FeedState();
}

class FeedInitial extends FeedState {
  const FeedInitial();
  @override
  List<Object?> get props => [];
}

class FeedLoading extends FeedState {
  const FeedLoading();
  @override
  List<Object?> get props => [];
}

class FeedLoaded extends FeedState {
  const FeedLoaded({
    required this.posts,
    required this.hasMore,
    this.isLoadingMore = false,
    this.cursor,
  });

  final List<PostEntity> posts;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? cursor;

  FeedLoaded copyWith({
    List<PostEntity>? posts,
    bool? hasMore,
    bool? isLoadingMore,
    Object? cursor,
    bool clearCursor = false,
  }) {
    return FeedLoaded(
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
    );
  }

  @override
  List<Object?> get props => [posts, hasMore, isLoadingMore, cursor];
}

class FeedFailure extends FeedState {
  const FeedFailure({required this.error});

  final String error;

  @override
  List<Object?> get props => [error];
}
