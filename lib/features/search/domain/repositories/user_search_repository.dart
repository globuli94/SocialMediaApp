// lib/features/search/domain/repositories/user_search_repository.dart
//
// UserSearchRepository — abstract contract for user search operations.

import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';

/// Abstract contract for searching users by display name.
abstract class UserSearchRepository {
  /// Returns up to 20 [UserProfileEntity] results whose displayName starts
  /// with [query], excluding the user identified by [excludeUid].
  Future<List<UserProfileEntity>> searchUsers({
    required String query,
    required String excludeUid,
  });
}
