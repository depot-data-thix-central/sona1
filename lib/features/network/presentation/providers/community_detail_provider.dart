// lib/features/network/presentation/providers/community_detail_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/models/network_community.dart';
import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart'; // Ajustez l'import

/// 1. L'objet d'état immuable
class CommunityDetailState {
  final NetworkCommunity community;
  final List<NetworkPost> posts;
  final List<Map<String, dynamic>> members;
  final bool isMember;
  final bool hasMorePosts;

  const CommunityDetailState({
    required this.community,
    this.posts = const [],
    this.members = const [],
    this.isMember = false,
    this.hasMorePosts = true,
  });

  CommunityDetailState copyWith({
    NetworkCommunity? community,
    List<NetworkPost>? posts,
    List<Map<String, dynamic>>? members,
    bool? isMember,
    bool? hasMorePosts,
  }) {
    return CommunityDetailState(
      community: community ?? this.community,
      posts: posts ?? this.posts,
      members: members ?? this.members,
      isMember: isMember ?? this.isMember,
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
    );
  }
}

/// 2. Le Notifier qui gère toute la logique
class CommunityDetailNotifier extends AutoDisposeFamilyAsyncNotifier<CommunityDetailState, String> {
  static const int _limit = 20;
  int _postsOffset = 0;

  @override
  Future<CommunityDetailState> build(String arg) async {
    _postsOffset = 0;
    return _loadInitialData(arg);
  }

  Future<CommunityDetailState> _loadInitialData(String communityId) async {
    final supabase = ref.read(supabaseClientProvider);
    final currentUserId = supabase.auth.currentUser?.id;

    final results = await Future.wait([
      supabase.from('communities').select('*').eq('id', communityId).maybeSingle(),
      supabase.from('community_members').select('users!user_id (id, display_name, photo_url, profession)').eq('community_id', communityId).limit(50),
      supabase.from('posts').select('*, users!user_id (display_name, photo_url, profession)').eq('community_id', communityId).order('created_at', ascending: false).range(0, _limit - 1),
      currentUserId != null ? supabase.from('community_members').select('id').eq('community_id', communityId).eq('user_id', currentUserId).maybeSingle() : Future.value(null),
    ]);

    final communityData = results[0] as Map<String, dynamic>?;
    if (communityData == null) throw Exception('Communauté introuvable');

    final membersData = results[1] as List<dynamic>;
    final postsData = results[2] as List<dynamic>;
    final memberCheck = results[3] as Map<String, dynamic>?;

    final posts = postsData.map((e) => _mapPost(e)).toList();
    _postsOffset = posts.length;

    return CommunityDetailState(
      community: NetworkCommunity.fromJson({...communityData, 'members_count': communityData['members_count'] ?? 0}),
      members: membersData.map((e) => e['users'] as Map<String, dynamic>).toList(),
      posts: posts,
      isMember: memberCheck != null,
      hasMorePosts: posts.length >= _limit, // Sécurité pour la pagination
    );
  }

  NetworkPost _mapPost(dynamic e) {
    final row = e as Map<String, dynamic>;
    final userData = row['users'] as Map<String, dynamic>?;
    return NetworkPost.fromJson({
      ...row,
      'author_name': userData?['display_name'] ?? 'Utilisateur',
      'author_avatar': userData?['photo_url'],
      'author_title': userData?['profession'],
      'media_urls': _extractMediaUrls(row),
    });
  }

  List<String> _extractMediaUrls(Map<String, dynamic> row) {
    if (row['media_urls'] != null) return List<String>.from(row['media_urls'] as List);
    if (row['media_url'] != null && row['media_url'].toString().isNotEmpty) return [row['media_url'].toString()];
    if (row['image_urls'] != null) return List<String>.from(row['image_urls'] as List);
    return [];
  }

  Future<void> loadMorePosts() async {
    final currentState = state.valueOrNull;
    if (currentState == null || !currentState.hasMorePosts) return;

    try {
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase.from('posts').select('*, users!user_id (display_name, photo_url, profession)')
          .eq('community_id', arg)
          .order('created_at', ascending: false)
          .range(_postsOffset, _postsOffset + _limit - 1);

      if (res.isEmpty) {
        state = AsyncData(currentState.copyWith(hasMorePosts: false));
        return;
      }

      final morePosts = (res as List).map((e) => _mapPost(e)).toList();
      _postsOffset += morePosts.length;

      state = AsyncData(currentState.copyWith(
        posts: [...currentState.posts, ...morePosts],
        hasMorePosts: morePosts.length >= _limit,
      ));
    } catch (_) {
      // Échec silencieux pour ne pas bloquer l'UI lors de la pagination
    }
  }

  Future<void> toggleJoin() async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final wasMember = currentState.isMember;
    final currentCount = currentState.community.membersCount;

    // UI Optimiste : mise à jour instantanée
    state = AsyncData(currentState.copyWith(
      isMember: !wasMember,
      community: currentState.community.copyWith(membersCount: wasMember ? (currentCount - 1) : (currentCount + 1))
    ));

    try {
      final supabase = ref.read(supabaseClientProvider);
      final uid = supabase.auth.currentUser!.id;
      if (wasMember) {
        await supabase.from('community_members').delete().eq('community_id', arg).eq('user_id', uid);
      } else {
        await supabase.from('community_members').insert({'community_id': arg, 'user_id': uid, 'joined_at': DateTime.now().toIso8601String()});
      }
    } catch (e) {
      // Retour à l'état initial en cas d'erreur
      state = AsyncData(currentState);
      throw Exception("Erreur de synchronisation réseau");
    }
  }

  Future<void> toggleLike(String postId) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final postIndex = currentState.posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final post = currentState.posts[postIndex];
    final newIsLiked = !post.isLiked;
    
    final updatedPosts = List<NetworkPost>.from(currentState.posts);
    updatedPosts[postIndex] = post.copyWith(isLiked: newIsLiked, likesCount: post.likesCount + (newIsLiked ? 1 : -1));

    // UI Optimiste
    state = AsyncData(currentState.copyWith(posts: updatedPosts));

    try {
      if (newIsLiked) {
        await ref.read(networkServiceProvider).likePost(postId);
      } else {
        await ref.read(networkServiceProvider).unlikePost(postId);
      }
    } catch (_) {
      // Re-synchronisation propre en cas d'erreur
      ref.invalidateSelf();
    }
  }
}

// 3. Le Provider
final communityDetailProvider = AsyncNotifierProvider.autoDispose.family<CommunityDetailNotifier, CommunityDetailState, String>(
  CommunityDetailNotifier.new
);
