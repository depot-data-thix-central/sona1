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
    this.ringColor = ThixPolicy.primary,
    this.fallbackIcon = Icons.person,
    this.ringWidth = 2.5,
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
              color: ThixPolicy.tint,
              child: (imageUrl != null && imageUrl!.isNotEmpty)
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(fallbackIcon, size: size * 0.45, color: ThixPolicy.primaryDeep),
                    )
                  : Icon(fallbackIcon, size: size * 0.45, color: ThixPolicy.primaryDeep),
            ),
          ),
        ),
        if (isLive)
          Positioned(
            bottom: -3,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: ThixPolicy.danger,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.3),
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
        backgroundColor: ThixPolicy.surfaceSoft,
        body: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      );
    }

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft, // Fond gris léger pour faire ressortir les cartes blanches
      body: Stack(
        children: [
          RefreshIndicator(
            color: ThixPolicy.primary,
            backgroundColor: ThixPolicy.card,
            onRefresh: _onRefresh,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                _buildSliverAppBar(isLive: liveHostIds.contains(currentUser.id)),
                
                // Entrée "Créer un post" (Standard Réseaux Sociaux)
                SliverToBoxAdapter(
                  child: _QuickPostEntryCard(
                    avatarUrl: currentUser.photoUrl,
                    onTap: () => showDialog(context: context, builder: (_) => const CreatePostDialog()),
                  ),
                ),
                
                // Stories
                SliverToBoxAdapter(child: _buildStoriesFacebook(currentUser.id, liveHostIds)),
                
                // Filtres
                SliverToBoxAdapter(child: _buildFilters()),
                
                // Live Hub Rétractable
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
                    child: _CollapsibleLiveHub(liveSessionsAsync: liveSessionsAsync),
                  ),
                ),
                
                // Suggestions
                if (_suggestions.isNotEmpty)
                  SliverToBoxAdapter(child: _buildSuggestions(liveHostIds)),
                
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
                          padding: const EdgeInsets.only(bottom: ThixPolicy.s8),
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

  // ─────────────────────────── APP BAR ───────────────────────────
  Widget _buildSliverAppBar({required bool isLive}) {
    return SliverAppBar(
      backgroundColor: ThixPolicy.card,
      elevation: 0,
      scrolledUnderElevation: 0,
      floating: true,
      snap: true,
      toolbarHeight: ThixPolicy.appBarHeight,
      titleSpacing: ThixPolicy.s16,
      title: ShaderMask(
        shaderCallback: (b) => ThixPolicy.brandGradient.createShader(b),
        child: const Text(
          'THIX PRO',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.4),
        ),
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
            child: RoundAvatar(size: 36, ringWidth: 2.2, isLive: isLive),
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
        width: 40, height: 40,
        decoration: const BoxDecoration(color: ThixPolicy.tint, shape: BoxShape.circle),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 20, color: ThixPolicy.primaryDeep),
            if (badge != null)
              Positioned(
                top: 4, right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: ThixPolicy.danger,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(badge, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── STORIES ───────────────────────────
  Widget _buildStoriesFacebook(String currentUserId, Set<String> liveHostIds) {
    if (_loadingStories) {
      return Container(
        color: ThixPolicy.card,
        height: 168,
        alignment: Alignment.center,
        child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: ThixPolicy.primary)),
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
      padding: const EdgeInsets.only(top: ThixPolicy.s8, bottom: ThixPolicy.s16),
      child: SizedBox(
        height: 152,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
          itemCount: otherUsersList.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
          itemBuilder: (c, i) {
            if (i == 0) {
              return _FbStoryCard(
                isMe: true,
                hasStory: myStories.isNotEmpty,
                isLive: liveHostIds.contains(currentUserId),
                name: myStories.isNotEmpty ? 'Votre story' : 'Créer',
                coverUrl: myStories.isNotEmpty ? (myStories.first.imageUrl.isNotEmpty ? myStories.first.imageUrl : myStories.first.userAvatar) : null,
                avatarUrl: myStories.isNotEmpty ? myStories.first.userAvatar : null,
                onTap: myStories.isNotEmpty ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewer(stories: myStories, initialIndex: 0))) : _openCreateStory,
                onAdd: _openCreateStory,
              );
            }
            final userId = otherUsersList[i - 1];
            final userStories = groupedOtherStories[userId]!;
            final firstStory = userStories.first;

            return _FbStoryCard(
              isMe: false,
              hasStory: true,
              isLive: liveHostIds.contains(userId),
              name: firstStory.userName.split(' ').first,
              coverUrl: firstStory.imageUrl.isNotEmpty ? firstStory.imageUrl : null,
              avatarUrl: firstStory.userAvatar,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewer(stories: userStories, initialIndex: 0))),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────── FILTRES ───────────────────────────
  Widget _buildFilters() {
    final filters = {
      'all': ('Pour vous', Icons.auto_awesome_rounded),
      'network': ('Abonnements', Icons.people_alt_rounded),
      'popular': ('Tendances', Icons.local_fire_department_rounded),
      'recent': ('Récents', Icons.schedule_rounded),
    };

    return Container(
      color: ThixPolicy.card,
      padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, 0, ThixPolicy.s16, ThixPolicy.s16),
      margin: const EdgeInsets.only(bottom: ThixPolicy.s8), // Séparation du Feed
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.entries.map((e) {
            final sel = _feedType == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: ThixPolicy.s8),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  if (sel) return;
                  setState(() => _feedType = e.key);
                  ref.read(feedProvider.notifier).loadFeed(feedType: e.key, force: true);
                  _lastRefreshTime = DateTime.now();
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? ThixPolicy.tint : ThixPolicy.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: sel ? ThixPolicy.primary : ThixPolicy.border, width: sel ? 1.4 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(e.value.$2, size: 16, color: sel ? ThixPolicy.primaryDeep : ThixPolicy.textSecondary),
                      const SizedBox(width: 6),
                      Text(e.value.$1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? ThixPolicy.primaryDeep : ThixPolicy.textMain)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────── SUGGESTIONS ───────────────────────────
  Widget _buildSuggestions(Set<String> liveHostIds) {
    return Container(
      margin: const EdgeInsets.only(bottom: ThixPolicy.s8),
      padding: const EdgeInsets.symmetric(vertical: ThixPolicy.s16),
      color: ThixPolicy.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Personnes à découvrir', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ThixPolicy.textMain)),
                Icon(Icons.groups_2_rounded, size: 20, color: ThixPolicy.primary),
              ],
            ),
          ),
          const SizedBox(height: ThixPolicy.s16),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
              itemBuilder: (c, i) {
                final u = _suggestions[i];
                return Container(
                  width: 140,
                  padding: const EdgeInsets.all(ThixPolicy.s12),
                  decoration: BoxDecoration(
                    color: ThixPolicy.surface,
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    border: Border.all(color: ThixPolicy.border),
                  ),
                  child: Column(
                    children: [
                      RoundAvatar(size: 60, imageUrl: u.avatar, ringWidth: 2.5, isLive: liveHostIds.contains(u.id)),
                      const SizedBox(height: ThixPolicy.s8),
                      Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                      const SizedBox(height: 2),
                      Text(u.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: ThixPolicy.primary,
                            side: const BorderSide(color: ThixPolicy.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () async {
                            await ref.read(networkServiceProvider).sendConnectionRequest(u.id);
                            setState(() => _suggestions.remove(u));
                          },
                          child: const Text('Se connecter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
        margin: const EdgeInsets.only(bottom: ThixPolicy.s8),
        height: 200,
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: ThixPolicy.tint, shape: BoxShape.circle),
            child: const Icon(Icons.feed_outlined, size: 40, color: ThixPolicy.primaryDeep),
          ),
          const SizedBox(height: 16),
          const Text('Aucune publication pour ce filtre', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _onRefresh,
            child: const Text('Actualiser'),
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
            ListTile(
              leading: const Icon(Icons.link, color: ThixPolicy.primary),
              title: const Text('Copier le lien', style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w600)),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: link));
                try { await ref.read(networkServiceProvider).sharePost(id); } catch (_) {}
                if (mounted) Navigator.pop(context);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: ThixPolicy.textSecondary),
              title: const Text('Fermer', style: TextStyle(color: ThixPolicy.textMain)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── BOTTOM NAV ───────────────────────────
  Widget _buildBottomNav(bool visible) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      offset: visible ? Offset.zero : const Offset(0, 1.6),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: ThixPolicy.card.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: ThixPolicy.border),
                      boxShadow: [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _navBtn(Icons.home_rounded, 'Accueil', true, () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
                        _navBtn(Icons.explore_outlined, 'Découvrir', false, () => _safePush('/network/discover')),
                        _navBtn(Icons.add_circle_outline_rounded, 'Publier', false, () => showDialog(context: context, builder: (_) => const CreatePostDialog())),
                        _navBtn(Icons.groups_outlined, 'Réseau', false, () => _safePush('/network/connections')),
                        _navBtn(Icons.mail_outline_rounded, 'Message', false, () => _safePush('/messages')),
                      ],
                    ),
                  ),
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
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ic, size: 22, color: active ? ThixPolicy.primary : ThixPolicy.textSecondary),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? ThixPolicy.primary : ThixPolicy.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// COMPOSANT NOUVEAU — QUICK POST ENTRY (Façon LinkedIn/Facebook)
// ============================================================================
class _QuickPostEntryCard extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback onTap;

  const _QuickPostEntryCard({required this.avatarUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThixPolicy.card,
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
      child: Row(
        children: [
          RoundAvatar(size: 40, imageUrl: avatarUrl, ringWidth: 0),
          const SizedBox(width: ThixPolicy.s12),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
                decoration: BoxDecoration(
                  color: ThixPolicy.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: const Text(
                  'Commencer un post...',
                  style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          const SizedBox(width: ThixPolicy.s12),
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.image_outlined, color: ThixPolicy.domainMedia),
            tooltip: 'Ajouter un média',
          )
        ],
      ),
    );
  }
}

// ============================================================================
// COMPOSANT NOUVEAU — LIVE HUB RETRACTABLE
// ============================================================================
class _CollapsibleLiveHub extends StatefulWidget {
  final AsyncValue<List<Map<String, dynamic>>> liveSessionsAsync;
  const _CollapsibleLiveHub({required this.liveSessionsAsync});

  @override
  State<_CollapsibleLiveHub> createState() => _CollapsibleLiveHubState();
}

class _CollapsibleLiveHubState extends State<_CollapsibleLiveHub> {
  bool _isExpanded = true;

  void _joinLive([Map<String, dynamic>? session]) {
    if (session == null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const LivePrepScreen()));
    } else {
      debugPrint("Rejoindre le canal Agora : ${session['channel_name']}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.liveSessionsAsync.value ?? const <Map<String, dynamic>>[];
    final count = sessions.length;

    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.cardRadius),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(),
      ),
      child: Column(
        children: [
          // En-tête cliquable pour réduire/étendre
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: _isExpanded ? const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rLg)) : BorderRadius.circular(ThixPolicy.rLg),
            child: Padding(
              padding: const EdgeInsets.all(ThixPolicy.s16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.sensors_rounded, color: ThixPolicy.danger, size: 20),
                  ),
                  const SizedBox(width: ThixPolicy.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Directs & Espaces', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ThixPolicy.textMain)),
                            if (count > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: ThixPolicy.danger, borderRadius: BorderRadius.circular(10)),
                                child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          count > 0 ? 'Sessions en cours' : 'Aucun direct',
                          style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  
                  // Bouton Lancer (visible même réduit)
                  ElevatedButton.icon(
                    onPressed: () => _joinLive(),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Lancer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixPolicy.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      minimumSize: const Size(80, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  Icon(_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: ThixPolicy.textSecondary),
                ],
              ),
            ),
          ),

          // Zone Rétractable
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: !_isExpanded
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: ThixPolicy.s16),
                    child: SizedBox(
                      height: 130,
                      child: widget.liveSessionsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)),
                        error: (_, __) => const Center(child: Text('Erreur de chargement', style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary))),
                        data: (list) {
                          if (list.isEmpty) {
                            return const Center(
                              child: Text('Les lives de votre réseau apparaîtront ici.', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13)),
                            );
                          }
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
                            itemBuilder: (context, i) {
                              final s = list[i];
                              final type = (s['session_type'] as String?) ?? 'video';
                              return _buildLiveCard(
                                title: (s['title'] as String?) ?? 'Direct sans titre',
                                host: (s['host_name'] as String?) ?? 'THIX',
                                type: type,
                                viewers: (s['viewer_count'] as int?) ?? 0,
                                color: type == 'video' ? ThixPolicy.primary : ThixPolicy.inkDeep,
                                onTap: () => _joinLive(s),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCard({required String title, required String host, required String type, required int viewers, required Color color, required VoidCallback onTap}) {
    final isVideo = type == 'video';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [color.withOpacity(0.85), color]),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            Positioned(right: -10, bottom: -10, child: Icon(isVideo ? Icons.videocam_rounded : Icons.mic_rounded, size: 80, color: Colors.white.withOpacity(0.15))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: ThixPolicy.danger, borderRadius: BorderRadius.circular(4)),
                        child: const Text('EN DIRECT', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.visibility_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                          Text(viewers.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, height: 1.2)),
                  const SizedBox(height: 4),
                  Text(host, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// STORIES (Design épuré type FB/LinkedIn)
// ============================================================================
class _FbStoryCard extends StatelessWidget {
  final bool isMe;
  final bool hasStory;
  final bool isLive;
  final String name;
  final String? coverUrl;
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _FbStoryCard({required this.isMe, required this.hasStory, this.isLive = false, required this.name, this.coverUrl, this.avatarUrl, required this.onTap, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: ThixPolicy.surface,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          border: Border.all(color: isLive ? ThixPolicy.danger : ThixPolicy.border, width: isLive ? 1.5 : 1),
        ),
        child: Stack(
          children: [
            // Cover Image
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                child: (coverUrl != null && coverUrl!.isNotEmpty)
                    ? Image.network(coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: ThixPolicy.tint))
                    : Container(color: ThixPolicy.tint),
              ),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.6)]),
                ),
              ),
            ),
            // Avatar
            Positioned(
              top: 8, left: 8,
              child: RoundAvatar(
                size: 32, imageUrl: avatarUrl, ringColor: hasStory || isMe ? ThixPolicy.primary : Colors.transparent, ringWidth: 2, isLive: isLive,
              ),
            ),
            // "Add" Button for current user
            if (isMe)
              Positioned(
                top: 24, left: 24,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.primary, border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ),
            // Name
            Positioned(
              bottom: 8, left: 8, right: 8,
              child: Text(
                name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
