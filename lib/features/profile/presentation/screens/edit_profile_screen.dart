// lib/features/profile/presentation/screens/edit_profile_screen.dart
//
// EditProfileScreen — lets the current user update their display name, bio,
// and avatar.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:social_network/features/auth/presentation/bloc/auth_state.dart';
import 'package:social_network/features/profile/domain/entities/user_profile_entity.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_event.dart';
import 'package:social_network/features/profile/presentation/bloc/profile_state.dart';
import 'package:social_network/features/profile/presentation/widgets/avatar_widget.dart';

/// Screen for editing the current user's display name, bio, and avatar.
///
/// Accessible only for the authenticated user's own profile via `/profile/edit`.
class EditProfileScreen extends StatefulWidget {
  /// Creates an [EditProfileScreen].
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  bool _initialized = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Pre-fills text fields once the profile has loaded.
  void _initFromProfile(UserProfileEntity profile) {
    if (!_initialized) {
      _displayNameController = TextEditingController(text: profile.displayName);
      _bioController = TextEditingController(text: profile.bio);
      _initialized = true;
    }
  }

  /// Opens the gallery picker and dispatches [ProfileAvatarUploadRequested].
  Future<void> _pickAvatar(BuildContext context, String uid) async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = '.${file.path.split('.').last.toLowerCase()}';
    if (!context.mounted) return;
    context.read<ProfileBloc>().add(
          ProfileAvatarUploadRequested(uid: uid, bytes: bytes, extension: ext),
        );
  }

  /// Validates the form and dispatches [ProfileUpdateRequested].
  void _save(BuildContext context, String uid) {
    if (!_formKey.currentState!.validate()) return;
    context.read<ProfileBloc>().add(
          ProfileUpdateRequested(
            uid: uid,
            displayName: _displayNameController.text.trim(),
            bio: _bioController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final uid =
        authState is AuthAuthenticated ? authState.user.uid : null;

    if (uid == null) {
      // Should not happen — router guard redirects unauthenticated users.
      return const Scaffold(
        body: Center(child: Text('Not signed in.')),
      );
    }

    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (BuildContext context, ProfileState state) {
        if (state is ProfileLoaded) {
          // Return to profile screen after a successful save.
          if (_initialized) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile updated.')),
            );
            context.go('/home');
          }
        }
        if (state is ProfileFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error)),
          );
        }
      },
      builder: (BuildContext context, ProfileState state) {
        final UserProfileEntity? profile = switch (state) {
          ProfileLoaded(:final profile) => profile,
          ProfileUpdating(:final profile) => profile,
          _ => null,
        };

        if (profile == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        _initFromProfile(profile);
        final bool isSaving = state is ProfileUpdating;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Profile'),
            actions: [
              if (!isSaving)
                TextButton(
                  onPressed: () => _save(context, uid),
                  child: const Text('Save'),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AvatarWidget(
                    displayName: profile.displayName,
                    avatarUrl: profile.avatarUrl,
                    radius: 56,
                    onTap: isSaving ? null : () => _pickAvatar(context, uid),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      hintText: 'Your public name',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 50,
                    textInputAction: TextInputAction.next,
                    enabled: !isSaving,
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Display name is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioController,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      hintText: 'Tell the world about yourself',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 160,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    enabled: !isSaving,
                  ),
                  const SizedBox(height: 24),
                  if (isSaving)
                    const CircularProgressIndicator()
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _save(context, uid),
                        child: const Text('Save changes'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
