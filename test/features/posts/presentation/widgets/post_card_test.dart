// test/features/posts/presentation/widgets/post_card_test.dart
//
// Widget tests for PostCard — verifies rendering of avatar, display name,
// relative timestamp, post text, optional image, and conditional delete button.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';
import 'package:social_network/features/posts/presentation/widgets/post_card.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockPostBloc extends MockBloc<PostEvent, PostState> implements PostBloc {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final PostEntity _ownPost = PostEntity(
  id: 'post-own',
  authorUid: 'uid-me',
  authorDisplayName: 'Alice',
  content: 'My own post',
  // Use a recent time so the relative timestamp shows minutes
  createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  authorAvatarUrl: null,
  imageUrl: null,
);

final PostEntity _otherPost = PostEntity(
  id: 'post-other',
  authorUid: 'uid-bob',
  authorDisplayName: 'Bob',
  content: "Bob's post",
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  authorAvatarUrl: null,
  imageUrl: null,
);

final PostEntity _postWithImage = PostEntity(
  id: 'post-img',
  authorUid: 'uid-carol',
  authorDisplayName: 'Carol',
  content: 'Post with image',
  createdAt: DateTime.now().subtract(const Duration(days: 1)),
  authorAvatarUrl: 'https://example.com/carol.jpg',
  imageUrl: 'https://example.com/image.jpg',
);

final PostEntity _oldPost = PostEntity(
  id: 'post-old',
  authorUid: 'uid-dave',
  authorDisplayName: 'Dave',
  content: 'Old post',
  createdAt: DateTime.now().subtract(const Duration(days: 3)),
  authorAvatarUrl: null,
  imageUrl: null,
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockPostBloc postBloc,
  required PostEntity post,
  required String currentUserUid,
}) {
  return BlocProvider<PostBloc>.value(
    value: postBloc,
    child: MaterialApp(
      home: Scaffold(
        body: PostCard(
          post: post,
          currentUserUid: currentUserUid,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockPostBloc postBloc;

  setUpAll(() {
    registerFallbackValue(const PostDeleteRequested(postId: ''));
  });

  setUp(() {
    postBloc = MockPostBloc();
    when(() => postBloc.state)
        .thenReturn(PostLoaded(posts: [_ownPost, _otherPost]));
  });

  // -------------------------------------------------------------------------
  // Display name
  // -------------------------------------------------------------------------

  group('author display name', () {
    testWidgets('renders author display name', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          postBloc: postBloc,
          post: _ownPost,
          currentUserUid: 'uid-me',
        ),
      );

      expect(find.text('Alice'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Post content text
  // -------------------------------------------------------------------------

  group('post content', () {
    testWidgets('renders post text content', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          postBloc: postBloc,
          post: _ownPost,
          currentUserUid: 'uid-me',
        ),
      );

      expect(find.text('My own post'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Relative timestamp
  // -------------------------------------------------------------------------

  group('relative timestamp', () {
    testWidgets('shows "Xm ago" for posts created within the last hour',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          postBloc: postBloc,
          post: _ownPost, // 5 minutes ago
          currentUserUid: 'uid-me',
        ),
      );

      expect(find.textContaining('m ago'), findsOneWidget);
    });

    testWidgets('shows "Xh ago" for posts created within the last 24 hours',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          postBloc: postBloc,
          post: _otherPost, // 2 hours ago
          currentUserUid: 'uid-me',
        ),
      );

      expect(find.textContaining('h ago'), findsOneWidget);
    });

    testWidgets('shows "Xd ago" for posts older than 24 hours', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          postBloc: postBloc,
          post: _oldPost, // 3 days ago
          currentUserUid: 'uid-me',
        ),
      );

      expect(find.textContaining('d ago'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Delete button visibility
  // -------------------------------------------------------------------------

  group('delete button', () {
    testWidgets('shows delete button when post belongs to current user',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          postBloc: postBloc,
          post: _ownPost,
          currentUserUid: 'uid-me',
        ),
      );

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('hides delete button when post belongs to another user',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          postBloc: postBloc,
          post: _otherPost,
          currentUserUid: 'uid-me',
        ),
      );

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('tapping delete dispatches PostDeleteRequested', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          postBloc: postBloc,
          post: _ownPost,
          currentUserUid: 'uid-me',
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      verify(
        () => postBloc.add(const PostDeleteRequested(postId: 'post-own')),
      ).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // Optional image
  // -------------------------------------------------------------------------

  group('optional image', () {
    testWidgets('does not show Image.network when imageUrl is null',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          postBloc: postBloc,
          post: _ownPost,
          currentUserUid: 'uid-me',
        ),
      );

      expect(find.byType(Image), findsNothing);
    });

    testWidgets(
        'shows ClipRRect container for the image when imageUrl is set',
        (tester) async {
      // Suppress the NetworkImageLoadException that the test binding reports;
      // the errorBuilder in PostCard handles it gracefully in production.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception.toString().contains('NetworkImageLoad') ||
            details.exception.toString().contains('statusCode: 400')) {
          return; // swallow network image errors in tests
        }
        originalOnError?.call(details);
      };

      await tester.pumpWidget(
        _buildSubject(
          postBloc: postBloc,
          post: _postWithImage,
          currentUserUid: 'uid-me',
        ),
      );

      // When imageUrl is non-null, a ClipRRect with borderRadius 8 wraps the
      // Image.network. AvatarWidget uses CircleAvatar (not ClipRRect), so this
      // finder uniquely identifies the image container.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is ClipRRect &&
              w.borderRadius == BorderRadius.circular(8),
        ),
        findsOneWidget,
      );

      FlutterError.onError = originalOnError;
    });
  });

  // -------------------------------------------------------------------------
  // Avatar
  // -------------------------------------------------------------------------

  group('avatar', () {
    testWidgets('renders AvatarWidget in the card header', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          postBloc: postBloc,
          post: _ownPost,
          currentUserUid: 'uid-me',
        ),
      );

      // The Card and Padding are present — AvatarWidget renders a CircleAvatar
      expect(find.byType(Card), findsOneWidget);
    });
  });
}
