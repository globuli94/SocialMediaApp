// test/features/posts/data/datasources/post_storage_service_test.dart
//
// Unit tests for FirebasePostStorageService — uploadBytes, getDownloadUrl,
// and delete (including the error-swallowing path) are covered using
// mocktail stubs for FirebaseStorage and Reference.
//
// FirebaseStorage and Reference are NOT sealed in firebase_storage v12 so
// they can be safely mocked with mocktail.  UploadTask wraps a private
// TaskPlatform constructor, so a thin Fake is used that implements the
// Future<TaskSnapshot> contract required by `await putData(...)`.

import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/posts/data/datasources/post_storage_service.dart';

// ---------------------------------------------------------------------------
// Mocks & fakes
// ---------------------------------------------------------------------------

class MockFirebaseStorage extends Mock implements FirebaseStorage {}

class MockReference extends Mock implements Reference {}

/// Minimal [TaskSnapshot] stub — no methods are accessed by [uploadBytes]
/// because the caller discards the awaited result.
class _FakeTaskSnapshot extends Fake implements TaskSnapshot {}

/// Minimal [UploadTask] fake.  Only the [Future] contract is implemented;
/// all other Task methods throw [UnimplementedError] via [Fake].
/// The wrapped [_FakeTaskSnapshot] is never accessed for [uploadBytes]
/// because the caller discards the awaited result.
class _FakeUploadTask extends Fake implements UploadTask {
  static final _snapshot = _FakeTaskSnapshot();

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
      Future<TaskSnapshot>.value(_snapshot).catchError(onError, test: test);

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
  late MockFirebaseStorage mockStorage;
  late MockReference mockRef;
  late FirebasePostStorageService sut;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(SettableMetadata());
  });

  setUp(() {
    mockStorage = MockFirebaseStorage();
    mockRef = MockReference();
    sut = FirebasePostStorageService(mockStorage);
  });

  // -------------------------------------------------------------------------
  // uploadBytes
  // -------------------------------------------------------------------------

  group('uploadBytes', () {
    test('calls ref(path).putData with correct bytes and content type',
        () async {
      final bytes = Uint8List.fromList([10, 20, 30]);
      final fakeTask = _FakeUploadTask();

      when(() => mockStorage.ref('posts/abc')).thenReturn(mockRef);
      when(() => mockRef.putData(any(), any())).thenAnswer((_) => fakeTask);

      await sut.uploadBytes('posts/abc', bytes, 'image/jpeg');

      verify(() => mockStorage.ref('posts/abc')).called(1);
      verify(() => mockRef.putData(bytes, any())).called(1);
    });

    test('passes correct contentType in SettableMetadata', () async {
      final bytes = Uint8List.fromList([1]);
      final fakeTask = _FakeUploadTask();

      when(() => mockStorage.ref(any())).thenReturn(mockRef);
      when(() => mockRef.putData(any(), any())).thenAnswer((_) => fakeTask);

      await sut.uploadBytes('posts/xyz', bytes, 'image/png');

      // Capture the SettableMetadata that was passed.
      final captured =
          verify(() => mockRef.putData(any(), captureAny())).captured;
      final meta = captured.single as SettableMetadata;
      expect(meta.contentType, 'image/png');
    });
  });

  // -------------------------------------------------------------------------
  // getDownloadUrl
  // -------------------------------------------------------------------------

  group('getDownloadUrl', () {
    test('returns URL from ref.getDownloadURL()', () async {
      const url = 'https://storage.example.com/posts/abc.jpg';
      when(() => mockStorage.ref('posts/abc')).thenReturn(mockRef);
      when(() => mockRef.getDownloadURL()).thenAnswer((_) async => url);

      final result = await sut.getDownloadUrl('posts/abc');

      expect(result, url);
      verify(() => mockStorage.ref('posts/abc')).called(1);
      verify(() => mockRef.getDownloadURL()).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // delete
  // -------------------------------------------------------------------------

  group('delete', () {
    test('calls ref(path).delete() on happy path', () async {
      when(() => mockStorage.ref('posts/abc')).thenReturn(mockRef);
      when(() => mockRef.delete()).thenAnswer((_) async {});

      await sut.delete('posts/abc');

      verify(() => mockStorage.ref('posts/abc')).called(1);
      verify(() => mockRef.delete()).called(1);
    });

    test('swallows exception from ref.delete() without rethrowing', () async {
      when(() => mockStorage.ref(any())).thenReturn(mockRef);
      when(() => mockRef.delete()).thenThrow(Exception('not found'));

      // Should not throw.
      await expectLater(sut.delete('posts/missing'), completes);
    });
  });
}
