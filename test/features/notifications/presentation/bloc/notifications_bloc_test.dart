import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/notifications/domain/entities/notification_entity.dart';
import 'package:social_network/features/notifications/domain/repositories/notification_repository.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_event.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_state.dart';

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  group('NotificationsBloc', () {
    late MockNotificationRepository mockRepository;

    setUp(() {
      mockRepository = MockNotificationRepository();
    });

    group('NotificationsWatchStarted', () {
      blocTest<NotificationsBloc, NotificationsState>(
        'emits NotificationsLoaded with stream data',
        build: () {
          const uid = 'user123';
          final notifications = [
            NotificationEntity(
              id: 'notif1',
              type: 'like',
              actorUid: 'actor1',
              actorDisplayName: 'John Doe',
              actorAvatarUrl: 'https://example.com/avatar.jpg',
              postId: 'post1',
              read: false,
              createdAt: DateTime.now(),
            ),
          ];

          when(() => mockRepository.watchNotifications(uid))
              .thenAnswer((_) => Stream.value(notifications));

          return NotificationsBloc(notificationRepository: mockRepository);
        },
        act: (bloc) => bloc.add(const NotificationsWatchStarted('user123')),
        expect: () => [
          isA<NotificationsLoaded>()
              .having(
                (state) => state.notifications.length,
                'notification count',
                1,
              )
              .having(
                (state) => state.notifications[0].type,
                'notification type',
                'like',
              ),
        ],
      );
    });

    group('NotificationReadRequested', () {
      test('calls markAsRead on repository with correct parameters', () async {
        const uid = 'user123';
        const notificationId = 'notif456';

        when(
          () => mockRepository.markAsRead(uid, notificationId),
        ).thenAnswer((_) async {});

        when(() => mockRepository.watchNotifications(uid))
            .thenAnswer((_) => Stream.value(const []));

        final bloc = NotificationsBloc(notificationRepository: mockRepository);

        bloc.add(const NotificationReadRequested(
          uid: uid,
          notificationId: notificationId,
        ));

        await Future.delayed(const Duration(milliseconds: 100));

        verify(
          () => mockRepository.markAsRead(uid, notificationId),
        ).called(1);

        bloc.close();
      });
    });

    group('unreadCount getter', () {
      test('returns correct count of unread notifications', () {
        final now = DateTime.now();
        final notifications = [
          NotificationEntity(
            id: 'notif1',
            type: 'like',
            actorUid: 'actor1',
            actorDisplayName: 'User One',
            read: false,
            createdAt: now,
          ),
          NotificationEntity(
            id: 'notif2',
            type: 'like',
            actorUid: 'actor2',
            actorDisplayName: 'User Two',
            read: false,
            createdAt: now,
          ),
          NotificationEntity(
            id: 'notif3',
            type: 'follow',
            actorUid: 'actor3',
            actorDisplayName: 'User Three',
            read: true,
            createdAt: now,
          ),
        ];

        final state = NotificationsLoaded(notifications);

        expect(state.unreadCount, 2);
      });
    });
  });
}
