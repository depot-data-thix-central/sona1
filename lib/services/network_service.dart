import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/network_post.dart';
import '../models/network_connection.dart';
import '../models/network_community.dart';
import '../models/network_message.dart';
import '../models/network_notification.dart';
import '../models/network_story.dart';
import '../models/comment.dart';

class NetworkService extends ChangeNotifier {
  final SupabaseClient _supabase;
  NetworkService(this._supabase);

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';
  String? get _uid => _supabase.auth.currentUser?.id;

  // ── FEED FIX & SMART MIX ──
  Future<List<NetworkPost>> getFeedPosts({int limit = 20, int offset = 0, String feedType = 'recent'}) async {
    final uid = currentUserId;
    if (uid.isEmpty) return [];

    final hiddenRes = await _supabase.from('hidden_posts').select('post_id').eq('user_id', uid);
    final hiddenSet = (hiddenRes as List).map((e) => e['post_id'] as String).toSet();

    if (feedType == 'all' || feedType == 'recent' || feedType == 'Pour vous' || feedType == 'smart' || feedType == 'Pourvous') {
      final res = await _supabase.from('posts_view').select().eq('is_public', true).order('created_at', ascending: false).range(offset, offset + limit - 1);
      return (res as List).map((e) => NetworkPost.fromJson(e)).where((p) => !hiddenSet.contains(p.id)).toList();
    }

    if (feedType == 'network' || feedType == 'Réseau') {
      final connIds = await _getConnectionIds();
      connIds.add(uid);
      final res = await _supabase.from('posts_view').select().inFilter('user_id', connIds.toList()).order('created_at', ascending: false).range(offset, offset + limit - 1);
      return (res as List).map((e) => NetworkPost.fromJson(e)).where((p) => !hiddenSet.contains(p.id)).toList();
    }

    final res = await _supabase.from('posts_view').select().eq('is_public', true).order('likes_count', ascending: false).range(offset, offset + limit - 1);
    return (res as List).map((e) => NetworkPost.fromJson(e)).where((p) => !hiddenSet.contains(p.id)).toList();
  }

  Future<List<NetworkPost>> getPosts({String? feedType}) => getFeedPosts(feedType: feedType ?? 'recent');
  
  Future<Set<String>> _getConnectionIds() async {
    final uid = currentUserId;
    if (uid.isEmpty) return {};

    final res = await _supabase.from('connections')
        .select('user1_id, user2_id')
        .or('user1_id.eq.$uid,user2_id.eq.$uid');
        
    return (res as List).map((e) {
      final user1 = e['user1_id'] as String;
      final user2 = e['user2_id'] as String;
      return user1 == uid ? user2 : user1;
    }).toSet();
  }

  Future<NetworkPost?> getPostById(String postId) async {
    try {
      final res = await _supabase.from('posts_view').select().eq('id', postId).maybeSingle();
      if (res == null) return null;
      return NetworkPost.fromJson(res);
    } catch (e) {
      debugPrint('getPostById: $e');
      return null;
    }
  }

  Future<NetworkCommunity> createCommunity({required String name, String? description, String? bannerUrl, String? logoUrl}) async {
    final res = await _supabase.from('communities').insert({
      'name': name.trim(),
      'description': description?.trim(),
      'logo_url': logoUrl ?? bannerUrl,
      'banner_url': bannerUrl,
      'created_by': currentUserId,
      'created_at': DateTime.now().toIso8601String(),
      'members_count': 1,
      'posts_count': 0,
    }).select().single();
    await _supabase.from('community_members').upsert({
      'community_id': res['id'],
      'user_id': currentUserId,
      'role': 'admin',
      'joined_at': DateTime.now().toIso8601String(),
    }, onConflict: 'community_id,user_id');
    notifyListeners();
    return NetworkCommunity.fromJson(res);
  }

  Future<String> createPost(String content, List<String> images) async {
    final res = await _supabase.from('posts').insert({
      'user_id': currentUserId,
      'content': content.trim(),
      'image_urls': images,
      'media_urls': images,
      'media_url': images.isNotEmpty ? images.first : null,
      'is_public': true,
    }).select('id').single();
    notifyListeners();
    return res['id'] as String;
  }

