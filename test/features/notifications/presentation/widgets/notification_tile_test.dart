// test/features/notifications/presentation/widgets/notification_tile_test.dart
//
// Widget tests for NotificationTile — verifies rendering of notification
// content, unread state visual distinction, and tap behavior.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/notifications/domain/entities/notification_model.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_event.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_state.dart';
import 'package:social_network/features/notifications/presentation/widgets/notification_tile.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockNotificationBloc extends Mock implements NotificationBloc {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildTile({
  required NotificationModel notification,
  required String uid,
  required MockNotificationBloc mockBloc,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<NotificationBloc>.value(
        value: mockBloc,
        child: NotificationTile(
          notification: notification,
          uid: uid,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(const NotificationTapped(uid: '', notificationId: ''));
  });

  group('NotificationTile', () {
    // -------------------------------------------------------------------------
    // Actor display name and body text
    // -------------------------------------------------------------------------

    group('Renders notification content correctly', () {
      testWidgets('renders actor display name and "liked your post" for like notifications',
          (tester) async {
        final mockBloc = MockNotificationBloc();
        when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());

        final notif = NotificationModel(
          id: 'notif-1',
          type: 'like',
          actorUid: 'uid-bob',
          actorDisplayName: 'Bob Smith',
          postId: 'post-123',
          isRead: false,
          createdAt: DateTime(2026, 5, 20, 10, 0),
        );

        await tester.pumpWidget(_buildTile(
          notification: notif,
          uid: 'uid-alice',
          mockBloc: mockBloc,
        ));

        expect(find.text('Bob Smith'), findsWidgets);
        expect(find.text('liked your post'), findsOneWidget);
      });

    });

    // -------------------------------------------------------------------------
    // Unread vs read visual distinction
    // -------------------------------------------------------------------------

    group('Unread vs read visual distinction', () {
      testWidgets('unread tile has visually distinct background',
          (tester) async {
        final mockBloc = MockNotificationBloc();
        when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());

        final notif = NotificationModel(
          id: 'notif-3',
          type: 'like',
          actorUid: 'uid-henry',
          actorDisplayName: 'Henry',
          postId: 'post-111',
          isRead: false,
          createdAt: DateTime(2026, 5, 20),
        );

        await tester.pumpWidget(_buildTile(
          notification: notif,
          uid: 'uid-alice',
          mockBloc: mockBloc,
        ));

        // Find the tile's container with background color
        final containerFinder = find.byType(Container);
        expect(containerFinder, findsWidgets);

        // Verify that there is at least one Container with a non-null color
        bool foundUnreadBackground = false;
        for (final widget in containerFinder.evaluate()) {
          final container = widget.widget as Container;
          if (container.color != null) {
            foundUnreadBackground = true;
            break;
          }
        }
        expect(foundUnreadBackground, true,
            reason: 'unread tile should have a container with background color');
      });

    });

    // -------------------------------------------------------------------------
    // Tap behavior for unread notifications
    // -------------------------------------------------------------------------

    group('Tap behavior', () {
      testWidgets('dispatches NotificationTapped event when unread tile is tapped',
          (tester) async {
        final mockBloc = MockNotificationBloc();
        when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
        when(() => mockBloc.add(any())).thenReturn(null);

        final notif = NotificationModel(
          id: 'notif-5',
          type: 'like',
          actorUid: 'uid-jack',
          actorDisplayName: 'Jack',
          postId: 'post-222',
          isRead: false,
          createdAt: DateTime(2026, 5, 20),
        );

        await tester.pumpWidget(_buildTile(
          notification: notif,
          uid: 'uid-alice',
          mockBloc: mockBloc,
        ));

        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(
            const NotificationTapped(
              uid: 'uid-alice',
              notificationId: 'notif-5',
            ),
          ),
        ).called(1);
      });

      testWidgets('does not dispatch event for read tile when tapped',
          (tester) async {
        final mockBloc = MockNotificationBloc();
        when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());

        final notif = NotificationModel(
          id: 'notif-6',
          type: 'follow',
          actorUid: 'uid-kate',
          actorDisplayName: 'Kate',
          postId: null,
          isRead: true,
          createdAt: DateTime(2026, 5, 20),
        );

        await tester.pumpWidget(_buildTile(
          notification: notif,
          uid: 'uid-bob',
          mockBloc: mockBloc,
        ));

        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        verifyNever(
          () => mockBloc.add(any()),
        );
      });
    });
  });
}
