// lib/features/chat/presentation/screens/conversations_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_bloc.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_state.dart';

String _formatTime(DateTime dt) {
  final h = dt.hour;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = h >= 12 ? 'PM' : 'AM';
  final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  return '$hour:$m $period';
}

/// Displays the list of active conversations for the current user.
class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: BlocBuilder<ConversationsBloc, ConversationsState>(
        builder: (context, state) {
          return switch (state) {
            ConversationsInitial() || ConversationsLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            ConversationsError(:final message) => Center(
                child: Text(message),
              ),
            ConversationsNavigateToChat() => const Center(
                child: CircularProgressIndicator(),
              ),
            ConversationsLoaded(
              :final conversations,
              :final currentUid,
              :final userProfiles,
            ) =>
              conversations.isEmpty
                  ? const Center(child: Text('No conversations yet'))
                  : ListView.builder(
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conv = conversations[index];
                        final otherUid = conv.participantUids.firstWhere(
                          (uid) => uid != currentUid,
                          orElse: () => conv.participantUids.first,
                        );
                        final profile = userProfiles[otherUid];
                        final displayName = profile?.displayName ?? otherUid;
                        final avatarUrl = profile?.avatarUrl;
                        final initials = displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?';
                        final unread = conv.unreadCountFor(currentUid);
                        final timeLabel =
                            _formatTime(conv.lastMessageAt.toLocal());
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child:
                                avatarUrl == null ? Text(initials) : null,
                          ),
                          title: Text(displayName),
                          subtitle: Text(
                            conv.lastMessageText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                timeLabel,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (unread > 0)
                                Badge(
                                  label: Text('$unread'),
                                ),
                            ],
                          ),
                          onTap: () => context.push(
                            '/chat/${conv.id}',
                            extra: <String, String>{
                              'currentUid': currentUid,
                              'recipientUid': otherUid,
                            },
                          ),
                        );
                      },
                    ),
          };
        },
      ),
    );
  }
}