  Future<String> createCommunityPost({required String communityId, required String content, List<String> images = const []}) async {
    final res = await _supabase.from('posts').insert({
      'user_id': currentUserId,
      'community_id': communityId,
      'content': content.trim(),
      'image_urls': images,
      'media_urls': images,
      'media_url': images.isNotEmpty ? images.first : null,
      'is_public': true,
    }).select('id').single();
    notifyListeners();
    return res['id'] as String;
  }

  Future<void> updatePost(String id, String c) async {
    await _supabase.from('posts').update({'content': c.trim(), 'updated_at': DateTime.now().toIso8601String()}).eq('id', id);
    notifyListeners();
  }
  Future<void> deletePost(String id) async { await _supabase.from('posts').delete().eq('id', id); notifyListeners(); }
  Future<void> hidePost(String id) async { await _supabase.from('hidden_posts').upsert({'post_id': id, 'user_id': currentUserId, 'hidden_at': DateTime.now().toIso8601String()}, onConflict: 'post_id,user_id'); notifyListeners(); }
  Future<void> reportPost(String postId, String reason) async { await _supabase.from('reported_posts').insert({'post_id': postId, 'user_id': currentUserId, 'reason': reason, 'reported_at': DateTime.now().toIso8601String()}); }
  Future<void> pinPost(String postId) async { await _supabase.from('posts').update({'is_pinned': false}).eq('user_id', currentUserId).eq('is_pinned', true); await _supabase.from('posts').update({'is_pinned': true}).eq('id', postId); notifyListeners(); }
  Future<void> unpinPost(String postId) async { await _supabase.from('posts').update({'is_pinned': false}).eq('id', postId); notifyListeners(); }
  Future<NetworkPost?> getPinnedPost(String userId) async { final res = await _supabase.from('posts_view').select().eq('user_id', userId).eq('is_pinned', true).maybeSingle(); return res == null ? null : NetworkPost.fromJson(res); }
  Future<List<NetworkPost>> getPinnedPosts(String userId) async { final res = await _supabase.from('posts_view').select().eq('user_id', userId).eq('is_pinned', true).order('created_at', ascending: false); return (res as List).map((e) => NetworkPost.fromJson(e)).toList(); }
  
  Future<void> likePost(String id) async { 
    if (currentUserId.isEmpty) return;
    try {
      await _supabase.from('post_likes').upsert(
        {'post_id': id, 'user_id': currentUserId},
        onConflict: 'post_id,user_id', 
        ignoreDuplicates: true
      ); 
      
      final owner = await _getPostOwnerId(id); 
      if (owner.isNotEmpty && owner != currentUserId) {
        unawaited(_createNotification(userId: owner, type: 'like', postId: id)); 
      }
    } catch (e) {
      debugPrint('🔥 likePost erreur : $e');
    }
    notifyListeners(); 
  }

  Future<void> unlikePost(String id) async { 
    if (currentUserId.isEmpty) return;
    try {
      await _supabase.from('post_likes')
          .delete()
          .eq('post_id', id)
          .eq('user_id', currentUserId); 
    } catch (e) {
      debugPrint('🔥 unlikePost erreur : $e');
    }
    notifyListeners(); 
  }

