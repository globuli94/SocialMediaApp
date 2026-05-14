// lib/features/profile/presentation/bloc/profile_bloc.dart
//
// ProfileBloc — manages user profile state and delegates to ProfileRepository.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/profile/domain/repositories/profile_repository.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';

/// BLoC that manages user profile state.
///
/// Listens for [ProfileWatchRequested], [ProfileLoadRequested],
/// [ProfileUpdateRequested], and [ProfileAvatarUploadRequested] events and
/// delegates all data operations to [ProfileRepository].
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  /// Creates a [ProfileBloc] with the given [profileRepository].
  ProfileBloc({required ProfileRepository profileRepository})
      : _repository = profileRepository,
        super(const ProfileInitial()) {
    on<ProfileWatchRequested>(_onWatchRequested);
    on<ProfileLoadRequested>(_onLoadRequested);
    on<ProfileUpdateRequested>(_onUpdateRequested);
    on<ProfileAvatarUploadRequested>(_onAvatarUploadRequested);
  }

  final ProfileRepository _repository;

  /// Subscribes to real-time Firestore snapshots via [Emitter.forEach].
  ///
  /// Runs in its own event-type pipeline so [ProfileUpdateRequested] and
  /// [ProfileAvatarUploadRequested] are not blocked by the open stream.
  Future<void> _onWatchRequested(
    ProfileWatchRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    await emit.forEach(
      _repository.watchProfile(event.uid),
      onData: (profile) => ProfileLoaded(profile: profile),
      onError: (e, _) => ProfileFailure(error: e.toString()),
    );
  }

  /// Fetches the profile for the requested UID.
  ///
  /// Creates the Firestore document with defaults if it does not yet exist.
  Future<void> _onLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());
    try {
      final profile = await _repository.getProfile(event.uid);
      emit(ProfileLoaded(profile: profile));
    } catch (e) {
      emit(ProfileFailure(error: e.toString()));
    }
  }

  /// Writes [displayName] and [bio] to Firestore and reloads the profile.
  Future<void> _onUpdateRequested(
    ProfileUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    final currentProfile =
        currentState is ProfileLoaded ? currentState.profile : null;

    if (currentProfile != null) {
      emit(ProfileUpdating(profile: currentProfile));
    } else {
      emit(const ProfileLoading());
    }

    try {
      await _repository.updateProfile(
        uid: event.uid,
        displayName: event.displayName,
        bio: event.bio,
      );
      final updated = await _repository.getProfile(event.uid);
      emit(ProfileLoaded(profile: updated));
    } catch (e) {
      emit(ProfileFailure(error: e.toString()));
    }
  }

  /// Uploads avatar bytes to Firebase Storage and updates Firestore.
  Future<void> _onAvatarUploadRequested(
    ProfileAvatarUploadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    final currentProfile =
        currentState is ProfileLoaded ? currentState.profile : null;

    if (currentProfile != null) {
      emit(ProfileUpdating(profile: currentProfile));
    } else {
      emit(const ProfileLoading());
    }

    try {
      await _repository.uploadAvatar(
        uid: event.uid,
        bytes: event.bytes,
        extension: event.extension,
      );
      final updated = await _repository.getProfile(event.uid);
      emit(ProfileLoaded(profile: updated));
    } catch (e) {
      emit(ProfileFailure(error: e.toString()));
    }
  }
}
