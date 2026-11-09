import '../../features/voice_copilot/domain/voice_conversation_model.dart';
import '../storage/local_store.dart';
import 'voice_chat_repository.dart';

/// Local offline implementation of [VoiceChatRepository] backed by [LocalStore].
///
/// Ensures sequential, safe persistence of voice conversations without external dependencies.
class VoiceChatRepositoryLocal implements VoiceChatRepository {
  /// Creates a local voice chat repository with an optional explicit [LocalStore].
  VoiceChatRepositoryLocal([LocalStore? store]) : _explicitStore = store;

  final LocalStore? _explicitStore;
  LocalStore get _store => _explicitStore ?? LocalStore.instance;

  @override
  Future<List<VoiceConversation>> loadConversations() async {
    final json = await _store.readJson(LocalStore.keyVoiceConversations);
    if (json == null || json is! List) {
      return [];
    }

    final conversations = <VoiceConversation>[];
    for (final item in json) {
      if (item is Map) {
        final map =
            item is Map<String, dynamic> ? item : item.cast<String, dynamic>();
        conversations.add(VoiceConversation.fromJson(map));
      }
    }

    // Sort descending by updatedAt so newest conversations appear first
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  @override
  Future<void> saveConversations(List<VoiceConversation> conversations) async {
    final list = conversations.map((c) => c.toJson()).toList();
    await _store.writeJson(LocalStore.keyVoiceConversations, list);
  }

  @override
  Future<void> saveConversation(VoiceConversation conversation) async {
    final current = await loadConversations();
    final index = current.indexWhere((c) => c.id == conversation.id);

    if (index != -1) {
      // Update existing thread in place
      current[index] = conversation;
    } else {
      // Insert new thread at the head of the list
      current.insert(0, conversation);
    }

    // Re-sort to maintain newest-first order
    current.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await saveConversations(current);
  }

  @override
  Future<void> deleteConversation(String id) async {
    final current = await loadConversations();
    current.removeWhere((c) => c.id == id);
    await saveConversations(current);
  }

  @override
  Future<void> clear() async {
    await _store.writeJson(LocalStore.keyVoiceConversations, <dynamic>[]);
  }

  @override
  Future<void> flush() async {
    await _store.flush();
  }
}

