// lib/features/likes/presentation/widgets/like_button.dart
//
// LikeButton — displays a like button with like count for a post.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/likes/presentation/bloc/like_bloc.dart';
import 'package:social_network/features/likes/presentation/bloc/like_event.dart';
import 'package:social_network/features/likes/presentation/bloc/like_state.dart';

/// Button widget that displays the like status and count for a post.
///
/// Listens to [LikeBloc] to receive updates on like status and count.
/// Allows the user to toggle the like state when tapped.
///
/// Requires [postId] and [currentUserUid] to identify the post and user.
/// The [onLikeToggleError] callback is called if toggling fails.
class LikeButton extends StatefulWidget {
  const LikeButton({
    super.key,
    required this.postId,
    required this.currentUserUid,
    this.onLikeToggleError,
  });

  final String postId;
  final String currentUserUid;
  final Function(String error)? onLikeToggleError;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  @override
  void initState() {
    super.initState();
    // Start watching like status and count when widget mounts
    context.read<LikeBloc>().add(
          LikeWatchRequested(
            postId: widget.postId,
            userId: widget.currentUserUid,
          ),
        );
  }

  void _onLikePressed() {
    context.read<LikeBloc>().add(
          LikeToggleRequested(
            postId: widget.postId,
            userId: widget.currentUserUid,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LikeBloc, LikeState>(
      listener: (context, state) {
        if (state is LikeFailure && widget.onLikeToggleError != null) {
          widget.onLikeToggleError!(state.error);
        }
      },
      child: BlocBuilder<LikeBloc, LikeState>(
        builder: (context, state) {
          if (state is LikeLoading) {
            return const SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          if (state is LikeFailure) {
            return IconButton(
              icon: const Icon(Icons.favorite_border),
              tooltip: 'Error loading likes',
              onPressed: () {
                context.read<LikeBloc>().add(
                      LikeWatchRequested(
                        postId: widget.postId,
                        userId: widget.currentUserUid,
                      ),
                    );
              },
            );
          }

          if (state is LikeLoaded) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    state.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: state.isLiked ? Colors.red : null,
                  ),
                  tooltip: state.isLiked ? 'Unlike' : 'Like',
                  onPressed: state.isSubmitting ? null : _onLikePressed,
                ),
                Text(
                  state.likeCount.toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          }

          return IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Like',
            onPressed: _onLikePressed,
          );
        },
      ),
    );
  }
}
