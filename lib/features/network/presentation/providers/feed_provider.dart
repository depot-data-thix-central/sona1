// lib/features/network/presentation/providers/feed_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/models/network_post.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_ranker.dart';

final feedProvider =
    AsyncNotifierProvider<Feed, List<NetworkPost>>(Feed.new);

class Feed extends AsyncNotifier<List<NetworkPost>> {
  String _currentType = 'all';
  bool _hasMore = true;
  Set<String> _connectionIds = {};

  bool get hasMore => _hasMore;
  String get currentType => _currentType;

  Future<void> _ensureConnections() async {
    if (_connectionIds.isNotEmpty) return;
    try {
      final service = ref.read(networkServiceProvider);
      _connectionIds = await service.getMyConnectionIds();
    } catch (e) {
      debugPrint('🔥 connections for rank: $e');
      _connectionIds = {};
    }
  }

  List<NetworkPost> _rank(List<NetworkPost> posts) {
    return FeedRanker.rank(
      posts: posts,
      connectionIds: _connectionIds,
      feedType: _currentType,
    );
  }

  @override
  Future<List<NetworkPost>> build() async {
    _hasMore = true;
    try {
      await _ensureConnections();
      final service = ref.read(networkServiceProvider);
      final limit = _currentType == 'all' ? 50 : 20;
      final posts = await service.getFeedPosts(
        feedType: _currentType,
        limit: limit,
        offset: 0,
      );
      _hasMore = posts.length >= limit;
      return _rank(posts);
    } catch (e) {
      debugPrint('🔥 Erreur dans Feed.build: $e');
      return [];
    }
  }

  Future<void> loadFeed({String? feedType, bool force = false}) async {
    if (feedType != null) _currentType = feedType;
    state = const AsyncLoading();

    try {
      if (force) _connectionIds = {};
      await _ensureConnections();

      final service = ref.read(networkServiceProvider);
      final limit = _currentType == 'all' ? 50 : 30;
      final posts = await service.getFeedPosts(
        feedType: _currentType,
        limit: limit,
        offset: 0,
      );
      _hasMore = posts.length >= limit;
      state = AsyncData(_rank(posts));
    } catch (e, stack) {
      debugPrint('🔥 Erreur dans Feed.loadFeed: $e');
      state = AsyncError(e, stack);
    }
  }

  void addPostOnTop(NetworkPost post) {
    final current = state.valueOrNull ?? [];
    state = AsyncData([post, ...current]);
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    final current = state.valueOrNull ?? [];
    try {
      await _ensureConnections();
      final service = ref.read(networkServiceProvider);
      final limit = _currentType == 'all' ? 30 : 20;
      final more = await service.getFeedPosts(
        feedType: _currentType,
        limit: limit,
        offset: current.length,
      );
      _hasMore = more.length >= limit;

      // Rank uniquement le nouveau batch (ordre du haut stable)
      final rankedMore = _rank(more);
      state = AsyncData([...current, ...rankedMore]);
    } catch (e) {
      debugPrint('🔥 Erreur dans Feed.loadMore: $e');
    }
  }

  Future<void> deletePost(String postId) async {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((p) => p.id != postId).toList());
    try {
      await ref.read(networkServiceProvider).deletePost(postId);
    } catch (_) {
      state = AsyncData(current);
    }
  }

  Future<void> toggleLike(String postId) async {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final old = current[idx];
    final wasLiked = old.isLiked;
    final oldCount = old.likesCount;

    final optimistic = old.copyWith(
      isLiked: !wasLiked,
      likesCount: wasLiked ? (oldCount - 1).clamp(0, 1 << 30) : oldCount + 1,
    );

    final list = [...current];
    list[idx] = optimistic;
    state = AsyncData(list);

    try {
      final service = ref.read(networkServiceProvider);
      if (wasLiked) {
        await service.unlikePost(postId);
      } else {
        await service.likePost(postId);
      }
    } catch (e) {
      debugPrint('🔥 toggleLike rollback: $e');
      state = AsyncData(current);
    }
  }
}
