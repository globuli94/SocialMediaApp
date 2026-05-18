// lib/features/notifications/data/repositories/notification_repository_impl.dart
//
// NotificationRepositoryImpl — Firestore-backed implementation.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_network/features/notifications/domain/entities/notification_entity.dart';
import 'package:social_network/features/notifications/domain/repositories/notification_repository.dart';

/// Firestore implementation of [NotificationRepository].
///
/// Notifications are stored under `users/{uid}/notifications`.
class NotificationRepositoryImpl implements NotificationRepository {
  /// Creates a [NotificationRepositoryImpl].
  NotificationRepositoryImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _firestore.collection('users').doc(uid).collection('notifications');

  @override
  Stream<List<NotificationEntity>> watchNotifications(String recipientUid) {
    return _col(recipientUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _fromDoc(doc))
              .toList(),
        );
  }

  @override
  Future<void> markAsRead(
    String recipientUid,
    String notificationId,
  ) {
    return _col(recipientUid).doc(notificationId).update({'read': true});
  }

  @override
  Future<void> createLikeNotification({
    required String recipientUid,
    required String actorUid,
    required String actorDisplayName,
    String? actorAvatarUrl,
    required String postId,
  }) {
    return _col(recipientUid).add({
      'type': 'like',
      'actorUid': actorUid,
      'actorDisplayName': actorDisplayName,
      'actorAvatarUrl': actorAvatarUrl,
      'postId': postId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> createFollowNotification({
    required String recipientUid,
    required String actorUid,
    required String actorDisplayName,
    String? actorAvatarUrl,
  }) {
    return _col(recipientUid).add({
      'type': 'follow',
      'actorUid': actorUid,
      'actorDisplayName': actorDisplayName,
      'actorAvatarUrl': actorAvatarUrl,
      'postId': null,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  NotificationEntity _fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final ts = data['createdAt'];
    final createdAt = ts is Timestamp ? ts.toDate() : DateTime.now();
    return NotificationEntity(
      id: doc.id,
      type: data['type'] as String,
      actorUid: data['actorUid'] as String,
      actorDisplayName: data['actorDisplayName'] as String,
      actorAvatarUrl: data['actorAvatarUrl'] as String?,
      postId: data['postId'] as String?,
      read: data['read'] as bool,
      createdAt: createdAt,
    );
  }
}
