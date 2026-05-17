// lib/features/posts/presentation/bloc/post_bloc.dart
//
// PostBloc — manages post stream, creation, and deletion.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';

/// BLoC that manages the posts feed stream, post creation, and deletion.
class PostBloc extends Bloc<PostEvent, PostState> {
  PostBloc({required PostRepository postRepository})
      : _repository = postRepository,
        super(const PostInitial()) {
    on<PostWatchStarted>(_onWatchStarted);
    on<PostsWatchByAuthorRequested>(_onWatchByAuthorRequested);
    on<PostsUpdated>(_onPostsUpdated);
    on<PostCreateRequested>(_onCreateRequested);
    on<PostDeleteRequested>(_onDeleteRequested);
  }

  final PostRepository _repository;

  Future<void> _onWatchStarted(
    PostWatchStarted event,
    Emitter<PostState> emit,
  ) async {
    emit(const PostLoading());
    await emit.forEach<List<PostEntity>>(
      _repository.watchPosts(),
      onData: (posts) => PostLoaded(posts: posts),
      onError: (error, _) => PostFailure(error: error.toString()),
    );
  }

  Future<void> _onWatchByAuthorRequested(
    PostsWatchByAuthorRequested event,
    Emitter<PostState> emit,
  ) async {
    emit(const PostLoading());
    await emit.forEach<List<PostEntity>>(
      _repository.watchPostsByAuthor(event.authorUid),
      onData: (posts) => PostLoaded(posts: posts),
      onError: (error, _) => PostFailure(error: error.toString()),
    );
  }

  void _onPostsUpdated(
    PostsUpdated event,
    Emitter<PostState> emit,
  ) {
    emit(PostLoaded(posts: event.posts));
  }

  Future<void> _onCreateRequested(
    PostCreateRequested event,
    Emitter<PostState> emit,
  ) async {
    final current = state;
    if (current is PostLoaded) {
      emit(current.copyWith(isSubmitting: true));
    }

    try {
      await _repository.createPost(
        authorUid: event.authorUid,
        authorDisplayName: event.authorDisplayName,
        authorAvatarUrl: event.authorAvatarUrl,
        content: event.content,
        imageBytes: event.imageBytes,
        imageExtension: event.imageExtension,
      );
      // Stream update will deliver the new post via watchPosts() automatically.
      if (current is PostLoaded) {
        emit(current.copyWith(isSubmitting: false));
      }
    } catch (e) {
      emit(PostFailure(error: e.toString()));
    }
  }

  Future<void> _onDeleteRequested(
    PostDeleteRequested event,
    Emitter<PostState> emit,
  ) async {
    try {
      await _repository.deletePost(event.postId);
      // Stream update will remove the post automatically.
    } catch (e) {
      emit(PostFailure(error: e.toString()));
    }
  }
}
