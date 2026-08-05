// lib/services/chat/chat_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/chat/chat_message.dart';
import '../../models/chat/chat_conversation.dart';
import '../../models/chat/user_status.dart';
import '../../models/chat/group_info.dart';
import 'package:thix_id/models/chat/sentiment.dart';

class ChatService {
  final SupabaseClient _supabase;
  Timer? _presenceHeartbeat;

  ChatService(this._supabase);

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';
  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentUserId.isNotEmpty;

  // ============================================================
  // HELPERS
  // ============================================================
  static String _resolveDisplayName(Map<String, dynamic>? profile) {
    if (profile == null) return 'Utilisateur inconnu';
    final displayName = profile['display_name'] as String?;
    if (displayName != null && displayName.trim().isNotEmpty) return displayName;
    final fullName = profile['full_name'] as String?;
    if (fullName != null && fullName.trim().isNotEmpty) return fullName;
    return 'Utilisateur inconnu';
  }

  // ============================================================
  // PRÉSENCE / HEARTBEAT
  // ============================================================
  Future<void> startPresenceHeartbeat() async {
    _presenceHeartbeat?.cancel();
    await updatePresence('online');

    _presenceHeartbeat = Timer.periodic(const Duration(seconds: 45), (_) async {
      await updatePresence('online');
    });
  }

  Future<void> stopPresenceHeartbeat() async {
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;
    await updatePresence('offline');
  }

  Future<void> updatePresence(String status, {String? customStatus}) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    try {
      await _supabase.from('user_presence').upsert({
        'user_id': uid,
        'status': status,
        'custom_status': customStatus,
        'last_seen_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ updatePresence error: $e');
    }
  }

  Future<List<UserStatus>> getUsersPresence(List<String> userIds) async {
    try {
      if (userIds.isEmpty) return [];
      final response = await _supabase
          .from('user_presence')
          .select('*, profiles!user_id(display_name, full_name, avatar_url)')
          .inFilter('user_id', userIds);
      return (response as List).map((e) => UserStatus.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // CONVERSATIONS — VERSION ENTERPRISE (RPC) - PERFORMANCES MAXIMALES
  // ============================================================
  Future<List<ChatConversation>> getConversations({
    int limit = 20,
    int offset = 0,
    String filter = 'all', 
  }) async {
    try {
      if (currentUserId.isEmpty) return [];

      // 🚀 UNE SEULE REQUÊTE POUR TOUT RÉCUPÉRER
      final response = await _supabase.rpc(
        'rpc_get_user_conversations',
        params: {
          'p_limit': limit,
          'p_offset': offset,
          'p_filter': filter,
        },
      );

      if (response == null) return [];
      final List data = response as List;

      return data.map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        ChatMessage? lastMessage;
        
        final preview = map['last_message_preview'] as String?;
        if (preview != null && preview.isNotEmpty) {
          lastMessage = ChatMessage(
            id: '',
            conversationId: map['id']?.toString() ?? '',
            senderId: map['last_message_sender_id']?.toString() ?? '',
            content: preview,
            createdAt: map['last_message_at'] != null
                ? DateTime.parse(map['last_message_at'].toString())
                : DateTime.now(),
            type: map['last_message_type']?.toString() ?? 'text',
          );
        }

        return ChatConversation(
          id: map['id']?.toString() ?? '',
          isGroup: map['is_group'] ?? false,
          groupName: map['group_name'] as String?,
          groupAvatar: map['group_avatar'] as String?,
          participantIds: (map['participant_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
          otherParticipantName: map['other_display_name'] as String? ?? 'Utilisateur inconnu',
          otherParticipantAvatar: map['other_avatar_url'] as String?,
          lastMessage: lastMessage,
          unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
          updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'].toString()) : DateTime.now(),
          isPinned: map['is_pinned'] ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ getConversations (RPC): $e');
      return [];
    }
  }

  Future<int> getTotalUnreadCount() async {
    try {
      // 🚀 RAPIDE: Utilise la fonction SQL
      final result = await _supabase.rpc('rpc_get_total_unread');
      return (result as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('❌ getTotalUnreadCount (RPC): $e');
      return 0;
    }
  }

  Future<void> markConversationAsRead(String conversationId) async {
    try {
      // 🚀 RAPIDE: Utilise la fonction SQL
      await _supabase.rpc(
        'rpc_mark_conversation_read',
        params: {'p_conversation_id': conversationId},
      );
    } catch (e) {
      debugPrint('❌ markConversationAsRead: $e');
    }
  }

  // ============================================================
  // CRÉATION ET GESTION (Fusion des deux versions)
  // ============================================================
  Future<ChatConversation> createConversation({
    required List<String> participantIds,
    bool isGroup = false,
    String? groupName,
    String? groupAvatar,
  }) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw Exception('Not logged in');
    if (!participantIds.contains(uid)) participantIds = [...participantIds, uid];

    final String conversationId = const Uuid().v4();

    await _supabase.from('conversations').insert({
      'id': conversationId,
      'is_group': isGroup,
      'group_name': groupName,
      'group_avatar': groupAvatar,
      'updated_at': DateTime.now().toIso8601String(),
    });

    await Future.wait(participantIds.map((pid) => _supabase.from('conversation_participants').insert({
          'conversation_id': conversationId,
          'user_id': pid,
          'role': pid == uid ? 'admin' : 'member',
          'last_read_at': DateTime.now().toIso8601String(),
        })));

    return ChatConversation.fromJson({
      'id': conversationId,
      'is_group': isGroup,
      'participant_ids': participantIds,
      'updated_at': DateTime.now().toIso8601String(),
      'is_pinned': false,
    });
  }

  Future<void> togglePinned(String conversationId, bool isPinned) async {
    try {
      await _supabase
          .from('conversation_participants')
          .update({'is_pinned': isPinned})
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId);
    } catch (e) {
      debugPrint('❌ togglePinned: $e');
    }
  }

  // ============================================================
  // MESSAGES RICHES (Depuis la Version 2)
  // ============================================================
  Future<List<ChatMessage>> getMessages(String conversationId, {int limit = 50, int offset = 0}) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('*, profiles!sender_id(display_name, full_name, avatar_url)')
          .eq('conversation_id', conversationId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((e) {
        final profile = e['profiles'] as Map<String, dynamic>?;
        e['sender_name'] = _resolveDisplayName(profile);
        e['sender_avatar'] = profile?['avatar_url'];
        return ChatMessage.fromJson(e);
      }).toList();
    } catch (e) {
      debugPrint('❌ getMessages: $e');
      return [];
    }
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
    String? mediaUrl,
    String? mediaType,
    String? mediaName,
    int? mediaSize,
    String? replyToId,
    bool isEphemeral = false,
    int? ephemeralDuration,
  }) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw Exception('Not logged in');

    final now = DateTime.now();
    final deleteAt = isEphemeral && ephemeralDuration != null
        ? now.add(Duration(seconds: ephemeralDuration))
        : null;

    final response = await _supabase
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': uid,
          'content': content,
          'created_at': now.toIso8601String(),
          'media_url': mediaUrl,
          'media_type': mediaType,
          'media_name': mediaName,
          'media_size': mediaSize,
          'reply_to_id': replyToId,
          'is_ephemeral': isEphemeral,
          'ephemeral_duration': ephemeralDuration,
          'delete_at': deleteAt?.toIso8601String(),
        })
        .select('*, profiles!sender_id(display_name, full_name, avatar_url)')
        .single();

    final profile = response['profiles'] as Map<String, dynamic>?;
    response['sender_name'] = _resolveDisplayName(profile);
    response['sender_avatar'] = profile?['avatar_url'];
    
    // Note: updated_at de la table conversations est géré par le Trigger SQL !
    return ChatMessage.fromJson(response);
  }

