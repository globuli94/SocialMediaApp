// lib/features/notifications/presentation/bloc/notification_event.dart

import 'package:equatable/equatable.dart';

/// Base class for all notification events.
sealed class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

/// Starts a real-time subscription to [uid]'s notifications.
final class NotificationsSubscribed extends NotificationEvent {
  const NotificationsSubscribed(this.uid);

  final String uid;

  @override
  List<Object?> get props => [uid];
}

/// Marks [notificationId] as read for [uid].
final class NotificationTapped extends NotificationEvent {
  const NotificationTapped({required this.uid, required this.notificationId});

  final String uid;
  final String notificationId;

  @override
  List<Object?> get props => [uid, notificationId];
}
