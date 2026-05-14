// lib/features/follow/presentation/screens/following_screen.dart
//
// FollowingScreen — lists the users that a given user follows.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/features/follow/domain/entities/follow_user_entity.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/profile/presentation/widgets/avatar_widget.dart';

/// Screen that lists users that the profile identified by [uid] follows.
class FollowingScreen extends StatelessWidget {
  const FollowingScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: StreamBuilder<List<FollowUserEntity>>(
        stream: context.read<FollowRepository>().watchFollowing(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load following.'));
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('Not following anyone yet.'));
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
