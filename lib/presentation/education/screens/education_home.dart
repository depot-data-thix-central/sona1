import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

import '../providers/education_provider.dart' hide certificatesProvider;
import '../providers/certificate_provider.dart';
import '../widgets/common/education_category_chip.dart';
import '../widgets/common/formation_card.dart';
import '../models/category.dart';
import '../models/formation.dart';
import '../models/certificate.dart';

// ============================================================================
// PROVIDERS
// ============================================================================
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

// ============================================================================
// PAGE PRINCIPALE (HUB E-LEARNING)
// ============================================================================
class EducationHome extends ConsumerWidget {
  const EducationHome({super.key});

  // UX Enterprise : 5 onglets maximum dans une barre de navigation
  static const _pages = [
    _HomePage(),
    _ExplorePage(),
    _MyLearningPage(),
    _CertificatesPage(),
    _ProfilePage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(_eduTabIndexProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      body: Stack(
        children: [
          IndexedStack(
            index: selectedIndex,
            children: _pages,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FloatingBottomNav(selectedIndex: selectedIndex),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BOTTOM NAVIGATION FLOTTANTE PREMIUM
// ============================================================================
class _FloatingBottomNav extends ConsumerWidget {
  final int selectedIndex;
  const _FloatingBottomNav({required this.selectedIndex});

  static const _items = [
    (Icons.home_rounded, 'Accueil'),
    (Icons.explore_rounded, 'Découvrir'),
    (Icons.play_circle_filled_rounded, 'Mes cours'),
    (Icons.workspace_premium_rounded, 'Certificats'),
    (Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, 0, ThixPolicy.s16, ThixPolicy.s16),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: [
              BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_items.length, (i) {
              final isSelected = selectedIndex == i;
              final item = _items[i];
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(_eduTabIndexProvider.notifier).state = i;
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.$1,
                        color: isSelected ? ThixPolicy.domainLearning : ThixPolicy.textSecondary,
                        size: isSelected ? 24 : 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? ThixPolicy.domainLearning : ThixPolicy.textSecondary,
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

// ============================================================================
// ONGLET 1 : ACCUEIL
// ============================================================================
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
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
        ref.read(formationsProvider.notifier).loadMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = Supabase.instance.client.auth.currentUser;
    final unreadAsync = ref.watch(_unreadNotificationsProvider);
    final formationsAsync = ref.watch(formationsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return RefreshIndicator(
      color: ThixPolicy.domainLearning,
      backgroundColor: ThixPolicy.card,
      onRefresh: () async {
        ref.invalidate(formationsProvider);
        ref.invalidate(categoriesProvider);
        if (user != null) ref.invalidate(myEnrollmentsProvider(user.id));
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // ─── HEADER PREMIUM AVEC RECHERCHE ───
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + ThixPolicy.s20, bottom: ThixPolicy.s24),
              decoration: const BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(ThixPolicy.rXl)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: ThixPolicy.tint,
                          backgroundImage: user?.userMetadata?['avatar_url'] != null ? NetworkImage(user!.userMetadata!['avatar_url']) : null,
                          child: user?.userMetadata?['avatar_url'] == null ? const Icon(Icons.person, color: ThixPolicy.primaryDeep) : null,
                        ),
                        const SizedBox(width: ThixPolicy.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bonjour, ${user?.userMetadata?['full_name']?.split(' ')[0] ?? 'Apprenant'}', style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.textMain)),
                              Text('Que voulez-vous apprendre aujourd\'hui ?', style: ThixPolicy.bodySmallStyle),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/notifications'),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)),
                                child: const Icon(Icons.notifications_none_rounded, color: ThixPolicy.textMain, size: 22),
                              ),
                              unreadAsync.maybeWhen(
                                data: (count) => count > 0 ? Positioned(right: -2, top: -2, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle), child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))) : const SizedBox.shrink(),
                                orElse: () => const SizedBox.shrink(),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ThixPolicy.s20),
                  // Fausse barre de recherche
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                    child: GestureDetector(
                      onTap: () => context.push('/education/search'),
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                        decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), border: Border.all(color: ThixPolicy.border)),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: ThixPolicy.textSecondary, size: 22),
                            const SizedBox(width: ThixPolicy.s12),
                            const Text('Rechercher une formation, une compétence...', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s20)),

          formationsAsync.when(
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: ThixPolicy.domainLearning))),
            error: (_, __) => const SliverToBoxAdapter(child: Center(child: Text('Erreur de chargement.'))),
            data: (paginated) {
              final formations = paginated.items;
              
              // Découpage des listes pour simuler la diversité des sections
              final recentFormations = formations.take(5).toList();
              final upcomingFormations = formations.skip(2).take(4).toList(); // À venir
              final topFormations = [...formations]..sort((a, b) => b.rating.compareTo(a.rating)); // Top
              final trendingFormations = formations.reversed.take(5).toList(); // Tendances
              final languageFormations = formations.skip(1).take(4).toList(); // Langues
              final shortPrograms = formations.skip(3).take(5).toList(); // Programmes courts

              return SliverList(
                delegate: SliverChildListDelegate([
                  // ─── REPRISE D'APPRENTISSAGE (Priorité 1) ───
                  if (user != null) Padding(padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20), child: _ContinueLearningCard(userId: user.id)),
                  
                  const SizedBox(height: ThixPolicy.s24),

                  // ─── HERO CAROUSEL NOUVEAUTÉS (Agrandie) ───
                  Padding(padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20), child: _HeroCarousel(recentFormations: recentFormations)),
                  
                  const SizedBox(height: ThixPolicy.s32),

                  // ─── CATÉGORIES ───
                  _SectionHeader(title: 'Explorer par catégorie', onSeeAll: () => ref.read(_eduTabIndexProvider.notifier).state = 1),
                  const SizedBox(height: ThixPolicy.s16),
                  categoriesAsync.when(
                    data: (cats) => SizedBox(
                      height: 40,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                        scrollDirection: Axis.horizontal,
                        itemCount: cats.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s8),
                        itemBuilder: (_, i) {
                          if (i == 0) return EducationCategoryChip(label: 'Tous', isSelected: ref.read(formationsProvider.notifier).currentCategory == null, onTap: () => ref.read(formationsProvider.notifier).filterByCategory(null));
                          final cat = cats[i - 1];
                          return EducationCategoryChip(label: cat.name, isSelected: ref.read(formationsProvider.notifier).currentCategory == cat.id, onTap: () => ref.read(formationsProvider.notifier).filterByCategory(cat.id));
                        },
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: ThixPolicy.s32),

                  // ─── À VENIR (Compact, pas de mock-up) ───
                  if (upcomingFormations.isNotEmpty) ...[
                    const _SectionHeader(title: 'À venir prochainement'),
                    const SizedBox(height: ThixPolicy.s16),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                        scrollDirection: Axis.horizontal,
                        itemCount: upcomingFormations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
                        itemBuilder: (_, i) {
                          final f = upcomingFormations[i];
                          return _CompactFormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}'));
                        },
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s32),
                  ],

                  // ─── TOP DES FORMATIONS ───
                  if (topFormations.isNotEmpty) ...[
                    _SectionHeader(title: 'Top des formations', onSeeAll: () => ref.read(_eduTabIndexProvider.notifier).state = 1),
                    const SizedBox(height: ThixPolicy.s16),
                    SizedBox(
                      height: 260,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                        scrollDirection: Axis.horizontal,
                        itemCount: topFormations.length > 6 ? 6 : topFormations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
                        itemBuilder: (_, i) {
                          final f = topFormations[i];
                          return SizedBox(width: 200, child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}')));
                        },
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s32),
                  ],

                  // ─── TENDANCES ACTUELLES (Section A) ───
                  if (trendingFormations.isNotEmpty) ...[
                    _SectionHeader(title: 'Tendances actuelles', onSeeAll: () => ref.read(_eduTabIndexProvider.notifier).state = 1),
                    const SizedBox(height: ThixPolicy.s16),
                    SizedBox(
                      height: 260,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                        scrollDirection: Axis.horizontal,
                        itemCount: trendingFormations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
                        itemBuilder: (_, i) {
                          final f = trendingFormations[i];
                          return SizedBox(width: 200, child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}')));
                        },
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s32),
                  ],

                  // ─── LANGUES (Milieu, Compact, même taille que À venir) ───
                  if (languageFormations.isNotEmpty) ...[
                    const _SectionHeader(title: 'Apprendre une langue'),
                    const SizedBox(height: ThixPolicy.s16),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                        scrollDirection: Axis.horizontal,
                        itemCount: languageFormations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
                        itemBuilder: (_, i) {
                          final f = languageFormations[i];
                          return _CompactFormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}'));
                        },
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s32),
                  ],

