// test/features/notifications/presentation/bloc/unread_count_cubit_test.dart
//
// Unit tests for UnreadCountCubit — verifies initial state and startWatching behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/notifications/data/repositories/notification_repository.dart';
import 'package:social_network/features/notifications/presentation/bloc/unread_count_cubit.dart';

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

  setUp(() {
    mockRepository = MockNotificationRepository();
  });

  group('UnreadCountCubit', () {
    // -------------------------------------------------------------------------
    // Initial state
    // -------------------------------------------------------------------------

    group('Initial state', () {
      test('initial state is 0', () {
        final cubit = UnreadCountCubit(notificationRepository: mockRepository);
        expect(cubit.state, 0);
      });
    });

    // -------------------------------------------------------------------------
    // startWatching
    // -------------------------------------------------------------------------

    group('startWatching', () {
      test('calls unreadCount on repository with correct uid', () {
        when(() => mockRepository.unreadCount('uid-alice'))
            .thenAnswer((_) => Stream.value(5));

        final cubit = UnreadCountCubit(notificationRepository: mockRepository);
        cubit.startWatching('uid-alice');

        verify(
          () => mockRepository.unreadCount('uid-alice'),
        ).called(1);
      });

      test('emits updated count when repository stream emits', () async {
        when(() => mockRepository.unreadCount('uid-bob'))
            .thenAnswer((_) => Stream.value(3));

        final cubit = UnreadCountCubit(notificationRepository: mockRepository);
        cubit.startWatching('uid-bob');

        // Give the stream subscription time to emit
        await Future.delayed(const Duration(milliseconds: 100));

        expect(cubit.state, 3);
      });

      test('emits 0 when all notifications are read', () async {
        when(() => mockRepository.unreadCount('uid-charlie'))
            .thenAnswer((_) => Stream.value(0));

        final cubit = UnreadCountCubit(notificationRepository: mockRepository);
        cubit.startWatching('uid-charlie');

        await Future.delayed(const Duration(milliseconds: 100));

        expect(cubit.state, 0);
      });
    });
  });
}
