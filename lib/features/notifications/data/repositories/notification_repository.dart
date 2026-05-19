// lib/features/notifications/data/repositories/notification_repository.dart
//
// NotificationRepository — Firestore-backed notification data access.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_network/features/notifications/domain/entities/notification_model.dart';

/// Provides read and write access to a user's notifications stored under
/// `users/{uid}/notifications`.
class NotificationRepository {
  NotificationRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Emits the full notification list for [uid], ordered newest-first.
  ///
  /// Uses the `createdAt desc` single-field index (no composite index needed
  /// because there is no inequality filter combined with orderBy on a
  /// different field).
  Stream<List<NotificationModel>> notifications(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_docToModel).toList());
  }

  /// Emits the count of unread notifications for [uid].
  ///
  /// Uses the composite index on `isRead + createdAt` (created in SOCAA-297).
  Stream<int> unreadCount(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Marks a single notification as read.
  Future<void> markAsRead(String uid, String notificationId) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  NotificationModel _docToModel(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return NotificationModel(
      id: doc.id,
      type: data['type'] as String? ?? '',
      actorUid: data['actorUid'] as String? ?? '',
      actorDisplayName: data['actorDisplayName'] as String? ?? '',
      actorAvatarUrl: data['actorAvatarUrl'] as String?,
      postId: data['postId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: createdAt,
    );
  }
}
