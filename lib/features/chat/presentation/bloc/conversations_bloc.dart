// lib/features/chat/presentation/bloc/conversations_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/chat/domain/entities/conversation_entity.dart';
import 'package:social_network/features/chat/domain/repositories/chat_repository.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_event.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_state.dart';

/// Manages the conversations list and open/create navigation.
class ConversationsBloc extends Bloc<ConversationsEvent, ConversationsState> {
  ConversationsBloc({required ChatRepository chatRepository})
      : _repository = chatRepository,
        super(const ConversationsInitial()) {
    on<ConversationsWatchStarted>(_onWatchStarted);
    on<ConversationsOpenOrCreate>(_onOpenOrCreate);
  }

  final ChatRepository _repository;
  ConversationsLoaded? _lastLoaded;

  Future<void> _onWatchStarted(
    ConversationsWatchStarted event,
    Emitter<ConversationsState> emit,
  ) async {
    emit(const ConversationsLoading());
    await emit.forEach<List<ConversationEntity>>(
      _repository.watchConversations(event.uid),
      onData: (conversations) {
        final loaded = ConversationsLoaded(
          conversations: conversations,
          currentUid: event.uid,
        );
        _lastLoaded = loaded;
        return loaded;
      },
      onError: (_, __) =>
          const ConversationsError('Failed to load conversations'),
    );
  }

  Future<void> _onOpenOrCreate(
    ConversationsOpenOrCreate event,
    Emitter<ConversationsState> emit,
  ) async {
    try {
      final conversation = await _repository.getOrCreateConversation(
        event.currentUid,
        event.otherUid,
      );
      emit(ConversationsNavigateToChat(conversation));
      // Restore the loaded state so the UI reflects the conversation list again.
      if (_lastLoaded != null) {
        emit(_lastLoaded!);
      }
    } catch (e) {
      emit(ConversationsError(e.toString()));
    }
  }
}
