// test/features/profile/presentation/bloc/profile_bloc_test.dart
//
// Unit tests for ProfileBloc — covers every event handler with success and
// failure paths to satisfy the ≥ 90% bloc coverage threshold.

import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';
import 'package:social_network/features/profile/domain/repositories/profile_repository.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockProfileRepository extends Mock implements ProfileRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const UserProfileEntity testProfile = UserProfileEntity(
  uid: 'uid-test',
  displayName: 'Test User',
  bio: 'Hello world',
  avatarUrl: null,
  postCount: 3,
);

const UserProfileEntity updatedProfile = UserProfileEntity(
  uid: 'uid-test',
  displayName: 'Updated Name',
  bio: 'Updated bio',
  avatarUrl: null,
  postCount: 3,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockProfileRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockRepository = MockProfileRepository();
  });

  group('ProfileBloc', () {
    // -----------------------------------------------------------------------
    // ProfileLoadRequested
    // -----------------------------------------------------------------------

    group('ProfileLoadRequested', () {
      blocTest<ProfileBloc, ProfileState>(
        'emits [ProfileLoading, ProfileLoaded] on success',
        setUp: () {
          when(() => mockRepository.getProfile('uid-test'))
              .thenAnswer((_) async => testProfile);
        },
        build: () => ProfileBloc(profileRepository: mockRepository),
        act: (bloc) =>
            bloc.add(const ProfileLoadRequested(uid: 'uid-test')),
        expect: () => [
          const ProfileLoading(),
          isA<ProfileLoaded>()
              .having((s) => s.profile.uid, 'uid', 'uid-test')
              .having((s) => s.profile.displayName, 'displayName', 'Test User'),
        ],
        verify: (_) =>
            verify(() => mockRepository.getProfile('uid-test')).called(1),
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits [ProfileLoading, ProfileFailure] when getProfile throws',
        setUp: () {
          when(() => mockRepository.getProfile(any()))
              .thenThrow('Failed to load profile: network error');
        },
        build: () => ProfileBloc(profileRepository: mockRepository),
        act: (bloc) =>
            bloc.add(const ProfileLoadRequested(uid: 'uid-test')),
        expect: () => [
          const ProfileLoading(),
          isA<ProfileFailure>(),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // ProfileUpdateRequested — from ProfileLoaded state
    // -----------------------------------------------------------------------

    group('ProfileUpdateRequested — from ProfileLoaded state', () {
      blocTest<ProfileBloc, ProfileState>(
        'emits [ProfileUpdating, ProfileLoaded] on success',
        setUp: () {
          when(
            () => mockRepository.updateProfile(
              uid: 'uid-test',
              displayName: 'Updated Name',
              bio: 'Updated bio',
            ),
          ).thenAnswer((_) async {});
          when(() => mockRepository.getProfile('uid-test'))
              .thenAnswer((_) async => updatedProfile);
        },
        build: () => ProfileBloc(profileRepository: mockRepository),
        seed: () => const ProfileLoaded(profile: testProfile),
        act: (bloc) => bloc.add(
          const ProfileUpdateRequested(
            uid: 'uid-test',
            displayName: 'Updated Name',
            bio: 'Updated bio',
          ),
        ),
        expect: () => [
          isA<ProfileUpdating>()
              .having((s) => s.profile, 'profile', testProfile),
          isA<ProfileLoaded>()
              .having((s) => s.profile.displayName, 'displayName', 'Updated Name'),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits [ProfileUpdating, ProfileFailure] when updateProfile throws',
        setUp: () {
          when(
            () => mockRepository.updateProfile(
              uid: any(named: 'uid'),
              displayName: any(named: 'displayName'),
              bio: any(named: 'bio'),
            ),
          ).thenThrow('Failed to update profile: timeout');
        },
        build: () => ProfileBloc(profileRepository: mockRepository),
        seed: () => const ProfileLoaded(profile: testProfile),
        act: (bloc) => bloc.add(
          const ProfileUpdateRequested(
            uid: 'uid-test',
            displayName: 'Bad Name',
            bio: 'Bad bio',
          ),
        ),
        expect: () => [
          isA<ProfileUpdating>(),
          isA<ProfileFailure>(),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // ProfileUpdateRequested — from non-loaded state
    // -----------------------------------------------------------------------

    group('ProfileUpdateRequested — from non-loaded state', () {
      blocTest<ProfileBloc, ProfileState>(
        'emits [ProfileLoading, ProfileLoaded] when no current profile',
        setUp: () {
          when(
            () => mockRepository.updateProfile(
              uid: any(named: 'uid'),
              displayName: any(named: 'displayName'),
              bio: any(named: 'bio'),
            ),
          ).thenAnswer((_) async {});
          when(() => mockRepository.getProfile('uid-test'))
              .thenAnswer((_) async => updatedProfile);
        },
        build: () => ProfileBloc(profileRepository: mockRepository),
        // default initial state is ProfileInitial, not ProfileLoaded
        act: (bloc) => bloc.add(
          const ProfileUpdateRequested(
            uid: 'uid-test',
            displayName: 'Updated Name',
            bio: 'Updated bio',
          ),
        ),
        expect: () => [
          const ProfileLoading(),
          isA<ProfileLoaded>(),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // ProfileAvatarUploadRequested — from ProfileLoaded state
    // -----------------------------------------------------------------------

    group('ProfileAvatarUploadRequested — from ProfileLoaded state', () {
      blocTest<ProfileBloc, ProfileState>(
        'emits [ProfileUpdating, ProfileLoaded] on successful upload',
        setUp: () {
          when(
            () => mockRepository.uploadAvatar(
              uid: 'uid-test',
              bytes: any(named: 'bytes'),
              extension: '.jpg',
            ),
          ).thenAnswer((_) async {});
          when(() => mockRepository.getProfile('uid-test')).thenAnswer(
            (_) async => const UserProfileEntity(
              uid: 'uid-test',
              displayName: 'Test User',
              bio: 'Hello world',
              avatarUrl: 'https://example.com/avatar.jpg',
              postCount: 3,
            ),
          );
        },
        build: () => ProfileBloc(profileRepository: mockRepository),
        seed: () => const ProfileLoaded(profile: testProfile),
        act: (bloc) => bloc.add(
          ProfileAvatarUploadRequested(
            uid: 'uid-test',
            bytes: Uint8List.fromList([1, 2, 3]),
            extension: '.jpg',
          ),
        ),
        expect: () => [
          isA<ProfileUpdating>()
              .having((s) => s.profile, 'profile', testProfile),
          isA<ProfileLoaded>()
              .having(
                (s) => s.profile.avatarUrl,
                'avatarUrl',
                'https://example.com/avatar.jpg',
              ),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits [ProfileUpdating, ProfileFailure] when uploadAvatar throws',
        setUp: () {
          when(
            () => mockRepository.uploadAvatar(
              uid: any(named: 'uid'),
              bytes: any(named: 'bytes'),
              extension: any(named: 'extension'),
            ),
          ).thenThrow('Failed to upload avatar: storage error');
        },
        build: () => ProfileBloc(profileRepository: mockRepository),
        seed: () => const ProfileLoaded(profile: testProfile),
        act: (bloc) => bloc.add(
          ProfileAvatarUploadRequested(
            uid: 'uid-test',
            bytes: Uint8List.fromList([1, 2, 3]),
            extension: '.png',
          ),
        ),
        expect: () => [
          isA<ProfileUpdating>(),
          isA<ProfileFailure>(),
        ],
      );
    });

    // -----------------------------------------------------------------------
    // ProfileAvatarUploadRequested — from non-loaded state
    // -----------------------------------------------------------------------

    group('ProfileAvatarUploadRequested — from non-loaded state', () {
      blocTest<ProfileBloc, ProfileState>(
        'emits [ProfileLoading, ProfileLoaded] when no current profile',
        setUp: () {
          when(
            () => mockRepository.uploadAvatar(
              uid: any(named: 'uid'),
              bytes: any(named: 'bytes'),
              extension: any(named: 'extension'),
            ),
          ).thenAnswer((_) async {});
          when(() => mockRepository.getProfile('uid-test'))
              .thenAnswer((_) async => testProfile);
        },
        build: () => ProfileBloc(profileRepository: mockRepository),
        act: (bloc) => bloc.add(
          ProfileAvatarUploadRequested(
            uid: 'uid-test',
            bytes: Uint8List.fromList([1, 2, 3]),
            extension: '.jpg',
          ),
        ),
        expect: () => [
          const ProfileLoading(),
          isA<ProfileLoaded>(),
        ],
      );
    });
  });

  // -----------------------------------------------------------------------
  // Event props / equality — exercises Equatable props getters for coverage
  // -----------------------------------------------------------------------

  group('ProfileEvent props and equality', () {
    test('ProfileLoadRequested props contains uid', () {
      const event = ProfileLoadRequested(uid: 'uid-123');
      expect(event.props, equals(['uid-123']));
    });

    test('ProfileLoadRequested supports value equality', () {
      const a = ProfileLoadRequested(uid: 'uid-abc');
      const b = ProfileLoadRequested(uid: 'uid-abc');
      expect(a, equals(b));
    });

    test('ProfileUpdateRequested props contains uid, displayName, bio', () {
      const event = ProfileUpdateRequested(
        uid: 'uid-123',
        displayName: 'Alice',
        bio: 'Hello',
      );
      expect(event.props, equals(['uid-123', 'Alice', 'Hello']));
    });

    test('ProfileUpdateRequested supports value equality', () {
      const a = ProfileUpdateRequested(
        uid: 'uid-123',
        displayName: 'Alice',
        bio: 'Hello',
      );
      const b = ProfileUpdateRequested(
        uid: 'uid-123',
        displayName: 'Alice',
        bio: 'Hello',
      );
      expect(a, equals(b));
    });

    test('ProfileAvatarUploadRequested props contains uid, bytes, extension',
        () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final event = ProfileAvatarUploadRequested(
        uid: 'uid-123',
        bytes: bytes,
        extension: '.jpg',
      );
      expect(event.props, equals(['uid-123', bytes, '.jpg']));
    });

    test('ProfileAvatarUploadRequested supports value equality with same bytes',
        () {
      final bytes = Uint8List.fromList([10, 20]);
      final a = ProfileAvatarUploadRequested(
        uid: 'uid-x',
        bytes: bytes,
        extension: '.png',
      );
      final b = ProfileAvatarUploadRequested(
        uid: 'uid-x',
        bytes: bytes,
        extension: '.png',
      );
      expect(a, equals(b));
    });
  });
}
