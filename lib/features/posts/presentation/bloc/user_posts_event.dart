// lib/features/posts/presentation/bloc/user_posts_event.dart
//
// UserPostsEvent — event hierarchy for UserPostsBloc.

import 'package:equatable/equatable.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';

/// Base class for all user-posts events.
abstract class UserPostsEvent extends Equatable {
  const UserPostsEvent();

  @override
  List<Object?> get props => [];
}

/// Starts watching posts authored by [uid].
class UserPostsWatchStarted extends UserPostsEvent {
  const UserPostsWatchStarted({required this.uid});

  final String uid;

  @override
  List<Object?> get props => [uid];
}

/// Internal event emitted when the Firestore stream delivers a new list.
class UserPostsUpdated extends UserPostsEvent {
  const UserPostsUpdated(this.posts);

  final List<PostEntity> posts;

  @override
  List<Object?> get props => [posts];
}
