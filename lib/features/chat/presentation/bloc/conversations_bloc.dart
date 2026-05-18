// lib/features/chat/presentation/bloc/conversations_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/chat/domain/repositories/chat_repository.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_event.dart';
import 'package:social_network/features/chat/presentation/bloc/conversations_state.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';
import 'package:social_network/features/profile/domain/repositories/profile_repository.dart';

/// Manages the conversations list and open/create navigation.
class ConversationsBloc extends Bloc<ConversationsEvent, ConversationsState> {
  ConversationsBloc({
    required ChatRepository chatRepository,
    required ProfileRepository profileRepository,
  })  : _repository = chatRepository,
        _profileRepository = profileRepository,
        super(const ConversationsInitial()) {
    on<ConversationsWatchStarted>(_onWatchStarted);
    on<ConversationsOpenOrCreate>(_onOpenOrCreate);
  }

  final ChatRepository _repository;
  final ProfileRepository _profileRepository;

  /// Profile cache so each user is fetched at most once per session.
  final Map<String, UserProfileEntity> _profileCache = {};
  ConversationsLoaded? _lastLoaded;

  Future<void> _onWatchStarted(
    ConversationsWatchStarted event,
    Emitter<ConversationsState> emit,
  ) async {
    emit(const ConversationsLoading());
    await emit.forEach(
      _repository.watchConversations(event.uid).asyncMap(
        (conversations) async {
          final otherUids = conversations
              .map(
                (c) => c.participantUids.firstWhere(
                  (uid) => uid != event.uid,
                  orElse: () => c.participantUids.first,
                ),
              )
              .toSet();
          // Fetch only UIDs not already in cache.
          await Future.wait([
            for (final uid in otherUids)
              if (!_profileCache.containsKey(uid))
                _profileRepository
                    .getProfile(uid)
                    .then(
                      (p) => _profileCache[p.uid] = p,
                      onError: (_) {},
                    ),
          ]);
          return conversations;
        },
      ),
      onData: (conversations) {
        final loaded = ConversationsLoaded(
          conversations: conversations,
          currentUid: event.uid,
          userProfiles: Map.unmodifiable(_profileCache),
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
