// test/features/notifications/presentation/bloc/notification_bloc_test.dart
//
// Unit tests for NotificationBloc — verifies NotificationsSubscribed event
// handling, stream-to-state emission, NotificationTapped event handling,
// and error handling.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/notifications/data/repositories/notification_repository.dart';
import 'package:social_network/features/notifications/domain/entities/notification_model.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_event.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockNotificationRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(const NotificationsSubscribed(''));
    registerFallbackValue(const NotificationTapped(
      uid: '',
      notificationId: '',
    ));
  });

  setUp(() {
    mockRepository = MockNotificationRepository();
  });

  group('NotificationBloc', () {
    // -------------------------------------------------------------------------
    // NotificationsSubscribed
    // -------------------------------------------------------------------------

    group('NotificationsSubscribed', () {
      blocTest<NotificationBloc, NotificationState>(
        'emits [NotificationsLoading, NotificationsLoaded] '
        'when repository stream emits notifications',
        setUp: () {
          final mockNotif = NotificationModel(
            id: 'notif-1',
            type: 'like',
            actorUid: 'uid-bob',
            actorDisplayName: 'Bob',
            actorAvatarUrl: 'https://example.com/bob.jpg',
            postId: 'post-123',
            isRead: false,
            createdAt: DateTime(2026, 5, 20, 10, 0),
          );
          when(() => mockRepository.notifications('uid-alice'))
              .thenAnswer((_) => Stream.value([mockNotif]));
        },
        build: () => NotificationBloc(notificationRepository: mockRepository),
        act: (bloc) => bloc.add(const NotificationsSubscribed('uid-alice')),
        expect: () => [
          const NotificationsLoading(),
          isA<NotificationsLoaded>()
              .having((s) => s.notifications, 'notifications', hasLength(1))
              .having((s) => s.notifications.first.id, 'first notif id',
                  'notif-1'),
        ],
        verify: (_) => verify(
          () => mockRepository.notifications('uid-alice'),
        ).called(1),
      );

      blocTest<NotificationBloc, NotificationState>(
        'emits NotificationsLoaded with empty list when stream emits empty',
        setUp: () {
          when(() => mockRepository.notifications('uid-bob'))
              .thenAnswer((_) => Stream.value([]));
        },
        build: () => NotificationBloc(notificationRepository: mockRepository),
        act: (bloc) => bloc.add(const NotificationsSubscribed('uid-bob')),
        expect: () => [
          const NotificationsLoading(),
          isA<NotificationsLoaded>()
              .having((s) => s.notifications, 'notifications', isEmpty),
        ],
      );

      blocTest<NotificationBloc, NotificationState>(
        'emits NotificationsLoaded with correct list from repository stream',
        setUp: () {
          final notif1 = NotificationModel(
            id: 'notif-1',
            type: 'follow',
            actorUid: 'uid-alice',
            actorDisplayName: 'Alice',
            postId: null,
            isRead: false,
            createdAt: DateTime(2026, 5, 20),
          );
          final notif2 = NotificationModel(
            id: 'notif-2',
            type: 'like',
            actorUid: 'uid-bob',
            actorDisplayName: 'Bob',
            postId: 'post-456',
            isRead: true,
            createdAt: DateTime(2026, 5, 21),
          );
          when(() => mockRepository.notifications('uid-charlie'))
              .thenAnswer((_) => Stream.value([notif2, notif1]));
        },
        build: () => NotificationBloc(notificationRepository: mockRepository),
        act: (bloc) =>
            bloc.add(const NotificationsSubscribed('uid-charlie')),
        expect: () => [
          const NotificationsLoading(),
          isA<NotificationsLoaded>()
              .having((s) => s.notifications, 'notifications', hasLength(2))
              .having((s) => s.notifications[0].id, 'first notif id', 'notif-2')
              .having((s) => s.notifications[1].id, 'second notif id', 'notif-1'),
        ],
      );

      blocTest<NotificationBloc, NotificationState>(
        'emits [NotificationsLoading, NotificationsError] '
        'when repository stream errors',
        setUp: () {
          when(() => mockRepository.notifications('uid-error'))
              .thenAnswer((_) =>
                  Stream.error(Exception('firestore connection error')));
        },
        build: () => NotificationBloc(notificationRepository: mockRepository),
        act: (bloc) =>
            bloc.add(const NotificationsSubscribed('uid-error')),
        expect: () => [
          const NotificationsLoading(),
          isA<NotificationsError>(),
        ],
      );
    });

    // -------------------------------------------------------------------------
    // NotificationTapped
    // -------------------------------------------------------------------------

    group('NotificationTapped', () {
      blocTest<NotificationBloc, NotificationState>(
        'calls markAsRead on repository when notification is tapped',
        setUp: () {
          when(() => mockRepository.notifications('uid-dave'))
              .thenAnswer((_) => Stream.value([]));
          when(() =>
                  mockRepository.markAsRead('uid-dave', 'notif-to-mark'))
              .thenAnswer((_) => Future.value());
        },
        build: () => NotificationBloc(notificationRepository: mockRepository),
        act: (bloc) async {
          bloc.add(const NotificationsSubscribed('uid-dave'));
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(const NotificationTapped(
            uid: 'uid-dave',
            notificationId: 'notif-to-mark',
          ));
        },
        verify: (_) => verify(
          () => mockRepository.markAsRead('uid-dave', 'notif-to-mark'),
        ).called(1),
      );

      blocTest<NotificationBloc, NotificationState>(
        'marks correct notification as read (not others)',
        setUp: () {
          final notif1 = NotificationModel(
            id: 'notif-1',
            type: 'follow',
            actorUid: 'uid-alice',
            actorDisplayName: 'Alice',
            postId: null,
            isRead: false,
            createdAt: DateTime(2026, 5, 20),
          );
          when(() => mockRepository.notifications('uid-eve'))
              .thenAnswer((_) => Stream.value([notif1]));
          when(() =>
                  mockRepository.markAsRead('uid-eve', 'notif-1'))
              .thenAnswer((_) => Future.value());
        },
        build: () => NotificationBloc(notificationRepository: mockRepository),
        act: (bloc) async {
          bloc.add(const NotificationsSubscribed('uid-eve'));
          await Future.delayed(const Duration(milliseconds: 100));
          bloc.add(const NotificationTapped(
            uid: 'uid-eve',
            notificationId: 'notif-1',
          ));
        },
        verify: (_) => verify(
          () => mockRepository.markAsRead('uid-eve', 'notif-1'),
        ).called(1),
      );
    });

    // -------------------------------------------------------------------------
    // Stream updates
    // -------------------------------------------------------------------------

    group('Stream updates', () {
      blocTest<NotificationBloc, NotificationState>(
        'emits multiple NotificationsLoaded states as repository stream updates',
        setUp: () {
          final controller = StreamController<List<NotificationModel>>();
          when(() => mockRepository.notifications('uid-frank'))
              .thenAnswer((_) => controller.stream);

          Future.microtask(() async {
            // Emit first list
            final notif1 = NotificationModel(
              id: 'notif-1',
              type: 'follow',
              actorUid: 'uid-alice',
              actorDisplayName: 'Alice',
              postId: null,
              isRead: false,
              createdAt: DateTime(2026, 5, 20),
            );
            controller.add([notif1]);

            await Future<void>.delayed(const Duration(milliseconds: 50));

            // Emit second list with additional notification
            final notif2 = NotificationModel(
              id: 'notif-2',
              type: 'like',
              actorUid: 'uid-bob',
              actorDisplayName: 'Bob',
              postId: 'post-123',
              isRead: false,
              createdAt: DateTime(2026, 5, 21),
            );
            controller.add([notif2, notif1]);
          });
        },
        build: () => NotificationBloc(notificationRepository: mockRepository),
        act: (bloc) async {
          bloc.add(const NotificationsSubscribed('uid-frank'));
          await Future.delayed(const Duration(milliseconds: 200));
        },
        expect: () => [
          const NotificationsLoading(),
          isA<NotificationsLoaded>()
              .having((s) => s.notifications, 'notifications', hasLength(1)),
          isA<NotificationsLoaded>()
              .having((s) => s.notifications, 'notifications', hasLength(2)),
        ],
      );
    });
  });
}
