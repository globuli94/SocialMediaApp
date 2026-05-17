// lib/features/follow/presentation/screens/followers_screen.dart
//
// FollowersScreen — displays a list of users who follow a given user.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_bloc.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_state.dart';
import 'package:social_network/features/profile/presentation/widgets/avatar_widget.dart';

/// Screen that displays a list of users who follow the given [uid].
class FollowersScreen extends StatefulWidget {
  /// Creates a [FollowersScreen].
  const FollowersScreen({super.key, required this.uid});

  /// The UID of the user whose followers to display.
  final String uid;

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FollowListBloc>().add(FollowersWatchRequested(uid: widget.uid));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Followers'),
      ),
      body: BlocBuilder<FollowListBloc, FollowListState>(
        builder: (context, state) {
          return switch (state) {
            FollowListInitial() => const Center(
                child: CircularProgressIndicator(),
              ),
            FollowListLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            FollowListLoaded(:final users) => users.isEmpty
                ? const Center(
                    child: Text('No followers yet.'),
                  )
                : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: AvatarWidget(
                          displayName: user.displayName,
                          avatarUrl: user.avatarUrl,
                          radius: 20,
                        ),
                        title: Text(user.displayName),
                        onTap: () {
                          context.push('/profile/${user.uid}');
                        },
                      );
                    },
                  ),
            FollowListFailure(:final error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Could not load followers.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(error),
                    ],
                  ),
                ),
              ),
            _ => const Center(
                child: CircularProgressIndicator(),
              ),
          };
        },
      ),
    );
  }
}
