// test/features/auth/data/repositories/auth_repository_impl_test.dart
//
// Unit tests for AuthRepositoryImpl — covers every public method with success
// and failure paths to satisfy the ≥ 80% repository coverage threshold.
//
// All Firebase interactions are replaced by mocktail stubs; no real Firebase
// instance is required.

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:social_network/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:social_network/features/auth/domain/entities/user_entity.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockFirebaseUser extends Mock implements fb.User {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthRemoteDataSource mockDataSource;
  late MockFirebaseUser mockFirebaseUser;
  late AuthRepositoryImpl sut;

  setUp(() {
    mockDataSource = MockAuthRemoteDataSource();
    mockFirebaseUser = MockFirebaseUser();
    sut = AuthRepositoryImpl(dataSource: mockDataSource);
  });

  // -------------------------------------------------------------------------
  // currentUser
  // -------------------------------------------------------------------------

  group('currentUser', () {
    test('returns null when data source returns null', () {
      when(() => mockDataSource.currentUser).thenReturn(null);

      expect(sut.currentUser, isNull);
    });

    test('maps Firebase user to UserEntity', () {
      when(() => mockDataSource.currentUser).thenReturn(mockFirebaseUser);
      when(() => mockFirebaseUser.uid).thenReturn('uid-123');
      when(() => mockFirebaseUser.email).thenReturn('user@example.com');
      when(() => mockFirebaseUser.displayName).thenReturn('Display Name');

      final UserEntity? result = sut.currentUser;

      expect(result, isNotNull);
      expect(result!.uid, 'uid-123');
      expect(result.email, 'user@example.com');
      // displayName falls back to email prefix when displayName is null
      expect(result.displayName, 'Display Name');
    });

    test('uses email prefix as displayName when displayName is null', () {
      when(() => mockDataSource.currentUser).thenReturn(mockFirebaseUser);
      when(() => mockFirebaseUser.uid).thenReturn('uid-456');
      when(() => mockFirebaseUser.email).thenReturn('alice@example.com');
      when(() => mockFirebaseUser.displayName).thenReturn(null);

      final UserEntity? result = sut.currentUser;

      expect(result!.displayName, 'alice');
    });
  });

  // -------------------------------------------------------------------------
  // authStateChanges
  // -------------------------------------------------------------------------

  group('authStateChanges', () {
    test('emits UserEntity when Firebase user is present', () async {
      when(() => mockFirebaseUser.uid).thenReturn('uid-stream');
      when(() => mockFirebaseUser.email).thenReturn('stream@example.com');
      when(() => mockFirebaseUser.displayName).thenReturn(null);
      when(() => mockDataSource.authStateChanges)
          .thenAnswer((_) => Stream.value(mockFirebaseUser));

      final UserEntity? result = await sut.authStateChanges.first;

      expect(result, isNotNull);
      expect(result!.uid, 'uid-stream');
    });

    test('emits null when Firebase user is null', () async {
      when(() => mockDataSource.authStateChanges)
          .thenAnswer((_) => Stream.value(null));

      final UserEntity? result = await sut.authStateChanges.first;

      expect(result, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // signIn
  // -------------------------------------------------------------------------

  group('signIn', () {
    test('completes without throwing on success', () async {
      when(
        () => mockDataSource.signInWithEmailAndPassword(
          email: 'user@example.com',
          password: 'pass123',
        ),
      ).thenAnswer((_) async {});

      await expectLater(
        sut.signIn(email: 'user@example.com', password: 'pass123'),
        completes,
      );
    });

    test('throws String message on FirebaseAuthException', () async {
      when(
        () => mockDataSource.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        fb.FirebaseAuthException(
          code: 'wrong-password',
          message: 'The password is invalid.',
        ),
      );

      await expectLater(
        sut.signIn(email: 'user@example.com', password: 'bad'),
        throwsA('The password is invalid.'),
      );
    });

    test('throws fallback message when FirebaseAuthException.message is null',
        () async {
      when(
        () => mockDataSource.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        fb.FirebaseAuthException(code: 'unknown'),
      );

      await expectLater(
        sut.signIn(email: 'user@example.com', password: 'bad'),
        throwsA('Sign-in failed.'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // signUp
  // -------------------------------------------------------------------------

  group('signUp', () {
    test('completes without throwing on success', () async {
      when(
        () => mockDataSource.createUserWithEmailAndPassword(
          email: 'new@example.com',
          password: 'pass123',
        ),
      ).thenAnswer((_) async {});

      await expectLater(
        sut.signUp(email: 'new@example.com', password: 'pass123'),
        completes,
      );
    });

    test('throws String message on FirebaseAuthException', () async {
      when(
        () => mockDataSource.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        fb.FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'Email already in use.',
        ),
      );

      await expectLater(
        sut.signUp(email: 'taken@example.com', password: 'pass123'),
        throwsA('Email already in use.'),
      );
    });

    test('throws fallback message when FirebaseAuthException.message is null',
        () async {
      when(
        () => mockDataSource.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        fb.FirebaseAuthException(code: 'unknown'),
      );

      await expectLater(
        sut.signUp(email: 'new@example.com', password: 'pass123'),
        throwsA('Sign-up failed.'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // sendPasswordResetEmail
  // -------------------------------------------------------------------------

  group('sendPasswordResetEmail', () {
    test('completes without throwing on success', () async {
      when(
        () => mockDataSource.sendPasswordResetEmail(email: 'user@example.com'),
      ).thenAnswer((_) async {});

      await expectLater(
        sut.sendPasswordResetEmail(email: 'user@example.com'),
        completes,
      );
    });

    test('throws String message on FirebaseAuthException', () async {
      when(
        () => mockDataSource.sendPasswordResetEmail(
          email: any(named: 'email'),
        ),
      ).thenThrow(
        fb.FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found for that email.',
        ),
      );

      await expectLater(
        sut.sendPasswordResetEmail(email: 'missing@example.com'),
        throwsA('No user found for that email.'),
      );
    });

    test('throws fallback message when FirebaseAuthException.message is null',
        () async {
      when(
        () => mockDataSource.sendPasswordResetEmail(
          email: any(named: 'email'),
        ),
      ).thenThrow(
        fb.FirebaseAuthException(code: 'unknown'),
      );

      await expectLater(
        sut.sendPasswordResetEmail(email: 'user@example.com'),
        throwsA('Failed to send password reset email.'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // signOut
  // -------------------------------------------------------------------------

  group('signOut', () {
    test('delegates to data source signOut', () async {
      when(() => mockDataSource.signOut()).thenAnswer((_) async {});

      await sut.signOut();

      verify(() => mockDataSource.signOut()).called(1);
    });
  });
}
