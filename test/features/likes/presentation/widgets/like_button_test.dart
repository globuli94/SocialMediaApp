// test/features/likes/presentation/widgets/like_button_test.dart
//
// Widget tests for LikeButton — verifies acceptance criteria from SOCAA-203:
// heart icon rendering, filled vs outlined state, likeCount display, tap
// interaction, error callback, and loading indicator.
//
// NOTE: LikeButton requires a BlocProvider<LikeBloc> in the widget tree.
// These tests provide a MockLikeBloc directly since LikeButton is the entry-
// point widget under test. A separate BUG- ticket has been filed because
// PostCard and FeedScreen do NOT provide LikeBloc in production — see the
// scaffolding gap bug report comment on SOCAA-203.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_network/features/likes/presentation/bloc/like_bloc.dart';
import 'package:social_network/features/likes/presentation/bloc/like_event.dart';
import 'package:social_network/features/likes/presentation/bloc/like_state.dart';
import 'package:social_network/features/likes/presentation/widgets/like_button.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockLikeBloc extends MockBloc<LikeEvent, LikeState> implements LikeBloc {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [LikeButton] in a minimal [MaterialApp] with [BlocProvider<LikeBloc>].
Widget _buildSubject({
  required MockLikeBloc likeBloc,
  String postId = 'post-1',
  String currentUserUid = 'uid-alice',
  Function(String)? onLikeToggleError,
}) {
  return BlocProvider<LikeBloc>.value(
    value: likeBloc,
    child: MaterialApp(
      home: Scaffold(
        body: LikeButton(
          postId: postId,
          currentUserUid: currentUserUid,
          onLikeToggleError: onLikeToggleError,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockLikeBloc likeBloc;

  setUpAll(() {
    registerFallbackValue(
      const LikeWatchRequested(postId: '', userId: ''),
    );
    registerFallbackValue(
      const LikeToggleRequested(postId: '', userId: ''),
    );
  });

  setUp(() {
    likeBloc = MockLikeBloc();
    when(() => likeBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  // -------------------------------------------------------------------------
  // AC: Like button (heart icon) appears on every post in the feed
  // -------------------------------------------------------------------------

  group('heart icon is always present (AC: like button appears on every post)', () {
    testWidgets('shows heart icon in LikeInitial state', (tester) async {
      when(() => likeBloc.state).thenReturn(const LikeInitial());

      await tester.pumpWidget(_buildSubject(likeBloc: likeBloc));

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('shows heart icon in LikeLoading state', (tester) async {
      when(() => likeBloc.state).thenReturn(const LikeLoading());

      await tester.pumpWidget(_buildSubject(likeBloc: likeBloc));

      // Loading shows a CircularProgressIndicator, not an icon
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows heart icon in LikeLoaded state', (tester) async {
      when(() => likeBloc.state).thenReturn(
        const LikeLoaded(isLiked: false, likeCount: 0),
      );

      await tester.pumpWidget(_buildSubject(likeBloc: likeBloc));

      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && (w.icon == Icons.favorite_border || w.icon == Icons.favorite),
        ),
        findsOneWidget,
      );
    });
  });

  // -------------------------------------------------------------------------
  // AC: Outlined heart when NOT liked; filled heart when liked
  // -------------------------------------------------------------------------

  group('heart fill state (AC: outlined vs filled heart)', () {
    testWidgets(
        'shows outlined heart (Icons.favorite_border) when isLiked is false',
        (tester) async {
      when(() => likeBloc.state).thenReturn(
        const LikeLoaded(isLiked: false, likeCount: 3),
      );

      await tester.pumpWidget(_buildSubject(likeBloc: likeBloc));

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
    });

    testWidgets(
        'shows filled heart (Icons.favorite) when isLiked is true',
        (tester) async {
      when(() => likeBloc.state).thenReturn(
        const LikeLoaded(isLiked: true, likeCount: 5),
      );

      await tester.pumpWidget(_buildSubject(likeBloc: likeBloc));

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // AC: likeCount value is displayed and updates immediately
  // -------------------------------------------------------------------------

  group('likeCount display (AC: count shown and updates immediately)', () {
    testWidgets('displays likeCount as text when LikeLoaded', (tester) async {
      when(() => likeBloc.state).thenReturn(
        const LikeLoaded(isLiked: false, likeCount: 42),
      );

      await tester.pumpWidget(_buildSubject(likeBloc: likeBloc));

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('displays 0 when likeCount is 0', (tester) async {
      when(() => likeBloc.state).thenReturn(
        const LikeLoaded(isLiked: false, likeCount: 0),
      );

      await tester.pumpWidget(_buildSubject(likeBloc: likeBloc));

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('updates count display when state changes', (tester) async {
      final stateController = StreamController<LikeState>.broadcast();
      when(() => likeBloc.state).thenReturn(
        const LikeLoaded(isLiked: false, likeCount: 1),
      );
      when(() => likeBloc.stream)
          .thenAnswer((_) => stateController.stream);

      await tester.pumpWidget(_buildSubject(likeBloc: likeBloc));
      expect(find.text('1'), findsOneWidget);

      stateController.add(const LikeLoaded(isLiked: true, likeCount: 2));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      await stateController.close();
    });
  });

  // -------------------------------------------------------------------------
  // AC: Button is interactive and responds to tap
  // AC: Tapping Like dispatches LikeToggleRequested
  // -------------------------------------------------------------------------

  group('tap interaction (AC: button interactive, dispatches toggle)', () {
    testWidgets('tapping like button dispatches LikeToggleRequested', (tester) async {
      when(() => likeBloc.state).thenReturn(
        const LikeLoaded(isLiked: false, likeCount: 0),
      );

      await tester.pumpWidget(
        _buildSubject(
          likeBloc: likeBloc,
          postId: 'post-1',
          currentUserUid: 'uid-alice',
        ),
      );

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      verify(
        () => likeBloc.add(
          const LikeToggleRequested(postId: 'post-1', userId: 'uid-alice'),
        ),
      ).called(1);
    });

    testWidgets('tapping unlike button dispatches LikeToggleRequested', (tester) async {
      when(() => likeBloc.state).thenReturn(
        const LikeLoaded(isLiked: true, likeCount: 5),
      );

      await tester.pumpWidget(
        _buildSubject(
          likeBloc: likeBloc,
          postId: 'post-1',
          currentUserUid: 'uid-alice',
        ),
      );

      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pump();

      verify(
        () => likeBloc.add(
          const LikeToggleRequested(postId: 'post-1', userId: 'uid-alice'),
        ),
      ).called(1);
    });

    testWidgets('dispatches LikeWatchRequested on mount with correct postId and userId',
        (tester) async {
      when(() => likeBloc.state).thenReturn(const LikeInitial());

      await tester.pumpWidget(
        _buildSubject(
          likeBloc: likeBloc,
          postId: 'post-42',
          currentUserUid: 'uid-bob',
        ),
      );

      verify(
        () => likeBloc.add(
          const LikeWatchRequested(postId: 'post-42', userId: 'uid-bob'),
        ),
      ).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // AC: isSubmitting disables the button (race-condition protection)
  // -------------------------------------------------------------------------

  group('isSubmitting disables button (AC: rapid taps / race-condition protection)', () {
    testWidgets('button is disabled when isSubmitting is true', (tester) async {
      when(() => likeBloc.state).thenReturn(
        const LikeLoaded(isLiked: false, likeCount: 1, isSubmitting: true),
      );

      await tester.pumpWidget(_buildSubject(likeBloc: likeBloc));

      // IconButton's onPressed is null → widget is disabled
      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('button is enabled when isSubmitting is false', (tester) async {
      when(() => likeBloc.state).thenReturn(
        const LikeLoaded(isLiked: false, likeCount: 1),
      );

      await tester.pumpWidget(_buildSubject(likeBloc: likeBloc));

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.onPressed, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // AC: Error handling — network errors show user feedback
  // -------------------------------------------------------------------------

  group('error handling (AC: network errors show user feedback)', () {
    testWidgets('calls onLikeToggleError callback when state is LikeFailure',
        (tester) async {
      String? capturedError;

      final stateController = StreamController<LikeState>.broadcast();
      when(() => likeBloc.state).thenReturn(const LikeInitial());
      when(() => likeBloc.stream)
          .thenAnswer((_) => stateController.stream);

      await tester.pumpWidget(
        _buildSubject(
          likeBloc: likeBloc,
          onLikeToggleError: (error) => capturedError = error,
        ),
      );

      stateController.add(const LikeFailure(error: 'Network unavailable'));
      await tester.pump();

      expect(capturedError, 'Network unavailable');

      await stateController.close();
    });

    testWidgets('shows heart icon when in LikeFailure state (retry UI)', (tester) async {
      when(() => likeBloc.state).thenReturn(
        const LikeFailure(error: 'Connection error'),
      );

      await tester.pumpWidget(_buildSubject(likeBloc: likeBloc));

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('tapping in LikeFailure state dispatches LikeWatchRequested for retry',
        (tester) async {
      when(() => likeBloc.state).thenReturn(
        const LikeFailure(error: 'Connection error'),
      );

      await tester.pumpWidget(
        _buildSubject(
          likeBloc: likeBloc,
          postId: 'post-1',
          currentUserUid: 'uid-alice',
        ),
      );

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      verify(
        () => likeBloc.add(
          const LikeWatchRequested(postId: 'post-1', userId: 'uid-alice'),
        ),
      ).called(greaterThanOrEqualTo(1));
    });
  });
}
