// lib/features/notifications/presentation/bloc/notification_state.dart

import 'package:equatable/equatable.dart';
import 'package:social_network/features/notifications/domain/entities/notification_model.dart';

/// Base class for all notification states.
sealed class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any subscription has started.
final class NotificationsInitial extends NotificationState {
  const NotificationsInitial();
}

/// Subscription started; waiting for the first snapshot.
final class NotificationsLoading extends NotificationState {
  const NotificationsLoading();
}

/// Notifications loaded successfully.
final class NotificationsLoaded extends NotificationState {
  const NotificationsLoaded({required this.notifications});

  final List<NotificationModel> notifications;

  @override
  List<Object?> get props => [notifications];
}

/// An error occurred while loading notifications.
final class NotificationsError extends NotificationState {
  const NotificationsError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
