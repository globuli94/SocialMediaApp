// lib/features/search/data/datasources/user_search_remote_data_source.dart
//
// UserSearchRemoteDataSource — Firestore prefix query on displayName.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';

/// Abstract interface for the user search data source.
abstract class UserSearchRemoteDataSource {
  /// Returns [UserProfileEntity] results whose displayName starts with [query],
  /// excluding [excludeUid], limited to 20 results.
  Future<List<UserProfileEntity>> searchUsers({
    required String query,
    required String excludeUid,
  });
}

/// Firestore implementation of [UserSearchRemoteDataSource].
class UserSearchRemoteDataSourceImpl implements UserSearchRemoteDataSource {
  /// Creates a [UserSearchRemoteDataSourceImpl].
  const UserSearchRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Future<List<UserProfileEntity>> searchUsers({
    required String query,
    required String excludeUid,
  }) async {
    final snap = await _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();

    return snap.docs
        .map((doc) => doc.data())
        .where((data) => data['uid'] != excludeUid)
        .map(
          (data) => UserProfileEntity(
            uid: data['uid'] as String? ?? '',
            displayName: data['displayName'] as String? ?? '',
            bio: data['bio'] as String? ?? '',
            avatarUrl: data['avatarUrl'] as String?,
            postCount: (data['postsCount'] as num?)?.toInt() ?? 0,
            followerCount: (data['followersCount'] as num?)?.toInt() ?? 0,
            followingCount: (data['followingCount'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }
}
