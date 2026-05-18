// lib/features/notifications/domain/repositories/notification_repository.dart
//
// NotificationRepository — abstract interface for notification persistence.

import 'package:social_network/features/notifications/domain/entities/notification_entity.dart';

/// Abstract contract for reading and writing notifications.
abstract class NotificationRepository {
  /// Streams the notifications for [recipientUid], ordered by newest first.
  Stream<List<NotificationEntity>> watchNotifications(String recipientUid);

  /// Marks the given notification as read.
  Future<void> markAsRead(String recipientUid, String notificationId);

  /// Creates a like notification in the recipient's subcollection.
  Future<void> createLikeNotification({
    required String recipientUid,
    required String actorUid,
    required String actorDisplayName,
    String? actorAvatarUrl,
    required String postId,
  });

  /// Creates a follow notification in the recipient's subcollection.
  Future<void> createFollowNotification({
    required String recipientUid,
    required String actorUid,
    required String actorDisplayName,
    String? actorAvatarUrl,
  });
}
