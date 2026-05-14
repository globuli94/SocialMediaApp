// lib/features/profile/presentation/bloc/profile_event.dart
//
// ProfileEvent — sealed event hierarchy for ProfileBloc.

import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Base class for all profile events.
sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Requests a real-time stream of the profile for [uid].
///
/// [ProfileBloc] will emit a new [ProfileLoaded] state on every Firestore
/// change, keeping followerCount and followingCount up to date.
final class ProfileWatchRequested extends ProfileEvent {
  /// Creates a [ProfileWatchRequested].
  const ProfileWatchRequested({required this.uid});

  /// The Firebase Auth UID whose profile to watch.
  final String uid;

  @override
  List<Object?> get props => [uid];
}

/// Requests loading the profile for [uid] from Firestore.
///
/// If no document exists for [uid], the data source creates one with defaults.
final class ProfileLoadRequested extends ProfileEvent {
  /// Creates a [ProfileLoadRequested].
  const ProfileLoadRequested({required this.uid});

  /// The Firebase Auth UID whose profile to load.
  final String uid;

  @override
  List<Object?> get props => [uid];
}

/// Requests updating [displayName] and [bio] for [uid].
final class ProfileUpdateRequested extends ProfileEvent {
  /// Creates a [ProfileUpdateRequested].
  const ProfileUpdateRequested({
    required this.uid,
    required this.displayName,
    required this.bio,
  });

  /// The Firebase Auth UID of the profile to update.
  final String uid;

  /// New display name (max 50 chars).
  final String displayName;

  /// New biography (max 160 chars, may be empty).
  final String bio;

  @override
  List<Object?> get props => [uid, displayName, bio];
}

/// Requests uploading a new avatar for [uid].
///
/// [bytes] is the raw image data; [extension] includes the leading dot
/// (e.g. `.jpg`).
final class ProfileAvatarUploadRequested extends ProfileEvent {
  /// Creates a [ProfileAvatarUploadRequested].
  const ProfileAvatarUploadRequested({
    required this.uid,
    required this.bytes,
    required this.extension,
  });

  /// The Firebase Auth UID whose avatar to replace.
  final String uid;

  /// Raw bytes of the selected image.
  final Uint8List bytes;

  /// File extension including the leading dot, e.g. `.jpg`.
  final String extension;

  @override
  List<Object?> get props => [uid, bytes, extension];
}
