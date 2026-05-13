// lib/features/feed/presentation/screens/feed_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';
import 'package:social_network/features/posts/presentation/widgets/post_card.dart';

/// Feed screen — displays the real-time list of posts from Firestore.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  @override
  void initState() {
    super.initState();
    // Defer until after the first frame so the BLoC provider is guaranteed to
    // be in scope. Silently no-ops in contexts where PostBloc is not provided
    // (e.g., router-level widget tests).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<PostBloc>().add(const PostWatchStarted());
      } catch (_) {
        // PostBloc unavailable — feed stays in initial state.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/post/create'),
        tooltip: 'New post',
        child: const Icon(Icons.edit_outlined),
      ),
      body: BlocBuilder<PostBloc, PostState>(
        builder: (context, state) {
          if (state is PostLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is PostFailure) {
            return Center(child: Text(state.error));
          }
          if (state is PostLoaded) {
            if (state.posts.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async {
                  context.read<PostBloc>().add(const PostWatchStarted());
                  await context.read<PostBloc>().stream.firstWhere(
                        (s) => s is! PostLoading,
                      );
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No posts yet.'),
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                context.read<PostBloc>().add(const PostWatchStarted());
                await context.read<PostBloc>().stream.firstWhere(
                      (s) => s is! PostLoading,
                    );
              },
              child: ListView.builder(
                itemCount: state.posts.length,
                itemBuilder: (context, index) => PostCard(
                  post: state.posts[index],
                  currentUserUid:
                      context.read<AuthBloc>().state is AuthAuthenticated
                          ? (context.read<AuthBloc>().state as AuthAuthenticated)
                              .user
                              .uid
                          : '',
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
