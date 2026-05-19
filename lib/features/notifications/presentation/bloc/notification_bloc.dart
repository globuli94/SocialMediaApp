// lib/features/notifications/presentation/bloc/notification_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/notifications/data/repositories/notification_repository.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_event.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_state.dart';

/// BLoC that manages the notifications list for the current user.
///
/// [NotificationsSubscribed] opens a real-time Firestore stream via
/// [Emitter.forEach]. [NotificationTapped] writes `isRead = true` to
/// Firestore; the stream update will automatically refresh the loaded state.
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc({required NotificationRepository notificationRepository})
      : _repository = notificationRepository,
        super(const NotificationsInitial()) {
    on<NotificationsSubscribed>(_onSubscribed);
    on<NotificationTapped>(_onTapped);
  }

  final NotificationRepository _repository;

  Future<void> _onSubscribed(
    NotificationsSubscribed event,
    Emitter<NotificationState> emit,
  ) async {
    emit(const NotificationsLoading());
    await emit.forEach(
      _repository.notifications(event.uid),
      onData: (notifications) =>
          NotificationsLoaded(notifications: notifications),
      onError: (e, _) => NotificationsError(message: e.toString()),
    );
  }

  Future<void> _onTapped(
    NotificationTapped event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _repository.markAsRead(event.uid, event.notificationId);
      // Stream subscription in _onSubscribed will emit a new NotificationsLoaded
      // once the Firestore document is updated.
    } catch (_) {
      // Silently ignore mark-as-read errors; UX is not critically impacted.
    }
  }
}
