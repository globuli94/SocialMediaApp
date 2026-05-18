// lib/features/chat/presentation/bloc/conversations_event.dart

import 'package:equatable/equatable.dart';

/// Base class for all [ConversationsBloc] events.
sealed class ConversationsEvent extends Equatable {
  const ConversationsEvent();

  @override
  List<Object?> get props => [];
}

/// Start watching conversations for [uid].
final class ConversationsWatchStarted extends ConversationsEvent {
  const ConversationsWatchStarted(this.uid);
  final String uid;

  @override
  List<Object?> get props => [uid];
}

/// Open or create a conversation between [currentUid] and [otherUid].
/// Produces a [ConversationsNavigateToChat] state when resolved.
final class ConversationsOpenOrCreate extends ConversationsEvent {
  const ConversationsOpenOrCreate({
    required this.currentUid,
    required this.otherUid,
  });
  final String currentUid;
  final String otherUid;

  @override
  List<Object?> get props => [currentUid, otherUid];
}
