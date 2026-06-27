import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/chat_message.dart';
import '../../../../ai/gemma/gemma_service.dart';
import '../../../../ai/gemma/gemma_provider.dart';
import '../../../../core/mascot/mascot_painter.dart';
import '../../../onboarding/presentation/onboarding_provider.dart';

export '../../domain/chat_message.dart';

final chatProvider = StateNotifierProvider.autoDispose<ChatNotifier, ChatState>(
  (ref) {
    final notifier = ChatNotifier(ref);
    ref.onDispose(() => GemmaService.instance.endTutorSession());
    return notifier;
  },
);

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;

  ChatNotifier(this._ref) : super(const ChatState()) {
    _init();
  }

  Future<void> _init() async {
    final userAsync = await _ref.read(currentUserProvider.future);
    final name = userAsync?.name?.split(' ').first ?? '';
    String weakTopic = 'General Studies';
    try {
      final list = List<String>.from(
          jsonDecode(userAsync?.weakDomains ?? '[]') as List);
      if (list.isNotEmpty) weakTopic = list.first;
    } catch (_) {}

    final greeting = ChatMessage(
      text: 'Namaste${name.isNotEmpty ? ' $name' : ''}! Main Solvy hoon — tumhara personal AI tutor. '
          'Aaj $weakTopic practice karein? Ya kuch aur poochna hai?',
      isUser: false,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [greeting],
      mascotEmotion: MascotEmotion.greeting,
      gemmaReady: false,
    );

    final downloadState = _ref.read(gemmaDownloadStatusProvider);
    if (downloadState.status == GemmaDownloadStatus.ready) {
      await GemmaService.instance.loadModel();
      state = state.copyWith(gemmaReady: true);
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isTyping: true,
      mascotEmotion: MascotEmotion.thinking,
    );

    if (!state.gemmaReady) {
      final fallback = ChatMessage(
        text: 'Gemma AI abhi download nahi hua. Settings mein jaake "Download Gemma 4" karein, '
            'phir main tumhare saath fully interact kar sakta hoon!',
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, fallback],
        isTyping: false,
        mascotEmotion: MascotEmotion.idle,
      );
      return;
    }

    final placeholder = ChatMessage(
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    state = state.copyWith(messages: [...state.messages, placeholder]);

    try {
      await for (final chunk in GemmaService.instance.sendTutorMessage(text)) {
        final updated = List<ChatMessage>.from(state.messages);
        updated[updated.length - 1] = placeholder.copyWith(
          text: chunk,
          isStreaming: true,
        );
        state = state.copyWith(messages: updated, mascotEmotion: MascotEmotion.thinking);
      }
      final done = List<ChatMessage>.from(state.messages);
      done[done.length - 1] = done.last.copyWith(isStreaming: false);
      state = state.copyWith(
        messages: done,
        isTyping: false,
        mascotEmotion: MascotEmotion.happy,
      );
    } catch (e) {
      final err = ChatMessage(
        text: 'Kuch error aa gaya: $e. Dobara try karo.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, err],
        isTyping: false,
        mascotEmotion: MascotEmotion.sad,
      );
    }
  }
}
