// lib/features/search/presentation/screens/search_screen.dart
//
// SearchScreen — allows users to search for other users by display name.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_bloc.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_state.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';
import 'package:social_network/features/profile/presentation/widgets/avatar_widget.dart';
import 'package:social_network/features/search/presentation/bloc/search_bloc.dart';
import 'package:social_network/features/search/presentation/bloc/search_event.dart';
import 'package:social_network/features/search/presentation/bloc/search_state.dart';

/// Screen that lets users search for other users by display name.
///
/// Results are debounced (300 ms) and show avatar, display name, and a
/// Follow/Unfollow button. Tapping a result navigates to that user's profile.
class SearchScreen extends StatefulWidget {
  /// Creates a [SearchScreen].
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  String? _currentUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUid = authState.user.uid;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    if (_currentUid == null) return;
    context.read<SearchBloc>().add(
          SearchQueryChanged(query: query, currentUid: _currentUid!),
        );
  }

  void _onClear() {
    _controller.clear();
    context.read<SearchBloc>().add(const SearchCleared());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          onChanged: _onChanged,
          autofocus: false,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search users…',
            border: InputBorder.none,
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                return value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _onClear,
                      )
                    : const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
      body: BlocBuilder<SearchBloc, SearchState>(
        builder: (context, state) {
          return switch (state) {
            SearchInitial() => const _SearchPrompt(),
            SearchLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            SearchLoaded(:final results) when results.isEmpty =>
              const _EmptyState(),
            SearchLoaded(:final results) => _ResultsList(
                results: results,
                currentUid: _currentUid ?? '',
              ),
            SearchFailure(:final error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Search failed: $error'),
                ),
              ),
          };
        },
      ),
    );
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Search for users by display name',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No users found',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.results,
    required this.currentUid,
  });

  final List<UserProfileEntity> results;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        return _SearchResultItem(
          profile: results[index],
          currentUid: currentUid,
        );
      },
    );
  }
}

/// A single search result row with avatar, display name, and follow button.
///
/// Creates its own [FollowBloc] instance so that each row independently
/// tracks and updates follow status.
class _SearchResultItem extends StatelessWidget {
  const _SearchResultItem({
    required this.profile,
    required this.currentUid,
  });

  final UserProfileEntity profile;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FollowBloc>(
      create: (ctx) => FollowBloc(
        followRepository: ctx.read<FollowRepository>(),
      )..add(
          FollowWatchRequested(
            followerId: currentUid,
            followeeId: profile.uid,
          ),
        ),
      child: ListTile(
        leading: AvatarWidget(
          displayName: profile.displayName,
          avatarUrl: profile.avatarUrl,
          radius: 24,
        ),
        title: Text(profile.displayName),
        trailing: _FollowButton(
          currentUid: currentUid,
          targetUid: profile.uid,
        ),
        onTap: () => context.push('/profile/${profile.uid}'),
      ),
    );
  }
}

/// Follow/Unfollow button that reads its own scoped [FollowBloc].
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
        if (state is FollowLoading || state is FollowInitial) {
          return const SizedBox(
            width: 80,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final isFollowing = state is FollowLoaded && state.isFollowing;
        return TextButton(
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
