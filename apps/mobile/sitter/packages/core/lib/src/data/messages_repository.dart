import 'package:supabase_flutter/supabase_flutter.dart';

/// Realtime chat (BACKEND.md §13). Tables added to supabase_realtime
/// publication in migration 20260209100018.
class MessagesRepository {
  MessagesRepository(this._client);
  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> stream(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId);
  }

  Future<String?> findOrCreateConversation({
    required String familyId,
    required String sitterId,
    String? jobId,
  }) async {
    // 1. Check if a conversation for this pair (and optionally job) exists
    var query = _client
        .from('conversations')
        .select('id')
        .eq('family_id', familyId)
        .eq('sitter_id', sitterId);

    if (jobId != null) {
      query = query.eq('job_id', jobId);
    } else {
      query = query.isFilter('job_id', null);
    }

    final existing = await query.maybeSingle();

    if (existing != null) {
      return (existing as Map)['id']?.toString();
    }

    // 2. Create new
    final res = await _client
        .from('conversations')
        .insert({
          'family_id': familyId,
          'sitter_id': sitterId,
          if (jobId != null) 'job_id': jobId,
        })
        .select('id')
        .single();

    return (res as Map)['id']?.toString();
  }

  Future<void> send({
    required String conversationId,
    required String body,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Sign in required to send a message');
    }
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': uid,
      'body': body,
    });
  }

  Future<void> markRead(String messageId) async {
    await _client
        .from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', messageId);
  }

  Future<void> markConversationRead(String conversationId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    await _client
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_id', uid)
        .isFilter('read_at', null);
  }
}