                  // ─── PROGRAMMES COURTS (Section B) ───
                  if (shortPrograms.isNotEmpty) ...[
                    _SectionHeader(title: 'Programmes courts', onSeeAll: () => ref.read(_eduTabIndexProvider.notifier).state = 1),
                    const SizedBox(height: ThixPolicy.s16),
                    SizedBox(
                      height: 260,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                        scrollDirection: Axis.horizontal,
                        itemCount: shortPrograms.length,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
                        itemBuilder: (_, i) {
                          final f = shortPrograms[i];
                          return SizedBox(width: 200, child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}')));
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 120), // Espace pour la bottom nav
                ]),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS DE L'ACCUEIL
// ============================================================================

// 🌟 NOUVEAU COMPOSANT : CARTE COMPACTE SANS MOCKUP IMAGE
class _CompactFormationCard extends StatelessWidget {
  final Formation formation;
  final VoidCallback onTap;

  const _CompactFormationCard({required this.formation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: ThixPolicy.shadowSoft(),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: ThixPolicy.tint,
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              ),
              // Un simple icône épuré pour éviter le mockup cassé "Image non disponible"
              child: const Icon(Icons.school_rounded, color: ThixPolicy.domainLearning, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formation.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ThixPolicy.textMain, height: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formation.instructorName ?? 'THIX Academy',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThixPolicy.textMain, letterSpacing: -0.5)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text('Tout voir', style: TextStyle(color: ThixPolicy.domainLearning, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

class _ContinueLearningCard extends ConsumerWidget {
  final String userId;
  const _ContinueLearningCard({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollAsync = ref.watch(myEnrollmentsProvider(userId));
    return enrollAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final inProgress = list.where((e) => e.formation != null && (e.progress ?? 0) > 0 && (e.progress ?? 0) < 1).toList();
        if (inProgress.isEmpty) return const SizedBox.shrink(); // Ne s'affiche que s'il y a un cours en cours
        
        final current = inProgress.first;
        final f = current.formation!;
        final pct = ((current.progress ?? 0) * 100).round();

        return GestureDetector(
          onTap: () => context.push('/education/formation/${f.id}'),
          child: Container(
            padding: const EdgeInsets.all(ThixPolicy.s20),
            decoration: BoxDecoration(
              color: ThixPolicy.inkDeep,
              borderRadius: BorderRadius.circular(ThixPolicy.rXl),
              boxShadow: ThixPolicy.shadowCard(),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reprendre le cours', style: TextStyle(color: ThixPolicy.gold, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      const SizedBox(height: ThixPolicy.s8),
                      Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.2)),
                      const SizedBox(height: ThixPolicy.s16),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: current.progress, minHeight: 6, backgroundColor: Colors.white.withOpacity(0.2), color: ThixPolicy.gold),
                            ),
                          ),
                          const SizedBox(width: ThixPolicy.s12),
                          Text('$pct%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ThixPolicy.s20),
                Container(
                  width: 50, height: 50,
                  decoration: const BoxDecoration(color: ThixPolicy.gold, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: ThixPolicy.inkDeep, size: 28),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroCarousel extends StatefulWidget {
  final List<Formation> recentFormations;
  const _HeroCarousel({required this.recentFormations});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.recentFormations.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 230, // 🌟 Agrandissement de la bannière Hero (180 -> 230)
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.recentFormations.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final f = widget.recentFormations[i];
              return GestureDetector(
                onTap: () => context.push('/education/formation/${f.id}'),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                    image: f.imageUrl != null ? DecorationImage(image: NetworkImage(f.imageUrl!), fit: BoxFit.cover) : null,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                      gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.black.withOpacity(0.8), Colors.black.withOpacity(0.2)]),
                    ),
                    padding: const EdgeInsets.all(ThixPolicy.s24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: ThixPolicy.domainLearning, borderRadius: BorderRadius.circular(6)), child: const Text('NOUVEAU', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
                        const SizedBox(height: ThixPolicy.s16),
                        Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.2, letterSpacing: -0.5)),
                        const SizedBox(height: ThixPolicy.s8),
                        Text(f.instructorName ?? 'THIX Academy', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: ThixPolicy.s12),
        if (widget.recentFormations.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.recentFormations.length,
              (i) => AnimatedContainer(duration: const Duration(milliseconds: 250), margin: const EdgeInsets.symmetric(horizontal: 3), width: _page == i ? 16 : 6, height: 6, decoration: BoxDecoration(color: _page == i ? ThixPolicy.domainLearning : ThixPolicy.border, borderRadius: BorderRadius.circular(3))),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// ONGLET 2 : DÉCOUVRIR (TOUTES LES FORMATIONS)
// ============================================================================
class _ExplorePage extends ConsumerWidget {
  const _ExplorePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formationsAsync = ref.watch(formationsProvider);
    
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Découvrir', style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5)),
        actions: [IconButton(icon: const Icon(Icons.search, color: ThixPolicy.textMain), onPressed: () => context.push('/education/search'))],
      ),
      body: formationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.domainLearning)),
        error: (_, __) => const Center(child: Text('Erreur de chargement')),
        data: (paginated) => GridView.builder(
          padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: ThixPolicy.s12, mainAxisSpacing: ThixPolicy.s16),
          itemCount: paginated.items.length,
          itemBuilder: (_, i) {
            final f = paginated.items[i];
            return FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}'));
          },
        ),
      ),
    );
  }
}

