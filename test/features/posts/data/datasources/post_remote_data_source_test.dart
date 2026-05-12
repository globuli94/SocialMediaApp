// test/features/posts/data/datasources/post_remote_data_source_test.dart
//
// Unit tests for PostRemoteDataSource.
// All Firebase SDK types are hidden behind abstract interfaces and replaced
// with mocktail doubles.

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
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  late MockPostFirestoreService firestoreService;
  late MockPostStorageService storageService;
  late PostRemoteDataSource dataSource;

  const postId = 'generated-post-id';
  const authorUid = 'uid-alice';
  const authorDisplayName = 'Alice';
  const content = 'Hello world';

  setUp(() {
    firestoreService = MockPostFirestoreService();
    storageService = MockPostStorageService();
    dataSource = PostRemoteDataSource(
      firestoreService: firestoreService,
      storageService: storageService,
    );
  });

  // -------------------------------------------------------------------------
  // watchFeed
  // -------------------------------------------------------------------------

  group('watchFeed', () {
    test('delegates to firestoreService.watchPosts and returns the stream', () {
      final data = <Map<String, dynamic>>[
        {'id': 'post-1', 'content': 'Hello', 'authorUid': 'uid-1'},
      ];
      when(() => firestoreService.watchPosts())
          .thenAnswer((_) => Stream.value(data));

      final stream = dataSource.watchFeed();

      expect(stream, emits(data));
      verify(() => firestoreService.watchPosts()).called(1);
    });

    test('propagates stream events as they arrive', () async {
      final events = <List<Map<String, dynamic>>>[
        [
          {'id': 'p1', 'content': 'First'},
        ],
        [
          {'id': 'p1', 'content': 'First'},
          {'id': 'p2', 'content': 'Second'},
        ],
      ];
      when(() => firestoreService.watchPosts())
          .thenAnswer((_) => Stream.fromIterable(events));

      await expectLater(dataSource.watchFeed(), emitsInOrder(events));
    });
  });

  // -------------------------------------------------------------------------
  // createPost — text-only
  // -------------------------------------------------------------------------

  group('createPost — text-only', () {
    setUp(() {
      when(() => firestoreService.generatePostId()).thenReturn(postId);
      when(() => firestoreService.createPostWithId(any(), any()))
          .thenAnswer((_) async {});
      when(() => firestoreService.adjustPostCount(any(), any()))
          .thenAnswer((_) async {});
    });

    test('does not call any storage service methods', () async {
      await dataSource.createPost(
        authorUid: authorUid,
        authorDisplayName: authorDisplayName,
        content: content,
      );

      verifyNever(() => storageService.uploadBytes(any(), any(), any()));
      verifyNever(() => storageService.getDownloadUrl(any()));
    });

    test('calls createPostWithId with correct authorUid, displayName, content',
        () async {
      await dataSource.createPost(
        authorUid: authorUid,
        authorDisplayName: authorDisplayName,
        content: content,
      );

      final captured = verify(
        () => firestoreService.createPostWithId(postId, captureAny()),
      ).captured;
      final data = captured.first as Map<String, dynamic>;

      expect(data['authorUid'], equals(authorUid));
      expect(data['authorDisplayName'], equals(authorDisplayName));
      expect(data['content'], equals(content));
      expect(data['likeCount'], equals(0));
      // imageUrl key should be absent (not set) for text-only posts.
      expect(data.containsKey('imageUrl'), isFalse);
    });

    test('calls generatePostId to obtain the document ID', () async {
      await dataSource.createPost(
        authorUid: authorUid,
        authorDisplayName: authorDisplayName,
        content: content,
      );

      verify(() => firestoreService.generatePostId()).called(1);
    });

    test('increments postCount via adjustPostCount(authorUid, 1)', () async {
      await dataSource.createPost(
        authorUid: authorUid,
        authorDisplayName: authorDisplayName,
        content: content,
      );

      verify(() => firestoreService.adjustPostCount(authorUid, 1)).called(1);
    });

    test('returns a map that includes the generated post id', () async {
      final result = await dataSource.createPost(
        authorUid: authorUid,
        authorDisplayName: authorDisplayName,
        content: content,
      );

      expect(result['id'], equals(postId));
    });

    test('stores authorAvatarUrl in document when provided', () async {
      const avatarUrl = 'https://example.com/avatar.jpg';
      when(() => firestoreService.generatePostId()).thenReturn(postId);

      await dataSource.createPost(
        authorUid: authorUid,
        authorDisplayName: authorDisplayName,
        content: content,
        authorAvatarUrl: avatarUrl,
      );

      final captured = verify(
        () => firestoreService.createPostWithId(postId, captureAny()),
      ).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['authorAvatarUrl'], equals(avatarUrl));
    });
  });

  // -------------------------------------------------------------------------
  // createPost — with image bytes
  // -------------------------------------------------------------------------

  group('createPost — with image bytes', () {
    const imageUrl = 'https://storage.example.com/posts/generated-post-id';
    const storagePath = 'posts/$postId';
    late Uint8List imageBytes;

    setUp(() {
      imageBytes = Uint8List.fromList([1, 2, 3, 4]);
      when(() => firestoreService.generatePostId()).thenReturn(postId);
      when(() => firestoreService.createPostWithId(any(), any()))
          .thenAnswer((_) async {});
      when(() => firestoreService.adjustPostCount(any(), any()))
          .thenAnswer((_) async {});
      when(
        () => storageService.uploadBytes(storagePath, imageBytes, any()),
      ).thenAnswer((_) async {});
      when(() => storageService.getDownloadUrl(storagePath))
          .thenAnswer((_) async => imageUrl);
    });

    test('calls uploadBytes with path posts/{postId} and jpeg content-type',
        () async {
      await dataSource.createPost(
        authorUid: authorUid,
        authorDisplayName: authorDisplayName,
        content: content,
        imageBytes: imageBytes,
        imageExtension: '.jpg',
      );

      verify(
        () => storageService.uploadBytes(
          storagePath,
          imageBytes,
          'image/jpeg',
        ),
      ).called(1);
    });

    test('calls getDownloadUrl after uploading', () async {
      await dataSource.createPost(
        authorUid: authorUid,
        authorDisplayName: authorDisplayName,
        content: content,
        imageBytes: imageBytes,
        imageExtension: '.jpg',
      );

      verify(() => storageService.getDownloadUrl(storagePath)).called(1);
    });

    test('stores imageUrl in post document', () async {
      await dataSource.createPost(
        authorUid: authorUid,
        authorDisplayName: authorDisplayName,
        content: content,
        imageBytes: imageBytes,
        imageExtension: '.jpg',
      );

      final captured = verify(
        () => firestoreService.createPostWithId(postId, captureAny()),
      ).captured;
      final data = captured.first as Map<String, dynamic>;
      expect(data['imageUrl'], equals(imageUrl));
    });

    test('uses image/png content-type for .png extension', () async {
      when(
        () => storageService.uploadBytes(storagePath, imageBytes, 'image/png'),
      ).thenAnswer((_) async {});

      await dataSource.createPost(
        authorUid: authorUid,
        authorDisplayName: authorDisplayName,
        content: content,
        imageBytes: imageBytes,
        imageExtension: '.png',
      );

      verify(
        () => storageService.uploadBytes(storagePath, imageBytes, 'image/png'),
      ).called(1);
    });

    test('uses image/webp content-type for .webp extension', () async {
      when(
        () =>
            storageService.uploadBytes(storagePath, imageBytes, 'image/webp'),
      ).thenAnswer((_) async {});

      await dataSource.createPost(
        authorUid: authorUid,
        authorDisplayName: authorDisplayName,
        content: content,
        imageBytes: imageBytes,
        imageExtension: '.webp',
      );

      verify(
        () =>
            storageService.uploadBytes(storagePath, imageBytes, 'image/webp'),
      ).called(1);
    });

    test('still increments postCount when image is uploaded', () async {
      await dataSource.createPost(
        authorUid: authorUid,
        authorDisplayName: authorDisplayName,
        content: content,
        imageBytes: imageBytes,
        imageExtension: '.jpg',
      );

      verify(() => firestoreService.adjustPostCount(authorUid, 1)).called(1);
    });

    test('skips storage when imageBytes is provided but imageExtension is null',
        () async {
      await dataSource.createPost(
        authorUid: authorUid,
        authorDisplayName: authorDisplayName,
        content: content,
        imageBytes: imageBytes,
        // imageExtension omitted — storage upload should be skipped
      );

      verifyNever(() => storageService.uploadBytes(any(), any(), any()));
    });
  });

  // -------------------------------------------------------------------------
  // deletePost — with imageUrl
  // -------------------------------------------------------------------------

  group('deletePost — with imageUrl', () {
    const deletePostId = 'post-to-delete';
    const imageUrl = 'https://storage.example.com/posts/post-to-delete';

    setUp(() {
      when(() => firestoreService.deletePost(any()))
          .thenAnswer((_) async {});
      when(() => firestoreService.adjustPostCount(any(), any()))
          .thenAnswer((_) async {});
      when(() => storageService.delete(any()))
          .thenAnswer((_) async {});
    });

    test('calls firestoreService.deletePost', () async {
      await dataSource.deletePost(
        postId: deletePostId,
        authorUid: authorUid,
        imageUrl: imageUrl,
      );

      verify(() => firestoreService.deletePost(deletePostId)).called(1);
    });

    test('calls storageService.delete with path posts/{postId}', () async {
      await dataSource.deletePost(
        postId: deletePostId,
        authorUid: authorUid,
        imageUrl: imageUrl,
      );

      verify(() => storageService.delete('posts/$deletePostId')).called(1);
    });

    test('decrements postCount via adjustPostCount(authorUid, -1)', () async {
      await dataSource.deletePost(
        postId: deletePostId,
        authorUid: authorUid,
        imageUrl: imageUrl,
      );

      verify(
        () => firestoreService.adjustPostCount(authorUid, -1),
      ).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // deletePost — without imageUrl
  // -------------------------------------------------------------------------

  group('deletePost — no imageUrl', () {
    const deletePostId = 'post-no-image';

    setUp(() {
      when(() => firestoreService.deletePost(any()))
          .thenAnswer((_) async {});
      when(() => firestoreService.adjustPostCount(any(), any()))
          .thenAnswer((_) async {});
    });

    test('skips storageService.delete when imageUrl is null', () async {
      await dataSource.deletePost(
        postId: deletePostId,
        authorUid: authorUid,
      );

      verifyNever(() => storageService.delete(any()));
    });

    test('still calls firestoreService.deletePost', () async {
      await dataSource.deletePost(
        postId: deletePostId,
        authorUid: authorUid,
      );

      verify(() => firestoreService.deletePost(deletePostId)).called(1);
    });

    test('decrements postCount via adjustPostCount(authorUid, -1)', () async {
      await dataSource.deletePost(
        postId: deletePostId,
        authorUid: authorUid,
      );

      verify(
        () => firestoreService.adjustPostCount(authorUid, -1),
      ).called(1);
    });
  });
}
