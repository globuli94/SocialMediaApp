// lib/features/profile/presentation/widgets/avatar_widget.dart
//
// AvatarWidget — displays a user's avatar with an optional edit overlay.

import 'package:flutter/material.dart';

/// Circular avatar widget that shows the user's profile picture.
///
/// When [avatarUrl] is non-null, the image is loaded from the network.
/// Otherwise the first character of [displayName] is shown as initials.
///
/// If [onTap] is provided, tapping the avatar triggers the callback (used for
/// the avatar-upload flow on own-profile screens).
class AvatarWidget extends StatelessWidget {
  /// Creates an [AvatarWidget].
  const AvatarWidget({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.radius = 48,
    this.onTap,
  });

  /// Display name used for the initials fallback.
  final String displayName;

  /// Network URL of the profile picture, or `null` to show initials.
  final String? avatarUrl;

  /// Radius of the [CircleAvatar]. Defaults to 48.
  final double radius;

  /// Optional callback invoked when the avatar is tapped.
  ///
  /// When set, an edit icon overlay is rendered to hint at the tap target.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundImage:
          avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null
          ? Text(
              displayName.isNotEmpty
                  ? displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(fontSize: radius * 0.6),
            )
          : null,
    );

    if (onTap == null) return avatar;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          avatar,
          CircleAvatar(
            radius: radius * 0.28,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Icon(
              Icons.camera_alt,
              size: radius * 0.3,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
