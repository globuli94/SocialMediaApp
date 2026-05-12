// lib/features/feed/presentation/screens/feed_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:social_network/features/feed/presentation/bloc/feed_event.dart';
import 'package:social_network/features/feed/presentation/bloc/feed_state.dart';
import 'package:social_network/features/posts/domain/repositories/post_repository.dart';
import 'package:social_network/features/posts/presentation/widgets/post_card.dart';

/// Feed screen — displays a paginated list of posts with pull-to-refresh
/// and infinite scroll.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final FeedBloc _feedBloc;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Create and start the bloc on first dependency resolution so that
    // context.read<PostRepository>() is available.
    if (!_isBlocInitialized) {
      _feedBloc = FeedBloc(postRepository: context.read<PostRepository>())
        ..add(const FeedStarted());
      _isBlocInitialized = true;
    }
  }

  bool _isBlocInitialized = false;

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _feedBloc.close();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _feedBloc.add(const FeedLoadMoreRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _feedBloc,
      child: Scaffold(
        appBar: AppBar(title: const Text('Feed')),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/post/create'),
          tooltip: 'New post',
          child: const Icon(Icons.edit_outlined),
        ),
        body: BlocBuilder<FeedBloc, FeedState>(
          builder: (context, state) {
            if (state is FeedLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is FeedFailure) {
              return Center(child: Text(state.error));
            }
            if (state is FeedLoaded) {
              if (state.posts.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async {
                    _feedBloc.add(const FeedRefreshRequested());
                  },
                  child: const SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: 400,
                      child: Center(child: Text('No posts yet.')),
                    ),
                  ),
                );
              }

              final currentUserUid =
                  context.read<AuthBloc>().state is AuthAuthenticated
                      ? (context.read<AuthBloc>().state as AuthAuthenticated)
                          .user
                          .uid
                      : '';

              return RefreshIndicator(
                onRefresh: () async {
                  _feedBloc.add(const FeedRefreshRequested());
                },
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount:
                      state.posts.length + (state.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.posts.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final post = state.posts[index];
                    return PostCard(
                      post: post,
                      currentUserUid: currentUserUid,
                      onAuthorTap: () =>
                          context.push('/profile/${post.authorUid}'),
                    );
                  },
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
