// test/features/posts/data/repositories/post_repository_impl_test.dart
//
// Data-layer tests for PostRemoteDataSource — covers watchFeed, createPost
// (with and without image), and deletePost, satisfying the ≥ 80% repository
// coverage threshold.
//
// PostRepositoryImpl delegates directly to FirebaseFirestore/FirebaseStorage
// (which are sealed in cloud_firestore v5 and cannot be mocked). These tests
// therefore target PostRemoteDataSource, which depends on the mockable
// PostFirestoreService and PostStorageService abstractions. This approach
// follows the same pattern used for the Profile feature (data-source mock
// rather than Firebase mock) and avoids subtype_of_sealed_class lint errors.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/posts/data/datasources/post_firestore_service.dart';
import 'package:social_network/features/posts/data/datasources/post_remote_data_source.dart';
import 'package:social_network/features/posts/data/datasources/post_storage_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPostFirestoreService extends Mock implements PostFirestoreService {}

class MockPostStorageService extends Mock implements PostStorageService {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockPostFirestoreService mockFirestoreService;
  late MockPostStorageService mockStorageService;
  late PostRemoteDataSource sut;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    mockFirestoreService = MockPostFirestoreService();
    mockStorageService = MockPostStorageService();

    sut = PostRemoteDataSource(
      firestoreService: mockFirestoreService,
      storageService: mockStorageService,
    );
  });

  // -------------------------------------------------------------------------
  // watchFeed
  // -------------------------------------------------------------------------

  group('watchFeed', () {
    test('returns the stream emitted by PostFirestoreService.watchPosts',
        () async {
      final rawPosts = [
        {
          'id': 'post-1',
          'authorUid': 'uid-alice',
          'authorDisplayName': 'Alice',
          'content': 'Hello',
          'createdAt': DateTime(2026, 1, 1),
        },
        {
          'id': 'post-2',
          'authorUid': 'uid-bob',
          'authorDisplayName': 'Bob',
          'content': 'World',
          'createdAt': DateTime(2026, 1, 2),
          'imageUrl': 'https://example.com/img.jpg',
        },
      ];
      when(() => mockFirestoreService.watchPosts())
          .thenAnswer((_) => Stream.value(rawPosts));

      final result = await sut.watchFeed().first;

      expect(result.length, 2);
      expect(result[0]['id'], 'post-1');
      expect(result[1]['imageUrl'], 'https://example.com/img.jpg');
      verify(() => mockFirestoreService.watchPosts()).called(1);
    });

    test('returns empty list when firestoreService emits an empty snapshot',
        () async {
      when(() => mockFirestoreService.watchPosts())
          .thenAnswer((_) => Stream.value([]));

      final result = await sut.watchFeed().first;
      expect(result, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // createPost — without image
  // -------------------------------------------------------------------------

  group('createPost (no image)', () {
    test('creates document and returns data map without imageUrl', () async {
      when(() => mockFirestoreService.generatePostId())
          .thenReturn('post-text-only');
      when(() => mockFirestoreService.createPostWithId(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockFirestoreService.adjustPostCount(any(), any()))
          .thenAnswer((_) async {});

      final result = await sut.createPost(
        authorUid: 'uid-alice',
        authorDisplayName: 'Alice',
        content: 'My first post',
      );

      expect(result['id'], 'post-text-only');
      expect(result['authorUid'], 'uid-alice');
      expect(result['authorDisplayName'], 'Alice');
      expect(result['content'], 'My first post');
      expect(result['imageUrl'], isNull);
      expect(result['createdAt'], isA<DateTime>());

      verify(() => mockFirestoreService.createPostWithId(
            'post-text-only',
            any(),
          )).called(1);
      verify(
        () => mockFirestoreService.adjustPostCount('uid-alice', 1),
      ).called(1);
      verifyNever(
        () => mockStorageService.uploadBytes(any(), any(), any()),
      );
    });

    test('includes authorAvatarUrl in returned map when provided', () async {
      when(() => mockFirestoreService.generatePostId())
          .thenReturn('post-with-avatar');
      when(() => mockFirestoreService.createPostWithId(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockFirestoreService.adjustPostCount(any(), any()))
          .thenAnswer((_) async {});

      final result = await sut.createPost(
        authorUid: 'uid-alice',
        authorDisplayName: 'Alice',
        authorAvatarUrl: 'https://example.com/alice.jpg',
        content: 'Post with avatar',
      );

      expect(result['authorAvatarUrl'], 'https://example.com/alice.jpg');
    });

    test('omits authorAvatarUrl key when not provided', () async {
      when(() => mockFirestoreService.generatePostId()).thenReturn('post-no-av');
      when(() => mockFirestoreService.createPostWithId(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockFirestoreService.adjustPostCount(any(), any()))
          .thenAnswer((_) async {});

      final result = await sut.createPost(
        authorUid: 'uid-alice',
        authorDisplayName: 'Alice',
        content: 'No avatar',
      );

      expect(result.containsKey('authorAvatarUrl'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // createPost — with image (.jpg → image/jpeg content type)
  // -------------------------------------------------------------------------

  group('createPost (with image)', () {
    test('uploads image then creates document with imageUrl', () async {
      const postId = 'post-img-id';
      final bytes = Uint8List.fromList([1, 2, 3]);
      const storagePath = 'posts/$postId';
      const downloadUrl = 'https://storage.example.com/posts/$postId';

      when(() => mockFirestoreService.generatePostId()).thenReturn(postId);
      when(
        () => mockStorageService.uploadBytes(
          storagePath,
          any(),
          'image/jpeg',
        ),
      ).thenAnswer((_) async {});
      when(() => mockStorageService.getDownloadUrl(storagePath))
          .thenAnswer((_) async => downloadUrl);
      when(() => mockFirestoreService.createPostWithId(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockFirestoreService.adjustPostCount(any(), any()))
          .thenAnswer((_) async {});

      final result = await sut.createPost(
        authorUid: 'uid-alice',
        authorDisplayName: 'Alice',
        content: 'Post with image',
        imageBytes: bytes,
        imageExtension: '.jpg',
      );

      expect(result['imageUrl'], downloadUrl);
      verify(
        () => mockStorageService.uploadBytes(storagePath, any(), 'image/jpeg'),
      ).called(1);
      verify(() => mockStorageService.getDownloadUrl(storagePath)).called(1);
      verify(
        () => mockFirestoreService.createPostWithId(postId, any()),
      ).called(1);
      verify(
        () => mockFirestoreService.adjustPostCount('uid-alice', 1),
      ).called(1);
    });

    test('uses image/png content type for .png extension', () async {
      const postId = 'post-png-id';
      const storagePath = 'posts/$postId';

      when(() => mockFirestoreService.generatePostId()).thenReturn(postId);
      when(
        () => mockStorageService.uploadBytes(storagePath, any(), 'image/png'),
      ).thenAnswer((_) async {});
      when(() => mockStorageService.getDownloadUrl(storagePath))
          .thenAnswer((_) async => 'https://example.com/posts/$postId');
      when(() => mockFirestoreService.createPostWithId(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockFirestoreService.adjustPostCount(any(), any()))
          .thenAnswer((_) async {});

      await sut.createPost(
        authorUid: 'uid-alice',
        authorDisplayName: 'Alice',
        content: 'PNG image post',
        imageBytes: Uint8List.fromList([1]),
        imageExtension: '.png',
      );

      verify(
        () => mockStorageService.uploadBytes(storagePath, any(), 'image/png'),
      ).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // deletePost
  // -------------------------------------------------------------------------

  group('deletePost', () {
    test('deletes post document and decrements postCount (no image)', () async {
      when(() => mockFirestoreService.deletePost(any()))
          .thenAnswer((_) async {});
      when(() => mockFirestoreService.adjustPostCount(any(), any()))
          .thenAnswer((_) async {});

      await sut.deletePost(postId: 'post-1', authorUid: 'uid-alice');

      verify(() => mockFirestoreService.deletePost('post-1')).called(1);
      verify(
        () => mockFirestoreService.adjustPostCount('uid-alice', -1),
      ).called(1);
      verifyNever(() => mockStorageService.delete(any()));
    });

    test('deletes storage image then post document when imageUrl provided',
        () async {
      when(() => mockFirestoreService.deletePost(any()))
          .thenAnswer((_) async {});
      when(() => mockStorageService.delete(any())).thenAnswer((_) async {});
      when(() => mockFirestoreService.adjustPostCount(any(), any()))
          .thenAnswer((_) async {});

      await sut.deletePost(
        postId: 'post-2',
        authorUid: 'uid-alice',
        imageUrl: 'https://example.com/img.jpg',
      );

      verify(() => mockStorageService.delete('posts/post-2')).called(1);
      verify(() => mockFirestoreService.deletePost('post-2')).called(1);
      verify(
        () => mockFirestoreService.adjustPostCount('uid-alice', -1),
      ).called(1);
    });
  });
}
