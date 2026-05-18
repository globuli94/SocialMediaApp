// lib/features/notifications/domain/entities/notification_entity.dart
//
// NotificationEntity — pure Dart domain entity for a user notification.

import 'package:equatable/equatable.dart';

/// Immutable domain entity representing a notification for a user.
class NotificationEntity extends Equatable {
  /// Creates a [NotificationEntity].
  const NotificationEntity({
    required this.id,
    required this.type,
    required this.actorUid,
    required this.actorDisplayName,
    this.actorAvatarUrl,
    this.postId,
    required this.read,
    required this.createdAt,
  });

  /// Document ID from Firestore.
  final String id;

  /// Notification type — `'like'` or `'follow'`.
  final String type;

  /// UID of the user who triggered the notification.
  final String actorUid;

  /// Display name of the actor (denormalised at write time).
  final String actorDisplayName;

  /// Avatar URL of the actor, or `null` if not set.
  final String? actorAvatarUrl;

  /// ID of the post that was liked — non-null for `type == 'like'`.
  final String? postId;

  /// Whether the notification has been read by the recipient.
  final bool read;

  /// Server timestamp converted to [DateTime].
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        type,
        actorUid,
        actorDisplayName,
        actorAvatarUrl,
        postId,
        read,
        createdAt,
      ];
}
