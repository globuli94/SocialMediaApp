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
    on<PostsByAuthorWatchStarted>(_onByAuthorWatchStarted);
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

  Future<void> _onByAuthorWatchStarted(
    PostsByAuthorWatchStarted event,
    Emitter<PostState> emit,
  ) async {
    emit(const PostLoading());
    await emit.forEach<List<PostEntity>>(
      _repository.watchPostsByAuthorUid(event.authorUid),
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
      // Use the live state rather than the captured `current` so that any
      // posts delivered by the watchPosts() stream during the async write are
      // preserved. Using `current` here would overwrite a fresh stream
      // emission with the stale pre-creation list.
      final afterCreate = state;
      if (afterCreate is PostLoaded) {
        emit(afterCreate.copyWith(isSubmitting: false));
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
