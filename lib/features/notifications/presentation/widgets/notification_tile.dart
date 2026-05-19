// lib/features/notifications/presentation/widgets/notification_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/notifications/domain/entities/notification_model.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_event.dart';
import 'package:social_network/features/profile/presentation/widgets/avatar_widget.dart';

/// A single row in the notifications list.
///
/// Shows the actor avatar, a human-readable description of the event, a
/// relative timestamp, and an unread background when [notification.isRead]
/// is false.
///
/// Tapping the tile dispatches [NotificationTapped] to the parent
/// [NotificationBloc] which marks the notification as read.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.uid,
  });

  final NotificationModel notification;
  final String uid;

  String _relativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _bodyText() {
    switch (notification.type) {
      case 'like':
        return '${notification.actorDisplayName} liked your post';
      case 'follow':
        return '${notification.actorDisplayName} started following you';
      default:
        return '${notification.actorDisplayName} interacted with you';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadBg = notification.isRead
        ? null
        : Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.15);

    return InkWell(
      onTap: () {
        if (!notification.isRead) {
          context.read<NotificationBloc>().add(
                NotificationTapped(
                  uid: uid,
                  notificationId: notification.id,
                ),
              );
        }
      },
      child: Container(
        color: unreadBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarWidget(
              displayName: notification.actorDisplayName,
              avatarUrl: notification.actorAvatarUrl,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _bodyText(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(notification.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
