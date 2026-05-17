// lib/features/posts/presentation/widgets/like_button.dart
//
// LikeButton — displays and toggles the like state for a post.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/like_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/like_event.dart';
import 'package:social_network/features/posts/presentation/bloc/like_state.dart';

/// A button that displays the like count and allows liking/unliking a post.
///
/// Provides its own [LikeBloc] per instance, enabling concurrent like operations
/// across multiple posts in a list.
class LikeButton extends StatefulWidget {
  const LikeButton({
    super.key,
    required this.postId,
    required this.likeCount,
    required this.currentUserUid,
  });

  final String postId;
  final int likeCount;
  final String currentUserUid;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  late LikeBloc _likeBloc;

  @override
  void initState() {
    super.initState();
    _likeBloc = LikeBloc(
      postRepository: context.read<PostRepository>(),
    );
    _likeBloc.add(LikeFetched(
      postId: widget.postId,
      userId: widget.currentUserUid,
      initialLikeCount: widget.likeCount,
    ));
  }

  @override
  void dispose() {
    _likeBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LikeBloc>.value(
      value: _likeBloc,
      child: BlocBuilder<LikeBloc, LikeState>(
        builder: (context, state) {
          final isLiked = state is LikeUpdated && state.isLiked;
          final likeCount = state is LikeUpdated ? state.likeCount : widget.likeCount;

          return Row(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.grey,
                ),
                onPressed: () {
                  context.read<LikeBloc>().add(
                    LikeToggled(
                      postId: widget.postId,
                      userId: widget.currentUserUid,
                      isLiked: isLiked,
                      currentLikeCount: likeCount,
                    ),
                  );
                },
              ),
              Text(
                likeCount.toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
