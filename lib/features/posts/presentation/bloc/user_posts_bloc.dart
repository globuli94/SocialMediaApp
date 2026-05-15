// lib/features/posts/presentation/bloc/user_posts_bloc.dart
//
// UserPostsBloc — manages the stream of posts authored by a single user.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/user_posts_event.dart';
import 'package:social_network/features/posts/presentation/bloc/user_posts_state.dart';

/// BLoC that manages the posts authored by a specific user.
///
/// State is completely independent of the global-feed [PostBloc].
class UserPostsBloc extends Bloc<UserPostsEvent, UserPostsState> {
  UserPostsBloc({required PostRepository postRepository})
      : _repository = postRepository,
        super(const UserPostsInitial()) {
    on<UserPostsWatchStarted>(_onWatchStarted);
    on<UserPostsUpdated>(_onPostsUpdated);
  }

  final PostRepository _repository;

  Future<void> _onWatchStarted(
    UserPostsWatchStarted event,
    Emitter<UserPostsState> emit,
  ) async {
    emit(const UserPostsLoading());
    await emit.forEach<List<PostEntity>>(
      _repository.watchPostsByUser(event.uid),
      onData: (posts) => UserPostsLoaded(posts: posts),
      onError: (error, _) => UserPostsFailure(error: error.toString()),
    );
  }

  void _onPostsUpdated(
    UserPostsUpdated event,
    Emitter<UserPostsState> emit,
  ) {
    emit(UserPostsLoaded(posts: event.posts));
  }
}
