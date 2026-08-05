// lib/services/chat/chat_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
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
  // Helper: extrait le meilleur nom disponible depuis un profil
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
  // PRÉSENCE / HEARTBEAT (CORRIGÉ)
  // ============================================================

  /// Démarre le heartbeat (toutes les 45 secondes)
  Future<void> startPresenceHeartbeat() async {
    _presenceHeartbeat?.cancel();
    await updatePresence('online');

    _presenceHeartbeat = Timer.periodic(const Duration(seconds: 45), (_) async {
      await updatePresence('online');
    });
  }

  /// Arrête le heartbeat et passe offline
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

  Future<UserStatus?> getUserPresence(String userId) async {
    try {
      final response = await _supabase
          .from('user_presence')
          .select('*, profiles!user_id(display_name, full_name, avatar_url)')
          .eq('user_id', userId)
          .maybeSingle();
      if (response == null) return null;
      return UserStatus.fromJson(response);
    } catch (e) {
      return null;
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
  // CONVERSATIONS (OPTIMISÉES)
  // ============================================================

  Future<int> getTotalUnreadCount() async {
    try {
      final uid = currentUserId;
      if (uid.isEmpty) return 0;

      final participantResponse = await _supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', uid);
      if (participantResponse.isEmpty) return 0;

      final conversationIds =
          (participantResponse as List).map((e) => e['conversation_id'] as String).toList();

      final unreadResponse = await _supabase
          .from('messages')
          .select('id')
          .inFilter('conversation_id', conversationIds)
          .eq('is_read', false)
          .neq('sender_id', uid);

      return (unreadResponse as List).length;
    } catch (e) {
      debugPrint('❌ getTotalUnreadCount: $e');
      return 0;
    }
  }

  Future<List<ChatConversation>> getConversations({int limit = 20, int offset = 0}) async {
    try {
      final uid = currentUserId;
      if (uid.isEmpty) return [];

      final participantResponse = await _supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', uid);
      if (participantResponse.isEmpty) return [];

      final allConversationIds =
          (participantResponse as List).map((e) => e['conversation_id'] as String).toList();

      final response = await _supabase
          .from('conversations')
          .select('''
            *,
            conversation_participants!inner (
              user_id,
              role,
              profiles!user_id (
                display_name,
                full_name,
                avatar_url
              )
            )
          ''')
          .inFilter('id', allConversationIds)
          .order('updated_at', ascending: false)
          .range(offset, offset + limit - 1);

      final paginatedConversations = response as List;
      if (paginatedConversations.isEmpty) return [];

      final pageConversationIds =
          paginatedConversations.map((c) => c['id'] as String).toList();

      final unreadResponse = await _supabase
          .from('messages')
          .select('conversation_id')
          .inFilter('conversation_id', pageConversationIds)
          .eq('is_read', false)
          .neq('sender_id', uid);

      final unreadCounts = <String, int>{};
      for (var msg in unreadResponse as List) {
        final cid = msg['conversation_id'] as String;
        unreadCounts[cid] = (unreadCounts[cid] ?? 0) + 1;
      }

      final futures = paginatedConversations.map((conv) async {
        final cid = conv['id'] as String;
        final participants = conv['conversation_participants'] as List;
        final participantIds = participants.map((p) => p['user_id'] as String).toList();

        String? otherName, otherAvatar;
        if (!(conv['is_group'] ?? false) && participants.length == 2) {
          final other = participants.firstWhere(
            (p) => p['user_id'] != uid,
            orElse: () => null,
          );
          if (other != null) {
            final profile = other['profiles'] as Map<String, dynamic>?;
            otherName = _resolveDisplayName(profile);
            otherAvatar = profile?['avatar_url'] as String?;
          }
        }

        final lastMsg = await _supabase
            .from('messages')
            .select('*, profiles!sender_id(display_name, full_name, avatar_url)')
            .eq('conversation_id', cid)
            .eq('is_deleted', false)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        ChatMessage? lastMessage;
        if (lastMsg != null) {
          final profile = lastMsg['profiles'] as Map<String, dynamic>?;
          lastMsg['sender_name'] = _resolveDisplayName(profile);
          lastMsg['sender_avatar'] = profile?['avatar_url'];
          lastMessage = ChatMessage.fromJson(lastMsg);
        }

        return ChatConversation(
          id: cid,
          isGroup: conv['is_group'] ?? false,
          groupName: conv['group_name'],
          groupAvatar: conv['group_avatar'],
          participantIds: participantIds,
          otherParticipantName: otherName ?? 'Utilisateur inconnu',
          otherParticipantAvatar: otherAvatar,
          lastMessage: lastMessage,
          unreadCount: unreadCounts[cid] ?? 0,
          updatedAt: DateTime.parse(conv['updated_at']),
          isPinned: conv['is_pinned'] ?? false,
        );
      });

      final conversations = await Future.wait(futures);
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return conversations;
    } catch (e) {
      debugPrint('❌ getConversations: $e');
      return [];
    }
  }

  Future<ChatConversation?> getConversation(String conversationId) async {
    try {
      final uid = currentUserId;
      if (uid.isEmpty) return null;

      final response = await _supabase
          .from('conversations')
          .select('''
            *,
            conversation_participants (
              user_id,
              role,
              profiles!user_id (
                display_name,
                full_name,
                avatar_url
              )
            )
          ''')
          .eq('id', conversationId)
          .maybeSingle();

      if (response == null) return null;

      final participants = response['conversation_participants'] as List? ?? [];
      final participantIds = participants.map((p) => p['user_id'] as String).toList();

      String? otherParticipantName;
      String? otherParticipantAvatar;

      if (!(response['is_group'] ?? false)) {
        if (participants.isNotEmpty) {
          final other = participants.firstWhere(
            (p) => p['user_id'] != uid,
            orElse: () => participants.first,
          );
          if (other != null) {
            final profile = other['profiles'] as Map<String, dynamic>?;
            otherParticipantName = _resolveDisplayName(profile);
            otherParticipantAvatar = profile?['avatar_url'] as String?;
          }
        } else {
          otherParticipantName = 'Client (escalade)';
        }
      }

      return ChatConversation.fromJson({
        ...response,
        'participant_ids': participantIds,
        'other_participant_name': otherParticipantName ?? 'Utilisateur inconnu',
        'other_participant_avatar': otherParticipantAvatar,
      });
    } catch (e) {
      debugPrint('❌ getConversation: $e');
      return null;
    }
  }

  Future<ChatConversation> createConversation({
    required List<String> participantIds,
    bool isGroup = false,
    String? groupName,
    String? groupAvatar,
  }) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw Exception('Not logged in');

    if (!participantIds.contains(uid)) participantIds = [...participantIds, uid];

    if (!isGroup && participantIds.length == 2) {
      final otherId = participantIds.firstWhere((id) => id != uid);
      final existing = await _supabase
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', uid);
      final convIds = (existing as List).map((e) => e['conversation_id'] as String).toList();

      for (var cid in convIds) {
        final other = await _supabase
            .from('conversation_participants')
            .select('user_id')
            .eq('conversation_id', cid)
            .neq('user_id', uid);
        if ((other as List).length == 1 && other[0]['user_id'] == otherId) {
          final convData = await _supabase.from('conversations').select('*').eq('id', cid).single();
          final otherProfile = await _supabase
              .from('profiles')
              .select('display_name, full_name, avatar_url')
              .eq('id', otherId)
              .single();
          return ChatConversation.fromJson({
            ...convData,
            'other_participant_name': _resolveDisplayName(otherProfile),
            'other_participant_avatar': otherProfile['avatar_url'],
          });
        }
      }
    }

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

    if (isGroup) {
      await _supabase.from('group_info').upsert({
        'group_id': conversationId,
        'name': groupName ?? 'Groupe',
        'is_public': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    String? otherName, otherAvatar;
    if (!isGroup && participantIds.length == 2) {
      final otherId = participantIds.firstWhere((id) => id != uid);
      final otherProfile = await _supabase
          .from('profiles')
          .select('display_name, full_name, avatar_url')
          .eq('id', otherId)
          .single();
      otherName = _resolveDisplayName(otherProfile);
      otherAvatar = otherProfile['avatar_url'];
    }

    return ChatConversation.fromJson({
      'id': conversationId,
      'is_group': isGroup,
      'group_name': groupName,
      'group_avatar': groupAvatar,
      'updated_at': DateTime.now().toIso8601String(),
      'is_pinned': false,
      'participant_ids': participantIds,
      'other_participant_name': otherName,
      'other_participant_avatar': otherAvatar,
    });
  }

  Future<void> addParticipant(String conversationId, String userId) async {
    await _supabase.from('conversation_participants').insert({
      'conversation_id': conversationId,
      'user_id': userId,
      'role': 'member',
      'last_read_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeParticipant(String conversationId, String userId) async {
    await _supabase
        .from('conversation_participants')
        .delete()
        .eq('conversation_id', conversationId)
        .eq('user_id', userId);
  }

  Future<void> togglePinned(String conversationId) async {
    final conv = await _supabase.from('conversations').select('is_pinned').eq('id', conversationId).single();
    await _supabase
        .from('conversations')
        .update({'is_pinned': !(conv['is_pinned'] ?? false)})
        .eq('id', conversationId);
  }

  // ============================================================
  // GROUPES
  // ============================================================

  Future<List<GroupMember>> getGroupMembers(String conversationId) async {
    try {
      final uid = currentUserId;
      if (uid.isEmpty) return [];

      final data = await _supabase
          .from('conversation_participants')
          .select('''
            user_id,
            role,
            last_read_at,
            profiles!user_id (
              display_name,
              full_name,
              avatar_url
            )
          ''')
          .eq('conversation_id', conversationId);

      final members = <GroupMember>[];
      for (var p in data as List) {
        final profile = p['profiles'] as Map<String, dynamic>?;
        final userId = p['user_id'] as String;
        final role = p['role'] as String? ?? 'member';

        final presence = await _supabase
            .from('user_presence')
            .select('status, last_seen_at')
            .eq('user_id', userId)
            .maybeSingle();

        bool isOnline = false;
        if (presence != null && presence['status'] == 'online') {
          final lastSeen = DateTime.tryParse(presence['last_seen_at'] ?? '');
          if (lastSeen != null && DateTime.now().difference(lastSeen).inMinutes <= 2) {
            isOnline = true;
          }
        }

        members.add(GroupMember(
          userId: userId,
          displayName: _resolveDisplayName(profile),
          avatarUrl: profile?['avatar_url'],
          role: role,
          isOnline: isOnline,
          joinedAt: DateTime.parse(p['last_read_at'] ?? DateTime.now().toIso8601String()),
        ));
      }
      return members;
    } catch (e) {
      debugPrint('❌ getGroupMembers: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getGroupInfoDetails(String groupId) async {
    try {
      return await _supabase.from('group_info').select('*').eq('group_id', groupId).maybeSingle()
          as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // MESSAGES
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

    await _supabase
        .from('conversations')
        .update({'updated_at': now.toIso8601String()})
        .eq('id', conversationId);

    return ChatMessage.fromJson(response);
  }

  Future<ChatMessage> sendAudioMessage({
    required String conversationId,
    required Uint8List audioData,
    required int duration,
    String? fileName,
    bool isEphemeral = false,
    int? ephemeralDuration,
    String? replyToId,
  }) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw Exception('Not logged in');

    final bucket = 'audio';
    final extension = fileName?.split('.').last ?? 'm4a';
    final uniqueName = '${const Uuid().v4()}.$extension';
    final path = 'messages/$conversationId/$uniqueName';

    try {
      await _supabase.storage.from(bucket).uploadBinary(path, audioData);
    } catch (e) {
      throw Exception('Échec de l\'upload audio');
    }

    final audioUrl = _supabase.storage.from(bucket).getPublicUrl(path);

    return sendMessage(
      conversationId: conversationId,
      content: '🎤 Message audio (${duration}s)',
      mediaUrl: audioUrl,
      mediaType: 'audio',
      replyToId: replyToId,
      isEphemeral: isEphemeral,
      ephemeralDuration: ephemeralDuration,
    );
  }

  Future<void> markAsRead(String conversationId) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', uid)
        .eq('is_read', false);

    await _supabase
        .from('conversation_participants')
        .update({'last_read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('user_id', uid);
  }

  Future<void> deleteMessage(String messageId) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw Exception('Not logged in');

    final msg = await _supabase.from('messages').select('sender_id').eq('id', messageId).single();
    if (msg['sender_id'] != uid) throw Exception('You cannot delete this message');

    await _supabase.from('messages').update({'is_deleted': true}).eq('id', messageId);
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
      await _supabase
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', uid);
    } else {
      await _supabase.from('message_reactions').insert({
        'message_id': messageId,
        'user_id': uid,
        'reaction': reaction,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> updateMessageSentiment(String messageId, SentimentResult sentiment) async {
    try {
      final sentimentValue = sentiment.toString().split('.').last;
      await _supabase.from('messages').update({'sentiment': sentimentValue}).eq('id', messageId);
    } catch (e) {
      throw Exception('Impossible de mettre à jour le sentiment');
    }
  }

  Future<ChatMessage?> getMessageById(String messageId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('*, profiles!sender_id(display_name, full_name, avatar_url)')
          .eq('id', messageId)
          .maybeSingle();
      if (response == null) return null;
      final profile = response['profiles'] as Map<String, dynamic>?;
      response['sender_name'] = _resolveDisplayName(profile);
      response['sender_avatar'] = profile?['avatar_url'];
      return ChatMessage.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> cleanupEphemeralMessages() async {
    try {
      await _supabase
          .from('messages')
          .delete()
          .eq('is_ephemeral', true)
          .lt('delete_at', DateTime.now().toIso8601String());
    } catch (e) {}
  }

  // ============================================================
  // REALTIME / STREAMS
  // ============================================================

  Stream<List<ChatMessage>> subscribeToMessages(String conversationId) {
    final controller = StreamController<List<ChatMessage>>();
    final channel = _supabase.channel('messages:$conversationId');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) async {
            if (payload.eventType == PostgresChangeEvent.insert ||
                payload.eventType == PostgresChangeEvent.update) {
              final msgId = payload.newRecord['id'] as String?;
              if (msgId != null) {
                final singleMessage = await getMessageById(msgId);
                if (singleMessage != null) controller.add([singleMessage]);
              }
            } else if (payload.eventType == PostgresChangeEvent.delete) {
              final oldId = payload.oldRecord['id'] as String?;
              if (oldId != null) {
                final deletedMsg = ChatMessage.fromJson({
                  ...payload.oldRecord,
                  'is_deleted': true,
                });
                controller.add([deletedMsg]);
              }
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };
    return controller.stream;
  }

  Stream<List<UserStatus>> subscribeToPresence(List<String> userIds) {
    final controller = StreamController<List<UserStatus>>();
    final channel = _supabase.channel('presence:all');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_presence',
          callback: (payload) async {
            final statuses = await getUsersPresence(userIds);
            controller.add(statuses);
          },
        )
        .subscribe();

    controller.onCancel = () {
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  // ============================================================
  // UPLOAD DE FICHIERS
  // ============================================================

  Future<String?> uploadFile(String bucket, String path, Uint8List fileData) async {
    try {
      await _supabase.storage.from(bucket).uploadBinary(path, fileData);
      return _supabase.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteFile(String bucket, String path) async {
    try {
      await _supabase.storage.from(bucket).remove([path]);
    } catch (e) {}
  }

  Future<String?> uploadFileWithUniqueName(
    String bucket,
    String folder,
    Uint8List fileData,
    String extension,
  ) async {
    try {
      final fileName = '${const Uuid().v4()}.$extension';
      final path = '$folder/$fileName';
      return await uploadFile(bucket, path, fileData);
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // UTILITAIRES
  // ============================================================

  Future<void> signOut() async {
    await stopPresenceHeartbeat();
    await _supabase.auth.signOut();
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final uid = currentUserId;
      if (uid.isEmpty) return null;
      return await _supabase.from('profiles').select('*').eq('id', uid).maybeSingle()
          as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }
}
