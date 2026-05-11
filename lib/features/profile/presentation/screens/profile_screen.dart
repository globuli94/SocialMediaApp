// lib/features/profile/presentation/screens/profile_screen.dart
//
// ProfileScreen — displays a user profile fetched from Firestore.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';
import 'package:social_network/features/profile/presentation/widgets/avatar_widget.dart';

/// Screen that displays a user profile.
///
/// If [uid] is `null`, the currently authenticated user's profile is shown and
/// an "Edit Profile" button is rendered. When [uid] is provided and differs
/// from the signed-in user, the screen is read-only.
class ProfileScreen extends StatefulWidget {
  /// Creates a [ProfileScreen].
  ///
  /// Pass [uid] to view another user's profile. Omit [uid] (or pass `null`)
  /// to view the current user's own profile.
  const ProfileScreen({super.key, this.uid});

  /// The UID of the profile to display. `null` means the current user.
  final String? uid;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _resolvedUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authState = context.read<AuthBloc>().state;
    final currentUid =
        authState is AuthAuthenticated ? authState.user.uid : null;
    final targetUid = widget.uid ?? currentUid;

    // Load profile on first resolution or when the target UID changes.
    if (targetUid != null && targetUid != _resolvedUid) {
      _resolvedUid = targetUid;
      context.read<ProfileBloc>().add(ProfileLoadRequested(uid: targetUid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUid =
        authState is AuthAuthenticated ? authState.user.uid : null;
    final isOwnProfile = widget.uid == null || widget.uid == currentUid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (isOwnProfile) ...[
            TextButton(
              onPressed: () => context.push('/profile/edit'),
              child: const Text('Edit'),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
              onPressed: () =>
                  context.read<AuthBloc>().add(const AuthSignOutRequested()),
            ),
          ],
        ],
      ),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (BuildContext context, ProfileState state) {
          return switch (state) {
            ProfileInitial() || ProfileLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            ProfileLoaded(:final profile) ||
            ProfileUpdating(:final profile) =>
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AvatarWidget(
                      displayName: profile.displayName,
                      avatarUrl: profile.avatarUrl,
                      radius: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    if (profile.bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        profile.bio,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    _StatChip(label: 'Posts', value: profile.postCount),
                    if (state is ProfileUpdating) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ProfileFailure(:final error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load profile.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(error),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (_resolvedUid != null) {
                            context.read<ProfileBloc>().add(
                                  ProfileLoadRequested(uid: _resolvedUid!),
                                );
                          }
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
          };
        },
      ),
    );
  }
}

/// Small chip that displays a stat label and numeric value.
class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  /// Label shown below the numeric value.
  final String label;

  /// Numeric count to display.
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
