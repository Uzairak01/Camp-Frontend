import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../garage/controllers/active_bike_controller.dart';
import '../../../maintenance/controllers/maintenance_controller.dart';
import '../../../maintenance/domain/service_schedule_item.dart';
import '../../../mechanics/controllers/mechanic_controller.dart';
import '../../controllers/voice_chat_controller.dart';
import '../../domain/voice_conversation_model.dart';

/// Represents a single conversation message in the Voice Copilot dialogue.
@immutable
class _ChatMessage {
  /// Creates a chat message value object.
  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  /// Text content of the dialogue turn.
  final String text;

  /// Whether the turn was spoken/typed by the rider (`true`) or assistant (`false`).
  final bool isUser;

  /// Time when the message occurred
  final DateTime timestamp;
}

/// CAMP Voice Copilot Screen
///
/// Hands-free expedition voice assistant for motorcyclists with persistent
/// chat history side panel, real app data answers, and dark navy + orange theme.
class VoiceAssistantScreen extends StatefulWidget {
  /// Creates the Voice Assistant Screen.
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _isListening = false;
  bool _isPanelOpen = false;
  String _liveTranscript = '';

  static const List<String> _idleChips = [
    'How much fuel do I have left?',
    'What service is due next?',
    'Find my nearest mechanic',
    'Log a refill',
  ];

  @override
  void initState() {
    super.initState();
    // Pulse animation controller for the central glowing mic button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Listen to history changes and load stored conversations
    VoiceChatController.instance.addListener(_onVoiceChatChanged);
    VoiceChatController.instance.load();

    // If an active conversation exists in controller, hydrate it into the view
    final active = VoiceChatController.instance.currentConversation;
    if (active != null) {
      _messages.addAll(active.messages.map((m) => _ChatMessage(
            text: m.text,
            isUser: m.isUser,
            timestamp: m.timestamp,
          )));
    }
  }