  Future<void> sharePost(String id) async { await _supabase.rpc('increment_share', params: {'p_post_id': id}); }
  Future<void> savePost(String postId) async { await _supabase.from('saved_posts').upsert({'post_id': postId, 'user_id': currentUserId, 'saved_at': DateTime.now().toIso8601String()}, onConflict: 'post_id,user_id'); notifyListeners(); }
  Future<void> unsavePost(String postId) async { await _supabase.from('saved_posts').delete().eq('post_id', postId).eq('user_id', currentUserId); notifyListeners(); }
  Future<List<NetworkPost>> getSavedPosts() async { final res = await _supabase.from('saved_posts').select('post:post_id(*, profiles:user_id(display_name, avatar_url, profession))').eq('user_id', currentUserId).order('saved_at', ascending: false); return (res as List).map((e) => NetworkPost.fromJson(e['post'] as Map<String, dynamic>)).toList(); }
  Future<void> repost(String originalPostId, String? quote) async { await _supabase.from('reposts').insert({'original_post_id': originalPostId, 'user_id': currentUserId, 'quote': quote}); notifyListeners(); }
  Future<List<NetworkPost>> getUserReposts(String userId) async { final res = await _supabase.from('reposts').select('post:original_post_id(*)').eq('user_id', userId).order('created_at', ascending: false); return (res as List).map((e) => NetworkPost.fromJson(e['post'] as Map<String, dynamic>)).toList(); }
  Future<List<Comment>> getCommentsWithReplies(String postId) async { try { final res = await _supabase.from('comments').select('*, profiles!user_id(display_name, avatar_url)').eq('post_id', postId).order('created_at', ascending: true); final Map<String, Comment> map = { for (var j in res as List) j['id']: Comment.fromJson(j) }; final List<Comment> roots = []; for (var c in map.values) { if (c.parentId == null || c.parentId!.isEmpty || !map.containsKey(c.parentId)) { roots.add(c); } else { final parent = map[c.parentId]; if (parent != null) parent.replies.add(c); } } return roots; } catch (e) { debugPrint('getCommentsWithReplies: $e'); return []; } }
  Future<Comment> addComment(String postId, String content, {String? parentId}) async { final res = await _supabase.from('comments').insert({ 'post_id': postId, 'user_id': currentUserId, 'content': content.trim(), 'parent_id': parentId, }).select('*, profiles!user_id(display_name, avatar_url)').single(); final owner = await _getPostOwnerId(postId); if (parentId == null && owner != currentUserId) unawaited(_createNotification(userId: owner, type: 'comment', postId: postId)); notifyListeners(); return Comment.fromJson(res); }
  Future<bool> addCommentToPost(String postId, String comment) async { try { await addComment(postId, comment); return true; } catch (_) { return false; } }
  Future<List<Map<String, dynamic>>> getComments(String postId) async { final res = await _supabase.from('comments').select('*, profiles!user_id(display_name, avatar_url)').eq('post_id', postId).order('created_at', ascending: true); return (res as List).map((e) => {'id': e['id'], 'user_id': e['user_id'], 'user_name': e['profiles']?['display_name'], 'user_avatar': e['profiles']?['avatar_url'], 'content': e['content'], 'created_at': e['created_at']}).toList(); }
  Future<bool> updateComment(String commentId, String newContent) async { try { await _supabase.from('comments').update({'content': newContent.trim(), 'is_edited': true}).eq('id', commentId); notifyListeners(); return true; } catch (_) { return false; } }
  Future<bool> deleteComment(String commentId) async { try { await _supabase.from('comments').delete().eq('id', commentId); notifyListeners(); return true; } catch (_) { return false; } }
  
  Future<bool> likeComment(String commentId) async { if (_uid == null) return false; try { await _supabase.from('comment_likes').upsert({'comment_id': commentId, 'user_id': _uid}, onConflict: 'comment_id,user_id', ignoreDuplicates: true); notifyListeners(); return true; } catch (_) { return false; } }
  Future<bool> unlikeComment(String commentId) async { try { await _supabase.from('comment_likes').delete().eq('comment_id', commentId).eq('user_id', _uid!); notifyListeners(); return true; } catch (_) { return false; } }

