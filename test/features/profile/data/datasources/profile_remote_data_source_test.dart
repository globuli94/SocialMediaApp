// test/features/profile/data/datasources/profile_remote_data_source_test.dart
//
// Unit tests for ProfileRemoteDataSource.
// All Firebase SDK types are hidden behind abstract interfaces and replaced
// with mocktail doubles.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:social_network/features/profile/data/datasources/profile_auth_service.dart';
import 'package:social_network/features/profile/data/datasources/profile_firestore_service.dart';
import 'package:social_network/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:social_network/features/profile/data/datasources/profile_storage_service.dart';

class _MockFirestoreService extends Mock implements ProfileFirestoreService {}

class _MockStorageService extends Mock implements ProfileStorageService {}

class _MockAuthService extends Mock implements ProfileAuthService {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  late _MockFirestoreService firestoreService;
  late _MockStorageService storageService;
  late _MockAuthService authService;
  late ProfileRemoteDataSource dataSource;

  setUp(() {
    firestoreService = _MockFirestoreService();
    storageService = _MockStorageService();
    authService = _MockAuthService();
    dataSource = ProfileRemoteDataSource(
      firestoreService: firestoreService,
      storageService: storageService,
      authService: authService,
    );
  });

  group('fetchProfile', () {
    test('returns existing document data when document exists', () async {
      const uid = 'user-123';
      final existingData = <String, dynamic>{
        'uid': uid,
        'displayName': 'Alice',
        'bio': 'Hello',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'postCount': 5,
      };
      when(() => firestoreService.getUser(uid))
          .thenAnswer((_) async => existingData);

      final result = await dataSource.fetchProfile(uid);

      expect(result, equals(existingData));
      verifyNever(() => firestoreService.createUser(any(), any()));
    });

    test(
        'creates document with defaults and returns them when document is missing '
        '(email available)', () async {
      const uid = 'new-user';
      const email = 'alice@example.com';
      when(() => firestoreService.getUser(uid)).thenAnswer((_) async => null);
      when(() => authService.currentUserEmail).thenReturn(email);
      when(() => firestoreService.createUser(uid, any()))
          .thenAnswer((_) async {});

      final result = await dataSource.fetchProfile(uid);

      expect(result['uid'], equals(uid));
      expect(result['displayName'], equals('alice')); // email prefix
      expect(result['bio'], equals(''));
      expect(result['avatarUrl'], isNull);
      expect(result['postCount'], equals(0));

      verify(() => firestoreService.createUser(uid, any())).called(1);
    });

    test(
        'creates document using uid as displayName when no email is available',
        () async {
      const uid = 'anon-user';
      when(() => firestoreService.getUser(uid)).thenAnswer((_) async => null);
      when(() => authService.currentUserEmail).thenReturn(null);
      when(() => firestoreService.createUser(uid, any()))
          .thenAnswer((_) async {});

      final result = await dataSource.fetchProfile(uid);

      expect(result['displayName'], equals(uid));
    });

    test('propagates exception when getUser throws', () async {
      const uid = 'user-err';
      when(() => firestoreService.getUser(uid))
          .thenThrow(Exception('Firestore error'));

      expect(() => dataSource.fetchProfile(uid), throwsException);
    });
  });

  group('updateProfile', () {
    test('delegates to firestoreService.updateUser with correct fields',
        () async {
      const uid = 'user-123';
      const displayName = 'Bob';
      const bio = 'My bio';
      when(() => firestoreService.updateUser(uid, any()))
          .thenAnswer((_) async {});

      await dataSource.updateProfile(uid: uid, displayName: displayName, bio: bio);

      verify(
        () => firestoreService.updateUser(
          uid,
          {'displayName': displayName, 'bio': bio},
        ),
      ).called(1);
    });

    test('propagates exception when updateUser throws', () async {
      when(() => firestoreService.updateUser(any(), any()))
          .thenThrow(Exception('update failed'));

      expect(
        () => dataSource.updateProfile(
            uid: 'u', displayName: 'n', bio: 'b'),
        throwsException,
      );
    });
  });

  group('uploadAvatarBytes', () {
    test('uploads bytes and returns download URL', () async {
      const uid = 'user-123';
      const extension = '.jpg';
      final bytes = Uint8List.fromList([1, 2, 3]);
      const expectedUrl = 'https://storage.example.com/avatars/user-123.jpg';
      const path = 'avatars/$uid';

      when(() => storageService.uploadBytes(path, bytes, 'image/jpeg'))
          .thenAnswer((_) async {});
      when(() => storageService.getDownloadUrl(path))
          .thenAnswer((_) async => expectedUrl);

      final result = await dataSource.uploadAvatarBytes(
          uid: uid, bytes: bytes, extension: extension);

      expect(result, equals(expectedUrl));
      verify(() => storageService.uploadBytes(path, bytes, 'image/jpeg')).called(1);
      verify(() => storageService.getDownloadUrl(path)).called(1);
    });

    test('propagates exception when uploadBytes throws', () async {
      when(() => storageService.uploadBytes(
            any(),
            any(),
            any(),
          )).thenThrow(Exception('upload failed'));

      expect(
        () => dataSource.uploadAvatarBytes(
            uid: 'u', bytes: Uint8List(0), extension: '.png'),
        throwsException,
      );
    });
  });

  group('updateAvatarUrl', () {
    test('delegates to firestoreService.updateUser with avatarUrl field',
        () async {
      const uid = 'user-123';
      const avatarUrl = 'https://example.com/new-avatar.jpg';
      when(() => firestoreService.updateUser(any(), any()))
          .thenAnswer((_) async {});

      await dataSource.updateAvatarUrl(uid: uid, avatarUrl: avatarUrl);

      verify(
        () => firestoreService.updateUser(uid, {'avatarUrl': avatarUrl}),
      ).called(1);
    });

    test('propagates exception when updateUser throws', () async {
      when(() => firestoreService.updateUser(any(), any()))
          .thenThrow(Exception('update failed'));

      expect(
        () => dataSource.updateAvatarUrl(uid: 'u', avatarUrl: 'url'),
        throwsException,
      );
    });
  });
}
