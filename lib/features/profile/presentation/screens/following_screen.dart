// lib/features/profile/presentation/screens/following_screen.dart
//
// FollowingScreen — displays a list of users that a given user is following.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_bloc.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_state.dart';
import 'package:social_network/features/profile/presentation/widgets/avatar_widget.dart';

/// Screen that displays a list of users that a given user is following.
class FollowingScreen extends StatefulWidget {
  /// Creates a [FollowingScreen].
  ///
  /// [uid] is the UID of the user whose following to display.
  const FollowingScreen({super.key, required this.uid});

  /// The UID of the user whose following to display.
  final String uid;

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context
        .read<FollowListBloc>()
        .add(FollowListWatchFollowingStarted(widget.uid));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Following'),
      ),
      body: BlocBuilder<FollowListBloc, FollowListState>(
        builder: (context, state) {
          return switch (state) {
            FollowListInitial() || FollowListLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            FollowListLoaded(:final users) => users.isEmpty
                ? const Center(
                    child: Text('Not following anyone yet'),
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
                        onTap: () => context.push('/profile/${user.uid}'),
                      );
                    },
                  ),
            FollowListFailure(:final error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load following'),
                      const SizedBox(height: 8),
                      Text(error),
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
