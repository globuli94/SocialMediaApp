// lib/features/posts/presentation/screens/create_post_screen.dart
//
// CreatePostScreen — compose and submit a new post.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/posts/presentation/bloc/post_bloc.dart';
import 'package:social_network/features/posts/presentation/bloc/post_event.dart';
import 'package:social_network/features/posts/presentation/bloc/post_state.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';

/// Screen for composing and submitting a new post (text + optional image).
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _textController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageExtension;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.')
        ? '.${picked.name.split('.').last.toLowerCase()}'
        : '.jpg';

    setState(() {
      _imageBytes = bytes;
      _imageExtension = ext;
    });
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post text cannot be empty.')),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final profileState = context.read<ProfileBloc>().state;
    String displayName = authState.user.displayName;
    String? avatarUrl;
    if (profileState is ProfileLoaded) {
      displayName = profileState.profile.displayName;
      avatarUrl = profileState.profile.avatarUrl;
    }

    context.read<PostBloc>().add(
          PostCreateRequested(
            authorUid: authState.user.uid,
            authorDisplayName: displayName,
            authorAvatarUrl: avatarUrl,
            content: text,
            imageBytes: _imageBytes,
            imageExtension: _imageExtension,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PostBloc, PostState>(
      listener: (context, state) {
        if (state is PostLoaded && !state.isSubmitting && _isSubmitting) {
          Navigator.of(context).pop();
        }
        if (state is PostFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error)),
          );
        }
        setState(() {
          _isSubmitting = state is PostLoaded && state.isSubmitting;
        });
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Post'),
          actions: [
            TextButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Post'),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _textController,
                autofocus: true,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: InputBorder.none,
                ),
              ),
              if (_imageBytes != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _imageBytes!,
                    fit: BoxFit.cover,
                    height: 200,
                    width: double.infinity,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    tooltip: 'Attach image',
                    onPressed: _isSubmitting ? null : _pickImage,
                  ),
                  if (_imageBytes != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Remove image',
                      onPressed: () {
                        setState(() {
                          _imageBytes = null;
                          _imageExtension = null;
                        });
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
