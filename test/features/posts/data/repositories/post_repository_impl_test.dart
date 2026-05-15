// test/features/posts/data/repositories/post_repository_impl_test.dart
//
// Unit tests for PostRepositoryImpl — covers watchPosts, createPost (with and
// without image), and deletePost, satisfying the ≥ 80% repository coverage
// threshold.
//
// Firestore operations are exercised against FakeFirebaseFirestore so that
// sealed internal Firestore types (Query, DocumentReference, etc.) remain
// in-memory without hitting real Firebase.  Firebase Storage is replaced by
// mocktail stubs.  UploadTask and TaskSnapshot are wrapped by thin Fake
// helpers (private to this file) because their constructors are private.

import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/posts/data/repositories/post_repository_impl.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';

// ---------------------------------------------------------------------------
// Mocks & fakes
// ---------------------------------------------------------------------------

class MockFirebaseStorage extends Mock implements FirebaseStorage {}

class MockReference extends Mock implements Reference {}

/// Minimal [TaskSnapshot] fake — only exposes [ref] which is the only
/// property accessed by [PostRepositoryImpl.createPost].
class _FakeTaskSnapshot extends Fake implements TaskSnapshot {
  _FakeTaskSnapshot(this._ref);
  final Reference _ref;

  @override
  Reference get ref => _ref;
}

/// Minimal [UploadTask] fake.  Implements [Future]<[TaskSnapshot]> by
/// delegating to [Future.value] so that `await uploadTask` resolves
/// synchronously to the wrapped snapshot in tests.
class _FakeUploadTask extends Fake implements UploadTask {
  _FakeUploadTask(this._snapshot);
  final TaskSnapshot _snapshot;

  @override
  Future<T> then<T>(
    FutureOr<T> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) =>
      Future<TaskSnapshot>.value(_snapshot).then(onValue, onError: onError);

  @override
  Future<TaskSnapshot> catchError(
    Function onError, {
    bool Function(Object)? test,
  }) =>
      Future<TaskSnapshot>.value(_snapshot)
          .catchError(onError, test: test);

  @override
  Future<TaskSnapshot> whenComplete(FutureOr<void> Function() action) =>
      Future<TaskSnapshot>.value(_snapshot).whenComplete(action);

  @override
  Future<TaskSnapshot> timeout(
    Duration timeLimit, {
    FutureOr<TaskSnapshot> Function()? onTimeout,
  }) =>
      Future<TaskSnapshot>.value(_snapshot)
          .timeout(timeLimit, onTimeout: onTimeout);

