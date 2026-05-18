// lib/features/chat/data/repositories/chat_repository_impl.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_network/features/chat/domain/entities/conversation_entity.dart';
import 'package:social_network/features/chat/domain/entities/message_entity.dart';
import 'package:social_network/features/chat/domain/repositories/chat_repository.dart';

/// Firestore-backed implementation of [ChatRepository].
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ConversationEntity>> watchConversations(String uid) {
    return _firestore
        .collection('conversations')
        .where('participantUids', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_docToConversation).toList());
  }

  @override
  Stream<List<MessageEntity>> watchMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(_docToMessage).toList());
  }

  @override
  Future<ConversationEntity> getOrCreateConversation(
    String currentUid,
    String otherUid,
  ) async {
    final snap = await _firestore
        .collection('conversations')
        .where('participantUids', arrayContains: currentUid)
        .get();

    final existing = snap.docs.where((doc) {
      final uids = List<String>.from(doc.data()['participantUids'] as List);
      return uids.contains(otherUid);
    }).toList();

    if (existing.isNotEmpty) {
      return _docToConversation(existing.first);
    }

    final now = Timestamp.now();
    final ref = _firestore.collection('conversations').doc();
    final data = {
      'participantUids': [currentUid, otherUid],
      'lastMessageText': '',
      'lastMessageAt': now,
      'lastMessageSenderUid': currentUid,
      'unreadCounts': {currentUid: 0, otherUid: 0},
      'createdAt': now,
    };
    await ref.set(data);
    return ConversationEntity(
      id: ref.id,
      participantUids: [currentUid, otherUid],
      lastMessageText: '',
      lastMessageAt: now.toDate(),
      lastMessageSenderUid: currentUid,
      unreadCounts: {currentUid: 0, otherUid: 0},
      createdAt: now.toDate(),
    );
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderUid,
    required String recipientUid,
    required String text,
  }) async {
    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();

    batch.set(messageRef, {
      'senderUid': senderUid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final convRef =
        _firestore.collection('conversations').doc(conversationId);

    batch.update(convRef, {
      'lastMessageText': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderUid': senderUid,
      'unreadCounts.$recipientUid': FieldValue.increment(1),
    });

    await batch.commit();
  }

  @override
  Future<void> markAsRead({
    required String conversationId,
    required String uid,
  }) async {
    await _firestore.collection('conversations').doc(conversationId).update({
      'unreadCounts.$uid': 0,
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  ConversationEntity _docToConversation(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawUnread = data['unreadCounts'] as Map<String, dynamic>? ?? {};
    final unreadCounts = rawUnread.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
    return ConversationEntity(
      id: doc.id,
      participantUids: List<String>.from(data['participantUids'] as List),
      lastMessageText: data['lastMessageText'] as String? ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp).toDate(),
      lastMessageSenderUid: data['lastMessageSenderUid'] as String? ?? '',
      unreadCounts: unreadCounts,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  MessageEntity _docToMessage(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return MessageEntity(
      id: doc.id,
      senderUid: data['senderUid'] as String,
      text: data['text'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
