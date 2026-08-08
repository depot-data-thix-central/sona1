import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Import de la Policy de Design
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../providers/education_provider.dart' hide certificatesProvider;
import '../providers/certificate_provider.dart';
import '../widgets/common/education_category_chip.dart';
import '../widgets/common/formation_card.dart';
import '../widgets/common/edu_image.dart';
import '../models/category.dart';
import '../models/formation.dart';
import '../models/certificate.dart';

final _eduTabIndexProvider = StateProvider<int>((ref) => 0);

final _unreadNotificationsProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider).value;
  if (userId == null) return 0;
  try {
    final res = await Supabase.instance.client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (res as List).length;
  } catch (_) {
    return 0;
  }
});

class EducationHome extends ConsumerWidget {
  const EducationHome({super.key});

  static const _titles = ['Accueil', 'Mes cours', 'Apprendre', 'Certificats', 'Bibliothèque', 'Profil'];
  static const _navIcons = [
    Icons.home_rounded,
    Icons.menu_book_rounded,
    Icons.school_rounded,
    Icons.workspace_premium_rounded,
    Icons.library_books_rounded,
    Icons.person_rounded,
  ];
  static const _pages = [
    _HomePage(),
    _MyLearningPage(),
    _AllFormationsPage(),
    _CertificatesPage(),
    _LibraryPage(),
    _ProfilePage(),
  ];

  void _openMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 20),
            _MenuTile(icon: Icons.card_giftcard_rounded, label: 'Cours gratuits', color: ThixPolicy.success, onTap: () {
              Navigator.pop(context);
              context.push('/education/free-courses');
            }),
            _MenuTile(icon: Icons.videocam_rounded, label: 'Webinaires', color: ThixPolicy.primary, onTap: () {
              Navigator.pop(context);
              context.push('/education/webinars');
            }),
            _MenuTile(icon: Icons.groups_rounded, label: 'Mentorat', color: ThixPolicy.warning, onTap: () {
              Navigator.pop(context);
              context.push('/education/mentorat');
            }),
            _MenuTile(icon: Icons.event_rounded, label: 'Événements', color: ThixPolicy.primaryDeep, onTap: () {
              Navigator.pop(context);
              context.push('/education/events');
            }),
            _MenuTile(icon: Icons.support_agent_rounded, label: 'Aide & support', color: ThixPolicy.textSecondary, onTap: () {
              Navigator.pop(context);
              context.push('/education/help');
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(_eduTabIndexProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final unreadAsync = ref.watch(_unreadNotificationsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Row(
                children: [
                  _IconBtn(icon: Icons.menu_rounded, onTap: () => _openMoreMenu(context)),
                  const SizedBox(width: 10),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(gradient: ThixPolicy.brandGradient, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedIndex == 0 ? 'THIX FORMATION' : _titles[selectedIndex].toUpperCase(),
                          style: const TextStyle(color: ThixPolicy.textMain, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        if (selectedIndex == 0)
                          const Text(
                            'Apprenez. Progressez. Réussissez.',
                            style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 11.5),
                          ),
                      ],
                    ),
                  ),
                  _IconBtn(icon: Icons.search_rounded, onTap: () => context.push('/education/search')),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _IconBtn(icon: Icons.notifications_none_rounded, onTap: () => context.push('/notifications')),
                      unreadAsync.maybeWhen(
                        data: (count) => count > 0
                            ? Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle),
                                  child: Text(
                                    count > 9 ? '9+' : '$count',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => ref.read(_eduTabIndexProvider.notifier).state = 5,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: ThixPolicy.tint,
                      backgroundImage: user?.userMetadata?['avatar_url'] != null
                          ? NetworkImage(user!.userMetadata!['avatar_url'])
                          : null,
                      child: user?.userMetadata?['avatar_url'] == null
                          ? const Icon(Icons.person_rounded, color: ThixPolicy.primaryDeep, size: 18)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(index: selectedIndex, children: _pages),
      bottomNavigationBar: _BottomNav(selectedIndex: selectedIndex),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 44.0,
        height: 44.0,
        child: Icon(icon, color: ThixPolicy.primaryDeep, size: 22),
      ),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  final int selectedIndex;
  const _BottomNav({required this.selectedIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: ThixPolicy.shadowCard()),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(EducationHome._titles.length, (i) {
              final isCenter = i == 2;
              final isSelected = selectedIndex == i;
              return isCenter
                  ? GestureDetector(
                      onTap: () => ref.read(_eduTabIndexProvider.notifier).state = i,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: ThixPolicy.brandGradient,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: ThixPolicy.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(height: 2),
                          Text(EducationHome._titles[i], style: const TextStyle(fontSize: 9, color: ThixPolicy.primary, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    )
                  : InkWell(
                      onTap: () => ref.read(_eduTabIndexProvider.notifier).state = i,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(EducationHome._navIcons[i], color: isSelected ? ThixPolicy.primary : ThixPolicy.textSecondary, size: 20),
                            const SizedBox(height: 2),
                            Text(
                              EducationHome._titles[i],
                              style: TextStyle(
                                fontSize: 9,
                                color: isSelected ? ThixPolicy.primary : ThixPolicy.textSecondary,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
            }),
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
          ],
        ),
      ),
    );
  }
}

// ============================== ACCUEIL ==============================

class _HomePage extends ConsumerStatefulWidget {
  const _HomePage();
  @override
  ConsumerState<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<_HomePage> with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
      ref.read(formationsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final formationsAsync = ref.watch(formationsProvider);
    final userId = ref.watch(currentUserIdProvider).value;

    return formationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      error: (_, __) => const Center(child: Text('Une erreur est survenue.', style: TextStyle(color: ThixPolicy.textSecondary))),
      data: (paginated) {
        final formations = paginated.items;
        
        // 🌟 NOUVEAU : Récupération dynamique des 5 dernières formations
        final recentFormations = formations.take(5).toList();
        
        final recommended = [...formations]..sort((a, b) => b.rating.compareTo(a.rating));

        return RefreshIndicator(
          color: ThixPolicy.primary,
          backgroundColor: Colors.white,
          onRefresh: () async {
            ref.invalidate(formationsProvider);
            ref.invalidate(categoriesProvider);
            if (userId != null) ref.invalidate(myEnrollmentsProvider(userId));
          },
          child: CustomScrollView(
            controller: _scrollController,
            cacheExtent: 600,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🌟 On passe la liste dynamique au HeroCarousel
                    Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: _HeroCarousel(recentFormations: recentFormations)),
                    const SizedBox(height: 18),
                    const _QuickActionsRow(),
                    const SizedBox(height: 22),
                    _SectionHeader(title: 'Catégories', onSeeAll: () => ref.read(_eduTabIndexProvider.notifier).state = 2),
                    const SizedBox(height: 10),
                    categoriesAsync.when(
                      data: (cats) => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            EducationCategoryChip(
                              label: 'Tous',
                              isSelected: ref.read(formationsProvider.notifier).currentCategory == null,
                              onTap: () => ref.read(formationsProvider.notifier).filterByCategory(null),
                            ),
                            ...cats.map((cat) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: EducationCategoryChip(
                                    label: cat.name,
                                    isSelected: ref.read(formationsProvider.notifier).currentCategory == cat.id,
                                    onTap: () => ref.read(formationsProvider.notifier).filterByCategory(cat.id),
                                  ),
                                )),
                          ],
                        ),
                      ),
                      loading: () => const SizedBox(height: 36),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 22),
                    if (recommended.isNotEmpty) ...[
                      _SectionHeader(title: 'Recommandées pour vous', onSeeAll: () => ref.read(_eduTabIndexProvider.notifier).state = 2),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 230,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: recommended.length > 8 ? 8 : recommended.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, i) {
                            final f = recommended[i];
                            return SizedBox(
                              width: 150,
                              child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}')),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    if (userId != null)
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _ProgressRow(userId: userId)),
                    const SizedBox(height: 22),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _SectionHeader(title: 'Toutes les formations'),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              SylvainPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.70,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (c, i) {
                      if (i >= formations.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final f = formations[i];
                      return FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}'));
                    },
                    childCount: formations.length + (paginated.hasMore ? 1 : 0),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        );
      },
    );
  }
}

