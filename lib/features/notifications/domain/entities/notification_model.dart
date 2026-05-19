// lib/features/notifications/domain/entities/notification_model.dart

import 'package:equatable/equatable.dart';

/// Domain entity representing a single in-app notification.
///
/// [type] is either `'like'` (someone liked your post) or `'follow'`
/// (someone followed you). [postId] is non-null only when [type] == `'like'`.
class NotificationModel extends Equatable {
  const NotificationModel({
    required this.id,
    required this.type,
    required this.actorUid,
    required this.actorDisplayName,
    this.actorAvatarUrl,
    this.postId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String actorUid;
  final String actorDisplayName;
  final String? actorAvatarUrl;
  final String? postId;
  final bool isRead;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        type,
        actorUid,
        actorDisplayName,
        actorAvatarUrl,
        postId,
        isRead,
        createdAt,
      ];
}
