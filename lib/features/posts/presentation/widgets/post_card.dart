// lib/features/posts/presentation/widgets/post_card.dart
//
// PostCard — displays a single post in the feed.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/profile/presentation/widgets/avatar_widget.dart';

/// Card widget that renders a single [PostEntity] in the feed.
///
/// Shows the author avatar, display name, relative timestamp, post text,
/// optional image, and a delete button when the post belongs to the current
/// user.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.currentUserUid,
  });

  final PostEntity post;
  final String currentUserUid;

  String _relativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarWidget(
                  displayName: post.authorDisplayName,
                  avatarUrl: post.authorAvatarUrl,
                  radius: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorDisplayName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        _relativeTime(post.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (post.authorUid == currentUserUid)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete post',
                    onPressed: () {
                      context
                          .read<PostBloc>()
                          .add(PostDeleteRequested(postId: post.id));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(post.content),
            if (post.imageUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 300,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
