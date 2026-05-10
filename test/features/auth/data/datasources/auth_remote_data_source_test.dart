// test/features/auth/data/datasources/auth_remote_data_source_test.dart
//
// Unit tests for AuthRemoteDataSource — mocks FirebaseAuth and passes a
// MockFirebaseFirestore for constructor injection (never called in these tests).
//
// Note: CollectionReference and DocumentReference are sealed in
// cloud_firestore 5.x and cannot be mocked with mocktail without triggering
// subtype_of_sealed_class lint errors. The createUserWithEmailAndPassword
// Firestore-write path is therefore covered indirectly through the
// MockAuthRemoteDataSource stub in auth_repository_impl_test.dart.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/auth/data/datasources/auth_remote_data_source.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockUserCredential extends Mock implements UserCredential {}

class MockFirebaseUser extends Mock implements User {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late AuthRemoteDataSource sut;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    sut = AuthRemoteDataSource(
      firebaseAuth: mockAuth,
      firestore: mockFirestore,
    );
  });

  // -------------------------------------------------------------------------
  // authStateChanges
  // -------------------------------------------------------------------------

  group('authStateChanges', () {
    test('delegates to FirebaseAuth.authStateChanges()', () async {
      final MockFirebaseUser mockUser = MockFirebaseUser();
      when(() => mockAuth.authStateChanges())
          .thenAnswer((_) => Stream.value(mockUser));

      final User? result = await sut.authStateChanges.first;

      expect(result, mockUser);
      verify(() => mockAuth.authStateChanges()).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // currentUser
  // -------------------------------------------------------------------------

  group('currentUser', () {
    test('returns null when FirebaseAuth.currentUser is null', () {
      when(() => mockAuth.currentUser).thenReturn(null);

      expect(sut.currentUser, isNull);
    });

    test('returns FirebaseUser when signed in', () {
      final MockFirebaseUser mockUser = MockFirebaseUser();
      when(() => mockAuth.currentUser).thenReturn(mockUser);

      expect(sut.currentUser, mockUser);
    });
  });

  // -------------------------------------------------------------------------
  // signInWithEmailAndPassword
  // -------------------------------------------------------------------------

  group('signInWithEmailAndPassword', () {
    test('calls FirebaseAuth.signInWithEmailAndPassword', () async {
      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: 'user@example.com',
          password: 'pass123',
        ),
      ).thenAnswer((_) async => MockUserCredential());

      await sut.signInWithEmailAndPassword(
        email: 'user@example.com',
        password: 'pass123',
      );

      verify(
        () => mockAuth.signInWithEmailAndPassword(
          email: 'user@example.com',
          password: 'pass123',
        ),
      ).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // sendPasswordResetEmail
  // -------------------------------------------------------------------------

  group('sendPasswordResetEmail', () {
    test('calls FirebaseAuth.sendPasswordResetEmail', () async {
      when(
        () => mockAuth.sendPasswordResetEmail(email: 'user@example.com'),
      ).thenAnswer((_) async {});

      await sut.sendPasswordResetEmail(email: 'user@example.com');

      verify(
        () => mockAuth.sendPasswordResetEmail(email: 'user@example.com'),
      ).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // signOut
  // -------------------------------------------------------------------------

  group('signOut', () {
    test('calls FirebaseAuth.signOut()', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await sut.signOut();

      verify(() => mockAuth.signOut()).called(1);
    });
  });
}