  @override
  Stream<TaskSnapshot> asStream() => Stream.value(_snapshot);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseStorage mockStorage;
  late PostRepositoryImpl sut;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(SettableMetadata());
  });

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    mockStorage = MockFirebaseStorage();
    sut = PostRepositoryImpl(
      firestore: fakeFirestore,
      storage: mockStorage,
    );
    // Seed the default test user so update() calls on users/{uid} don't throw
    // not-found in fake_cloud_firestore (which mimics real Firestore behaviour).
    await fakeFirestore
        .collection('users')
        .doc('uid-alice')
        .set({'postCount': 0});
  });

  // -------------------------------------------------------------------------
  // watchPosts
  // -------------------------------------------------------------------------

  group('watchPosts', () {
    test('emits empty list when collection is empty', () async {
      final result = await sut.watchPosts().first;
      expect(result, isEmpty);
    });

    test('emits PostEntity list ordered by createdAt descending', () async {
      final older = Timestamp.fromDate(DateTime(2026, 1, 1));
      final newer = Timestamp.fromDate(DateTime(2026, 1, 2));

      await fakeFirestore.collection('posts').doc('post-old').set({
        'id': 'post-old',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Older post',
        'createdAt': older,
        'likeCount': 0,
      });
      await fakeFirestore.collection('posts').doc('post-new').set({
        'id': 'post-new',
        'authorUid': 'uid-bob',
        'authorDisplayName': 'Bob',
        'content': 'Newer post',
        'createdAt': newer,
        'likeCount': 0,
        'imageUrl': 'https://example.com/img.jpg',
      });

      final result = await sut.watchPosts().first;

      expect(result, hasLength(2));
      // Ordered newest-first.
      expect(result.first.id, 'post-new');
      expect(result.last.id, 'post-old');
    });

    test('maps all PostEntity fields correctly', () async {
      final ts = Timestamp.fromDate(DateTime(2026, 3, 15));
      await fakeFirestore.collection('posts').doc('p1').set({
        'id': 'p1',
        'authorUid': 'uid-charlie',
        'authorDisplayName': 'Charlie',
        'authorAvatarUrl': 'https://example.com/avatar.jpg',
        'content': 'Hello world',
        'createdAt': ts,
        'likeCount': 5,
        'imageUrl': 'https://example.com/post.jpg',
      });

      final entities = await sut.watchPosts().first;
      final entity = entities.single;

      expect(entity, isA<PostEntity>());
      expect(entity.id, 'p1');
      expect(entity.authorUid, 'uid-charlie');
      expect(entity.authorDisplayName, 'Charlie');
      expect(entity.authorAvatarUrl, 'https://example.com/avatar.jpg');
      expect(entity.content, 'Hello world');
      expect(entity.createdAt, DateTime(2026, 3, 15));
      expect(entity.imageUrl, 'https://example.com/post.jpg');
    });

    test('uses DateTime.now() when createdAt is missing', () async {
      await fakeFirestore.collection('posts').doc('p-no-ts').set({
        'id': 'p-no-ts',
        'authorUid': 'uid-x',
        'authorDisplayName': 'X',
        'content': 'No timestamp',
        'likeCount': 0,
      });

      final entities = await sut.watchPosts().first;
      expect(entities.single.createdAt, isA<DateTime>());
    });
  });

  // -------------------------------------------------------------------------
  // createPost — without image
  // -------------------------------------------------------------------------

  group('createPost (no image)', () {
    test('creates Firestore doc and returns PostEntity', () async {
      final result = await sut.createPost(
        authorUid: 'uid-alice',
        authorDisplayName: 'Alice',
        content: 'My first post',
      );

      expect(result, isA<PostEntity>());
      expect(result.authorUid, 'uid-alice');
      expect(result.authorDisplayName, 'Alice');
      expect(result.content, 'My first post');
      expect(result.imageUrl, isNull);

      final docs = await fakeFirestore.collection('posts').get();
      expect(docs.docs, hasLength(1));

      verifyNever(() => mockStorage.ref(any()));
    });

    test('includes authorAvatarUrl in returned entity when provided', () async {
      final result = await sut.createPost(
        authorUid: 'uid-alice',
        authorDisplayName: 'Alice',
        authorAvatarUrl: 'https://example.com/alice.jpg',
        content: 'With avatar',
      );

      expect(result.authorAvatarUrl, 'https://example.com/alice.jpg');
    });

    // BUG-008 regression
    test('increments users/{uid}.postCount by 1', () async {
      await fakeFirestore
          .collection('users')
          .doc('uid-alice')
          .set({'postCount': 2});

      await sut.createPost(
        authorUid: 'uid-alice',
        authorDisplayName: 'Alice',
        content: 'Count increment test',
      );

      final userSnap = await fakeFirestore
          .collection('users')
          .doc('uid-alice')
          .get();
      expect(userSnap.data()?['postCount'], 3);
    });
  });

  // -------------------------------------------------------------------------
  // createPost — with image
  // -------------------------------------------------------------------------

  group('createPost (with image)', () {
    late MockReference mockRef;
    late MockReference mockUploadRef;

    setUp(() {
      mockRef = MockReference();
      mockUploadRef = MockReference();
      when(() => mockStorage.ref(any())).thenReturn(mockRef);
      when(() => mockUploadRef.getDownloadURL())
          .thenAnswer((_) async => 'https://storage.example.com/post.jpg');
    });

    /// Calls [createPost] with [imageExtension] and returns the captured
    /// [SettableMetadata] passed to [Reference.putData].
    Future<SettableMetadata?> runAndCaptureMetadata(String extension) async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final fakeSnapshot = _FakeTaskSnapshot(mockUploadRef);
      final fakeTask = _FakeUploadTask(fakeSnapshot);
      when(() => mockRef.putData(any(), any())).thenAnswer((_) => fakeTask);

      await sut.createPost(
        authorUid: 'uid-alice',
        authorDisplayName: 'Alice',
        content: 'Image post',
        imageBytes: bytes,
        imageExtension: extension,
      );

      final captured =
          verify(() => mockRef.putData(captureAny(), captureAny())).captured;
      // captured = [bytes, SettableMetadata] for the single call.
      return captured[1] as SettableMetadata?;
    }

    test('uploads image and returns PostEntity with imageUrl', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final fakeSnapshot = _FakeTaskSnapshot(mockUploadRef);
      final fakeTask = _FakeUploadTask(fakeSnapshot);
      when(() => mockRef.putData(any(), any())).thenAnswer((_) => fakeTask);

      final result = await sut.createPost(
        authorUid: 'uid-alice',
        authorDisplayName: 'Alice',
        content: 'Image post',
        imageBytes: bytes,
        imageExtension: '.jpg',
      );

      expect(result.imageUrl, 'https://storage.example.com/post.jpg');
      verify(() => mockStorage.ref(any())).called(1);
      verify(() => mockRef.putData(any(), any())).called(1);
      verify(() => mockUploadRef.getDownloadURL()).called(1);
    });

    test(
        'putData receives SettableMetadata(contentType: image/jpeg) for .jpg',
        () async {
      final metadata = await runAndCaptureMetadata('.jpg');
      expect(metadata?.contentType, 'image/jpeg');
    });

    test(
        'putData receives SettableMetadata(contentType: image/png) for .png',
        () async {
      final metadata = await runAndCaptureMetadata('.png');
      expect(metadata?.contentType, 'image/png');
    });

    test(
        'putData receives SettableMetadata(contentType: image/webp) for .webp',
        () async {
      final metadata = await runAndCaptureMetadata('.webp');
      expect(metadata?.contentType, 'image/webp');
    });

    test(
        'putData receives SettableMetadata(contentType: image/jpeg) for unknown extension',
        () async {
      final metadata = await runAndCaptureMetadata('.gif');
      expect(metadata?.contentType, 'image/jpeg');
    });
  });

  // -------------------------------------------------------------------------
  // deletePost
  // -------------------------------------------------------------------------

  group('deletePost', () {
    test('deletes document when it does not exist (no-op)', () async {
      // Should not throw even if doc is missing.
      await expectLater(
        sut.deletePost('non-existent-post'),
        completes,
      );
    });

    test('deletes existing document without imageUrl', () async {
      await fakeFirestore.collection('posts').doc('p-del').set({
        'id': 'p-del',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'To be deleted',
        'createdAt': Timestamp.now(),
        'likeCount': 0,
      });

      await sut.deletePost('p-del');

      final snap = await fakeFirestore.collection('posts').doc('p-del').get();
      expect(snap.exists, isFalse);
      verifyNever(() => mockStorage.refFromURL(any()));
    });

    test('deletes storage image then document when imageUrl present', () async {
      const imageUrl = 'gs://my-bucket/posts/p-img.jpg';
      await fakeFirestore.collection('posts').doc('p-img').set({
        'id': 'p-img',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Image post',
        'createdAt': Timestamp.now(),
        'likeCount': 0,
        'imageUrl': imageUrl,
      });

      final mockRef = MockReference();
      when(() => mockStorage.refFromURL(imageUrl)).thenReturn(mockRef);
      when(() => mockRef.delete()).thenAnswer((_) async {});

      await sut.deletePost('p-img');

      verify(() => mockStorage.refFromURL(imageUrl)).called(1);
      verify(() => mockRef.delete()).called(1);

      final snap = await fakeFirestore.collection('posts').doc('p-img').get();
      expect(snap.exists, isFalse);
    });

    test('ignores storage delete error and still deletes Firestore doc',
        () async {
      const imageUrl = 'gs://my-bucket/posts/p-err.jpg';
      await fakeFirestore.collection('posts').doc('p-err').set({
        'id': 'p-err',
        'authorUid': 'uid-alice',
        'authorDisplayName': 'Alice',
        'content': 'Error image post',
        'createdAt': Timestamp.now(),
        'likeCount': 0,
        'imageUrl': imageUrl,
      });

      final mockRef = MockReference();
      when(() => mockStorage.refFromURL(imageUrl)).thenReturn(mockRef);
      when(() => mockRef.delete()).thenThrow(Exception('storage error'));

      // Should complete without throwing.
      await expectLater(sut.deletePost('p-err'), completes);

      final snap = await fakeFirestore.collection('posts').doc('p-err').get();
      expect(snap.exists, isFalse);
    });

    // BUG-008 regression
    test('decrements users/{uid}.postCount by 1 when post exists', () async {
      await fakeFirestore
          .collection('users')
          .doc('uid-count')
          .set({'postCount': 5});
      await fakeFirestore.collection('posts').doc('p-decrement').set({
        'id': 'p-decrement',
        'authorUid': 'uid-count',
        'authorDisplayName': 'CountUser',
        'content': 'To be decremented',
        'createdAt': Timestamp.now(),
        'likeCount': 0,
      });

      await sut.deletePost('p-decrement');

      final userSnap = await fakeFirestore
          .collection('users')
          .doc('uid-count')
          .get();
      expect(userSnap.data()?['postCount'], 4);
    });

    test('does not decrement postCount when deleted post does not exist',
        () async {
      await fakeFirestore
          .collection('users')
          .doc('uid-ghost')
          .set({'postCount': 7});

      await sut.deletePost('non-existent-post-id');

      final userSnap = await fakeFirestore
          .collection('users')
          .doc('uid-ghost')
          .get();
      expect(userSnap.data()?['postCount'], 7);
    });
  });
}
