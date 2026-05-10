// lib/features/auth/presentation/screens/home_screen.dart
//
// HomeScreen — placeholder guarded home screen for authenticated users.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';

/// Placeholder home screen shown to authenticated users.
///
/// Contains only an [AppBar] with a sign-out action; the feed and other
/// features will be added in subsequent tickets.
class HomeScreen extends StatelessWidget {
  /// Creates a [HomeScreen].
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthSignOutRequested()),
          ),
        ],
      ),
      body: const Center(
        child: Text('Welcome to Social Network!'),
      ),
    );
  }
}
