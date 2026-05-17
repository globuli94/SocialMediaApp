// lib/features/profile/presentation/screens/profile_screen.dart
//
// ProfileScreen — displays a user profile fetched from Firestore.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_bloc.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_state.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';
import 'package:social_network/features/profile/presentation/widgets/avatar_widget.dart';

/// Screen that displays a user profile.
///
/// If [uid] is `null`, the currently authenticated user's profile is shown and
/// an "Edit Profile" button is rendered. When [uid] is provided and differs
/// from the signed-in user, the screen is read-only and a Follow/Unfollow
/// button is displayed.
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
  String? _currentUid;

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
      _currentUid = currentUid;
      context
          .read<ProfileBloc>()
          .add(ProfileWatchRequested(uid: targetUid));

      // Watch posts by the user.
      context
          .read<PostBloc>()
          .add(PostsWatchByAuthorRequested(authorUid: targetUid));

      // Start watching follow status when viewing another user's profile.
      if (currentUid != null && targetUid != currentUid) {
        context.read<FollowBloc>().add(
              FollowWatchRequested(
                followerId: currentUid,
                followeeId: targetUid,
              ),
            );
      }
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
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: false,
                    floating: true,
                    expandedHeight: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Padding(
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _StatChip(
                                  label: 'Posts',
                                  value: profile.postCount,
                                  onTap: () {},
                                ),
                                const SizedBox(width: 32),
                                _StatChip(
                                  label: 'Followers',
                                  value: profile.followerCount,
                                  onTap: () {
                                    context.push(
                                      '/profile/$_resolvedUid/followers',
                                    );
                                  },
                                ),
                                const SizedBox(width: 32),
                                _StatChip(
                                  label: 'Following',
                                  value: profile.followingCount,
                                  onTap: () {
                                    context.push(
                                      '/profile/$_resolvedUid/following',
                                    );
                                  },
                                ),
                              ],
                            ),
                            if (!isOwnProfile) ...[
                              const SizedBox(height: 24),
                              _FollowButton(
                                currentUid: currentUid ?? _currentUid ?? '',
                                targetUid: _resolvedUid ?? '',
                              ),
                            ],
                            if (state is ProfileUpdating) ...[
                              const SizedBox(height: 16),
                              const CircularProgressIndicator(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Posts',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  BlocBuilder<PostBloc, PostState>(
                    builder: (context, postState) {
                      return switch (postState) {
                        PostInitial() => const SliverFillRemaining(
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        PostLoading() => const SliverFillRemaining(
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        PostLoaded(:final posts) => posts.isEmpty
                            ? const SliverFillRemaining(
                                child: Center(
                                  child: Text('No posts yet.'),
                                ),
                              )
                            : SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 1,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final post = posts[index];
                                    return Container(
                                      color: Colors.grey[300],
                                      child: post.imageUrl != null
                                          ? Image.network(
                                              post.imageUrl!,
                                              fit: BoxFit.cover,
                                            )
                                          : Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Text(
                                                  post.content,
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                    );
                                  },
                                  childCount: posts.length,
                                ),
                              ),
                        PostFailure(:final error) => SliverFillRemaining(
                            child: Center(
                              child: Text('Error: $error'),
                            ),
                          ),
                        _ => const SliverFillRemaining(
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      };
                    },
                  ),
                ],
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
                                  ProfileWatchRequested(uid: _resolvedUid!),
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

/// Follow/Unfollow button that reads from [FollowBloc].
class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.currentUid,
    required this.targetUid,
  });

  final String currentUid;
  final String targetUid;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FollowBloc, FollowState>(
      builder: (context, state) {
        if (state is FollowLoading) {
          return const SizedBox(
            width: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final isFollowing = state is FollowLoaded && state.isFollowing;
        return ElevatedButton(
          onPressed: () {
            if (isFollowing) {
              context.read<FollowBloc>().add(
                    UnfollowRequested(
                      followerId: currentUid,
                      followeeId: targetUid,
                    ),
                  );
            } else {
              context.read<FollowBloc>().add(
                    FollowRequested(
                      followerId: currentUid,
                      followeeId: targetUid,
                    ),
                  );
            }
          },
          child: Text(isFollowing ? 'Unfollow' : 'Follow'),
        );
      },
    );
  }
}

/// Small chip that displays a stat label and numeric value.
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.onTap,
  });

  /// Label shown below the numeric value.
  final String label;

  /// Numeric count to display.
  final int value;

  /// Optional callback when tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
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
      ),
    );
  }
}
