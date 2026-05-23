// lib/features/search/presentation/screens/search_screen.dart
//
// SearchScreen — allows users to search for other users by display name.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/search/presentation/bloc/user_search_bloc.dart';
import 'package:social_network/features/search/presentation/bloc/user_search_event.dart';
import 'package:social_network/features/search/presentation/bloc/user_search_state.dart';
import 'package:social_network/features/search/presentation/widgets/user_search_result_card.dart';

/// Screen that lets users search for other users by display name.
///
/// Debounces keystrokes by 500 ms before dispatching [UserSearchQueryChanged].
class SearchScreen extends StatefulWidget {
  /// Creates a [SearchScreen].
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  /// Returns the signed-in user's UID, or an empty string if not yet
  /// authenticated.
  String get _uid {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated ? authState.user.uid : '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      context.read<UserSearchBloc>().add(const UserSearchCleared());
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final uid = _uid;
      if (uid.isEmpty) return;
      context.read<UserSearchBloc>().add(
            UserSearchQueryChanged(query: query, currentUid: uid),
          );
    });
  }

  void _onClear() {
    _debounce?.cancel();
    _controller.clear();
    context.read<UserSearchBloc>().add(const UserSearchCleared());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          onChanged: _onChanged,
          autofocus: false,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search users…',
            border: InputBorder.none,
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                return value.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _onClear,
                      )
                    : const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
      body: BlocBuilder<UserSearchBloc, UserSearchState>(
        builder: (context, state) {
          return switch (state) {
            UserSearchInitial() => const _SearchPrompt(),
            UserSearchLoading() =>
              const Center(child: CircularProgressIndicator()),
            UserSearchEmpty() => const _EmptyState(),
            UserSearchLoaded(:final results) => ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) => UserSearchResultCard(
                  profile: results[index],
                  currentUid: _uid,
                ),
              ),
            UserSearchFailure(:final error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Search failed: $error'),
                ),
              ),
          };
        },
      ),
    );
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Search for users by display name',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No users found',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
