// lib/features/notifications/presentation/bloc/notifications_state.dart
//
// NotificationsBloc states.

import 'package:equatable/equatable.dart';
import 'package:social_network/features/notifications/domain/entities/notification_entity.dart';

/// Base class for all notifications states.
abstract class NotificationsState extends Equatable {
  const NotificationsState();

  @override
  List<Object?> get props => [];
}

/// Initial state before the stream has been started.
class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

/// Notifications have been loaded (may be empty).
class NotificationsLoaded extends NotificationsState {
  const NotificationsLoaded(this.notifications);

  final List<NotificationEntity> notifications;

  /// Number of notifications the user has not yet read.
  int get unreadCount => notifications.where((n) => !n.read).length;

  @override
  List<Object?> get props => [notifications];
}

/// A streaming or read error occurred.
class NotificationsError extends NotificationsState {
  const NotificationsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
