// lib/features/chat/domain/entities/conversation_entity.dart

import 'package:equatable/equatable.dart';

/// Immutable domain entity representing a 1-to-1 conversation.
class ConversationEntity extends Equatable {
  const ConversationEntity({
    required this.id,
    required this.participantUids,
    required this.lastMessageText,
    required this.lastMessageAt,
    required this.lastMessageSenderUid,
    required this.unreadCounts,
    required this.createdAt,
  });

  final String id;
  final List<String> participantUids;
  final String lastMessageText;
  final DateTime lastMessageAt;
  final String lastMessageSenderUid;
  final Map<String, int> unreadCounts;
  final DateTime createdAt;

  /// Returns the unread count for the given [uid], defaulting to 0.
  int unreadCountFor(String uid) => unreadCounts[uid] ?? 0;

  @override
  List<Object?> get props => [
        id,
        participantUids,
        lastMessageText,
        lastMessageAt,
        lastMessageSenderUid,
        unreadCounts,
        createdAt,
      ];
}
