// lib/features/profile/presentation/bloc/profile_state.dart
//
// ProfileState — sealed state hierarchy for ProfileBloc.

import 'package:equatable/equatable.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';

/// Base class for all profile states.
sealed class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any profile is loaded.
final class ProfileInitial extends ProfileState {
  /// Creates a [ProfileInitial].
  const ProfileInitial();
}

/// Profile data is being fetched or an operation is in progress.
final class ProfileLoading extends ProfileState {
  /// Creates a [ProfileLoading].
  const ProfileLoading();
}

/// Profile data was loaded successfully.
final class ProfileLoaded extends ProfileState {
  /// Creates a [ProfileLoaded].
  const ProfileLoaded({required this.profile});

  /// The loaded user profile.
  final UserProfileEntity profile;

  @override
  List<Object?> get props => [profile];
}

/// A save or upload operation is in progress while showing existing data.
final class ProfileUpdating extends ProfileState {
  /// Creates a [ProfileUpdating].
  const ProfileUpdating({required this.profile});

  /// The profile being updated (shown in the UI during the operation).
  final UserProfileEntity profile;

  @override
  List<Object?> get props => [profile];
}

/// A profile operation failed.
final class ProfileFailure extends ProfileState {
  /// Creates a [ProfileFailure].
  const ProfileFailure({required this.error});

  /// Human-readable error description.
  final String error;

  @override
  List<Object?> get props => [error];
}
