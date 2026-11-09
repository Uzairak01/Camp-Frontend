import 'package:flutter/foundation.dart';

import '../../../core/data/app_repositories.dart';
import '../../../core/data/voice_chat_repository.dart';
import '../domain/voice_conversation_model.dart';

/// Central state controller managing Voice Copilot conversation history.
///
/// Handles automatic thread saving, history retrieval, day-based grouping,
/// title search filtering, and active conversation selection.
class VoiceChatController extends ChangeNotifier {
  /// Creates a voice chat controller with an optional explicit [VoiceChatRepository].
  VoiceChatController({VoiceChatRepository? repository})
      : _repository =
            repository ?? AppRepositories.instance.voiceChatRepository;

  /// Global singleton instance across the application.
  static VoiceChatController instance = VoiceChatController();

  final VoiceChatRepository _repository;

  final List<VoiceConversation> _conversations = [];

  VoiceConversation? _currentConversation;

  /// Unmodifiable view of all stored conversations, ordered newest first.
  List<VoiceConversation> get conversations => List.unmodifiable(_conversations);

  /// Currently active conversation thread in the conversation view.
  VoiceConversation? get currentConversation => _currentConversation;

  /// Loads all conversation threads from the persistent repository.
  ///
  /// Release and debug builds both start empty with honest persistence.
  Future<void> load() async {
    try {
      final loaded = await _repository.loadConversations();
      _conversations
        ..clear()
        ..addAll(loaded);
      notifyListeners();
    } catch (_) {
      // Gracefully fall back to current in-memory state on I/O error
    }
  }

  /// Clears active conversation state to prepare for a fresh dialogue.
  void startNewChat() {
    _currentConversation = null;
    notifyListeners();
  }

  /// Designates [conversation] as the active dialogue shown in the conversation view.
  void selectConversation(VoiceConversation conversation) {
    _currentConversation = conversation;
    notifyListeners();
  }

  /// Appends an exchange to the current conversation or creates a new conversation thread.
  ///
  /// For new conversations, the title is automatically set to the first user query (trimmed).
  /// Automatically persists changes to disk via [_repository].
  Future<VoiceConversation> saveActiveMessage({
    required String userText,
    required String assistantText,
  }) async {
    final now = DateTime.now().toUtc();
    final userMsg = VoiceChatMessage(
      id: 'msg_${now.millisecondsSinceEpoch}_u',
      text: userText.trim(),
      isUser: true,
      timestamp: now,
    );
    final assistantMsg = VoiceChatMessage(
      id: 'msg_${now.millisecondsSinceEpoch}_a',
      text: assistantText,
      isUser: false,
      timestamp: now,
    );

    final VoiceConversation updated;

    if (_currentConversation == null) {
      // Create new conversation with title set to the first trimmed user query
      final newId = 'conv_${now.millisecondsSinceEpoch}';
      updated = VoiceConversation(
        id: newId,
        title: userText.trim(),
        createdAt: now,
        updatedAt: now,
        messages: [userMsg, assistantMsg],
      );
      _conversations.insert(0, updated);
    } else {
      // Append new exchange to the existing active conversation
      final currentList = List<VoiceChatMessage>.from(_currentConversation!.messages)
        ..add(userMsg)
        ..add(assistantMsg);

      updated = _currentConversation!.copyWith(
        messages: currentList,
        updatedAt: now,
      );

      final idx = _conversations.indexWhere((c) => c.id == updated.id);
      if (idx != -1) {
        _conversations[idx] = updated;
      } else {
        _conversations.insert(0, updated);
      }
    }

    // Keep conversations ordered newest first
    _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _currentConversation = updated;

    notifyListeners();

    try {
      await _repository.saveConversation(updated);
    } catch (_) {
      // State is maintained in memory even if async disk save encounters a transient error
    }

    return updated;
  }

  /// Groups conversations into Today, Yesterday, and Earlier sections.
  ///
  /// Optionally filters by [query] (case-insensitive substring match against title).
  /// [referenceDate] allows deterministic time-travel assertions in tests.
  Map<String, List<VoiceConversation>> getGroupedConversations({
    String query = '',
    DateTime? referenceDate,
  }) {
    final cleanQuery = query.trim().toLowerCase();

    // Filter conversations by title if search query is provided
    final filtered = cleanQuery.isEmpty
        ? _conversations
        : _conversations
            .where((c) => c.title.toLowerCase().contains(cleanQuery))
            .toList();

    // Determine calendar day boundaries in local time
    final now = referenceDate ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    final today = <VoiceConversation>[];
    final yesterday = <VoiceConversation>[];
    final earlier = <VoiceConversation>[];

    for (final conv in filtered) {
      final localDate = conv.updatedAt.toLocal();
      final convDay =
          DateTime(localDate.year, localDate.month, localDate.day);

      if (convDay.isAtSameMomentAs(todayStart)) {
        today.add(conv);
      } else if (convDay.isAtSameMomentAs(yesterdayStart)) {
        yesterday.add(conv);
      } else {
        earlier.add(conv);
      }
    }

    return {
      'Today': List.unmodifiable(today),
      'Yesterday': List.unmodifiable(yesterday),
      'Earlier': List.unmodifiable(earlier),
    };
  }
}

