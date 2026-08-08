// lib/presentation/network/network_pro_home.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/models/network_story.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'widgets/create_post_dialog.dart';
import 'widgets/create_story_dialog.dart';
import 'widgets/post_card.dart';
import 'widgets/story_viewer.dart';

// Import de l'écran Live
import 'package:thix_id/presentation/network/live/live_prep_screen.dart';

// ============================================================================
// PROVIDER — SESSIONS LIVE ACTIVES
// ============================================================================
// ⚠️ HYPOTHÈSE DE SCHÉMA À VÉRIFIER / AJUSTER :
// Table Supabase "live_sessions" avec colonnes :
//   id (text/uuid), host_id (text), host_name (text), host_avatar_url (text?),
//   title (text), session_type ('video' | 'audio'), viewer_count (int),
//   is_active (bool, true tant que le direct est en cours)
// Adapte le nom de la table et des colonnes à ton schéma réel
// (celui utilisé par live_stream_service.dart / live_broadcast_screen.dart).
final activeLiveSessionsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  try {
    return Supabase.instance.client
        .from('live_sessions')
        .stream(primaryKey: ['id'])
        .eq('status', 'live') // 🌟 CORRECTION ICI (au lieu de 'is_active', true)
        .limit(10);
  } catch (_) {
    return Stream.value(const <Map<String, dynamic>>[]);
  }
});


class ThixColors {
  static const background = Color(0xFFF6F7FB);
  static const white = Color(0xFFFFFFFF);
  static const primary = Color(0xFF2D6CDF);
  static const primaryDeep = Color(0xFF123B7A);
  static const navyDeep = Color(0xFF0A1F44);
  static const softBlue = Color(0xFFEAF1FF);
  static const steel = Color(0xFF64748B);
  static const textDark = Color(0xFF10192E);
  static const textSecondary = Color(0xFF7386A8);
  static const border = Color(0xFFE7EEFC);
  static const shadow = Color(0x142D6CDF);
  static const shadowDeep = Color(0x260A1F44);
  static const liveRed = Color(0xFFE5484D);

  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDeep, primaryDeep, primary],
  );
}

// ─────────────────────────────────────────────────────────────
// SIGNATURE VISUELLE : avatar rond avec anneau + indicateur LIVE
// ─────────────────────────────────────────────────────────────

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
    this.ringColor = ThixColors.primary,
    this.fallbackIcon = Icons.person,
    this.ringWidth = 2.5,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRingColor = isLive ? ThixColors.liveRed : ringColor;
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
              color: ThixColors.softBlue,
              child: (imageUrl != null && imageUrl!.isNotEmpty)
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        fallbackIcon,
                        size: size * 0.45,
                        color: ThixColors.primaryDeep,
                      ),
                    )
                  : Icon(
                      fallbackIcon,
                      size: size * 0.45,
                      color: ThixColors.primaryDeep,
                    ),
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
                  color: ThixColors.liveRed,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ThixColors.white, width: 1.2),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class NetworkProHome extends ConsumerStatefulWidget {
  const NetworkProHome({super.key});

  @override
  ConsumerState<NetworkProHome> createState() => _NetworkProHomeState();
}

