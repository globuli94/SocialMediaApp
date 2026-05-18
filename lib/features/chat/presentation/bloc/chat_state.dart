// lib/features/chat/presentation/bloc/chat_state.dart

import 'package:equatable/equatable.dart';
import 'package:social_network/features/chat/domain/entities/message_entity.dart';

/// Base class for all [ChatBloc] states.
sealed class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

/// No data loaded yet.
final class ChatInitial extends ChatState {
  const ChatInitial();
}

/// Loading in progress.
final class ChatLoading extends ChatState {
  const ChatLoading();
}

/// Messages loaded and chat is active.
final class ChatLoaded extends ChatState {
  const ChatLoaded({
    required this.conversationId,
    required this.currentUid,
    required this.recipientUid,
    required this.messages,
    this.recipientDisplayName,
    this.recipientAvatarUrl,
  });

  final String conversationId;
  final String currentUid;
  final String recipientUid;
  final List<MessageEntity> messages;

  /// Resolved display name for the other participant, or null while loading.
  final String? recipientDisplayName;

  /// Avatar URL for the other participant, or null if unset.
  final String? recipientAvatarUrl;

  @override
  List<Object?> get props => [
        conversationId,
        currentUid,
        recipientUid,
        messages,
        recipientDisplayName,
        recipientAvatarUrl,
      ];
}

/// An error occurred.
final class ChatError extends ChatState {
  const ChatError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
