// lib/features/chat/presentation/bloc/chat_event.dart

import 'package:equatable/equatable.dart';

/// Base class for all [ChatBloc] events.
sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

/// Start watching messages for a conversation.
final class ChatWatchStarted extends ChatEvent {
  const ChatWatchStarted({
    required this.conversationId,
    required this.currentUid,
    required this.recipientUid,
  });

  final String conversationId;
  final String currentUid;
  final String recipientUid;

  @override
  List<Object?> get props => [conversationId, currentUid, recipientUid];
}

/// Send a text message.
final class ChatMessageSent extends ChatEvent {
  const ChatMessageSent(this.text);
  final String text;

  @override
  List<Object?> get props => [text];
}

/// Mark the conversation as read for the current user.
final class ChatMarkAsRead extends ChatEvent {
  const ChatMarkAsRead();
}
