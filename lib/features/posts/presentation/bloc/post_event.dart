// lib/features/posts/presentation/bloc/post_event.dart
//
// PostEvent — sealed event hierarchy for PostBloc.

import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';

/// Base class for all post events.
abstract class PostEvent extends Equatable {
  const PostEvent();

  @override
  List<Object?> get props => [];
}

/// Starts watching the posts stream from Firestore.
class PostWatchStarted extends PostEvent {
  const PostWatchStarted();
}

/// Requests creation of a new post.
class PostCreateRequested extends PostEvent {
  const PostCreateRequested({
    required this.authorUid,
    required this.authorDisplayName,
    this.authorAvatarUrl,
    required this.content,
    this.imageBytes,
    this.imageExtension,
  });

  final String authorUid;
  final String authorDisplayName;
  final String? authorAvatarUrl;
  final String content;
  final Uint8List? imageBytes;
  final String? imageExtension;

  @override
  List<Object?> get props => [authorUid, content, imageBytes];
}

/// Requests deletion of a post by its ID.
class PostDeleteRequested extends PostEvent {
  const PostDeleteRequested({required this.postId});

  final String postId;

  @override
  List<Object?> get props => [postId];
}

/// Internal event emitted when the Firestore stream delivers a new list.
class PostsUpdated extends PostEvent {
  const PostsUpdated(this.posts);

  final List<PostEntity> posts;

  @override
  List<Object?> get props => [posts];
}

/// Starts watching posts filtered by [authorUid], ordered by createdAt desc.
class PostsByAuthorWatchStarted extends PostEvent {
  const PostsByAuthorWatchStarted({required this.authorUid});

  final String authorUid;

  @override
  List<Object?> get props => [authorUid];
}

/// Starts watching the following feed for [currentUserUid].
/// Shows posts from followed users, or all posts if following list is empty.
class PostFollowingFeedWatchStarted extends PostEvent {
  const PostFollowingFeedWatchStarted({required this.currentUserUid});

  final String currentUserUid;

  @override
  List<Object?> get props => [currentUserUid];
}
