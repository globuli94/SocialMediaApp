// lib/features/search/presentation/widgets/user_search_result_card.dart
//
// UserSearchResultCard — a single search result row with follow button.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/features/follow/domain/repositories/follow_repository.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_bloc.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_event.dart';
import 'package:social_network/features/follow/presentation/bloc/follow_state.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';
import 'package:social_network/features/profile/presentation/widgets/avatar_widget.dart';

/// A [ListTile] showing a user's avatar, display name, and follow button.
///
/// Creates its own [FollowBloc] instance so each row independently tracks
/// and updates follow status. Hidden for the signed-in user's own entry.
class UserSearchResultCard extends StatelessWidget {
  /// Creates a [UserSearchResultCard].
  const UserSearchResultCard({
    super.key,
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
        trailing: profile.uid == currentUid
            ? null
            : _FollowButton(
                currentUid: currentUid,
                targetUid: profile.uid,
              ),
        onTap: () => context.push('/profile/${profile.uid}'),
      ),
    );
  }
}

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
