import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/models/network_story.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';
import 'package:thix_id/features/network/presentation/providers/feed_provider.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'widgets/create_post_dialog.dart';
import 'widgets/create_story_dialog.dart';
import 'widgets/post_card.dart';
import 'widgets/story_viewer.dart';

class ThixColors {
  static const background = Color(0xFFF6F7FB);
  static const white = Color(0xFFFFFFFF);
  static const primary = Color(0xFF2D6CDF);
  static const primaryDeep = Color(0xFF123B7A);
  static const navyDeep = Color(0xFF0A1F44);
  static const softBlue = Color(0xFFEAF1FF);
  static const gold = Color(0xFFE3B23C);
  static const goldLight = Color(0xFFF3D999);
  static const textDark = Color(0xFF10192E);
  static const textSecondary = Color(0xFF7386A8);
  static const border = Color(0xFFE7EEFC);
  static const shadow = Color(0x142D6CDF);
  static const shadowDeep = Color(0x260A1F44);

  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDeep, primaryDeep, primary],
  );

  static const gradientGold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, goldLight],
  );

  static const gradientStoryRing = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDeep, gold],
  );
}

class NetworkProHome extends ConsumerStatefulWidget {
  const NetworkProHome({super.key});
  @override
  ConsumerState<NetworkProHome> createState() => _NetworkProHomeState();
}

