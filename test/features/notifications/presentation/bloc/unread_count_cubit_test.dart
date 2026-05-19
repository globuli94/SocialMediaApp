// test/features/notifications/presentation/bloc/unread_count_cubit_test.dart
//
// Unit tests for UnreadCountCubit — verifies initial state, startWatching
// behavior, and stream emissions.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
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
      blocTest<UnreadCountCubit, int>(
        'emits updated count when repository stream emits',
        build: () {
          when(() => mockRepository.unreadCount('uid-alice'))
              .thenAnswer((_) => Stream.value(5));
          return UnreadCountCubit(notificationRepository: mockRepository);
        },
        act: (cubit) => cubit.startWatching('uid-alice'),
        expect: () => [5],
      );

      cubitTest<UnreadCountCubit, int>(
        'emits 0 when all notifications are read',
        build: () {
          when(() => mockRepository.unreadCount('uid-bob'))
              .thenAnswer((_) => Stream.value(0));
          return UnreadCountCubit(notificationRepository: mockRepository);
        },
        act: (cubit) => cubit.startWatching('uid-bob'),
        expect: () => [0],
      );

      cubitTest<UnreadCountCubit, int>(
        'emits multiple updates as repository stream updates',
        build: () {
          final controller = StreamController<int>();
          when(() => mockRepository.unreadCount('uid-charlie'))
              .thenAnswer((_) => controller.stream);

          Future.microtask(() async {
            controller.add(3);
            await Future<void>.delayed(const Duration(milliseconds: 50));
            controller.add(2);
            await Future<void>.delayed(const Duration(milliseconds: 50));
            controller.add(1);
            await Future<void>.delayed(const Duration(milliseconds: 50));
            controller.add(0);
          });

          return UnreadCountCubit(notificationRepository: mockRepository);
        },
        act: (cubit) async {
          cubit.startWatching('uid-charlie');
          await Future.delayed(const Duration(milliseconds: 250));
        },
        expect: () => [3, 2, 1, 0],
      );

      cubitTest<UnreadCountCubit, int>(
        'subscribes to unreadCount stream with correct uid',
        build: () {
          when(() => mockRepository.unreadCount('uid-dave'))
              .thenAnswer((_) => Stream.value(2));
          return UnreadCountCubit(notificationRepository: mockRepository);
        },
        act: (cubit) => cubit.startWatching('uid-dave'),
        verify: (_) => verify(
          () => mockRepository.unreadCount('uid-dave'),
        ).called(1),
      );

      cubitTest<UnreadCountCubit, int>(
        'emits correct count for different uids',
        build: () {
          when(() => mockRepository.unreadCount('uid-eve'))
              .thenAnswer((_) => Stream.value(7));
          when(() => mockRepository.unreadCount('uid-frank'))
              .thenAnswer((_) => Stream.value(3));
          return UnreadCountCubit(notificationRepository: mockRepository);
        },
        act: (cubit) async {
          // Start watching first user
          cubit.startWatching('uid-eve');
          // Give it time to emit
          await Future.delayed(const Duration(milliseconds: 100));
        },
        expect: () => [7],
      );
    });

    // -------------------------------------------------------------------------
    // Stream error handling
    // -------------------------------------------------------------------------

    group('Stream error handling', () {
      blocTest<UnreadCountCubit, int>(
        'maintains previous state when repository stream errors',
        build: () {
          when(() => mockRepository.unreadCount('uid-grace'))
              .thenAnswer((_) =>
                  Stream.error(Exception('firestore error')));
          return UnreadCountCubit(notificationRepository: mockRepository);
        },
        act: (cubit) => cubit.startWatching('uid-grace'),
        expect: () => [], // No emission on error
      );
    });
  });
}
