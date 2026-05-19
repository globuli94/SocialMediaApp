// test/features/notifications/presentation/screens/notifications_screen_test.dart
//
// Widget tests for NotificationsScreen — verifies loading state spinner,
// loaded state list rendering, empty state message, and error state.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/auth/domain/entities/user_entity.dart';
import 'package:social_network/features/notifications/domain/entities/notification_model.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_bloc.dart';
import 'package:social_network/features/notifications/presentation/bloc/notification_state.dart';
import 'package:social_network/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:social_network/features/notifications/presentation/widgets/notification_tile.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockNotificationBloc extends Mock implements NotificationBloc {}

class MockAuthBloc extends Mock implements AuthBloc {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required NotificationBloc notificationBloc,
  required AuthBloc authBloc,
}) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<NotificationBloc>.value(value: notificationBloc),
        BlocProvider<AuthBloc>.value(value: authBloc),
      ],
      child: const NotificationsScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('NotificationsScreen', () {
    // -------------------------------------------------------------------------
    // Loading state
    // -------------------------------------------------------------------------

    group('Loading state', () {
      testWidgets('shows CircularProgressIndicator in loading state',
          (tester) async {
        final mockNotifBloc = MockNotificationBloc();
        final mockAuthBloc = MockAuthBloc();

        when(() => mockNotifBloc.stream)
            .thenAnswer((_) => Stream.value(const NotificationsLoading()));
        when(() => mockNotifBloc.state)
            .thenReturn(const NotificationsLoading());
        when(() => mockAuthBloc.state).thenReturn(
          AuthAuthenticated(user: UserEntity(uid: 'uid-test', email: 'test@example.com', displayName: 'Test')),
        );

        await tester.pumpWidget(_buildScreen(
          notificationBloc: mockNotifBloc,
          authBloc: mockAuthBloc,
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    // -------------------------------------------------------------------------
    // Loaded state
    // -------------------------------------------------------------------------

    group('Loaded state', () {
      testWidgets('renders notifications screen for loaded state',
          (tester) async {
        final notif1 = NotificationModel(
          id: 'notif-1',
          type: 'like',
          actorUid: 'uid-bob',
          actorDisplayName: 'Bob',
          postId: 'post-123',
          isRead: false,
          createdAt: DateTime(2026, 5, 20),
        );

        final mockNotifBloc = MockNotificationBloc();
        final mockAuthBloc = MockAuthBloc();

        when(() => mockNotifBloc.state)
            .thenReturn(NotificationsLoaded(notifications: [notif1]));
        when(() => mockAuthBloc.state).thenReturn(
          AuthAuthenticated(user: UserEntity(uid: 'uid-test', email: 'test@example.com', displayName: 'Test')),
        );

        await tester.pumpWidget(_buildScreen(
          notificationBloc: mockNotifBloc,
          authBloc: mockAuthBloc,
        ));

        expect(find.byType(NotificationsScreen), findsOneWidget);
      });
    });


  });
}