class SylvainPadding extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget sliver;
  const SylvainPadding({required this.padding, required this.sliver});
  @override
  Widget build(BuildContext context) => SliverPadding(padding: padding, sliver: sliver);
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: const Text('Voir tout', style: TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
      ],
    );
  }
}

// ============================== HERO (DYNAMIQUE) ==============================

class _HeroCarousel extends StatefulWidget {
  final List<Formation> recentFormations;
  const _HeroCarousel({required this.recentFormations});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> with WidgetsBindingObserver {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.recentFormations.length <= 1) return;
    
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || !_controller.hasClients) return;
      _page = (_page + 1) % widget.recentFormations.length;
      _controller.animateToPage(_page, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recentFormations.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.recentFormations.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final f = widget.recentFormations[i];
              return GestureDetector(
                onTap: () => context.push('/education/formation/${f.id}'),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    gradient: ThixPolicy.heroGradient, 
                    borderRadius: BorderRadius.circular(20),
                    image: f.imageUrl != null 
                        ? DecorationImage(
                            image: NetworkImage(f.imageUrl!),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.55), BlendMode.darken),
                          )
                        : null,
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: ThixPolicy.gold, borderRadius: BorderRadius.circular(8)),
                              child: const Text('NOUVEAU', style: TextStyle(color: ThixPolicy.inkDeep, fontSize: 10, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(height: 10),
                            Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800, height: 1.2)),
                            const SizedBox(height: 5),
                            Text(f.description ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.play_arrow_rounded, color: ThixPolicy.gold, size: 28),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (widget.recentFormations.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.recentFormations.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(color: _page == i ? ThixPolicy.primary : ThixPolicy.border, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickActionsRow extends ConsumerWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(_eduTabIndexProvider.notifier);
    final items = [
      (Icons.grid_view_rounded, 'Toutes', () => notifier.state = 2),
      (Icons.workspace_premium_rounded, 'Certificats', () => notifier.state = 3),
      (Icons.local_fire_department_rounded, 'Populaires', () => notifier.state = 2),
      (Icons.menu_book_rounded, 'Mes cours', () => notifier.state = 1),
    ];

    return SizedBox(
      height: 76,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final item = items[i];
          return GestureDetector(
            onTap: item.$3,
            child: Container(
              width: 76,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixPolicy.border)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.$1, color: ThixPolicy.primary, size: 22),
                  const SizedBox(height: 6),
                  Text(item.$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProgressRow extends ConsumerWidget {
  final String userId;
  const _ProgressRow({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollAsync = ref.watch(myEnrollmentsProvider(userId));
    return enrollAsync.when(
      loading: () => const SizedBox(height: 110),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final inProgress = list.where((e) => e.formation != null && (e.progress ?? 0) > 0 && (e.progress ?? 0) < 1).toList();
        final current = inProgress.isNotEmpty ? inProgress.first : null;
        final completedCount = list.where((e) => (e.progress ?? 0) >= 1).length;
        const goal = 5;

        return Row(
          children: [
            Expanded(
              child: current == null
                  ? const _EmptyCard(title: 'Continuez', subtitle: 'Aucune formation en cours')
                  : GestureDetector(
                      onTap: () => context.push('/education/formation/${current.formation!.id}'),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: ThixPolicy.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('En cours', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textSecondary)),
                            const SizedBox(height: 8),
                            Text(current.formation!.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: current.progress, minHeight: 5, backgroundColor: ThixPolicy.border, color: ThixPolicy.success),
                            ),
                            const SizedBox(height: 5),
                            Text('${((current.progress ?? 0) * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.success)),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: ThixPolicy.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Objectif', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textSecondary)),
                    const SizedBox(height: 8),
                    const Text('Terminez 5 formations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: (completedCount / goal).clamp(0.0, 1.0), minHeight: 5, backgroundColor: ThixPolicy.border, color: ThixPolicy.primary),
                    ),
                    const SizedBox(height: 5),
                    Text('$completedCount / $goal', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.primary)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyCard({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: ThixPolicy.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textSecondary)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ============================ AUTRES ONGLETS ============================

class _MyLearningPage extends ConsumerWidget {
  const _MyLearningPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider).value;
    if (userId == null) return const Center(child: Text('Non connecté'));
    final enrollAsync = ref.watch(myEnrollmentsProvider(userId));
    return enrollAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      error: (_, __) => const Center(child: Text('Erreur de chargement')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('Aucune formation en cours', style: TextStyle(color: ThixPolicy.textSecondary)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final e = list[i];
            final f = e.formation;
            if (f == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}'), progress: e.progress?.toDouble()),
            );
          },
        );
      },
    );
  }
}

class _AllFormationsPage extends ConsumerWidget {
  const _AllFormationsPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formationsAsync = ref.watch(formationsProvider);
    return formationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      error: (_, __) => const Center(child: Text('Erreur de chargement')),
      data: (paginated) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: paginated.items.length,
        itemBuilder: (_, i) {
          final f = paginated.items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}')),
          );
        },
      ),
    );
  }
}

