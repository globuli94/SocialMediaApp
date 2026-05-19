// lib/features/notifications/presentation/bloc/unread_count_cubit.dart

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/notifications/data/repositories/notification_repository.dart';

/// Cubit that tracks the number of unread notifications for the current user.
///
/// Call [startWatching] once the user's UID is known (typically after
/// authentication). The cubit is designed to be provided globally in
/// [main.dart] and started from the auth-state listener, mirroring the
/// ConversationsBloc pattern.
class UnreadCountCubit extends Cubit<int> {
  UnreadCountCubit({required NotificationRepository notificationRepository})
      : _repository = notificationRepository,
        super(0);

  final NotificationRepository _repository;
  StreamSubscription<int>? _subscription;

  /// Subscribes to the unread notification count for [uid].
  ///
  /// Cancels any existing subscription before starting a new one.
  void startWatching(String uid) {
    _subscription?.cancel();
    _subscription = _repository.unreadCount(uid).listen(
      emit,
      onError: (_) => emit(0),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
