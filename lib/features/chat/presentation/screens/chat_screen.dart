// lib/features/chat/presentation/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_event.dart';
import 'package:social_network/features/chat/presentation/bloc/chat_state.dart';

String _formatTime(DateTime dt) {
  final h = dt.hour;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = h >= 12 ? 'PM' : 'AM';
  final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  return '$hour:$m $period';
}

/// Displays the message thread for a single conversation.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.currentUid,
    required this.recipientUid,
  });

  final String conversationId;
  final String currentUid;
  final String recipientUid;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(
          ChatWatchStarted(
            conversationId: widget.conversationId,
            currentUid: widget.currentUid,
            recipientUid: widget.recipientUid,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<ChatBloc, ChatState>(
          buildWhen: (previous, current) =>
              current is ChatLoaded &&
              (previous is! ChatLoaded ||
                  (previous).recipientDisplayName !=
                      (current).recipientDisplayName),
          builder: (context, state) {
            if (state is ChatLoaded) {
              return Text(state.recipientDisplayName ?? widget.recipientUid);
            }
            return Text(widget.recipientUid);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                return switch (state) {
                  ChatInitial() || ChatLoading() => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ChatError(:final message) => Center(child: Text(message)),
                  ChatLoaded(
                    :final messages,
                    :final currentUid,
                    :final recipientDisplayName,
                    :final recipientAvatarUrl,
                  ) =>
                    messages.isEmpty
                        ? const Center(child: Text('No messages yet'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final isSent = msg.senderUid == currentUid;
                              return _MessageBubble(
                                text: msg.text,
                                createdAt: msg.createdAt,
                                isSent: isSent,
                                senderDisplayName:
                                    isSent ? null : recipientDisplayName,
                                senderAvatarUrl:
                                    isSent ? null : recipientAvatarUrl,
                              );
                            },
                          ),
                };
              },
            ),
          ),
          _MessageInputBar(
            onSend: (text) =>
                context.read<ChatBloc>().add(ChatMessageSent(text)),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.createdAt,
    required this.isSent,
    this.senderDisplayName,
    this.senderAvatarUrl,
  });

  final String text;
  final DateTime createdAt;
  final bool isSent;

  /// Display name of the sender — only provided for received messages.
  final String? senderDisplayName;

  /// Avatar URL of the sender — only provided for received messages.
  final String? senderAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor =
        isSent ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final fgColor =
        isSent ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
    final timeLabel = _formatTime(createdAt.toLocal());

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
            isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isSent && senderDisplayName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                senderDisplayName!,
                style: TextStyle(
                  color: fgColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          Text(text, style: TextStyle(color: fgColor)),
          const SizedBox(height: 2),
          Text(
            timeLabel,
            style: TextStyle(
              color: fgColor.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );

    if (isSent) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    // Received message: show avatar to the left of the bubble.
    final initials = senderDisplayName?.isNotEmpty == true
        ? senderDisplayName![0].toUpperCase()
        : '?';
    final avatar = CircleAvatar(
      radius: 16,
      backgroundImage:
          senderAvatarUrl != null ? NetworkImage(senderAvatarUrl!) : null,
      child: senderAvatarUrl == null
          ? Text(initials, style: const TextStyle(fontSize: 12))
          : null,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(width: 6),
          bubble,
        ],
      ),
    );
  }
}

class _MessageInputBar extends StatefulWidget {
  const _MessageInputBar({required this.onSend});

  final void Function(String text) onSend;

  @override
  State<_MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<_MessageInputBar> {
  final _controller = TextEditingController();
  bool _isEmpty = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final empty = _controller.text.trim().isEmpty;
      if (empty != _isEmpty) setState(() => _isEmpty = empty);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _isEmpty ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
