// test/features/posts/presentation/widgets/create_post_screen_test.dart
//
// Widget tests for CreatePostScreen — verifies validation, Post button state,
// PostCreateRequested dispatch, and navigation on success.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/auth/domain/entities/user_entity.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';
import 'package:social_network/features/posts/presentation/screens/create_post_screen.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockPostBloc extends MockBloc<PostEvent, PostState> implements PostBloc {}

class MockProfileBloc extends MockBloc<ProfileEvent, ProfileState>
    implements ProfileBloc {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const UserEntity testUser = UserEntity(
  uid: 'uid-alice',
  email: 'alice@example.com',
  displayName: 'Alice',
);

const UserProfileEntity testProfile = UserProfileEntity(
  uid: 'uid-alice',
  displayName: 'Alice Profile',
  bio: 'Hello',
  avatarUrl: 'https://example.com/alice.jpg',
  postCount: 2,
);

final PostEntity testPost = PostEntity(
  id: 'post-new',
  authorUid: 'uid-alice',
  authorDisplayName: 'Alice',
  content: 'Hello world',
  createdAt: DateTime(2026, 1, 1),
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockAuthBloc authBloc,
  required MockPostBloc postBloc,
  required MockProfileBloc profileBloc,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: authBloc),
      BlocProvider<PostBloc>.value(value: postBloc),
      BlocProvider<ProfileBloc>.value(value: profileBloc),
    ],
    child: const MaterialApp(
      home: CreatePostScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthBloc authBloc;
  late MockPostBloc postBloc;
  late MockProfileBloc profileBloc;

  setUpAll(() {
    registerFallbackValue(
      const PostCreateRequested(
        authorUid: '',
        authorDisplayName: '',
        content: '',
      ),
    );
  });

  setUp(() {
    authBloc = MockAuthBloc();
    postBloc = MockPostBloc();
    profileBloc = MockProfileBloc();

    when(() => authBloc.state)
        .thenReturn(const AuthAuthenticated(user: testUser));
    when(() => postBloc.state).thenReturn(PostLoaded(posts: []));
    when(() => profileBloc.state)
        .thenReturn(const ProfileLoaded(profile: testProfile));
  });

  // -------------------------------------------------------------------------
  // Initial render
  // -------------------------------------------------------------------------

  group('initial render', () {
    testWidgets('shows "New Post" title in AppBar', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
        ),
      );

      expect(find.text('New Post'), findsOneWidget);
    });

    testWidgets('shows "Post" TextButton in AppBar', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
        ),
      );

      expect(find.text('Post'), findsOneWidget);
    });

    testWidgets('shows text field with placeholder hint', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Validation — empty text
  // -------------------------------------------------------------------------

  group('validation', () {
    testWidgets('shows snackbar when "Post" tapped with empty text',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
        ),
      );

      // Text field is empty — tap Post without entering text
      await tester.tap(find.text('Post'));
      await tester.pump();

      expect(
        find.text('Post text cannot be empty.'),
        findsOneWidget,
      );
    });

    testWidgets('does not dispatch PostCreateRequested when text is empty',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
        ),
      );

      await tester.tap(find.text('Post'));
      await tester.pump();

      verifyNever(() => postBloc.add(any()));
    });
  });

  // -------------------------------------------------------------------------
  // PostCreateRequested dispatch
  // -------------------------------------------------------------------------

  group('PostCreateRequested dispatch', () {
    testWidgets('dispatches PostCreateRequested with correct fields on submit',
        (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hello world');
      await tester.tap(find.text('Post'));
      await tester.pump();

      final captured =
          verify(() => postBloc.add(captureAny())).captured;
      expect(captured, hasLength(1));
      final event = captured.first as PostCreateRequested;
      expect(event.authorUid, 'uid-alice');
      expect(event.authorDisplayName, 'Alice Profile');
      expect(event.authorAvatarUrl, 'https://example.com/alice.jpg');
      expect(event.content, 'Hello world');
    });

    testWidgets(
        'uses displayName from AuthState when ProfileState is not loaded',
        (tester) async {
      when(() => profileBloc.state).thenReturn(const ProfileInitial());

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
        ),
      );

      await tester.enterText(find.byType(TextField), 'Fallback name test');
      await tester.tap(find.text('Post'));
      await tester.pump();

      final captured =
          verify(() => postBloc.add(captureAny())).captured;
      expect(captured, hasLength(1));
      final event = captured.first as PostCreateRequested;
      expect(event.authorDisplayName, 'Alice'); // falls back to UserEntity.displayName
    });
  });

  // -------------------------------------------------------------------------
  // Pop on success
  // -------------------------------------------------------------------------

  group('pop on success', () {
    testWidgets(
        'pops navigation when PostLoaded transitions from isSubmitting=true to false',
        (tester) async {
      // Use a StreamController to drive state manually so timing is
      // deterministic in the test environment.
      final stateController = StreamController<PostState>.broadcast();

      // Set up whenListen BEFORE the screen is rendered so the BlocListener
      // subscribes to the controlled stream.
      whenListen<PostState>(
        postBloc,
        stateController.stream,
        initialState: PostLoaded(posts: []),
      );

      bool popped = false;

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<PostBloc>.value(value: postBloc),
            BlocProvider<ProfileBloc>.value(value: profileBloc),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (_) => MultiBlocProvider(
                            providers: [
                              BlocProvider<AuthBloc>.value(value: authBloc),
                              BlocProvider<PostBloc>.value(value: postBloc),
                              BlocProvider<ProfileBloc>.value(
                                  value: profileBloc),
                            ],
                            child: const CreatePostScreen(),
                          ),
                        ),
                      )
                      .then((_) => popped = true);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open CreatePostScreen
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(CreatePostScreen), findsOneWidget);

      // Emit isSubmitting=true — this makes _isSubmitting = true in the widget.
      stateController.add(PostLoaded(posts: [], isSubmitting: true));
      await tester.pump();

      // Emit isSubmitting=false — the BlocListener sees a loaded+not-submitting
      // state while _isSubmitting was true, so it calls Navigator.pop().
      stateController.add(PostLoaded(posts: [testPost], isSubmitting: false));
      await tester.pump();
      await tester.pumpAndSettle();

      await stateController.close();

      expect(popped, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Error snackbar
  // -------------------------------------------------------------------------

  group('PostFailure snackbar', () {
    testWidgets('shows error snackbar when PostFailure state is emitted',
        (tester) async {
      whenListen<PostState>(
        postBloc,
        Stream.fromIterable([
          const PostFailure(error: 'Something went wrong'),
        ]),
        initialState: PostLoaded(posts: []),
      );

      await tester.pumpWidget(
        _buildSubject(
          authBloc: authBloc,
          postBloc: postBloc,
          profileBloc: profileBloc,
        ),
      );

      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });
}
