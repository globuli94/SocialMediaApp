// lib/features/notifications/presentation/screens/notifications_screen.dart
//
// NotificationsScreen — displays the authenticated user's notification list.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/notifications/domain/entities/notification_entity.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_event.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_state.dart';
import 'package:social_network/features/profile/presentation/widgets/avatar_widget.dart';

/// Shows the current user's notification feed.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _relativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Notifications'),
      ),
      body: BlocBuilder<NotificationsBloc, NotificationsState>(
        builder: (context, state) {
          if (state is NotificationsInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is NotificationsError) {
            return Center(child: Text(state.message));
          }
          if (state is NotificationsLoaded) {
            if (state.notifications.isEmpty) {
              return const Center(child: Text('No notifications yet'));
            }
            final authState = context.read<AuthBloc>().state;
            final currentUid =
                authState is AuthAuthenticated ? authState.user.uid : '';
            return ListView.builder(
              itemCount: state.notifications.length,
              itemBuilder: (context, index) {
                final n = state.notifications[index];
                return _NotificationTile(
                  notification: n,
                  currentUid: currentUid,
                  relativeTime: _relativeTime(n.createdAt),
                );
              },
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.currentUid,
    required this.relativeTime,
  });

  final NotificationEntity notification;
  final String currentUid;
  final String relativeTime;

  String get _titleText {
    if (notification.type == 'like') {
      return '${notification.actorDisplayName} liked your post';
    }
    return '${notification.actorDisplayName} started following you';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = notification.read
        ? Colors.transparent
        : Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3);

    return Container(
      color: backgroundColor,
      child: ListTile(
        leading: AvatarWidget(
          displayName: notification.actorDisplayName,
          avatarUrl: notification.actorAvatarUrl,
          radius: 20,
        ),
        title: Text(_titleText),
        trailing: Text(
          relativeTime,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: () {
          if (!notification.read) {
            context.read<NotificationsBloc>().add(
                  NotificationReadRequested(
                    uid: currentUid,
                    notificationId: notification.id,
                  ),
                );
          }
        },
      ),
    );
  }
}
