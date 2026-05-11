// test/features/profile/data/repositories/profile_repository_impl_test.dart
//
// Unit tests for ProfileRepositoryImpl — covers every public method with
// success and failure paths to satisfy the ≥ 80% repository coverage
// threshold.
//
// All Firebase interactions are replaced by mocktail stubs; no real Firebase
// instance is required.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:social_network/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockProfileRemoteDataSource extends Mock
    implements ProfileRemoteDataSource {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockProfileRemoteDataSource mockDataSource;
  late ProfileRepositoryImpl sut;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockDataSource = MockProfileRemoteDataSource();
    sut = ProfileRepositoryImpl(dataSource: mockDataSource);
  });

  // -------------------------------------------------------------------------
  // getProfile
  // -------------------------------------------------------------------------

  group('getProfile', () {
    const Map<String, dynamic> rawData = {
      'uid': 'uid-123',
      'displayName': 'Alice',
      'bio': 'Short bio',
      'avatarUrl': 'https://example.com/avatar.jpg',
      'postCount': 5,
    };

    test('maps raw data to UserProfileEntity on success', () async {
      when(() => mockDataSource.fetchProfile('uid-123'))
          .thenAnswer((_) async => rawData);

      final UserProfileEntity result = await sut.getProfile('uid-123');

      expect(result.uid, 'uid-123');
      expect(result.displayName, 'Alice');
      expect(result.bio, 'Short bio');
      expect(result.avatarUrl, 'https://example.com/avatar.jpg');
      expect(result.postCount, 5);
    });

    test('uses defaults for missing/null fields in raw data', () async {
      when(() => mockDataSource.fetchProfile('uid-empty'))
          .thenAnswer((_) async => <String, dynamic>{});

      final UserProfileEntity result = await sut.getProfile('uid-empty');

      expect(result.uid, '');
      expect(result.displayName, '');
      expect(result.bio, '');
      expect(result.avatarUrl, isNull);
      expect(result.postCount, 0);
    });

    test('throws string error when fetchProfile throws', () async {
      when(() => mockDataSource.fetchProfile(any()))
          .thenThrow(Exception('network error'));

      expect(
        () => sut.getProfile('uid-123'),
        throwsA(isA<String>().having((s) => s, 'message',
            contains('Failed to load profile'))),
      );
    });
  });

  // -------------------------------------------------------------------------
  // updateProfile
  // -------------------------------------------------------------------------

  group('updateProfile', () {
    test('delegates to dataSource.updateProfile', () async {
      when(
        () => mockDataSource.updateProfile(
          uid: 'uid-123',
          displayName: 'Bob',
          bio: 'New bio',
        ),
      ).thenAnswer((_) async {});

      await sut.updateProfile(
        uid: 'uid-123',
        displayName: 'Bob',
        bio: 'New bio',
      );

      verify(
        () => mockDataSource.updateProfile(
          uid: 'uid-123',
          displayName: 'Bob',
          bio: 'New bio',
        ),
      ).called(1);
    });

    test('throws string error when dataSource.updateProfile throws', () async {
      when(
        () => mockDataSource.updateProfile(
          uid: any(named: 'uid'),
          displayName: any(named: 'displayName'),
          bio: any(named: 'bio'),
        ),
      ).thenThrow(Exception('firestore error'));

      expect(
        () => sut.updateProfile(
          uid: 'uid-123',
          displayName: 'Bob',
          bio: 'New bio',
        ),
        throwsA(isA<String>().having((s) => s, 'message',
            contains('Failed to update profile'))),
      );
    });
  });

  // -------------------------------------------------------------------------
  // uploadAvatar
  // -------------------------------------------------------------------------

  group('uploadAvatar', () {
    test('calls uploadAvatarBytes then updateAvatarUrl', () async {
      final bytes = Uint8List.fromList([10, 20, 30]);
      when(
        () => mockDataSource.uploadAvatarBytes(
          uid: 'uid-123',
          bytes: bytes,
          extension: '.jpg',
        ),
      ).thenAnswer((_) async => 'https://storage.example.com/avatar.jpg');

      when(
        () => mockDataSource.updateAvatarUrl(
          uid: 'uid-123',
          avatarUrl: 'https://storage.example.com/avatar.jpg',
        ),
      ).thenAnswer((_) async {});

      await sut.uploadAvatar(
        uid: 'uid-123',
        bytes: bytes,
        extension: '.jpg',
      );

      verify(
        () => mockDataSource.uploadAvatarBytes(
          uid: 'uid-123',
          bytes: bytes,
          extension: '.jpg',
        ),
      ).called(1);

      verify(
        () => mockDataSource.updateAvatarUrl(
          uid: 'uid-123',
          avatarUrl: 'https://storage.example.com/avatar.jpg',
        ),
      ).called(1);
    });

    test('throws string error when uploadAvatarBytes throws', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(
        () => mockDataSource.uploadAvatarBytes(
          uid: any(named: 'uid'),
          bytes: any(named: 'bytes'),
          extension: any(named: 'extension'),
        ),
      ).thenThrow(Exception('storage quota exceeded'));

      expect(
        () => sut.uploadAvatar(
          uid: 'uid-123',
          bytes: bytes,
          extension: '.jpg',
        ),
        throwsA(isA<String>().having((s) => s, 'message',
            contains('Failed to upload avatar'))),
      );
    });

    test('throws string error when updateAvatarUrl throws', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(
        () => mockDataSource.uploadAvatarBytes(
          uid: any(named: 'uid'),
          bytes: any(named: 'bytes'),
          extension: any(named: 'extension'),
        ),
      ).thenAnswer((_) async => 'https://storage.example.com/avatar.jpg');

      when(
        () => mockDataSource.updateAvatarUrl(
          uid: any(named: 'uid'),
          avatarUrl: any(named: 'avatarUrl'),
        ),
      ).thenThrow(Exception('firestore write error'));

      expect(
        () => sut.uploadAvatar(
          uid: 'uid-123',
          bytes: bytes,
          extension: '.jpg',
        ),
        throwsA(isA<String>().having((s) => s, 'message',
            contains('Failed to upload avatar'))),
      );
    });
  });
}
