import '../../features/voice_copilot/domain/voice_conversation_model.dart';

/// Abstract persistence contract for Voice Copilot conversation history.
///
/// Encapsulates storage, retrieval, and lifecycle management for voice dialogues.
abstract class VoiceChatRepository {
  /// Loads all stored voice conversation threads, ordered chronologically.
  Future<List<VoiceConversation>> loadConversations();

  /// Persists a complete list of voice conversations to disk.
  Future<void> saveConversations(List<VoiceConversation> conversations);

  /// Saves or updates an individual conversation thread.
  Future<void> saveConversation(VoiceConversation conversation);

  /// Deletes a conversation by its unique identifier.
  Future<void> deleteConversation(String id);

  /// Clears all conversation history from storage.
  Future<void> clear();

  /// Awaits completion of all pending storage write operations.
  Future<void> flush();
}

