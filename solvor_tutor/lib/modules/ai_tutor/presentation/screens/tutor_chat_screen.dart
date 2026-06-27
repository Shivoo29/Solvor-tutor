import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/mascot/mascot_widget.dart';
import '../providers/chat_provider.dart';

class TutorChatScreen extends ConsumerStatefulWidget {
  const TutorChatScreen({super.key});

  @override
  ConsumerState<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends ConsumerState<TutorChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (chatState.messages.isNotEmpty) _scrollToBottom();

    return Scaffold(
      backgroundColor: isDark ? kVoid : kPaper,
      appBar: AppBar(
        backgroundColor: isDark ? kSurface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: Row(
          children: [
            MascotWidget(emotion: chatState.mascotEmotion, size: 36),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solvy',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : kInk,
                  ),
                ),
                Text(
                  chatState.isTyping ? 'Soch raha hoon...' : 'Personal AI Tutor',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? kNeonTeal : kMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(height: 1, color: isDark ? kSubtle : kBorder),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chatState.messages.length,
              itemBuilder: (context, i) {
                final msg = chatState.messages[i];
                return _MessageBubble(
                  message: msg,
                  isDark: isDark,
                );
              },
            ),
          ),

          Container(
            color: isDark ? kSurface : Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? kVoid : kPaper,
                        border: Border.all(color: isDark ? kSubtle : kBorder),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(
                            color: isDark ? Colors.white : kInk, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Kuch bhi poochho...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white24 : kMuted,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                        onSubmitted: (_) => _send(),
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      color: isDark ? kNeonYellow : kInk,
                      child: Icon(
                        Icons.send,
                        size: 18,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;

  const _MessageBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDark ? kNeonPurple.withValues(alpha: 0.3) : kBorder,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('S', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: isUser
                    ? (isDark ? kNeonPurple.withValues(alpha: 0.25) : kInk.withValues(alpha: 0.08))
                    : (isDark ? kSurface : Colors.white),
                border: Border(
                  left: !isUser
                      ? const BorderSide(color: kNeonPurple, width: 3)
                      : BorderSide.none,
                  top: BorderSide(color: isDark ? kSubtle : kBorder),
                  right: BorderSide(color: isDark ? kSubtle : kBorder),
                  bottom: BorderSide(color: isDark ? kSubtle : kBorder),
                ),
              ),
              child: message.isStreaming && message.text.isEmpty
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5,
                              color: isDark ? kNeonPurple : kMuted),
                        ),
                        const SizedBox(width: 8),
                        Text('Soch raha hoon...',
                            style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.white38 : kMuted)),
                      ],
                    )
                  : Text(
                      message.text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? Colors.white70 : kInk,
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
