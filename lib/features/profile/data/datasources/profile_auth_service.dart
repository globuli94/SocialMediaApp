// lib/features/profile/data/datasources/profile_auth_service.dart
//
// Abstract interface for auth operations needed by ProfileRemoteDataSource.
// Concrete implementation wraps FirebaseAuth; tests supply a mock.

import 'package:firebase_auth/firebase_auth.dart';

/// Provides the currently signed-in user's email without coupling
/// [ProfileRemoteDataSource] to FirebaseAuth directly.
abstract class ProfileAuthService {
  /// The email of the currently signed-in user, or `null` if none.
  String? get currentUserEmail;
}

/// Production implementation backed by [FirebaseAuth].
class FirebaseProfileAuthService implements ProfileAuthService {
  /// Creates a [FirebaseProfileAuthService].
  const FirebaseProfileAuthService(this._auth);

  final FirebaseAuth _auth;

  @override
  String? get currentUserEmail => _auth.currentUser?.email;
}
