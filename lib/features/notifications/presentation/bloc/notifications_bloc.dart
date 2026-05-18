// lib/features/notifications/presentation/bloc/notifications_bloc.dart
//
// NotificationsBloc — streams the current user's notifications.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/notifications/domain/entities/notification_entity.dart';
import 'package:social_network/features/notifications/domain/repositories/notification_repository.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_event.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_state.dart';

/// Manages the real-time notifications list for the authenticated user.
///
/// Mirrors the [ConversationsBloc] pattern: [NotificationsWatchStarted] starts
/// the stream via [Emitter.forEach]; [NotificationReadRequested] performs a
/// one-shot write.
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  /// Creates a [NotificationsBloc].
  NotificationsBloc({required NotificationRepository notificationRepository})
      : _repository = notificationRepository,
        super(const NotificationsInitial()) {
    on<NotificationsWatchStarted>(_onWatchStarted);
    on<NotificationReadRequested>(_onReadRequested);
  }

  final NotificationRepository _repository;

  Future<void> _onWatchStarted(
    NotificationsWatchStarted event,
    Emitter<NotificationsState> emit,
  ) async {
    await emit.forEach<List<NotificationEntity>>(
      _repository.watchNotifications(event.uid),
      onData: (notifications) => NotificationsLoaded(notifications),
      onError: (error, _) => NotificationsError(error.toString()),
    );
  }

  Future<void> _onReadRequested(
    NotificationReadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    try {
      await _repository.markAsRead(event.uid, event.notificationId);
    } catch (_) {
      // Silently ignore — a failed mark-as-read is non-critical.
    }
  }
}