  void _onVoiceChatChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkReducedMotion();
  }

  /// Pauses infinite animation loops when accessibility reduced-motion is requested.
  void _checkReducedMotion() {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 1.0;
      }
    } else if (_isListening && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    VoiceChatController.instance.removeListener(_onVoiceChatChanged);
    _pulseController.dispose();
    _textController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Toggles speech listening simulation state and updates pulse animations.
  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      _liveTranscript = '';
      final disableAnimations =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (_isListening) {
        if (!disableAnimations) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.value = 1.0;
        }
      } else {
        _pulseController.stop();
        _pulseController.value = 1.0;
      }
    });
  }

  /// Handles rider submission via keyboard send action.
  void _handleSubmitted(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    _textController.clear();
    _processQuery(query);
  }

  /// Processes rider query, updates UI bubbles, retrieves real data, and auto-saves thread.
  void _processQuery(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;

    _pulseController.stop();
    _pulseController.value = 1.0;

    setState(() {
      _isListening = false;
      _messages.add(_ChatMessage(
        text: clean,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });

    final answer = _resolveRealDataAnswer(clean);

    setState(() {
      _messages.add(_ChatMessage(
        text: answer,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });

    // Automatically persist conversation thread with title set to first user message
    VoiceChatController.instance.saveActiveMessage(
      userText: clean,
      assistantText: answer,
    );

    _scrollToBottom();
  }

  /// Automatically scrolls conversation view to reveal the latest exchange.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  /// Opens the 320px chat history side panel.
  void _openPanel() {
    setState(() {
      _isPanelOpen = true;
    });
  }

  /// Closes the side panel and resets active search query.
  void _closePanel() {
    setState(() {
      _isPanelOpen = false;
      _searchController.clear();
    });
  }

  /// Clears the current dialogue thread and returns to the idle prompt view.
  void _handleNewChat() {
    VoiceChatController.instance.startNewChat();
    setState(() {
      _messages.clear();
      _isPanelOpen = false;
      _searchController.clear();
    });
  }

  /// Loads a selected historical conversation into the active dialogue view.
  void _handleSelectConversation(VoiceConversation conversation) {
    VoiceChatController.instance.selectConversation(conversation);
    setState(() {
      _messages
        ..clear()
        ..addAll(conversation.messages.map((m) => _ChatMessage(
              text: m.text,
              isUser: m.isUser,
              timestamp: m.timestamp,
            )));
      _isPanelOpen = false;
      _searchController.clear();
    });
    _scrollToBottom();
  }

  /// Resolve assistant response strictly from real app data.
  /// If unanswerable from real data, returns "I can't answer that yet."
  String _resolveRealDataAnswer(String query) {
    final lower = query.trim().toLowerCase();

    // 1. Fuel status query
    if (lower == 'how much fuel do i have left?' ||
        lower == 'how much fuel do i have left' ||
        lower.contains('fuel left') ||
        lower.contains('fuel remaining') ||
        lower.contains('how much fuel') ||
        lower == 'fuel') {
      final activeBike = ActiveBikeController.instance.activeBike;
      if (activeBike == null) {
        return 'No active bike selected in your garage.';
      }

      if (activeBike.fuelRemainingLiters != null) {
        final liters = activeBike.fuelRemainingLiters!;
        final capacity = activeBike.fuelTankCapacityLiters;
        if (capacity != null && capacity > 0) {
          final pct = ((liters / capacity) * 100).round().clamp(0, 100);
          final avg = activeBike.fuelAverageKmPerLiter;
          if (avg != null && avg > 0) {
            final range = (liters * avg).round();
            return 'You have ${liters.toStringAsFixed(1)} L of fuel remaining (~$pct%). Estimated range is $range km.';
          }
          return 'You have ${liters.toStringAsFixed(1)} L of fuel remaining (~$pct%).';
        }
        return 'You have ${liters.toStringAsFixed(1)} L of fuel remaining.';
      } else if (activeBike.fuelLevelPercent != null) {
        return 'Your fuel level is approximately ${activeBike.fuelLevelPercent}%.';
      } else {
        return 'No fuel level recorded yet for ${activeBike.nickname ?? activeBike.modelName}.';
      }
    }

    // 2. Next service query
    if (lower == 'what service is due next?' ||
        lower == 'what service is due next' ||
        lower.contains('service is due') ||
        lower.contains('service due next') ||
        lower.contains('next service') ||
        lower == 'service') {
      final activeBike = ActiveBikeController.instance.activeBike;
      if (activeBike == null) {
        return 'No active bike selected in your garage.';
      }

      final predictions = MaintenanceController.instance.items(activeBike.id);
      final overdue = predictions
          .where((p) => p.scheduleStatus == ScheduleItemStatus.overdue)
          .toList();
      if (overdue.isNotEmpty) {
        return '${overdue.first.name} is overdue for service.';
      }

      final dueSoon = predictions
          .where((p) => p.scheduleStatus == ScheduleItemStatus.dueSoon)
          .toList();
      if (dueSoon.isNotEmpty) {
        final item = dueSoon.first;
        if (item.remainingKm != null) {
          return '${item.name} is due soon in ${item.remainingKm} km.';
        }
        return '${item.name} is due soon for service.';
      }

      final withKm = predictions
          .where((p) => p.remainingKm != null && p.remainingKm! > 0)
          .toList();
      if (withKm.isNotEmpty) {
        withKm.sort((a, b) => a.remainingKm!.compareTo(b.remainingKm!));
        return 'Next service is ${withKm.first.name} in ${withKm.first.remainingKm} km.';
      }

      if (predictions.isNotEmpty) {
        return 'All scheduled maintenance is up to date for ${activeBike.nickname ?? activeBike.modelName}.';
      }
      return 'No scheduled maintenance items configured for ${activeBike.nickname ?? activeBike.modelName}.';
    }

    // 3. Saved mechanic query
    if (lower == 'find my nearest mechanic' ||
        lower == 'find my nearest mechanic?' ||
        lower.contains('nearest mechanic') ||
        lower.contains('find mechanic') ||
        lower == 'mechanic') {
      final mechanics = MechanicController.instance.mechanics;
      if (mechanics.isNotEmpty) {
        final nearest = mechanics.first;
        final loc = nearest.durationOrLocation.trim();
        if (loc.isNotEmpty) {
          return 'Nearest saved mechanic is ${nearest.name} ($loc).';
        }
        return 'Nearest saved mechanic is ${nearest.name}.';
      }
      return 'No saved mechanics found in your offline directory.';
    }

    // 4. Log a refill query
    if (lower == 'log a refill' ||
        lower == 'log a refill?' ||
        lower.contains('log a refill') ||
        lower.contains('log refill')) {
      final activeBike = ActiveBikeController.instance.activeBike;
      if (activeBike != null) {
        return 'To log a refill for ${activeBike.nickname ?? activeBike.modelName}, tap "I Refilled" on the Home dashboard or add an expense under Finances.';
      }
      return 'To log a refill, select an active bike in your garage and tap "I Refilled" on the Home dashboard.';
    }

    // Unanswerable fallback strictly from real data
    return "I can't answer that yet.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D14),
      body: Stack(
        children: [
          // Main conversation screen layer
          SafeArea(
            child: Column(
              children: [
                // 1. Header: Menu (left, 44px) & Close (right, 44px)
                _buildHeader(),

                // 2. Middle Body: Listening State, Conversation, or Idle
                Expanded(
                  child: _isListening
                      ? _buildListeningBody()
                      : (_messages.isNotEmpty
                          ? _buildConversationBody()
                          : _buildIdleBody()),
                ),

                // 3. Bottom Bar: 60px Pill with TextField & Mic / Stop Button
                _buildBottomBar(),
              ],
            ),
          ),

          // Dim backdrop: tapping closes the panel
          if (_isPanelOpen) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: _closePanel,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                ),
              ),
            ),
            // Side panel: slides in from the left, 320px wide
            TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
                    ? 0.0
                    : -320.0,
                end: 0.0,
              ),
              duration:
                  (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              builder: (context, leftOffset, child) {
                return Positioned(
                  left: leftOffset,
                  top: 0,
                  bottom: 0,
                  width: 320,
                  child: child!,
                );
              },
              child: _buildSidePanel(),
            ),
          ],
        ],
      ),
    );
  }

  /// 1. Top Header: Menu button (left) and Close button (right)
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Menu button (44px circle, slides open the 320px chat history panel)
          GestureDetector(
            onTap: _openPanel,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E293B),
                border: Border.all(
                  color: const Color(0xFF334155),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.menu_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),

          // Right: Close button (44px circle)
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E293B),
                border: Border.all(
                  color: const Color(0xFF334155),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2A. Idle Body
  Widget _buildIdleBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'How can I help on this ride?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ask about your bike, fuel, service or saved mechanics.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 32),
          ..._idleChips.map((chipText) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: _buildChip(chipText),
              )),
        ],
      ),
    );
  }

  Widget _buildChip(String text) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _processQuery(text),
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFFF97316).withValues(alpha: 0.15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF334155),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFFF97316),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 2B. Listening State Body
  Widget _buildListeningBody() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Centered large orange mic with animated concentric rings
            _buildPulsingMicHub(
              size: 240,
              buttonSize: 100,
              iconSize: 44,
              isListening: true,
              onTap: _toggleListening,
            ),
            const SizedBox(height: 28),
            const Text(
              'Listening…',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _liveTranscript.isNotEmpty
                  ? _liveTranscript
                  : 'Say your command or ask a question',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: _liveTranscript.isNotEmpty
                    ? const Color(0xFFFDE68A)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 2C. Conversation State Body
  Widget _buildConversationBody() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isUser = message.isUser;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isUser) const SizedBox(width: 48),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFFF97316)
                        : const Color(0xFF1E293B),
                    border: isUser
                        ? null
                        : Border.all(
                            color: const Color(0xFF334155), width: 1.2),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.35,
                      fontWeight: isUser ? FontWeight.w600 : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (!isUser) const SizedBox(width: 48),
            ],
          ),
        );
      },
    );
  }

  /// 3. Bottom Bar: 60px pill with text field and existing mic/stop button
  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Container(
        height: 60,
        padding: const EdgeInsets.only(left: 18, right: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFF334155),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: _handleSubmitted,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: 'Message CAMP Copilot',
                  hintStyle: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            // Existing orange mic button inside the bar (switches to stop when listening)
            _buildPulsingMicHub(
              size: 52,
              buttonSize: 44,
              iconSize: 22,
              isListening: _isListening,
              overrideIcon:
                  _isListening ? Icons.stop_rounded : Icons.mic_rounded,
              onTap: _toggleListening,
            ),
          ],
        ),
      ),
    );
  }

  /// 4. Side Panel: 320px wide drawer with New Chat button, search, and grouped history.
  Widget _buildSidePanel() {
    final groups = VoiceChatController.instance
        .getGroupedConversations(query: _searchController.text);
    final hasAnyChats = (groups['Today']?.isNotEmpty ?? false) ||
        (groups['Yesterday']?.isNotEmpty ?? false) ||
        (groups['Earlier']?.isNotEmpty ?? false);

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0F1D),
        border: Border(
          right: BorderSide(
            color: Color(0xFF1E293B),
            width: 1.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panel Header: Title and Close (X) button
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chat History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: _closePanel,
                    tooltip: 'Close history',
                  ),
                ],
              ),
            ),

            // "New chat" button (tactical orange)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleNewChat,
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'New chat',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),

            // Search chats input field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF334155),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('voice_chat_search_field'),
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search chats',
                          hintStyle: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        child: const Icon(
                          Icons.clear_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Scrollable grouped chat history or empty state
            Expanded(
              child: hasAnyChats
                  ? ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        for (final groupTitle in ['Today', 'Yesterday', 'Earlier'])
                          if ((groups[groupTitle]?.isNotEmpty ?? false)) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 16, 18, 6),
                              child: Text(
                                groupTitle,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            ...groups[groupTitle]!.map(
                              (conv) => _buildConversationTile(conv),
                            ),
                          ],
                      ],
                    )
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 36,
                              color: Color(0xFF475569),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No chats yet',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Individual historical conversation entry tile inside the side panel.
  Widget _buildConversationTile(VoiceConversation conv) {
    final isActive =
        VoiceChatController.instance.currentConversation?.id == conv.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleSelectConversation(conv),
          borderRadius: BorderRadius.circular(10),
          splashColor: const Color(0xFFF97316).withValues(alpha: 0.15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF1E293B)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? const Color(0xFFF97316).withValues(alpha: 0.6)
                    : Colors.transparent,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: isActive
                      ? const Color(0xFFF97316)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    conv.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? Colors.white : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Reusable Mic Widget preserving concentric rings, pulse animation,
  /// and orange linear gradient.
  Widget _buildPulsingMicHub({
    required double size,
    required double buttonSize,
    required double iconSize,
    required bool isListening,
    required VoidCallback onTap,
    IconData? overrideIcon,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final disableAnimations =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        final scale =
            (!disableAnimations && isListening) ? _pulseAnimation.value : 1.0;

        final ringOuterColor =
            const Color(0xFF3E2314).withValues(alpha: 0.75);
        final ringMidColor =
            const Color(0xFF6B3113).withValues(alpha: 0.85);
        final ringInnerColor =
            const Color(0xFFEA580C).withValues(alpha: 0.65);
        const micGradientColors = [
          Color(0xFFFFB800),
          Color(0xFFF97316),
          Color(0xFFEA580C),
        ];
        final micIcon = overrideIcon ?? Icons.mic_rounded;
        const glowColor = Color(0xFFEA580C);

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outermost concentric ring
              Transform.scale(
                scale: scale,
                child: Container(
                  width: size * 0.98,
                  height: size * 0.98,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringOuterColor,
                      width: math.max(1.0, size * 0.008),
                    ),
                  ),
                ),
              ),

              // Middle concentric ring
              Transform.scale(
                scale: math.pow(scale, 0.65).toDouble(),
                child: Container(
                  width: size * 0.76,
                  height: size * 0.76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E130B).withValues(alpha: 0.4),
                    border: Border.all(
                      color: ringMidColor,
                      width: math.max(1.0, size * 0.01),
                    ),
                  ),
                ),
              ),

              // Inner glowing concentric ring
              Container(
                width: size * 0.55,
                height: size * 0.55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ringInnerColor,
                    width: math.max(1.2, size * 0.012),
                  ),
                ),
              ),

              // Central Tactile Mic / Stop Button
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: micGradientColors,
                    ),
                    boxShadow: [
                      if (isListening)
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.55),
                          blurRadius: math.max(8.0, size * 0.14),
                          spreadRadius: math.max(1.0, size * 0.02),
                          offset: const Offset(0, 3),
                        ),
                      BoxShadow(
                        color: micGradientColors.first.withValues(alpha: 0.35),
                        blurRadius: math.max(4.0, size * 0.06),
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: Icon(
                    micIcon,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