  Future<String> createPollPost({required String content, required List<String> options, List<String> images = const []}) async { final formattedOptions = options.map((opt) => {'text': opt, 'votes': <String>[]}).toList(); final res = await _supabase.from('posts').insert({ 'user_id': currentUserId, 'content': content.trim(), 'media_urls': images, 'image_urls': images, 'post_type': 'poll', 'poll_data': {'options': formattedOptions}, 'is_public': true, }).select('id').single(); notifyListeners(); return res['id'] as String; }
  Future<String> createChallengePost({required String title, required String description, required DateTime endDate, List<String> images = const []}) async { final res = await _supabase.from('posts').insert({ 'user_id': currentUserId, 'content': title.trim(), 'media_urls': images, 'image_urls': images, 'post_type': 'challenge', 'challenge_data': { 'description': description, 'end_date': endDate.toIso8601String(), 'participants_count': 0, }, 'is_public': true, }).select('id').single(); notifyListeners(); return res['id'] as String; }
  Future<void> votePoll(String postId, int optionIndex) async { final postRes = await _supabase.from('posts').select('poll_data').eq('id', postId).single(); final pollData = postRes['poll_data'] as Map<String, dynamic>?; if (pollData == null) return; final options = List<Map<String, dynamic>>.from(pollData['options'] ?? []); for (var opt in options) { final votes = List<String>.from(opt['votes'] ?? []); votes.remove(currentUserId); opt['votes'] = votes; } if (optionIndex >= 0 && optionIndex < options.length) { final targetVotes = List<String>.from(options[optionIndex]['votes'] ?? []); if (!targetVotes.contains(currentUserId)) { targetVotes.add(currentUserId); } options[optionIndex]['votes'] = targetVotes; } await _supabase.from('posts').update({ 'poll_data': {'options': options} }).eq('id', postId); notifyListeners(); }
  Future<List<NetworkStory>> getActiveStories() async { try { final res = await _supabase.from('active_stories').select('*').order('created_at', ascending: false).limit(30); return (res as List).map((e) => NetworkStory.fromJson(e)).toList(); } catch (e) { debugPrint('getActiveStories: $e'); return []; } }
  Future<void> createStory(String? mediaUrl, {String? text, String mediaType = 'image', int duration = 24}) async { await _supabase.from('stories').insert({ 'user_id': currentUserId, 'media_url': mediaUrl, 'text_content': text, 'media_type': mediaType, 'is_active': true, 'expires_at': DateTime.now().add(Duration(hours: duration.clamp(6, 48))).toIso8601String() }); notifyListeners(); }
  Future<void> deleteStory(String storyId) async { await _supabase.from('stories').delete().eq('id', storyId).eq('user_id', currentUserId); notifyListeners(); }
  Future<void> markStoryAsViewed(String storyId) async { await _supabase.from('story_views').upsert({'story_id': storyId, 'user_id': currentUserId}, onConflict: 'story_id,user_id', ignoreDuplicates: true); }
  Future<List<Highlight>> getUserHighlights(String userId) async { final res = await _supabase.from('story_highlights').select().eq('user_id', userId).order('created_at', ascending: false); return (res as List).map((e) => Highlight(id: e['id'], name: e['name'], coverImage: e['cover_image'], storyIds: List<String>.from(e['story_ids'] ?? []), createdAt: DateTime.parse(e['created_at']))).toList(); }
  Future<void> createHighlight(String name, List<String> storyIds, String? coverImage) async { await _supabase.from('story_highlights').insert({'user_id': currentUserId, 'name': name, 'cover_image': coverImage, 'story_ids': storyIds}); }
 
  Future<List<NetworkConnection>> getSuggestedConnections({int limit = 10}) async { try { final res = await _supabase.rpc('get_suggested_connections', params: {'p_user_id': currentUserId, 'p_limit': limit}); return (res as List).map((e) => NetworkConnection(id: e['id'], name: e['display_name'] ?? 'Utilisateur', avatar: e['avatar_url'], title: e['profession'] ?? 'Membre', mutualConnections: (e['mutual_count'] as num?)?.toInt() ?? 0)).toList(); } catch (e) { debugPrint('getSuggestedConnections: $e'); return []; } }
  Future<void> sendConnectionRequest(String targetId) async { await _supabase.from('connection_requests').upsert({'sender_id': currentUserId, 'receiver_id': targetId, 'status': 'pending'}, onConflict: 'sender_id,receiver_id'); if (targetId != currentUserId) unawaited(_createNotification(userId: targetId, type: 'connection')); }
  Future<void> acceptConnectionRequest(String requestId) async { await _supabase.from('connection_requests').update({'status': 'accepted'}).eq('id', requestId); final req = await _supabase.from('connection_requests').select('sender_id, receiver_id').eq('id', requestId).single(); await _supabase.from('connections').insert({'user1_id': req['sender_id'], 'user2_id': req['receiver_id']}); }

