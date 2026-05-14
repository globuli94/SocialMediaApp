// lib/features/follow/presentation/screens/followers_screen.dart
//
// FollowersScreen — lists the followers of a given user.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/features/follow/domain/entities/follow_user_entity.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/profile/presentation/widgets/avatar_widget.dart';

/// Screen that lists users who follow the profile identified by [uid].
class FollowersScreen extends StatelessWidget {
  const FollowersScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Followers')),
      body: StreamBuilder<List<FollowUserEntity>>(
        stream: context.read<FollowRepository>().watchFollowers(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load followers.'));
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('No followers yet.'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: AvatarWidget(
                  displayName: user.displayName,
                  avatarUrl: user.avatarUrl,
                  radius: 22,
                ),
                title: Text(user.displayName),
                onTap: () => context.push('/profile/${user.uid}'),
              );
            },
          );
        },
      ),
    );
  }
}
