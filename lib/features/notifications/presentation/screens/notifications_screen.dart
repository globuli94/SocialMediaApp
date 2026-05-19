// lib/features/notifications/presentation/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_event.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_state.dart';
import 'package:social_network/features/notifications/presentation/widgets/notification_tile.dart';

/// Screen that displays the current user's notification feed.
///
/// [NotificationBloc] is provided one level above this screen (in the route
/// builder in app_router.dart) and is already seeded with a
/// [NotificationsSubscribed] event. This screen only consumes the bloc.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final uid =
        authState is AuthAuthenticated ? authState.user.uid : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          return switch (state) {
            NotificationsInitial() ||
            NotificationsLoading() =>
              const Center(child: CircularProgressIndicator()),
            NotificationsLoaded(:final notifications) => notifications.isEmpty
                ? const Center(child: Text('No notifications yet'))
                : ListView.separated(
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) => NotificationTile(
                      notification: notifications[index],
                      uid: uid,
                    ),
                  ),
            NotificationsError(:final message) => Center(
                child: Text('Error: $message'),
              ),
          };
        },
      ),
    );
  }
}