class _NetworkProHomeState extends ConsumerState<NetworkProHome>
    with AutomaticKeepAliveClientMixin {
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

    if (pos.pixels >= pos.maxScrollExtent - 700 && !_isLoadingMore) {
      final notifier = ref.read(feedProvider.notifier);
      if (!ref.read(feedProvider).isLoading && notifier.hasMore) {
        _isLoadingMore = true;
        notifier.loadMore().whenComplete(() {
          if (mounted) _isLoadingMore = false;
        });
      }
    }

    final dir = pos.userScrollDirection;
    if (dir == ScrollDirection.reverse && _navVisible.value) {
      _navVisible.value = false;
    } else if (dir == ScrollDirection.forward && !_navVisible.value) {
      _navVisible.value = true;
    }
  }

  Future<void> _init() async {
    final now = DateTime.now();
    final needsRefresh = _lastRefreshTime == null ||
        now.difference(_lastRefreshTime!) > _refreshCooldown;

    await ref.read(feedProvider.notifier).loadFeed(
          feedType: _feedType,
          force: needsRefresh,
        );
    if (needsRefresh) _lastRefreshTime = now;

    await Future.wait([_loadStories(), _loadSuggestions()]);
  }

  Future<void> _loadStories() async {
    try {
      final data = await ref.read(networkServiceProvider).getActiveStories();
      if (mounted) {
        setState(() {
          _stories = data;
          _loadingStories = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStories = false);
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final data = await ref
          .read(networkServiceProvider)
          .getSuggestedConnections(limit: 8);
      if (mounted) setState(() => _suggestions = data);
    } catch (_) {}
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    await ref
        .read(feedProvider.notifier)
        .loadFeed(feedType: _feedType, force: true);
    _lastRefreshTime = DateTime.now();
    await Future.wait([_loadStories(), _loadSuggestions()]);
    ref.invalidate(activeLiveSessionsProvider);
  }

  Future<void> _openCreateStory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const CreateStoryDialog(),
    );
    if (ok == true && mounted) {
      HapticFeedback.mediumImpact();
      await _loadStories();
    }
  }

  void _safePush(String path) {
    if (!mounted) return;
    try {
      context.push(path);
    } catch (e) {
      debugPrint('nav: $e');
    }
  }

  Future<void> _openComments(String postId) async {
    _safePush('/network/comments/$postId');
  }

    void _joinLive([Map<String, dynamic>? session]) {
    if (session == null) {
      // Cas 1 : On clique sur le bouton "Lancer" -> On va préparer son propre direct
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LivePrepScreen()),
      );
    } else {
      // Cas 2 : On clique sur la carte d'un direct en cours -> On rejoint en tant que Spectateur
      final channelName = session['channel_name'] as String?;
      final liveId = session['id'].toString();
      
      if (channelName != null) {
        // 🌟 À FAIRE : Naviguer vers un écran LiveViewerScreen (Spectateur)
        // en lui passant le channelName pour qu'Agora s'y connecte sans allumer la caméra
        debugPrint("Rejoindre le canal Agora : $channelName");
      }
    }
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
        backgroundColor: ThixColors.background,
        body: Center(
          child: CircularProgressIndicator(color: ThixColors.primary),
        ),
      );
    }

    // Immunise cette page contre les réglages de taille de police système.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(1.0),
      ),
      child: Scaffold(
        backgroundColor: ThixColors.background,
        body: Stack(
          children: [
            RefreshIndicator(
              color: ThixColors.primary,
              backgroundColor: ThixColors.white,
              onRefresh: _onRefresh,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  _buildSliverAppBar(isLive: liveHostIds.contains(currentUser.id)),
                  SliverToBoxAdapter(
                    child: _buildStoriesFacebook(currentUser.id, liveHostIds),
                  ),
                  SliverToBoxAdapter(child: _buildFilters()),

                  // HUB DIRECTS & ESPACES — connecté aux vrais directs
                  SliverToBoxAdapter(child: _buildLiveHub(liveSessionsAsync)),

                  if (_suggestions.isNotEmpty)
                    SliverToBoxAdapter(child: _buildSuggestions(liveHostIds)),
                  feedAsync.when(
                    loading: () =>
                        SliverToBoxAdapter(child: _buildShimmerFeed()),
                    error: (e, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'Erreur: $e',
                            style: const TextStyle(
                              color: ThixColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    data: (posts) {
                      if (posts.isEmpty) {
                        return SliverToBoxAdapter(child: _buildEmpty());
                      }
                      return SliverList.builder(
                        itemCount: posts.length,
                        itemBuilder: (c, i) {
                          final post = posts[i];
                          return PostCard(
                            key: ValueKey(post.id),
                            post: post,
                            currentProfileId: currentUser.id,
                            onLike: null,
                            onComment: () => _openComments(post.id),
                            onShare: () => _showShareSheet(post),
                            onDelete: () => ref
                                .read(feedProvider.notifier)
                                .deletePost(post.id),
                            onRefresh: null,
                          );
                        },
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _navVisible,
              builder: (context, visible, _) => Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomNav(visible),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── APP BAR ───────────────────────────

  Widget _buildSliverAppBar({required bool isLive}) {
    return SliverAppBar(
      backgroundColor: ThixColors.white,
      elevation: 0,
      scrolledUnderElevation: 3,
      shadowColor: ThixColors.shadowDeep,
      floating: true,
      snap: true,
      toolbarHeight: 58,
      titleSpacing: 16,
      title: ShaderMask(
        shaderCallback: (b) => ThixColors.gradientPrimary.createShader(b),
        child: const Text(
          'THIX PRO',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 17,
            letterSpacing: -0.4,
          ),
        ),
      ),
      actions: [
        _appBarIcon(
          icon: Icons.search_rounded,
          onTap: () => _safePush('/network/search'),
        ),
        const SizedBox(width: 8),
        _appBarIcon(
          icon: Icons.notifications_none_rounded,
          onTap: () => _safePush('/network/notifications'),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: GestureDetector(
            onTap: () => _safePush('/profile'),
            child: RoundAvatar(size: 34, ringWidth: 2.2, isLive: isLive),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: ThixColors.border),
      ),
    );
  }

  Widget _appBarIcon({
    required IconData icon,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: ThixColors.softBlue,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 19, color: ThixColors.primaryDeep),
            if (badge != null)
              Positioned(
                top: 5,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: ThixColors.liveRed,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ThixColors.white, width: 1.5),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
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
        color: ThixColors.white,
        height: 168,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: ThixColors.primary),
        ),
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
      color: ThixColors.white,
      padding: const EdgeInsets.only(top: 12, bottom: 14),
      child: SizedBox(
        height: 152,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: otherUsersList.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (c, i) {
            if (i == 0) {
              return _FbStoryCard(
                isMe: true,
                hasStory: myStories.isNotEmpty,
                isLive: liveHostIds.contains(currentUserId),
                name: myStories.isNotEmpty ? 'Votre story' : 'Créer',
                coverUrl: myStories.isNotEmpty
                    ? (myStories.first.imageUrl.isNotEmpty ? myStories.first.imageUrl : myStories.first.userAvatar)
                    : null,
                avatarUrl: myStories.isNotEmpty ? myStories.first.userAvatar : null,
                onTap: myStories.isNotEmpty
                    ? () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => StoryViewer(stories: myStories, initialIndex: 0),
                        ));
                      }
                    : _openCreateStory,
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
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => StoryViewer(stories: userStories, initialIndex: 0),
                ));
              },
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
      color: ThixColors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.entries.map((e) {
            final sel = _feedType == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 9),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  if (sel) return;
                  setState(() => _feedType = e.key);
                  ref
                      .read(feedProvider.notifier)
                      .loadFeed(feedType: e.key, force: true);
                  _lastRefreshTime = DateTime.now();
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        sel ? ThixColors.softBlue : ThixColors.background,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: sel ? ThixColors.primary : ThixColors.border,
                      width: sel ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        e.value.$2,
                        size: 16,
                        color: sel
                            ? ThixColors.primaryDeep
                            : ThixColors.textSecondary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        e.value.$1,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: sel
                              ? ThixColors.primaryDeep
                              : ThixColors.textDark,
                        ),
                      ),
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

  // ─────────────────────────── HUB DIRECTS & ESPACES ───────────────────────────

  Widget _buildLiveHub(AsyncValue<List<Map<String, dynamic>>> liveSessionsAsync) {
    final sessions = liveSessionsAsync.value ?? const <Map<String, dynamic>>[];
    final count = sessions.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThixColors.border),
        boxShadow: const [
          BoxShadow(
            color: ThixColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const RoundAvatar(size: 44, ringWidth: 2.5),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Directs & Espaces',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: ThixColors.textDark,
                            ),
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: ThixColors.liveRed,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      count > 0
                          ? 'Rejoignez les sessions en cours'
                          : 'Aucun direct en ce moment',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: ThixColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _joinLive(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: ThixColors.liveRed,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.sensors_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Lancer',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          SizedBox(
            height: 120,
            child: liveSessionsAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ThixColors.primary),
                ),
              ),
              error: (_, __) => const Center(
                child: Text(
                  'Impossible de charger les directs',
                  style: TextStyle(fontSize: 12, color: ThixColors.textSecondary),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sensors_off_rounded, size: 26, color: ThixColors.textSecondary.withOpacity(0.5)),
                        const SizedBox(height: 6),
                        const Text(
                          'Aucun direct en cours',
                          style: TextStyle(fontSize: 12, color: ThixColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final s = list[i];
                    final type = (s['session_type'] as String?) ?? 'video';
                    return _buildLiveCard(
                      title: (s['title'] as String?) ?? 'Direct sans titre',
                      host: (s['host_name'] as String?) ?? 'THIX',
                      type: type,
                      viewers: (s['viewer_count'] as int?) ?? 0,
                      color: type == 'video' ? ThixColors.primary : ThixColors.navyDeep,
                      onTap: () => _joinLive(s),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCard({
    required String title,
    required String host,
    required String type,
    required int viewers,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isVideo = type == 'video';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 145,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [color.withOpacity(0.85), color],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                isVideo ? Icons.videocam_rounded : Icons.mic_rounded,
                size: 75,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
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
                        decoration: BoxDecoration(
                          color: ThixColors.liveRed,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'EN DIRECT',
                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.visibility_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            viewers.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── SUGGESTIONS ───────────────────────────

  Widget _buildSuggestions(Set<String> liveHostIds) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 14),
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: ThixColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Personnes à découvrir',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: ThixColors.textDark,
                  ),
                ),
                Icon(Icons.groups_2_rounded,
                    size: 18, color: ThixColors.primary),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 172,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (c, i) {
                final u = _suggestions[i];
                return Container(
                  width: 132,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThixColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ThixColors.border),
                  ),
                  child: Column(
                    children: [
                      RoundAvatar(
                        size: 54,
                        imageUrl: u.avatar,
                        ringWidth: 2.5,
                        isLive: liveHostIds.contains(u.id),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        u.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: ThixColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        u.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: ThixColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 30,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: ThixColors.gradientPrimary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () async {
                              await ref
                                  .read(networkServiceProvider)
                                  .sendConnectionRequest(u.id);
                              setState(() => _suggestions.remove(u));
                            },
                            child: const Text(
                              'Se connecter',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
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
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    height: 62,
                    decoration: BoxDecoration(
                      color: ThixColors.white.withOpacity(0.86),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: ThixColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: ThixColors.shadowDeep,
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _navBtn(
                          Icons.home_rounded,
                          'Accueil',
                          true,
                          () => _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                        ),
                        _navBtn(
                          Icons.explore_outlined,
                          'Découvrir',
                          false,
                          () => _safePush('/network/discover'),
                        ),
                        _navBtn(
                          Icons.add_circle_outline_rounded,
                          'Publier',
                          false,
                          () => showDialog(
                            context: context,
                            builder: (_) => const CreatePostDialog(),
                          ),
                        ),
                        _navBtn(
                          Icons.groups_outlined,
                          'Réseau',
                          false,
                          () => _safePush('/network/connections'),
                        ),
                        _navBtn(
                          Icons.mail_outline_rounded,
                          'Message',
                          false,
                          () => _safePush('/messages'),
                        ),
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

  Widget _navBtn(
    IconData ic,
    String label,
    bool active,
    VoidCallback tap,
  ) {
    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ic,
              size: 20,
              color: active ? ThixColors.primary : ThixColors.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: active ? ThixColors.primary : ThixColors.textSecondary,
              ),
            ),
            if (active)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: ThixColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerFeed() {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          height: 190,
          decoration: BoxDecoration(
            color: ThixColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ThixColors.border),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: ThixColors.softBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.feed_outlined,
              size: 40,
              color: ThixColors.primaryDeep,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune publication pour ce filtre',
            style: TextStyle(
              color: ThixColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              gradient: ThixColors.gradientPrimary,
              borderRadius: BorderRadius.circular(30),
            ),
            child: TextButton(
              onPressed: _onRefresh,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Actualiser',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showShareSheet(dynamic post) {
    final id = '${post.id}';
    final link =
        'https://depot-data-thix-central.github.io/sona1/network/post/$id';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ThixColors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ThixColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              ListTile(
                leading:
                    const Icon(Icons.link, color: ThixColors.primary),
                title: const Text('Copier le lien'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  try {
                    await ref.read(networkServiceProvider).sharePost(id);
                  } catch (_) {}
                  if (mounted) Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lien copié')),
                    );
                  }
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.close, color: ThixColors.textSecondary),
                title: const Text('Fermer'),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STORY CARD
// ─────────────────────────────────────────────────────────────

class _FbStoryCard extends StatelessWidget {
  final bool isMe;
  final bool hasStory;
  final bool isLive;
  final String name;
  final String? coverUrl;
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  const _FbStoryCard({
    required this.isMe,
    required this.hasStory,
    this.isLive = false,
    required this.name,
    this.coverUrl,
    this.avatarUrl,
    required this.onTap,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: ThixColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isLive ? ThixColors.liveRed : ThixColors.border,
            width: isLive ? 1.4 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: ThixColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: (coverUrl != null && coverUrl!.isNotEmpty)
                        ? Image.network(
                            coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: ThixColors.softBlue),
                          )
                        : Container(color: ThixColors.softBlue),
                  ),
                ),
                Positioned(
                  top: -6,
                  left: -6,
                  child: RoundAvatar(
                    size: 26,
                    imageUrl: avatarUrl,
                    ringColor: hasStory || isMe
                        ? ThixColors.primary
                        : ThixColors.border,
                    ringWidth: 2,
                    isLive: isLive,
                  ),
                ),
                if (isMe)
                  Positioned(
                    bottom: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ThixColors.primary,
                          border: Border.all(color: ThixColors.white, width: 2),
                        ),
                        child: const Icon(Icons.add_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                if (isLive)
                  Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ThixColors.liveRed,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ThixColors.textDark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
