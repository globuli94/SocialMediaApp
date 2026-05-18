// lib/features/chat/presentation/bloc/conversations_state.dart

import 'package:equatable/equatable.dart';
import 'package:social_network/features/chat/domain/entities/conversation_entity.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';

/// Base class for all [ConversationsBloc] states.
sealed class ConversationsState extends Equatable {
  const ConversationsState();

  @override
  List<Object?> get props => [];
}

/// No data loaded yet.
final class ConversationsInitial extends ConversationsState {
  const ConversationsInitial();
}

/// Loading in progress.
final class ConversationsLoading extends ConversationsState {
  const ConversationsLoading();
}

/// Conversations successfully loaded.
final class ConversationsLoaded extends ConversationsState {
  const ConversationsLoaded({
    required this.conversations,
    required this.currentUid,
    this.userProfiles = const {},
  });

  final List<ConversationEntity> conversations;
  final String currentUid;

  /// Resolved profiles for other participants, keyed by UID.
  /// May be partial while profiles are still being fetched.
  final Map<String, UserProfileEntity> userProfiles;

  /// Total unread messages across all conversations for [currentUid].
  int get totalUnread => conversations.fold(
        0,
        (sum, c) => sum + c.unreadCountFor(currentUid),
      );

  @override
  List<Object?> get props => [conversations, currentUid, userProfiles];
}

/// Loading or creating a conversation succeeded; navigate to chat.
final class ConversationsNavigateToChat extends ConversationsState {
  const ConversationsNavigateToChat(this.conversation);
  final ConversationEntity conversation;

  @override
  List<Object?> get props => [conversation];
}

/// An error occurred.
final class ConversationsError extends ConversationsState {
  const ConversationsError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
