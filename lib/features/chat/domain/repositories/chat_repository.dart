// lib/features/chat/domain/repositories/chat_repository.dart

import 'package:social_network/features/chat/domain/entities/conversation_entity.dart';
import 'package:social_network/features/chat/domain/entities/message_entity.dart';

/// Abstract contract for all chat data operations.
abstract class ChatRepository {
  /// Watches all conversations for [uid], ordered by most recent first.
  Stream<List<ConversationEntity>> watchConversations(String uid);

  /// Watches the message list for a conversation, ordered oldest-first.
  Stream<List<MessageEntity>> watchMessages(String conversationId);

  /// Returns an existing conversation between [currentUid] and [otherUid],
  /// or creates a new one if none exists.
  Future<ConversationEntity> getOrCreateConversation(
    String currentUid,
    String otherUid,
  );

  /// Sends a message and updates the conversation's last-message metadata.
  Future<void> sendMessage({
    required String conversationId,
    required String senderUid,
    required String recipientUid,
    required String text,
  });

  /// Resets the unread count to 0 for [uid] in [conversationId].
  Future<void> markAsRead({
    required String conversationId,
    required String uid,
  });
}
