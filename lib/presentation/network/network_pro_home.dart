// lib/presentation/network/network_pro_home.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ THIX Design System v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'package:thix_id/models/network_story.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'widgets/create_post_dialog.dart';
import 'widgets/create_story_dialog.dart';
import 'widgets/post_card.dart';
import 'widgets/story_viewer.dart';
import 'package:thix_id/presentation/network/live/live_prep_screen.dart';

// ============================================================================
// PROVIDER — SESSIONS LIVE ACTIVES
// ============================================================================
final activeLiveSessionsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  try {
    return Supabase.instance.client
        .from('live_sessions')
        .stream(primaryKey: ['id'])
        .eq('status', 'live')
        .limit(10);
  } catch (_) {
    return Stream.value(const <Map<String, dynamic>>[]);
  }
});

// ============================================================================
// COMPOSANT — AVATAR ROND PREMIUM
// ============================================================================
class RoundAvatar extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final Color ringColor;
  final IconData fallbackIcon;
  final double ringWidth;
  final bool isLive;

  const RoundAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.ringColor = Colors.transparent,
    this.fallbackIcon = Icons.person,
    this.ringWidth = 0,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRingColor = isLive ? ThixPolicy.danger : ringColor;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(ringWidth),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: effectiveRingColor,
          ),
          child: ClipOval(
            child: Container(
              color: ThixPolicy.surfaceStrong,
              child: (imageUrl != null && imageUrl!.isNotEmpty)
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(fallbackIcon, size: size * 0.5, color: ThixPolicy.textSecondary),
                    )
                  : Icon(fallbackIcon, size: size * 0.5, color: ThixPolicy.textSecondary),
            ),
          ),
        ),
        if (isLive)
          Positioned(
            bottom: -4,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: ThixPolicy.danger,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: ThixPolicy.card, width: 1.5),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// PAGE PRINCIPALE — RÉSEAU PRO
// ============================================================================
class NetworkProHome extends ConsumerStatefulWidget {
  const NetworkProHome({super.key});

  @override
  ConsumerState<NetworkProHome> createState() => _NetworkProHomeState();
}