  Future<List<NetworkCommunity>> getAllCommunities({int limit = 50}) async { try { final res = await _supabase.from('communities_with_membership').select().eq('current_user_id', currentUserId).order('members_count', ascending: false).limit(limit); return (res as List).map((e) => NetworkCommunity.fromJson(e)).toList(); } catch (_) { final res = await _supabase.from('communities').select().order('members_count', ascending: false).limit(limit); return (res as List).map((e) => NetworkCommunity.fromJson(e)).toList(); } }
  Future<List<NetworkCommunity>> getSuggestedCommunities({int limit = 10}) async { final res = await _supabase.from('communities').select().order('members_count', ascending: false).limit(limit); return (res as List).map((e) => NetworkCommunity.fromJson(e)).toList(); }
  Future<List<NetworkCommunity>> getMyCommunities() async { final res = await _supabase.from('community_members').select('communities(*)').eq('user_id', currentUserId); return (res as List).map((e) => NetworkCommunity.fromJson({...e['communities'], 'is_member': true})).toList(); }
  Future<NetworkCommunity?> getCommunityById(String id) async { final res = await _supabase.from('communities').select().eq('id', id).maybeSingle(); return res == null ? null : NetworkCommunity.fromJson(res); }
  Future<void> joinCommunity(String id) async { await _supabase.from('community_members').upsert({'community_id': id, 'user_id': currentUserId, 'role': 'member'}, onConflict: 'community_id,user_id', ignoreDuplicates: true); }
  Future<void> leaveCommunity(String id) async { await _supabase.from('community_members').delete().eq('community_id', id).eq('user_id', currentUserId); }
  Future<List<Map<String, dynamic>>> searchUsers(String q) async { if (q.trim().isEmpty) return []; final r = await _supabase.from('profiles').select('id, display_name, avatar_url, profession').ilike('display_name', '%$q%').limit(20); return List<Map<String, dynamic>>.from(r as List); }
  Future<List<Map<String, dynamic>>> searchPosts(String q) async { final r = await _supabase.from('posts_view').select('id, content, created_at, author_name, author_avatar').ilike('content', '%$q%').limit(20); return List<Map<String, dynamic>>.from(r as List); }
  Future<List<NetworkCommunity>> searchCommunities(String q) async { final r = await _supabase.from('communities').select().ilike('name', '%$q%').limit(20); return (r as List).map((e) => NetworkCommunity.fromJson(e)).toList(); }
  Future<List<Conversation>> getConversations() async { try { final uid = currentUserId; final res = await _supabase.from('messages').select('sender_id, receiver_id, content, created_at, is_read, sender:profiles!messages_sender_id_fkey(display_name, avatar_url), receiver:profiles!messages_receiver_id_fkey(display_name, avatar_url)').or('sender_id.eq.$uid,receiver_id.eq.$uid').order('created_at', ascending: false).limit(100); final Map<String, Conversation> map = {}; for (var m in res as List) { final otherId = m['sender_id'] == uid ? m['receiver_id'] : m['sender_id']; if (!map.containsKey(otherId)) { final other = m['sender_id'] == uid ? m['receiver'] : m['sender']; map[otherId] = Conversation(id: otherId, otherUserId: otherId, otherUserName: other?['display_name'] ?? 'Utilisateur', otherUserAvatar: other?['avatar_url'], lastMessage: m['content'], lastMessageAt: DateTime.parse(m['created_at']), lastMessageIsFromMe: m['sender_id'] == uid, unreadCount: (m['is_read'] == false && m['receiver_id'] == uid) ? 1 : 0); } } return map.values.toList(); } catch (e) { debugPrint('getConversations: $e'); return []; } }
  Future<List<Map<String, dynamic>>> getMessages(String otherId) async { final uid = currentUserId; final res = await _supabase.from('messages').select().or('and(sender_id.eq.$uid,receiver_id.eq.$otherId),and(sender_id.eq.$otherId,receiver_id.eq.$uid)').order('created_at', ascending: true).limit(100); return (res as List).map((e) => {'id': e['id'], 'content': e['content'], 'is_sent_by_me': e['sender_id'] == uid, 'created_at': DateTime.parse(e['created_at'])}).toList(); }
  Future<Map<String, dynamic>> sendMessage(String receiverId, String content) async { final res = await _supabase.from('messages').insert({'sender_id': currentUserId, 'receiver_id': receiverId, 'content': content.trim(), 'is_read': false}).select().single(); return {'id': res['id'], 'content': res['content'], 'is_sent_by_me': true, 'created_at': DateTime.parse(res['created_at'])}; }
  Future<void> markMessagesAsRead(String otherId) async { await _supabase.from('messages').update({'is_read': true}).eq('receiver_id', currentUserId).eq('sender_id', otherId); }
  Future<List<NetworkNotification>> getNotifications() async { final res = await _supabase.from('notifications').select('*, profiles!sender_id(display_name, avatar_url)').eq('user_id', currentUserId).order('created_at', ascending: false).limit(50); return (res as List).map((e) => NetworkNotification.fromJson(e)).toList(); }
  Future<int> getUnreadNotificationsCount() async { final res = await _supabase.from('notifications').select('id').eq('user_id', currentUserId).eq('is_read', false); return (res as List).length; }
  Future<int> getUnreadMessagesCount() async { final res = await _supabase.from('messages').select('id').eq('receiver_id', currentUserId).eq('is_read', false); return (res as List).length; }
  Future<void> markAllNotificationsAsRead() async { await _supabase.from('notifications').update({'is_read': true}).eq('user_id', currentUserId).eq('is_read', false); }
  Future<Map<String, dynamic>?> getUserProfile(String userId) async { final res = await _supabase.from('profiles').select('id, display_name, avatar_url, profession, bio').eq('id', userId).maybeSingle(); if (res == null) return null; final posts = await _supabase.from('posts').select('id').eq('user_id', userId); return {...res, 'posts_count': (posts as List).length}; }
  Future<List<NetworkPost>> getUserPosts(String userId, {int offset = 0, int limit = 15}) async { final res = await _supabase.from('posts_view').select().eq('user_id', userId).order('created_at', ascending: false).range(offset, offset + limit - 1); return (res as List).map((e) => NetworkPost.fromJson(e)).toList(); }
  Future<void> markEventInterest(String id) async { await _supabase.from('event_interests').upsert({'event_id': id, 'user_id': currentUserId}, onConflict: 'event_id,user_id', ignoreDuplicates: true); }
  Future<bool> hasEventInterest(String id) async { final r = await _supabase.from('event_interests').select('id').eq('event_id', id).eq('user_id', currentUserId).maybeSingle(); return r != null; }
  Future<Map<String, int>> getRecommendationsCount() async { return {'people': 5, 'opportunities': 0, 'communities': 5}; }
  