class _NetworkProHomeState extends ConsumerState<NetworkProHome> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _navVisible = ValueNotifier(true);
  
  // --- Chrono pour éviter le mixage permanent du fil ---
  static DateTime? _lastRefreshTime;
  static const _refreshCooldown = Duration(seconds: 60);

  String _feedType = 'all';

  List<NetworkStory> _stories = [];
  bool _loadingStories = true;
  List<dynamic> _suggestions = [];
  bool _isLoadingMore = false;

  @override bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 700 && !_isLoadingMore) {
      final notifier = ref.read(feedProvider.notifier);
      if (!ref.read(feedProvider).isLoading && notifier.hasMore) {
        _isLoadingMore = true;
        notifier.loadMore().whenComplete(() => _isLoadingMore = false);
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
    
    // On vérifie si 60 secondes se sont écoulées depuis le dernier refresh
    final needsRefresh = _lastRefreshTime == null ||
        now.difference(_lastRefreshTime!) > _refreshCooldown;

    if (needsRefresh) {
      await ref.read(feedProvider.notifier).loadFeed(feedType: _feedType, force: true);
      _lastRefreshTime = now;
    } else {
      await ref.read(feedProvider.notifier).loadFeed(feedType: _feedType, force: false);
    }
    
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
    
    // Le pull-to-refresh force TOUJOURS la mise à jour
    await ref.read(feedProvider.notifier).loadFeed(feedType: _feedType, force: true);
    
    // On réinitialise le chrono
    _lastRefreshTime = DateTime.now();
    
    await Future.wait([_loadStories(), _loadSuggestions()]);
  }

  Future<void> _openCreateStory() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const CreateStoryDialog());
    if (ok == true && mounted) {
      HapticFeedback.mediumImpact();
      await _loadStories();
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

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: ThixColors.background,
        body: Center(child: CircularProgressIndicator(color: ThixColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: ThixColors.background,
      body: Stack(
        children: [
          RefreshIndicator(
            color: ThixColors.primary,
            backgroundColor: ThixColors.white,
            onRefresh: _onRefresh,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                _buildSliverAppBar(),
                // "Mes status" (Votre story) est toujours la première case du carrousel
                SliverToBoxAdapter(child: _buildStories(currentUser.id)),
                SliverToBoxAdapter(child: _buildFilters()),
                SliverToBoxAdapter(child: _buildCreatePostBar()),
                if (_suggestions.isNotEmpty)
                  SliverToBoxAdapter(child: _buildSuggestions()),
                feedAsync.when(
                  loading: () => SliverToBoxAdapter(child: _buildShimmerFeed()),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text('Erreur: $e', style: const TextStyle(color: ThixColors.textSecondary)),
                      ),
                    ),
                  ),
                  data: (posts) {
                    if (posts.isEmpty) return SliverToBoxAdapter(child: _buildEmpty());
                    return SliverList.builder(
                      itemCount: posts.length,
                      itemBuilder: (c, i) {
                        final post = posts[i];
                        return PostCard(
                          key: ValueKey(post.id),
                          post: post,
                          currentProfileId: currentUser.id,
                          onLike: () => ref.read(feedProvider.notifier).toggleLike(post.id),
                          onComment: () => context.push('/network/comments/${post.id}'),
                          onShare: () => _showShareSheet(post),
                          onDelete: () => ref.read(feedProvider.notifier).loadFeed(force: true),
                          onRefresh: () => ref.read(feedProvider.notifier).loadFeed(force: true),
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
              left: 0, right: 0, bottom: 0,
              child: _buildBottomNav(visible),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── APP BAR ───────────────────────────

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: ThixColors.white,
      elevation: 0,
      scrolledUnderElevation: 3,
      shadowColor: ThixColors.shadowDeep,
      floating: true,
      snap: true,
      toolbarHeight: 58,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (b) => ThixColors.gradientPrimary.createShader(b),
            child: const Text(
              'THIX PRO',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.4),
            ),
          ),
          const SizedBox(width: 6),
          Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: ThixColors.gradientGold)),
        ],
      ),
      actions: [
        _appBarIcon(icon: Icons.search_rounded, onTap: () => context.push('/network/search')),
        const SizedBox(width: 8),
        _appBarIcon(
          icon: Icons.notifications_none_rounded,
          badge: '3',
          onTap: () => context.push('/network/notifications'),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: ThixColors.gradientStoryRing),
              child: const CircleAvatar(radius: 15, backgroundColor: ThixColors.softBlue, child: Icon(Icons.person, size: 16, color: ThixColors.primaryDeep)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _appBarIcon({required IconData icon, required VoidCallback onTap, String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: const BoxDecoration(color: ThixColors.softBlue, shape: BoxShape.circle),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 19, color: ThixColors.primaryDeep),
            if (badge != null)
              Positioned(
                top: 5, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(gradient: ThixColors.gradientGold, borderRadius: BorderRadius.circular(20), border: Border.all(color: ThixColors.white, width: 1.5)),
                  child: Text(badge, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: ThixColors.navyDeep)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── STORIES ───────────────────────────

  Widget _buildStories(String currentUserId) {
    if (_loadingStories) {
      return const SizedBox(
        height: 124,
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: ThixColors.primary))),
      );
    }
    final myStories = _stories.where((s) => s.userId == currentUserId).toList();
    final otherStories = _stories.where((s) => s.userId != currentUserId).toList();
    return Container(
      color: ThixColors.white,
      height: 124,
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: otherStories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (c, i) {
          if (i == 0) {
            return _MyStoryItem(
              hasStory: myStories.isNotEmpty,
              avatarUrl: myStories.isNotEmpty ? myStories.first.userAvatar : null,
              onView: myStories.isNotEmpty
                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewer(stories: myStories, initialIndex: 0)))
                  : _openCreateStory,
              onAdd: _openCreateStory,
            );
          }
          final s = otherStories[i - 1];
          return _StoryItem(
            story: s,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewer(stories: otherStories, initialIndex: i - 1))),
          );
        },
      ),
    );
  }

  // ─────────────────────────── FILTRES ───────────────────────────

  Widget _buildFilters() {
    final filters = {
      'all': ('Tous', Icons.public_rounded),
      'network': ('Pour vous', Icons.auto_awesome_rounded),
      'popular': ('Tendance', Icons.local_fire_department_rounded),
      'recent': ('Réseau', Icons.people_alt_rounded),
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
                  // Changement de filtre = on force le refresh et on relance le chrono
                  ref.read(feedProvider.notifier).loadFeed(feedType: e.key, force: true);
                  _lastRefreshTime = DateTime.now();
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? ThixColors.softBlue : ThixColors.background,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: sel ? ThixColors.primary : ThixColors.border, width: sel ? 1.4 : 1),
                  ),
                  child: Row(children: [
                    Icon(e.value.$2, size: 16, color: sel ? ThixColors.primaryDeep : ThixColors.textSecondary),
                    const SizedBox(width: 7),
                    Text(e.value.$1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? ThixColors.primaryDeep : ThixColors.textDark)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────── CREATE POST ───────────────────────────

  Widget _buildCreatePostBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: ThixColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThixColors.border),
        boxShadow: const [BoxShadow(color: ThixColors.shadow, blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: ThixColors.gradientStoryRing),
            child: const CircleAvatar(radius: 19, backgroundColor: ThixColors.softBlue, child: Icon(Icons.person, size: 19, color: ThixColors.primaryDeep)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => showDialog(context: context, builder: (_) => const CreatePostDialog())
                  .then((v) { if (v == true) ref.read(feedProvider.notifier).loadFeed(force: true); }),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: ThixColors.background, borderRadius: BorderRadius.circular(30)),
                alignment: Alignment.centerLeft,
                child: const Text('Quoi de neuf, pro ?', style: TextStyle(color: ThixColors.textSecondary, fontSize: 13.5)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: ThixColors.border),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _quickAction(Icons.image_rounded, 'Photo', ThixColors.primary),
          _quickAction(Icons.videocam_rounded, 'Vidéo', ThixColors.gold),
          _quickAction(Icons.sensors_rounded, 'Live', const Color(0xFFE0453C)),
        ]),
      ]),
    );
  }

  Widget _quickAction(IconData icon, String label, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showDialog(context: context, builder: (_) => const CreatePostDialog())
          .then((v) { if (v == true) ref.read(feedProvider.notifier).loadFeed(force: true); }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThixColors.textSecondary)),
        ]),
      ),
    );
  }

  // ─────────────────────────── SUGGESTIONS ───────────────────────────

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 14),
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: ThixColors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Personnes à découvrir', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: ThixColors.textDark)),
            Icon(Icons.groups_2_rounded, size: 18, color: ThixColors.gold),
          ]),
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
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: ThixColors.gradientStoryRing),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: ThixColors.softBlue,
                      backgroundImage: u.avatar != null ? NetworkImage(u.avatar!) : null,
                      child: u.avatar == null ? const Icon(Icons.person, color: ThixColors.primaryDeep) : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThixColors.textDark)),
                  const SizedBox(height: 2),
                  Text(u.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: ThixColors.textSecondary)),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 30,
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: ThixColors.gradientPrimary, borderRadius: BorderRadius.circular(20)),
                      child: TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        onPressed: () async {
                          await ref.read(networkServiceProvider).sendConnectionRequest(u.id);
                          setState(() => _suggestions.remove(u));
                        },
                        child: const Text('Suivre', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
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
              child: SizedBox(
                height: 58,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: ThixColors.white.withValues(alpha: 0.86),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: ThixColors.border),
                            boxShadow: const [BoxShadow(color: ThixColors.shadowDeep, blurRadius: 20, offset: Offset(0, 8))],
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _navBtn(Icons.home_rounded, 'Accueil', true, () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
                            _navBtn(Icons.explore_outlined, 'Découvrir', false, () => context.push('/network/discover')),
                            const SizedBox(width: 46),
                            _navBtn(Icons.groups_outlined, 'Réseau', false, () => context.push('/network/connections')),
                            _navBtn(Icons.person_outline, 'Profil', false, () => context.push('/profile')),
                          ]),
                        ),
                      ),
                    ),
                    Positioned(top: -14, child: _buildFab()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFab() {
    return Container(
      width: 54, height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ThixColors.gradientPrimary,
        boxShadow: [
          BoxShadow(color: ThixColors.primary.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 1, offset: const Offset(0, 6)),
        ],
        border: Border.all(color: ThixColors.white, width: 3),
      ),
      child: FloatingActionButton(
        elevation: 0,
        backgroundColor: Colors.transparent,
        onPressed: () => showDialog(context: context, builder: (_) => const CreatePostDialog())
            .then((v) { if (v == true) ref.read(feedProvider.notifier).loadFeed(force: true); }),
        child: const Icon(Icons.add_rounded, size: 26, color: Colors.white),
      ),
    );
  }

  Widget _navBtn(IconData ic, String label, bool active, VoidCallback tap) {
    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(ic, size: 20, color: active ? ThixColors.primary : ThixColors.textSecondary),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: active ? ThixColors.primary : ThixColors.textSecondary)),
          if (active)
            Container(margin: const EdgeInsets.only(top: 2), width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: ThixColors.gradientGold)),
        ]),
      ),
    );
  }

  // ─────────────────────────── ETATS ───────────────────────────

  Widget _buildShimmerFeed() {
    return Column(
      children: List.generate(3, (i) => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        height: 190,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [ThixColors.white, ThixColors.softBlue.withValues(alpha: 0.4), ThixColors.white]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThixColors.border),
        ),
      )),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: ThixColors.softBlue, shape: BoxShape.circle),
          child: const Icon(Icons.feed_outlined, size: 40, color: ThixColors.primaryDeep),
        ),
        const SizedBox(height: 16),
        const Text('Aucune publication pour ce filtre', style: TextStyle(color: ThixColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(gradient: ThixColors.gradientPrimary, borderRadius: BorderRadius.circular(30)),
          child: TextButton(
            onPressed: _onRefresh,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            child: const Text('Actualiser', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  void _showShareSheet(post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: ThixColors.white, borderRadius: BorderRadius.circular(20)),
          child: Wrap(children: [
            const SizedBox(height: 10),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixColors.border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 8),
            ListTile(leading: const Icon(Icons.link, color: ThixColors.primary), title: const Text('Copier le lien'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.share, color: ThixColors.primary), title: const Text('Partager'), onTap: () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
  }
}

class _MyStoryItem extends StatelessWidget {
  final bool hasStory;
  final String? avatarUrl;
  final VoidCallback onView;
  final VoidCallback onAdd;
  const _MyStoryItem({required this.hasStory, required this.avatarUrl, required this.onView, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onView,
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          hasStory
              ? Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: ThixColors.gradientStoryRing),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: ThixColors.softBlue,
                    backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty ? NetworkImage(avatarUrl!) : null,
                  ),
                )
              : Container(
                  width: 66, height: 66,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ThixColors.softBlue, border: Border.all(color: ThixColors.border, width: 1.5)),
                  child: const Icon(Icons.person, size: 28, color: ThixColors.primaryDeep),
                ),
          Positioned(
            bottom: -2, right: -2,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: ThixColors.gradientGold, border: Border.all(color: ThixColors.white, width: 2.5)),
                child: const Icon(Icons.add_rounded, size: 15, color: ThixColors.navyDeep),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(hasStory ? 'Votre story' : 'Ajouter', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ThixColors.textDark)),
      ]),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final NetworkStory story;
  final VoidCallback onTap;
  const _StoryItem({required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: ThixColors.gradientStoryRing),
          child: CircleAvatar(
            radius: 30,
            backgroundColor: ThixColors.softBlue,
            backgroundImage: story.userAvatar != null ? NetworkImage(story.userAvatar!) : null,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 68,
          child: Text(
            story.userName.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ThixColors.textDark),
          ),
        ),
      ]),
    );
  }
}
