// lib/features/chat/presentation/bloc/chat_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/chat/domain/entities/message_entity.dart';
import 'package:social_network/features/chat/domain/repositories/chat_repository.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_event.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_state.dart';

/// Manages the message stream and send/read operations for a single chat.
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({required ChatRepository chatRepository})
      : _repository = chatRepository,
        super(const ChatInitial()) {
    on<ChatWatchStarted>(_onWatchStarted);
    on<ChatMessageSent>(_onMessageSent);
    on<ChatMarkAsRead>(_onMarkAsRead);
  }

  final ChatRepository _repository;

  Future<void> _onWatchStarted(
    ChatWatchStarted event,
    Emitter<ChatState> emit,
  ) async {
    emit(const ChatLoading());
    // Mark as read immediately when the chat is opened.
    unawaited(
      _repository.markAsRead(
        conversationId: event.conversationId,
        uid: event.currentUid,
      ),
    );
    await emit.forEach<List<MessageEntity>>(
      _repository.watchMessages(event.conversationId),
      onData: (messages) => ChatLoaded(
        conversationId: event.conversationId,
        currentUid: event.currentUid,
        recipientUid: event.recipientUid,
        messages: messages,
      ),
      onError: (_, __) => const ChatError('Failed to load messages'),
    );
  }

  Future<void> _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) async {
    final current = state;
    if (current is! ChatLoaded) return;
    try {
      await _repository.sendMessage(
        conversationId: current.conversationId,
        senderUid: current.currentUid,
        recipientUid: current.recipientUid,
        text: event.text,
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onMarkAsRead(
    ChatMarkAsRead event,
    Emitter<ChatState> emit,
  ) async {
    final current = state;
    if (current is! ChatLoaded) return;
    unawaited(
      _repository.markAsRead(
        conversationId: current.conversationId,
        uid: current.currentUid,
      ),
    );
  }
}

// ignore: prefer_void_to_null
void unawaited(Future<void> future) {}