class _NetworkProHomeState extends ConsumerState<NetworkProHome> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _navVisible = ValueNotifier(true);

  static DateTime? _lastRefreshTime;
  static const _refreshCooldown = Duration(seconds: 60);

  String _feedType = 'all';
  List<NetworkStory> _stories = [];
  bool _loadingStories = true;
  List<dynamic> _suggestions = [];
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    // Load More (Pagination)
    if (pos.pixels >= pos.maxScrollExtent - 700 && !_isLoadingMore) {
      final notifier = ref.read(feedProvider.notifier);
      if (!ref.read(feedProvider).isLoading && notifier.hasMore) {
        _isLoadingMore = true;
        notifier.loadMore().whenComplete(() {
          if (mounted) _isLoadingMore = false;
        });
      }
    }

    // Hide/Show Bottom Nav
    final dir = pos.userScrollDirection;
    if (dir == ScrollDirection.reverse && _navVisible.value) {
      _navVisible.value = false;
    } else if (dir == ScrollDirection.forward && !_navVisible.value) {
      _navVisible.value = true;
    }
  }

  Future<void> _init() async {
    final now = DateTime.now();
    final needsRefresh = _lastRefreshTime == null || now.difference(_lastRefreshTime!) > _refreshCooldown;

    await ref.read(feedProvider.notifier).loadFeed(feedType: _feedType, force: needsRefresh);
    if (needsRefresh) _lastRefreshTime = now;

    await Future.wait([_loadStories(), _loadSuggestions()]);
  }

  Future<void> _loadStories() async {
    try {
      final data = await ref.read(networkServiceProvider).getActiveStories();
      if (mounted) setState(() { _stories = data; _loadingStories = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingStories = false);
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final data = await ref.read(networkServiceProvider).getSuggestedConnections(limit: 8);
      if (mounted) setState(() => _suggestions = data);
    } catch (_) {}
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    await ref.read(feedProvider.notifier).loadFeed(feedType: _feedType, force: true);
    _lastRefreshTime = DateTime.now();
    await Future.wait([_loadStories(), _loadSuggestions()]);
    ref.invalidate(activeLiveSessionsProvider);
  }

  Future<void> _openCreateStory() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const CreateStoryDialog());
    if (ok == true && mounted) {
      HapticFeedback.mediumImpact();
      await _loadStories();
    }
  }

  void _safePush(String path) {
    if (!mounted) return;
    try { context.push(path); } catch (e) { debugPrint('nav: $e'); }
  }

  Future<void> _openComments(String postId) async {
    _safePush('/network/comments/$postId');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _navVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authAsync = ref.watch(authControllerProvider);
    final feedAsync = ref.watch(feedProvider);
    final currentUser = authAsync.value;
    final liveSessionsAsync = ref.watch(activeLiveSessionsProvider);
    final liveHostIds = (liveSessionsAsync.value ?? const <Map<String, dynamic>>[])
        .map((s) => s['host_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: ThixPolicy.card,
        body: Center(child: CircularProgressIndicator(color: ThixPolicy.primaryDeep)),
      );
    }

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft, // Fond gris ultra-clair (séparation des blocs blancs)
      body: Stack(
        children: [
          RefreshIndicator(
            color: ThixPolicy.primaryDeep,
            backgroundColor: ThixPolicy.card,
            onRefresh: _onRefresh,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                _buildSliverAppBar(isLive: liveHostIds.contains(currentUser.id)),
                
                // Stories (Design Pro Circulaire)
                SliverToBoxAdapter(child: _buildProStories(currentUser.id, liveHostIds)),
                
                // Diviseur
                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // Entrée "Créer un post" (Minimaliste)
                SliverToBoxAdapter(
                  child: _ProPostEntry(
                    avatarUrl: currentUser.photoUrl,
                    onTap: () => showDialog(context: context, builder: (_) => const CreatePostDialog()),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                
                // Live Hub Automatique (Disparaît si vide)
                _buildAutoLiveHub(liveSessionsAsync),
                
                // Filtres du Feed
                SliverToBoxAdapter(child: _buildProFilters()),
                
                // Suggestions (Intégrées proprement)
                if (_suggestions.isNotEmpty)
                  SliverToBoxAdapter(child: _buildProSuggestions(liveHostIds)),
                
                // Feed Posts
                feedAsync.when(
                  loading: () => SliverToBoxAdapter(child: _buildShimmerFeed()),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(child: Text('Erreur: $e', style: const TextStyle(color: ThixPolicy.textSecondary))),
                    ),
                  ),
                  data: (posts) {
                    if (posts.isEmpty) return SliverToBoxAdapter(child: _buildEmpty());
                    return SliverList.builder(
                      itemCount: posts.length,
                      itemBuilder: (c, i) {
                        final post = posts[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: PostCard(
                            key: ValueKey(post.id),
                            post: post,
                            currentProfileId: currentUser.id,
                            onLike: null,
                            onComment: () => _openComments(post.id),
                            onShare: () => _showShareSheet(post),
                            onDelete: () => ref.read(feedProvider.notifier).deletePost(post.id),
                            onRefresh: null,
                          ),
                        );
                      },
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
          
          // Navigation Bottom Flottante
          ValueListenableBuilder<bool>(
            valueListenable: _navVisible,
            builder: (context, visible, _) => Positioned(
              left: 0, right: 0, bottom: 0,
              child: _buildBottomNav(visible),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── APP BAR (Propre) ───────────────────────────
  Widget _buildSliverAppBar({required bool isLive}) {
    return SliverAppBar(
      backgroundColor: ThixPolicy.card,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: ThixPolicy.inkDeep.withOpacity(0.1),
      floating: true,
      snap: true,
      toolbarHeight: ThixPolicy.appBarHeight,
      titleSpacing: ThixPolicy.s16,
      title: const Text(
        'THIX PRO',
        style: TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5),
      ),
      actions: [
        _appBarIcon(icon: Icons.search_rounded, onTap: () => _safePush('/network/search')),
        const SizedBox(width: ThixPolicy.s8),
        _appBarIcon(icon: Icons.notifications_none_rounded, onTap: () => _safePush('/network/notifications')),
        const SizedBox(width: ThixPolicy.s12),
        Padding(
          padding: const EdgeInsets.only(right: ThixPolicy.s16),
          child: GestureDetector(
            onTap: () => _safePush('/profile'),
            child: RoundAvatar(size: 34, ringWidth: 2, ringColor: ThixPolicy.border, isLive: isLive),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: ThixPolicy.border),
      ),
    );
  }

  Widget _appBarIcon({required IconData icon, required VoidCallback onTap, String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: ThixPolicy.surface,
          shape: BoxShape.circle,
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 20, color: ThixPolicy.inkDeep),
            if (badge != null)
              Positioned(
                top: 2, right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: ThixPolicy.danger,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ThixPolicy.card, width: 1.5),
                  ),
                  child: Text(badge, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── STORIES PRO (CERCLES) ───────────────────────────
  Widget _buildProStories(String currentUserId, Set<String> liveHostIds) {
    if (_loadingStories) {
      return Container(
        color: ThixPolicy.card,
        height: 110,
        alignment: Alignment.center,
        child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.textSecondary)),
      );
    }

    final myStories = _stories.where((s) => s.userId == currentUserId).toList();
    final Map<String, List<NetworkStory>> groupedOtherStories = {};
    for (final s in _stories) {
      if (s.userId != currentUserId) {
        groupedOtherStories.putIfAbsent(s.userId, () => []).add(s);
      }
    }
    final otherUsersList = groupedOtherStories.keys.toList();

    return Container(
      color: ThixPolicy.card,
      padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s12),
      child: SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
          itemCount: otherUsersList.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
          itemBuilder: (c, i) {
            if (i == 0) {
              return _ProStoryRing(
                isMe: true,
                hasStory: myStories.isNotEmpty,
                isLive: liveHostIds.contains(currentUserId),
                name: 'Vous',
                avatarUrl: myStories.isNotEmpty ? myStories.first.userAvatar : null, // Fallback si pas de story géré par le widget
                onTap: myStories.isNotEmpty ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewer(stories: myStories, initialIndex: 0))) : _openCreateStory,
                onAdd: _openCreateStory,
              );
            }
            final userId = otherUsersList[i - 1];
            final userStories = groupedOtherStories[userId]!;
            final firstStory = userStories.first;

            return _ProStoryRing(
              isMe: false,
              hasStory: true,
              isLive: liveHostIds.contains(userId),
              name: firstStory.userName.split(' ').first,
              avatarUrl: firstStory.userAvatar,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewer(stories: userStories, initialIndex: 0))),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────── AUTO LIVE HUB (S'affiche que si nécessaire) ───────────────────────────
  Widget _buildAutoLiveHub(AsyncValue<List<Map<String, dynamic>>> liveSessionsAsync) {
    return liveSessionsAsync.when(
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (sessions) {
        if (sessions.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        
        return SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: ThixPolicy.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text('Directs & Espaces Audio', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: ThixPolicy.inkDeep)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final s = sessions[i];
                      final type = (s['session_type'] as String?) ?? 'video';
                      return _ProLiveCard(
                        title: (s['title'] as String?) ?? 'Direct en cours',
                        host: (s['host_name'] as String?) ?? 'THIX Pro',
                        type: type,
                        viewers: (s['viewer_count'] as int?) ?? 0,
                        onTap: () {
                           // Logique pour rejoindre le live
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────── FILTRES PRO (Subtils) ───────────────────────────
  Widget _buildProFilters() {
    final filters = {
      'all': 'Pour vous',
      'network': 'Abonnements',
      'popular': 'Tendances',
    };

    return Container(
      color: ThixPolicy.card,
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 1), // Séparation fine avec le premier post
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.entries.map((e) {
            final sel = _feedType == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: ThixPolicy.s8),
              child: InkWell(
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                onTap: () {
                  if (sel) return;
                  setState(() => _feedType = e.key);
                  ref.read(feedProvider.notifier).loadFeed(feedType: e.key, force: true);
                  _lastRefreshTime = DateTime.now();
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? ThixPolicy.inkDeep : ThixPolicy.surface,
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    border: Border.all(color: sel ? ThixPolicy.inkDeep : ThixPolicy.border),
                  ),
                  child: Text(
                    e.value, 
                    style: TextStyle(
                      fontSize: 13, 
                      fontWeight: sel ? FontWeight.w800 : FontWeight.w600, 
                      color: sel ? Colors.white : ThixPolicy.textSecondary
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────── SUGGESTIONS PRO ───────────────────────────
  Widget _buildProSuggestions(Set<String> liveHostIds) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: ThixPolicy.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Suggestions pour vous', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ThixPolicy.inkDeep)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (c, i) {
                final u = _suggestions[i];
                return Container(
                  width: 130,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThixPolicy.card,
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                    border: Border.all(color: ThixPolicy.border),
                  ),
                  child: Column(
                    children: [
                      RoundAvatar(size: 50, imageUrl: u.avatar, isLive: liveHostIds.contains(u.id)),
                      const SizedBox(height: 8),
                      Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ThixPolicy.inkDeep)),
                      const SizedBox(height: 2),
                      Text(u.title ?? 'Membre', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 30,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: ThixPolicy.inkDeep,
                            side: const BorderSide(color: ThixPolicy.borderStrong),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                          ),
                          onPressed: () async {
                            await ref.read(networkServiceProvider).sendConnectionRequest(u.id);
                            setState(() => _suggestions.remove(u));
                          },
                          child: const Text('Connecter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── FEED UTILS ───────────────────────────
  Widget _buildShimmerFeed() {
    return Column(
      children: List.generate(3, (i) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 180,
        color: ThixPolicy.card,
      )),
    );
  }

  Widget _buildEmpty() {
    return Container(
      color: ThixPolicy.card,
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          const Icon(Icons.article_outlined, size: 48, color: ThixPolicy.borderStrong),
          const SizedBox(height: 16),
          const Text('Votre fil est vide.', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 18),
          TextButton(
            onPressed: _onRefresh,
            child: const Text('Actualiser', style: TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showShareSheet(dynamic post) {
    final id = '${post.id}';
    final link = 'https://thix.id/network/post/$id';
    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: ThixPolicy.inkDeep),
              title: const Text('Copier le lien', style: TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w700)),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: link));
                try { await ref.read(networkServiceProvider).sharePost(id); } catch (_) {}
                if (mounted) Navigator.pop(context);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié dans le presse-papiers')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded, color: ThixPolicy.textSecondary),
              title: const Text('Fermer', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── BOTTOM NAV (Flottante & Moderne) ───────────────────────────
  Widget _buildBottomNav(bool visible) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.5),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: ThixPolicy.inkDeep, // Navigation sombre et premium
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _navBtn(Icons.home_filled, 'Accueil', true, () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
                    _navBtn(Icons.search_rounded, 'Découvrir', false, () => _safePush('/network/discover')),
                    
                    // Bouton central de publication (Plus visible)
                    GestureDetector(
                      onTap: () => showDialog(context: context, builder: (_) => const CreatePostDialog()),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [ThixPolicy.primary, ThixPolicy.primaryDeep]),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: ThixPolicy.primary.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    
                    _navBtn(Icons.people_alt_rounded, 'Réseau', false, () => _safePush('/network/connections')),
                    _navBtn(Icons.mail_rounded, 'Message', false, () => _safePush('/messages')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navBtn(IconData ic, String label, bool active, VoidCallback tap) {
    return InkWell(
      onTap: tap,
      child: SizedBox(
        width: 50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ic, size: 22, color: active ? Colors.white : ThixPolicy.textSecondary.withOpacity(0.8)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? Colors.white : ThixPolicy.textSecondary.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS PRO : STORY RINGS ET QUICK POST
// ============================================================================

class _ProStoryRing extends StatelessWidget {
  final bool isMe;
  final bool hasStory;
  final bool isLive;
  final String name;
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _ProStoryRing({required this.isMe, required this.hasStory, this.isLive = false, required this.name, this.avatarUrl, required this.onTap, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: (hasStory && !isMe) || isLive 
                        ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [ThixPolicy.primary, ThixPolicy.primaryDeep]) 
                        : null,
                    color: (!hasStory && !isLive) ? ThixPolicy.border : null,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2), // Espace blanc entre la bordure et l'image
                    decoration: const BoxDecoration(color: ThixPolicy.card, shape: BoxShape.circle),
                    child: RoundAvatar(size: 52, imageUrl: avatarUrl, ringWidth: 0),
                  ),
                ),
                if (isMe)
                  Positioned(
                    bottom: 0, right: 0,
                    child: GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.primaryDeep, border: Border.all(color: ThixPolicy.card, width: 2.5)),
                        child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ThixPolicy.inkDeep),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProPostEntry extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback onTap;

  const _ProPostEntry({required this.avatarUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThixPolicy.card,
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: 12),
      child: Row(
        children: [
          RoundAvatar(size: 44, imageUrl: avatarUrl, ringWidth: 0),
          const SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: ThixPolicy.surface,
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: const Text('Commencer un post...', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(onPressed: onTap, icon: const Icon(Icons.image_outlined, color: ThixPolicy.textSecondary)),
        ],
      ),
    );
  }
}

class _ProLiveCard extends StatelessWidget {
  final String title;
  final String host;
  final String type;
  final int viewers;
  final VoidCallback onTap;

  const _ProLiveCard({required this.title, required this.host, required this.type, required this.viewers, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isVideo = type == 'video';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThixPolicy.surface,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(isVideo ? Icons.videocam_rounded : Icons.mic_rounded, size: 14, color: ThixPolicy.danger),
                    const SizedBox(width: 4),
                    const Text('EN DIRECT', style: TextStyle(color: ThixPolicy.danger, fontSize: 9, fontWeight: FontWeight.w900)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.visibility_rounded, color: ThixPolicy.textSecondary, size: 12),
                    const SizedBox(width: 4),
                    Text('$viewers', style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ThixPolicy.inkDeep, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(host, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