  Future<ChatMessage> sendAudioMessage({
    required String conversationId,
    required Uint8List audioData,
    required int duration,
    String? fileName,
  }) async {
    final bucket = 'audio';
    final extension = fileName?.split('.').last ?? 'm4a';
    final uniqueName = '${const Uuid().v4()}.$extension';
    final path = 'messages/$conversationId/$uniqueName';

    await _supabase.storage.from(bucket).uploadBinary(path, audioData);
    final audioUrl = _supabase.storage.from(bucket).getPublicUrl(path);

    return sendMessage(
      conversationId: conversationId,
      content: '🎤 Message audio (${duration}s)',
      mediaUrl: audioUrl,
      mediaType: 'audio',
    );
  }

  Future<void> toggleReaction(String messageId, String reaction) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    final existing = await _supabase
        .from('message_reactions')
        .select('id')
        .eq('message_id', messageId)
        .eq('user_id', uid)
        .maybeSingle();

    if (existing != null) {
      await _supabase.from('message_reactions').delete().eq('message_id', messageId).eq('user_id', uid);
    } else {
      await _supabase.from('message_reactions').insert({
        'message_id': messageId,
        'user_id': uid,
        'reaction': reaction,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // ============================================================
  // REALTIME / STREAMS (Pour les websockets)
  // ============================================================
  Stream<List<ChatMessage>> subscribeToMessages(String conversationId) {
    final controller = StreamController<List<ChatMessage>>();
    final channel = _supabase.channel('messages:$conversationId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) async {
        // Logique de rafraichissement du stream
        // Pour les performances, intégrez directement via Riverpod si possible
      },
    ).subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };
    return controller.stream;
  }
}