// ============================================================================
// ONGLET 3 : MES COURS
// ============================================================================
class _MyLearningPage extends ConsumerWidget {
  const _MyLearningPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider).value;
    if (userId == null) return const Center(child: Text('Non connecté'));
    
    final enrollAsync = ref.watch(myEnrollmentsProvider(userId));
    
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        title: const Text('Mes apprentissages', style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5)),
      ),
      body: enrollAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.domainLearning)),
        error: (_, __) => const Center(child: Text('Erreur')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_rounded, size: 64, color: ThixPolicy.borderStrong),
                  const SizedBox(height: ThixPolicy.s16),
                  const Text('Aucun cours en cours', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: ThixPolicy.s24),
                  ElevatedButton(onPressed: () => ref.read(_eduTabIndexProvider.notifier).state = 1, style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.domainLearning, foregroundColor: Colors.white), child: const Text('Découvrir des cours')),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, 120),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final e = list[i];
              final f = e.formation;
              if (f == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: ThixPolicy.s16),
                child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}'), progress: e.progress?.toDouble()),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// ONGLET 4 : CERTIFICATS
// ============================================================================
class _CertificatesPage extends ConsumerWidget {
  const _CertificatesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider).value;
    if (userId == null) return const Center(child: Text('Non connecté'));
    
    final certsAsync = ref.watch(certificatesProvider(userId));
    
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        title: const Text('Mes certificats', style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5)),
      ),
      body: certsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.domainLearning)),
        error: (_, __) => const Center(child: Text('Erreur')),
        data: (certs) {
          if (certs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium_rounded, size: 64, color: ThixPolicy.borderStrong),
                  const SizedBox(height: ThixPolicy.s16),
                  const Text('Vous n\'avez pas encore de certificats', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, 120),
            itemCount: certs.length,
            itemBuilder: (_, i) {
              final cert = certs[i];
              return Container(
                margin: const EdgeInsets.only(bottom: ThixPolicy.s16),
                padding: const EdgeInsets.all(ThixPolicy.s20),
                decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft()),
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: const BoxDecoration(gradient: ThixPolicy.goldGradient, shape: BoxShape.circle),
                      child: const Icon(Icons.workspace_premium_rounded, color: ThixPolicy.inkDeep, size: 30),
                    ),
                    const SizedBox(width: ThixPolicy.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Certificat de réussite', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: ThixPolicy.textMain)),
                          const SizedBox(height: 4),
                          Text('Délivré le ${cert.issuedAt.day}/${cert.issuedAt.month}/${cert.issuedAt.year}', style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.download_rounded, color: ThixPolicy.domainLearning), onPressed: () => context.push('/education/certificate/${cert.id}', extra: cert)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// ONGLET 5 : PROFIL & PLUS (HUB COMPTE)
// ============================================================================
class _ProfilePage extends ConsumerWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        title: const Text('Mon Compte', style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s24, ThixPolicy.s16, 120),
        child: Column(
          children: [
            // Avatar & Info
            Container(
              padding: const EdgeInsets.all(ThixPolicy.s24),
              decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rXl), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowCard()),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36, backgroundColor: ThixPolicy.tint,
                    backgroundImage: user?.userMetadata?['avatar_url'] != null ? NetworkImage(user!.userMetadata!['avatar_url']) : null,
                    child: user?.userMetadata?['avatar_url'] == null ? const Icon(Icons.person, size: 36, color: ThixPolicy.primaryDeep) : null,
                  ),
                  const SizedBox(width: ThixPolicy.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.userMetadata?['full_name'] ?? 'Apprenant THIX', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
                        const SizedBox(height: 4),
                        Text(user?.email ?? '', style: const TextStyle(fontSize: 13, color: ThixPolicy.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: ThixPolicy.s24),

            // Mode Formateur
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/instructor/dashboard'),
                icon: const Icon(Icons.co_present_rounded, size: 22),
                label: const Text('Passer en mode Formateur', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.inkDeep, foregroundColor: ThixPolicy.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                ),
              ),
            ),

            const SizedBox(height: ThixPolicy.s32),

            // Menu Extra (Anciennement _openMoreMenu)
            Align(alignment: Alignment.centerLeft, child: Text('Outils & Ressources', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ThixPolicy.textSecondary.withOpacity(0.8)))),
            const SizedBox(height: ThixPolicy.s12),
            Container(
              decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border)),
              child: Column(
                children: [
                  _ProfileMenuTile(icon: Icons.card_giftcard_rounded, label: 'Cours gratuits', color: ThixPolicy.success, onTap: () => context.push('/education/free-courses')),
                  const Divider(height: 1, color: ThixPolicy.border, indent: 56),
                  _ProfileMenuTile(icon: Icons.videocam_rounded, label: 'Webinaires', color: ThixPolicy.domainMedia, onTap: () => context.push('/education/webinars')),
                  const Divider(height: 1, color: ThixPolicy.border, indent: 56),
                  _ProfileMenuTile(icon: Icons.groups_rounded, label: 'Mentorat', color: ThixPolicy.warning, onTap: () => context.push('/education/mentorat')),
                  const Divider(height: 1, color: ThixPolicy.border, indent: 56),
                  _ProfileMenuTile(icon: Icons.event_rounded, label: 'Événements', color: ThixPolicy.domainEvents, onTap: () => context.push('/education/events')),
                ],
              ),
            ),

            const SizedBox(height: ThixPolicy.s24),

            Container(
              decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border)),
              child: _ProfileMenuTile(icon: Icons.support_agent_rounded, label: 'Aide & support', color: ThixPolicy.textSecondary, onTap: () => context.push('/education/help')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ProfileMenuTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: 4),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ThixPolicy.textMain)),
      trailing: const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textSecondary),
    );
  }
}