  // 🌟 FIX : DÉTECTION DU TYPE MIME POUR LES VIDÉOS ET GESTION D'ERREUR
  Future<String?> uploadImageBytes(Uint8List bytes, {required String fileExtension, String bucket = 'post_images'}) async { 
    try { 
      final name = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension'; 
      final path = '$currentUserId/$name'; 
      
      final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(fileExtension.toLowerCase());
      final mimeType = isVideo ? 'video/$fileExtension' : 'image/$fileExtension';

      await _supabase.storage.from(bucket).uploadBinary(
        path, 
        bytes, 
        fileOptions: FileOptions(contentType: mimeType, upsert: true)
      ); 
      
      return _supabase.storage.from(bucket).getPublicUrl(path); 
    } catch (e) { 
      debugPrint('uploadMedia Error: $e'); 
      throw Exception(e.toString()); // Relance l'erreur pour que CreatePostDialog l'affiche
    } 
  }

  Future<String> _getPostOwnerId(String postId) async { final r = await _supabase.from('posts').select('user_id').eq('id', postId).maybeSingle(); return r?['user_id'] ?? ''; }
  Future<void> _createNotification({required String userId, required String type, String? postId}) async { if (userId.isEmpty || userId == currentUserId) return; await _supabase.from('notifications').insert({'user_id': userId, 'type': type, 'sender_id': currentUserId, 'post_id': postId, 'is_read': false}); }
}

class Highlight { final String id, name; final String? coverImage; final List<String> storyIds; final DateTime createdAt; Highlight({required this.id, required this.name, this.coverImage, required this.storyIds, required this.createdAt}); }
class Conversation { final String id, otherUserId, otherUserName, lastMessage; final String? otherUserAvatar; final DateTime lastMessageAt; final bool lastMessageIsFromMe; final int unreadCount; Conversation({required this.id, required this.otherUserId, required this.otherUserName, this.otherUserAvatar, required this.lastMessage, required this.lastMessageAt, required this.lastMessageIsFromMe, required this.unreadCount}); }
