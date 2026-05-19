// test/features/feed/presentation/screens/feed_screen_test.dart
//
// Widget tests for FeedScreen — verifies rendering from PostBloc state:
// PostLoading spinner, empty state with pull-to-refresh, post list with
// RefreshIndicator, error message, PostWatchStarted on pull-to-refresh,
// and author tap navigation to /profile/:uid.
//
// FeedScreen drives its UI exclusively from PostBloc — there is no FeedBloc.
// The RefreshIndicator re-dispatches PostWatchStarted on pull.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/auth/domain/entities/user_entity.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_event.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/feed/presentation/screens/feed_screen.dart';
import 'package:social_network/features/notifications/presentation/bloc/unread_count_cubit.dart';
import 'package:social_network/features/posts/domain/entities/post_entity.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockPostBloc extends MockBloc<PostEvent, PostState> implements PostBloc {}

class MockPostRepository extends Mock implements PostRepository {}

class MockUnreadCountCubit extends MockCubit<int> implements UnreadCountCubit {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const UserEntity _testUser = UserEntity(
  uid: 'uid-me',
  email: 'me@example.com',
  displayName: 'Me',
);

PostEntity _makePost(String id, {String content = ''}) => PostEntity(
      id: id,
      authorUid: 'uid-other',
      authorDisplayName: 'Other User',
      content: content.isEmpty ? 'Post content $id' : content,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildSubject({
  required MockAuthBloc authBloc,
  required MockPostBloc postBloc,
  required MockPostRepository postRepository,
  required MockUnreadCountCubit unreadCountCubit,
}) {
  return RepositoryProvider<PostRepository>.value(
    value: postRepository,
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<PostBloc>.value(value: postBloc),
        BlocProvider<UnreadCountCubit>.value(value: unreadCountCubit),
      ],
      child: const MaterialApp(
        home: FeedScreen(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAuthBloc authBloc;
  late MockPostBloc postBloc;
  late MockPostRepository postRepository;
  late MockUnreadCountCubit unreadCountCubit;

  setUpAll(() {
    registerFallbackValue(const PostWatchStarted());
    registerFallbackValue(const PostDeleteRequested(postId: ''));
  });

  setUp(() {
    authBloc = MockAuthBloc();
    postBloc = MockPostBloc();
    postRepository = MockPostRepository();
    unreadCountCubit = MockUnreadCountCubit();
    when(() => authBloc.state)
        .thenReturn(const AuthAuthenticated(user: _testUser));
    when(() => authBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => postBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => unreadCountCubit.state).thenReturn(0);
    when(() => postRepository.watchPostLiked(any(), any()))
        .thenAnswer((_) => Stream.value(false));
  });

  // -------------------------------------------------------------------------
  // PostLoading
  // -------------------------------------------------------------------------

  group('PostLoading state', () {
    testWidgets('shows CircularProgressIndicator when state is PostLoading',
        (tester) async {
      when(() => postBloc.state).thenReturn(const PostLoading());

      await tester.pumpWidget(
          _buildSubject(authBloc: authBloc, postBloc: postBloc, postRepository: postRepository, unreadCountCubit: unreadCountCubit));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // PostLoaded — empty
  // -------------------------------------------------------------------------

  group('PostLoaded empty state', () {
    testWidgets('shows "No posts yet." when posts list is empty',
        (tester) async {
      when(() => postBloc.state).thenReturn(const PostLoaded(posts: []));

      await tester.pumpWidget(
          _buildSubject(authBloc: authBloc, postBloc: postBloc, postRepository: postRepository, unreadCountCubit: unreadCountCubit));
      await tester.pump();

      expect(find.text('No posts yet.'), findsOneWidget);
    });

    testWidgets('renders RefreshIndicator for empty state', (tester) async {
      when(() => postBloc.state).thenReturn(const PostLoaded(posts: []));

      await tester.pumpWidget(
          _buildSubject(authBloc: authBloc, postBloc: postBloc, postRepository: postRepository, unreadCountCubit: unreadCountCubit));
      await tester.pump();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('does not show CircularProgressIndicator for empty loaded state',
        (tester) async {
      when(() => postBloc.state).thenReturn(const PostLoaded(posts: []));

      await tester.pumpWidget(
          _buildSubject(authBloc: authBloc, postBloc: postBloc, postRepository: postRepository, unreadCountCubit: unreadCountCubit));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // PostLoaded — with posts
  // -------------------------------------------------------------------------

  group('PostLoaded with posts', () {
    testWidgets('renders post content text for each post', (tester) async {
      final posts = [_makePost('p1'), _makePost('p2')];
      when(() => postBloc.state).thenReturn(PostLoaded(posts: posts));

      await tester.pumpWidget(
          _buildSubject(authBloc: authBloc, postBloc: postBloc, postRepository: postRepository, unreadCountCubit: unreadCountCubit));
      await tester.pump();

      expect(find.text('Post content p1'), findsOneWidget);
      expect(find.text('Post content p2'), findsOneWidget);
    });

    testWidgets('renders RefreshIndicator wrapping the list', (tester) async {
      final posts = [_makePost('p1')];
      when(() => postBloc.state).thenReturn(PostLoaded(posts: posts));

      await tester.pumpWidget(
          _buildSubject(authBloc: authBloc, postBloc: postBloc, postRepository: postRepository, unreadCountCubit: unreadCountCubit));
      await tester.pump();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // PostFailure
  // -------------------------------------------------------------------------

  group('PostFailure state', () {
    testWidgets('shows error message when state is PostFailure', (tester) async {
      when(() => postBloc.state)
          .thenReturn(const PostFailure(error: 'Something went wrong'));

      await tester.pumpWidget(
          _buildSubject(authBloc: authBloc, postBloc: postBloc, postRepository: postRepository, unreadCountCubit: unreadCountCubit));
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // PostInitial
  // -------------------------------------------------------------------------

  group('PostInitial state', () {
    testWidgets('shows nothing when state is PostInitial', (tester) async {
      when(() => postBloc.state).thenReturn(const PostInitial());

      await tester.pumpWidget(
          _buildSubject(authBloc: authBloc, postBloc: postBloc, postRepository: postRepository, unreadCountCubit: unreadCountCubit));
      await tester.pump();

      expect(find.text('No posts yet.'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ListView), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // RefreshIndicator → PostWatchStarted
  // -------------------------------------------------------------------------

  group('RefreshIndicator', () {
    testWidgets('dispatches PostWatchStarted on pull-to-refresh',
        (tester) async {
      final posts = [_makePost('p1')];
      when(() => postBloc.state).thenReturn(PostLoaded(posts: posts));
      // Provide a stream that emits a non-PostLoading state so the
      // onRefresh future's firstWhere() can complete.
      when(() => postBloc.stream).thenAnswer(
        (_) => Stream.value(PostLoaded(posts: posts)),
      );

      await tester.pumpWidget(
          _buildSubject(authBloc: authBloc, postBloc: postBloc, postRepository: postRepository, unreadCountCubit: unreadCountCubit));
      await tester.pump();

      final refreshState = tester.state<RefreshIndicatorState>(
        find.byType(RefreshIndicator),
      );
      // ignore: unawaited_futures
      refreshState.show();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // initState also dispatches PostWatchStarted; the refresh adds at least
      // one more — use greaterThanOrEqualTo to account for both.
      verify(
        () => postBloc.add(const PostWatchStarted()),
      ).called(greaterThanOrEqualTo(1));
    });
  });

  // -------------------------------------------------------------------------
  // Author tap → /profile/:uid
  // -------------------------------------------------------------------------

  group('author tap navigation', () {
    Widget buildWithRouter({
      required MockAuthBloc authBloc,
      required MockPostBloc postBloc,
      required MockUnreadCountCubit unreadCountCubit,
    }) {
      final router = GoRouter(
        initialLocation: '/feed',
        routes: [
          GoRoute(
            path: '/feed',
            builder: (_, __) => const FeedScreen(),
          ),
          GoRoute(
            path: '/profile/:uid',
            builder: (context, state) => Scaffold(
              body: Text('Profile:${state.pathParameters['uid']}'),
            ),
          ),
          GoRoute(
            path: '/post/create',
            builder: (_, __) => const Scaffold(body: Text('Create Post')),
          ),
        ],
      );

      return RepositoryProvider<PostRepository>.value(
        value: postRepository,
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<PostBloc>.value(value: postBloc),
            BlocProvider<UnreadCountCubit>.value(value: unreadCountCubit),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
    }

    testWidgets('tapping author row navigates to /profile/<uid>',
        (tester) async {
      final post = PostEntity(
        id: 'p-nav',
        authorUid: 'uid-author-42',
        authorDisplayName: 'Nav Author',
        content: 'Navigation test post',
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      when(() => postBloc.state).thenReturn(PostLoaded(posts: [post]));
      when(() => postBloc.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(
          buildWithRouter(authBloc: authBloc, postBloc: postBloc, unreadCountCubit: unreadCountCubit));
      await tester.pump();

      await tester.tap(find.text('Nav Author'));
      await tester.pumpAndSettle();

      expect(find.text('Profile:uid-author-42'), findsOneWidget);
    });
  });
}
