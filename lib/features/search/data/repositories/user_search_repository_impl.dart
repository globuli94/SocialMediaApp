// lib/features/search/data/repositories/user_search_repository_impl.dart
//
// UserSearchRepositoryImpl — concrete implementation of UserSearchRepository.

import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';
import 'package:social_network/features/search/data/datasources/user_search_remote_data_source.dart';
import 'package:social_network/features/search/domain/repositories/user_search_repository.dart';

/// Concrete implementation of [UserSearchRepository] backed by Firestore.
class UserSearchRepositoryImpl implements UserSearchRepository {
  /// Creates a [UserSearchRepositoryImpl].
  const UserSearchRepositoryImpl({
    required UserSearchRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final UserSearchRemoteDataSource _remoteDataSource;

  @override
  Future<List<UserProfileEntity>> searchUsers({
    required String query,
    required String excludeUid,
  }) async {
    return _remoteDataSource.searchUsers(
      query: query,
      excludeUid: excludeUid,
    );
  }
}