class _CertificatesPage extends ConsumerWidget {
  const _CertificatesPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider).value;
    if (userId == null) return const Center(child: Text('Non connecté'));
    final certsAsync = ref.watch(certificatesProvider(userId));
    return certsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      error: (_, __) => const Center(child: Text('Erreur de chargement')),
      data: (certs) {
        if (certs.isEmpty) return const Center(child: Text('Aucun certificat', style: TextStyle(color: ThixPolicy.textSecondary)));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: certs.length,
          itemBuilder: (_, i) {
            final cert = certs[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: ThixPolicy.border)),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(gradient: ThixPolicy.brandGradient, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.verified_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text('Délivré le ${cert.issuedAt.day}/${cert.issuedAt.month}/${cert.issuedAt.year}', style: const TextStyle(fontWeight: FontWeight.w600, color: ThixPolicy.textMain))),
                  IconButton(icon: const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textSecondary), onPressed: () => context.push('/education/certificate/${cert.id}', extra: cert)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage();
  @override
  Widget build(BuildContext context) => const Center(child: Text('Bibliothèque — Bientôt disponible', style: TextStyle(color: ThixPolicy.textSecondary)));
}

class _ProfilePage extends ConsumerWidget {
  const _ProfilePage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: ThixPolicy.brandGradient),
              child: const Icon(Icons.person_rounded, size: 42, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(user?.email ?? 'Utilisateur', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/instructor/dashboard'),
                icon: const Icon(Icons.school_rounded),
                label: const Text('Mode formateur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
