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
      appBar: AppBar(title: Text(widget.recipientUid)),
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
                  ChatLoaded(:final messages, :final currentUid) =>
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
  });

  final String text;
  final DateTime createdAt;
  final bool isSent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor =
        isSent ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final fgColor =
        isSent ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
    final timeLabel = _formatTime(createdAt.toLocal());

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
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
