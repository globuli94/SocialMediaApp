// lib/features/notifications/presentation/bloc/notifications_event.dart
//
// NotificationsBloc events.

import 'package:equatable/equatable.dart';

/// Base class for all notifications events.
abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => [];
}

/// Starts streaming notifications for the given [uid].
class NotificationsWatchStarted extends NotificationsEvent {
  /// Creates a [NotificationsWatchStarted].
  const NotificationsWatchStarted(this.uid);

  /// UID of the currently authenticated user.
  final String uid;

  @override
  List<Object?> get props => [uid];
}

/// Marks a single notification as read.
class NotificationReadRequested extends NotificationsEvent {
  /// Creates a [NotificationReadRequested].
  const NotificationReadRequested({
    required this.uid,
    required this.notificationId,
  });

  /// UID of the notification owner.
  final String uid;

  /// ID of the notification document to mark as read.
  final String notificationId;

  @override
  List<Object?> get props => [uid, notificationId];
}
