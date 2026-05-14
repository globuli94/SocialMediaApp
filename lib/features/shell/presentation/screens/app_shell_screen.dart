// lib/features/shell/presentation/screens/app_shell_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/feed/presentation/screens/feed_screen.dart';
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

  static const List<Widget> _screens = [
    FeedScreen(),
    SearchScreen(),
    ProfileScreen(),
  ];

  static const int _profileTabIndex = 2;

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
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
