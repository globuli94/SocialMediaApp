// lib/features/shell/presentation/screens/app_shell_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_bloc.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_state.dart';
import 'package:social_network/features/chat/presentation/screens/conversations_screen.dart';
import 'package:social_network/features/feed/presentation/screens/feed_screen.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:social_network/features/notifications/presentation/bloc/notifications_state.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/screens/profile_screen.dart';
import 'package:social_network/features/search/presentation/screens/search_screen.dart';

/// Persistent app shell with a bottom [NavigationBar] (Material 3).
///
/// Uses [IndexedStack] so each tab's state is preserved across switches.
class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _selectedIndex = 0;

  // Tab order: Feed (0), Search (1), Messages (2), Profile (3).
  static const int _profileTabIndex = 3;

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    // Re-watch the signed-in user's own profile whenever the Profile tab is
    // activated. This prevents a stale watch (set while viewing another user's
    // profile via a pushed route) from persisting on this tab.
    if (index == _profileTabIndex) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        context
            .read<ProfileBloc>()
            .add(ProfileWatchRequested(uid: authState.user.uid));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social Network'),
        actions: const [_NotificationBellIcon()],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const FeedScreen(),
          const SearchScreen(),
          const ConversationsScreen(),
          // Provide a dedicated PostBloc for the profile tab so that
          // PostsByAuthorWatchStarted does not interfere with the global
          // PostBloc used by FeedScreen.
          BlocProvider<PostBloc>(
            create: (context) => PostBloc(
              postRepository: context.read<PostRepository>(),
            ),
            child: const ProfileScreen(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Feed',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: _ChatBadgeIcon(isSelected: false),
            selectedIcon: _ChatBadgeIcon(isSelected: true),
            label: 'Messages',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Bell icon that shows an unread badge when there are unseen notifications.
class _NotificationBellIcon extends StatelessWidget {
  const _NotificationBellIcon();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      builder: (context, state) {
        final unread =
            state is NotificationsLoaded ? state.unreadCount : 0;
        final icon = IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => context.go('/notifications'),
        );
        if (unread > 0) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Badge(
              label: Text('$unread'),
              child: icon,
            ),
          );
        }
        return icon;
      },
    );
  }
}

/// Chat icon that shows a red [Badge] when there are unread messages.
class _ChatBadgeIcon extends StatelessWidget {
  const _ChatBadgeIcon({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConversationsBloc, ConversationsState>(
      builder: (context, state) {
        final totalUnread =
            state is ConversationsLoaded ? state.totalUnread : 0;
        final icon = Icon(
          isSelected ? Icons.chat : Icons.chat_outlined,
        );
        if (totalUnread > 0) {
          return Badge(
            label: Text('$totalUnread'),
            child: icon,
          );
        }
        return icon;
      },
    );
  }
}
