import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/models/network_post.dart';

final userProfileProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final service = ref.read(networkServiceProvider);
  return await service.getUserProfile(userId);
});

final pinnedPostsProvider = FutureProvider.family<List<NetworkPost>, String>((ref, userId) async {
  final service = ref.read(networkServiceProvider);
  return await service.getPinnedPosts(userId);
});

final userPostsProvider = AsyncNotifierProviderFamily<UserPostsNotifier, List<NetworkPost>, String>(UserPostsNotifier.new);

class UserPostsNotifier extends FamilyAsyncNotifier<List<NetworkPost>, String> {
  int _offset = 0;
  static const _limit = 15;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool get hasMore => _hasMore;

  @override
  Future<List<NetworkPost>> build(String userId) async {
    _offset = 0;
    final service = ref.read(networkServiceProvider);
    final posts = await service.getUserPosts(userId, offset: 0, limit: _limit);
    _offset = posts.length;
    _hasMore = posts.length == _limit;
    return posts;
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final service = ref.read(networkServiceProvider);
      final more = await service.getUserPosts(arg, offset: _offset, limit: _limit);
      _hasMore = more.length == _limit;
      _offset += more.length;
      state = AsyncData([...state.valueOrNull?? [], ...more]);
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(networkServiceProvider);
      final posts = await service.getUserPosts(arg, offset: 0, limit: _limit);
      _offset = posts.length;
      _hasMore = posts.length == _limit;
      return posts;
    });
  }
}

final followStatusProvider = FutureProvider.family<bool, String>((ref, targetId) async {
  try {
    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser!.id;
    final res = await supabase.from('connections').select().eq('user_id', currentUserId).eq('status', 'accepted');
    return (res as List).any((r) => (r['connection_id']?? r['friend_id']?? r['connected_user_id']?? r['following_id']?? r['target_id']?? r['receiver_id']) == targetId);
  } catch (_) { return false; }
});
