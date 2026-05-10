// lib/features/profile/data/repositories/profile_repository_impl.dart
//
// ProfileRepositoryImpl — implements ProfileRepository using
// ProfileRemoteDataSource.

import 'dart:typed_data';

import 'package:social_network/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';
import 'package:social_network/features/profile/domain/repositories/profile_repository.dart';

/// Concrete implementation of [ProfileRepository] backed by
/// [ProfileRemoteDataSource].
///
/// Maps raw Firestore maps to domain [UserProfileEntity] instances so that
/// the domain and presentation layers remain free of Firebase imports.
class ProfileRepositoryImpl implements ProfileRepository {
  /// Creates a [ProfileRepositoryImpl].
  ProfileRepositoryImpl({required ProfileRemoteDataSource dataSource})
      : _dataSource = dataSource;

  final ProfileRemoteDataSource _dataSource;

  @override
  Future<UserProfileEntity> getProfile(String uid) async {
    try {
      final data = await _dataSource.fetchProfile(uid);
      return _mapToEntity(data);
    } catch (e) {
      throw 'Failed to load profile: $e';
    }
  }

  @override
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String bio,
  }) async {
    try {
      await _dataSource.updateProfile(
        uid: uid,
        displayName: displayName,
        bio: bio,
      );
    } catch (e) {
      throw 'Failed to update profile: $e';
    }
  }

  @override
  Future<void> uploadAvatar({
    required String uid,
    required Uint8List bytes,
    required String extension,
  }) async {
    try {
      final url = await _dataSource.uploadAvatarBytes(
        uid: uid,
        bytes: bytes,
        extension: extension,
      );
      await _dataSource.updateAvatarUrl(uid: uid, avatarUrl: url);
    } catch (e) {
      throw 'Failed to upload avatar: $e';
    }
  }

  /// Maps a raw Firestore [data] map to a [UserProfileEntity].
  UserProfileEntity _mapToEntity(Map<String, dynamic> data) {
    return UserProfileEntity(
      uid: data['uid'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String?,
      postCount: (data['postCount'] as num?)?.toInt() ?? 0,
    );
  }
}
