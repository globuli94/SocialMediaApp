// lib/features/follow/presentation/screens/following_screen.dart
//
// FollowingScreen — displays a list of users whom a given user is following.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_bloc.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_list_state.dart';
import 'package:social_network/features/profile/presentation/widgets/avatar_widget.dart';

/// Screen that displays a list of users whom [uid] is following.
class FollowingScreen extends StatefulWidget {
  /// Creates a [FollowingScreen].
  const FollowingScreen({super.key, required this.uid});

  /// The UID of the user whose following list to display.
  final String uid;

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FollowListBloc>().add(FollowingWatchRequested(uid: widget.uid));
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
            FollowListInitial() => const Center(
                child: CircularProgressIndicator(),
              ),
            FollowListLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            FollowListLoaded(:final users) => users.isEmpty
                ? const Center(
                    child: Text('Not following anyone yet.'),
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
                        'Could not load following.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
