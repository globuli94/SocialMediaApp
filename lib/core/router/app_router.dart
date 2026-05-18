// lib/core/router/app_router.dart
//
// AppRouter — go_router configuration with auth redirect guard.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/features/auth/domain/repositories/auth_repository.dart';
import 'package:social_network/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:social_network/features/auth/presentation/screens/login_screen.dart';
import 'package:social_network/features/auth/presentation/screens/signup_screen.dart';
import 'package:social_network/features/chat/domain/repositories/chat_repository.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:social_network/features/chat/presentation/screens/chat_screen.dart';
import 'package:social_network/features/chat/presentation/screens/conversations_screen.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_bloc.dart';
import 'package:social_network/features/notifications/domain/repositories/notification_repository.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_bloc.dart';
import 'package:social_network/features/follow/presentation/screens/followers_screen.dart';
import 'package:social_network/features/follow/presentation/screens/following_screen.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/screens/create_post_screen.dart';
import 'package:social_network/features/profile/domain/repositories/profile_repository.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:social_network/features/profile/presentation/screens/profile_screen.dart';
import 'package:social_network/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:social_network/features/shell/presentation/screens/app_shell_screen.dart';

/// A [ChangeNotifier] that triggers a router refresh whenever the auth stream
/// emits a new value.
class GoRouterRefreshStream extends ChangeNotifier {
  /// Creates a [GoRouterRefreshStream] subscribed to [stream].
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Creates the application [GoRouter] with an authentication redirect guard.
///
/// - Unauthenticated users are redirected to `/login`.
/// - Authenticated users accessing `/login`, `/signup`, or `/forgot-password`
///   are redirected to `/home`.
GoRouter createRouter({required AuthRepository authRepository}) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable:
        GoRouterRefreshStream(authRepository.authStateChanges),
    redirect: (BuildContext context, GoRouterState state) {
      final bool isLoggedIn = authRepository.currentUser != null;
      final String location = state.matchedLocation;

      final bool isAuthRoute = location == '/login' ||
          location == '/signup' ||
          location == '/forgot-password';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (BuildContext context, GoRouterState state) =>
            const SignUpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (BuildContext context, GoRouterState state) =>
            const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (BuildContext context, GoRouterState state) =>
            const AppShellScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (BuildContext context, GoRouterState state) =>
            const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/:uid',
        builder: (BuildContext context, GoRouterState state) {
          final uid = state.pathParameters['uid']!;
          return MultiBlocProvider(
            providers: [
              BlocProvider<ProfileBloc>(
                create: (_) => ProfileBloc(
                  profileRepository: context.read<ProfileRepository>(),
                ),
              ),
              BlocProvider<FollowBloc>(
                create: (_) => FollowBloc(
                  followRepository: context.read<FollowRepository>(),
                  notificationRepository:
                      context.read<NotificationRepository>(),
                ),
              ),
              BlocProvider<PostBloc>(
                create: (_) => PostBloc(
                  postRepository: context.read<PostRepository>(),
                ),
              ),
            ],
            child: ProfileScreen(uid: uid),
          );
        },
        routes: [
          GoRoute(
            path: 'followers',
            builder: (BuildContext context, GoRouterState state) {
              final uid = state.pathParameters['uid']!;
              return BlocProvider<FollowListBloc>(
                create: (_) => FollowListBloc(
                  followRepository: context.read<FollowRepository>(),
                ),
                child: FollowersScreen(uid: uid),
              );
            },
          ),
          GoRoute(
            path: 'following',
            builder: (BuildContext context, GoRouterState state) {
              final uid = state.pathParameters['uid']!;
              return BlocProvider<FollowListBloc>(
                create: (_) => FollowListBloc(
                  followRepository: context.read<FollowRepository>(),
                ),
                child: FollowingScreen(uid: uid),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/notifications',
        builder: (BuildContext context, GoRouterState state) =>
            const NotificationsScreen(),
      ),
      GoRoute(
        path: '/post/create',
        builder: (BuildContext context, GoRouterState state) =>
            const CreatePostScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (BuildContext context, GoRouterState state) =>
            const ConversationsScreen(),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (BuildContext context, GoRouterState state) {
          final conversationId = state.pathParameters['conversationId']!;
          final extra = state.extra as Map<String, String>;
          return BlocProvider<ChatBloc>(
            create: (_) => ChatBloc(
              chatRepository: context.read<ChatRepository>(),
            ),
            child: ChatScreen(
              conversationId: conversationId,
              currentUid: extra['currentUid']!,
              recipientUid: extra['recipientUid']!,
            ),
          );
        },
      ),
    ],
  );
}
