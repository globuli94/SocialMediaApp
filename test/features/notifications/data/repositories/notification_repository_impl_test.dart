// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/notifications/data/repositories/notification_repository_impl.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  group('NotificationRepositoryImpl', () {
    late MockFirebaseFirestore mockFirestore;
    late NotificationRepositoryImpl repository;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      repository = NotificationRepositoryImpl(firestore: mockFirestore);
    });

    group('createLikeNotification', () {
      test('writes correct fields to users/{recipientUid}/notifications/',
          () async {
        const recipientUid = 'user123';
        const actorUid = 'actor456';
        const actorDisplayName = 'John Doe';
        const actorAvatarUrl = 'https://example.com/avatar.jpg';
        const postId = 'post789';

        final mockUsersCollection = MockCollectionReference();
        final mockUserDocRef = MockDocumentReference();
        final mockNotificationsCollection = MockCollectionReference();

        when(() => mockFirestore.collection('users'))
            .thenReturn(mockUsersCollection);
        when(() => mockUsersCollection.doc(recipientUid))
            .thenReturn(mockUserDocRef);
        when(() => mockUserDocRef.collection('notifications'))
            .thenReturn(mockNotificationsCollection);
        when(() => mockNotificationsCollection.add(any()))
            .thenAnswer((_) async => MockDocumentReference());

        await repository.createLikeNotification(
          recipientUid: recipientUid,
          actorUid: actorUid,
          actorDisplayName: actorDisplayName,
          actorAvatarUrl: actorAvatarUrl,
          postId: postId,
        );

        verify(() => mockNotificationsCollection.add(
          any(
            that: isA<Map<String, dynamic>>()
                .having((m) => m['type'], 'type', 'like')
                .having((m) => m['actorUid'], 'actorUid', actorUid)
                .having((m) => m['actorDisplayName'], 'actorDisplayName',
                    actorDisplayName)
                .having((m) => m['actorAvatarUrl'], 'actorAvatarUrl',
                    actorAvatarUrl)
                .having((m) => m['postId'], 'postId', postId)
                .having((m) => m['read'], 'read', false)
                .having((m) => m['createdAt'], 'createdAt',
                    isA<FieldValue>()),
          ),
        )).called(1);
      });
    });

    group('createFollowNotification', () {
      test('writes correct fields with postId set to null', () async {
        const recipientUid = 'user123';
        const actorUid = 'actor456';
        const actorDisplayName = 'Jane Smith';
        const actorAvatarUrl = 'https://example.com/avatar.jpg';

        final mockUsersCollection = MockCollectionReference();
        final mockUserDocRef = MockDocumentReference();
        final mockNotificationsCollection = MockCollectionReference();

        when(() => mockFirestore.collection('users'))
            .thenReturn(mockUsersCollection);
        when(() => mockUsersCollection.doc(recipientUid))
            .thenReturn(mockUserDocRef);
        when(() => mockUserDocRef.collection('notifications'))
            .thenReturn(mockNotificationsCollection);
        when(() => mockNotificationsCollection.add(any()))
            .thenAnswer((_) async => MockDocumentReference());

        await repository.createFollowNotification(
          recipientUid: recipientUid,
          actorUid: actorUid,
          actorDisplayName: actorDisplayName,
          actorAvatarUrl: actorAvatarUrl,
        );

        verify(() => mockNotificationsCollection.add(
          any(
            that: isA<Map<String, dynamic>>()
                .having((m) => m['type'], 'type', 'follow')
                .having((m) => m['actorUid'], 'actorUid', actorUid)
                .having((m) => m['actorDisplayName'], 'actorDisplayName',
                    actorDisplayName)
                .having((m) => m['actorAvatarUrl'], 'actorAvatarUrl',
                    actorAvatarUrl)
                .having((m) => m['postId'], 'postId', null)
                .having((m) => m['read'], 'read', false)
                .having((m) => m['createdAt'], 'createdAt',
                    isA<FieldValue>()),
          ),
        )).called(1);
      });
    });

    group('markAsRead', () {
      test('updates only read: true on the correct doc', () async {
        const recipientUid = 'user456';
        const notificationId = 'notif123';

        final mockUsersCollection = MockCollectionReference();
        final mockUserDocRef = MockDocumentReference();
        final mockNotificationsCollection = MockCollectionReference();
        final mockNotificationDoc = MockDocumentReference();

        when(() => mockFirestore.collection('users'))
            .thenReturn(mockUsersCollection);
        when(() => mockUsersCollection.doc(recipientUid))
            .thenReturn(mockUserDocRef);
        when(() => mockUserDocRef.collection('notifications'))
            .thenReturn(mockNotificationsCollection);
        when(() => mockNotificationsCollection.doc(notificationId))
            .thenReturn(mockNotificationDoc);
        when(() => mockNotificationDoc.update(any()))
            .thenAnswer((_) async {});

        await repository.markAsRead(recipientUid, notificationId);

        verify(
          () => mockNotificationDoc.update({'read': true}),
        ).called(1);
      });
    });

    group('watchNotifications', () {
      test('emits NotificationEntity list ordered by createdAt descending',
          () async {
        const recipientUid = 'user123';

        final mockUsersCollection = MockCollectionReference();
        final mockUserDocRef = MockDocumentReference();
        final mockNotificationsCollection = MockCollectionReference();
        final mockQuery = MockQuery();

        final now = DateTime.now();
        final earlier =
            now.subtract(const Duration(hours: 1));

        // Create mock query docs with actual NotificationEntity data
        final mockDoc1 = MockQueryDocumentSnapshot();
        when(() => mockDoc1.id).thenReturn('notif1');
        when(() => mockDoc1.data()).thenReturn({
          'type': 'like',
          'actorUid': 'actor1',
          'actorDisplayName': 'User One',
          'actorAvatarUrl': 'https://example.com/avatar1.jpg',
          'postId': 'post1',
          'read': false,
          'createdAt': Timestamp.fromDate(now),
        });

        final mockDoc2 = MockQueryDocumentSnapshot();
        when(() => mockDoc2.id).thenReturn('notif2');
        when(() => mockDoc2.data()).thenReturn({
          'type': 'follow',
          'actorUid': 'actor2',
          'actorDisplayName': 'User Two',
          'actorAvatarUrl': null,
          'postId': null,
          'read': true,
          'createdAt': Timestamp.fromDate(earlier),
        });

        when(() => mockFirestore.collection('users'))
            .thenReturn(mockUsersCollection);
        when(() => mockUsersCollection.doc(recipientUid))
            .thenReturn(mockUserDocRef);
        when(() => mockUserDocRef.collection('notifications'))
            .thenReturn(mockNotificationsCollection);
        when(() => mockNotificationsCollection
                .orderBy('createdAt', descending: true))
            .thenReturn(mockQuery);

        final mockSnapshot = MockQuerySnapshot();
        when(() => mockSnapshot.docs).thenReturn([mockDoc1, mockDoc2]);

        when(() => mockQuery.snapshots())
            .thenAnswer((_) => Stream.value(mockSnapshot));

        final stream = repository.watchNotifications(recipientUid);
        final result = await stream.first;

        expect(result.length, 2);
        expect(result[0].type, 'like');
        expect(result[0].actorDisplayName, 'User One');
        expect(result[1].type, 'follow');
        expect(result[1].actorDisplayName, 'User Two');
      });
    });
  });
}
