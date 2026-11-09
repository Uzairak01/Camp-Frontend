import 'package:flutter/foundation.dart';

/// Represents an individual chat message in a Voice Copilot dialogue.
///
/// Encapsulates message payload, speaker identity, and creation timestamp.
@immutable
class VoiceChatMessage {
  /// Creates a new immutable voice chat message record.
  const VoiceChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  /// Creates a [VoiceChatMessage] instance from a JSON map with tolerant defaults.
  ///
  /// Defensively handles missing, null, or malformed fields without throwing exceptions.
  factory VoiceChatMessage.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return VoiceChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        text: '',
        isUser: true,
        timestamp: DateTime.now().toUtc(),
      );
    }

    final rawId = json['id']?.toString().trim();
    final effectiveId = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : 'msg_${DateTime.now().millisecondsSinceEpoch}';

    final text = json['text']?.toString() ?? '';
    final isUser = json['isUser'] == true;

    DateTime timestamp;
    try {
      final rawTs = json['timestamp']?.toString();
      timestamp = (rawTs != null && rawTs.isNotEmpty)
          ? (DateTime.tryParse(rawTs)?.toUtc() ?? DateTime.now().toUtc())
          : DateTime.now().toUtc();
    } catch (_) {
      timestamp = DateTime.now().toUtc();
    }

    return VoiceChatMessage(
      id: effectiveId,
      text: text,
      isUser: isUser,
      timestamp: timestamp,
    );
  }

  /// Unique identifier of the message.
  final String id;

  /// Content text of the user or assistant message.
  final String text;

  /// Whether the message originated from the rider (`true`) or assistant (`false`).
  final bool isUser;

  /// Timestamp when the message was recorded (in UTC).
  final DateTime timestamp;

  /// Serializes the message to a persistent JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Represents a persistent Voice Copilot conversation history thread.
///
/// Stores title, creation/update timestamps, and the sequence of exchanged messages.
@immutable
class VoiceConversation {
  /// Creates an immutable voice conversation thread.
  const VoiceConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  /// Creates a [VoiceConversation] from a JSON map using tolerant parsing.
  ///
  /// Guarantees that valid non-null domain objects are returned even with
  /// missing keys, corrupt dates, or malformed message arrays.
  factory VoiceConversation.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      final now = DateTime.now().toUtc();
      return VoiceConversation(
        id: 'conv_${now.millisecondsSinceEpoch}',
        title: 'Untitled Chat',
        createdAt: now,
        updatedAt: now,
        messages: const [],
      );
    }

    // Tolerant ID extraction with fallback timestamp identifier
    final rawId = json['id']?.toString().trim();
    final effectiveId = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : 'conv_${DateTime.now().millisecondsSinceEpoch}';

    // Tolerant title extraction defaulting to a generic placeholder
    final rawTitle = json['title']?.toString().trim();
    final effectiveTitle = (rawTitle != null && rawTitle.isNotEmpty)
        ? rawTitle
        : 'Untitled Chat';

    // Tolerant UTC timestamp parser with fallback safety
    DateTime parseUtc(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      try {
        final parsed = DateTime.tryParse(val.toString());
        return parsed?.toUtc() ?? fallback;
      } catch (_) {
        return fallback;
      }
    }

    final now = DateTime.now().toUtc();
    final effectiveCreatedAt = parseUtc(json['createdAt'], now);
    final effectiveUpdatedAt = parseUtc(json['updatedAt'], effectiveCreatedAt);

    // Tolerant messages parsing ignoring malformed individual entries
    final rawMessages = json['messages'];
    final parsedMessages = <VoiceChatMessage>[];
    if (rawMessages is List) {
      for (final item in rawMessages) {
        if (item is Map) {
          final map =
              item is Map<String, dynamic> ? item : item.cast<String, dynamic>();
          parsedMessages.add(VoiceChatMessage.fromJson(map));
        }
      }
    }

    return VoiceConversation(
      id: effectiveId,
      title: effectiveTitle,
      createdAt: effectiveCreatedAt,
      updatedAt: effectiveUpdatedAt,
      messages: List.unmodifiable(parsedMessages),
    );
  }

  /// Unique conversation identifier.
  final String id;

  /// Human-readable title of the conversation (derived from the first user query).
  final String title;

  /// UTC timestamp when the conversation was initiated.
  final DateTime createdAt;

  /// UTC timestamp of the most recent interaction in this thread.
  final DateTime updatedAt;

  /// Sequential messages exchanged in this conversation.
  final List<VoiceChatMessage> messages;

  /// Returns a copy of this conversation with optionally updated fields.
  VoiceConversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<VoiceChatMessage>? messages,
  }) {
    return VoiceConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  /// Serializes the conversation thread to a persistent JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}
