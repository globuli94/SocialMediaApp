// lib/features/chat/domain/entities/message_entity.dart

import 'package:equatable/equatable.dart';

/// Immutable domain entity representing a single chat message.
class MessageEntity extends Equatable {
  const MessageEntity({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String senderUid;
  final String text;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, senderUid, text, createdAt];
}
