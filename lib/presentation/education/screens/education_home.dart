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

/// Catégorie actuellement sélectionnée — piloté par StateProvider pour que
/// tous les widgets qui en dépendent (chips, grille) se reconstruisent
/// correctement quand elle change.
final _selectedCategoryProvider = StateProvider<String?>((ref) => null);

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

/// Collections personnelles créées par l'utilisateur dans sa Bibliothèque.
/// Stockage en mémoire pour l'instant (session) — prêt à être relié à
/// Supabase plus tard (table `user_collections` par ex).
class _CustomCollectionsNotifier extends StateNotifier<List<String>> {
  _CustomCollectionsNotifier() : super([]);

  void add(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.contains(trimmed)) return;
    state = [...state, trimmed];
  }

  void remove(String name) {
    state = state.where((c) => c != name).toList();
  }
}

final _customCollectionsProvider = StateNotifierProvider<_CustomCollectionsNotifier, List<String>>(
  (ref) => _CustomCollectionsNotifier(),
);

// ============================================================================
// PAGE PRINCIPALE (HUB E-LEARNING)
// ============================================================================
class EducationHome extends ConsumerWidget {
  const EducationHome({super.key});

  static const _pages = [
    _HomePage(),
    _ExplorePage(),
    _LibraryPage(),
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
// BOTTOM NAVIGATION
// ============================================================================
class _FloatingBottomNav extends ConsumerWidget {
  final int selectedIndex;
  const _FloatingBottomNav({required this.selectedIndex});

  static const _items = [
    (Icons.home_rounded, 'Accueil'),
    (Icons.explore_rounded, 'Découvrir'),
    (Icons.video_library_rounded, 'Bibliothèque'),
    (Icons.workspace_premium_rounded, 'Certificats'),
    (Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(ThixPolicy.s12, 0, ThixPolicy.s12, ThixPolicy.s12),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: [
              BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.07), blurRadius: 18, offset: const Offset(0, 6)),
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
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.$1,
                        color: isSelected ? ThixPolicy.domainLearning : ThixPolicy.textSecondary,
                        size: isSelected ? 22 : 20,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 9.5,
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
    final selectedCategory = ref.watch(_selectedCategoryProvider);

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
          // ─── HEADER COMPACT + RECHERCHE ───
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + ThixPolicy.s12, bottom: ThixPolicy.s16),
              decoration: const BoxDecoration(
                color: ThixPolicy.card,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(ThixPolicy.rLg)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: ThixPolicy.tint,
                          backgroundImage: user?.userMetadata?['avatar_url'] != null ? NetworkImage(user!.userMetadata!['avatar_url']) : null,
                          child: user?.userMetadata?['avatar_url'] == null ? const Icon(Icons.person, color: ThixPolicy.primaryDeep, size: 20) : null,
                        ),
                        const SizedBox(width: ThixPolicy.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bonjour, ${user?.userMetadata?['full_name']?.split(' ')[0] ?? 'Apprenant'}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
                              const Text('Que voulez-vous apprendre ?', style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/notifications'),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.border)),
                                child: const Icon(Icons.notifications_none_rounded, color: ThixPolicy.textMain, size: 20),
                              ),
                              unreadAsync.maybeWhen(
                                data: (count) => count > 0
                                    ? Positioned(
                                        right: -2, top: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle),
                                          child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                                orElse: () => const SizedBox.shrink(),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ThixPolicy.s12),
                  // Barre de recherche
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                    child: GestureDetector(
                      onTap: () => context.push('/education/search'),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                        decoration: BoxDecoration(color: ThixPolicy.surface, borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), border: Border.all(color: ThixPolicy.border)),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: ThixPolicy.textSecondary, size: 20),
                            const SizedBox(width: ThixPolicy.s8),
                            const Expanded(
                              child: Text('Rechercher une formation, une compétence...', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ThixPolicy.s12),
                  // ─── RACCOURCIS RAPIDES (façon Udemy: icônes fonctionnelles) ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                    child: Row(
                      children: [
                        Expanded(child: _QuickIcon(icon: Icons.grid_view_rounded, label: 'Catégories', onTap: () => ref.read(_eduTabIndexProvider.notifier).state = 1)),
                        Expanded(child: _QuickIcon(icon: Icons.video_library_rounded, label: 'Bibliothèque', onTap: () => ref.read(_eduTabIndexProvider.notifier).state = 2)),
                        Expanded(child: _QuickIcon(icon: Icons.workspace_premium_rounded, label: 'Certificats', onTap: () => ref.read(_eduTabIndexProvider.notifier).state = 3)),
                        Expanded(child: _QuickIcon(icon: Icons.co_present_rounded, label: 'Formateur', onTap: () => context.push('/instructor/dashboard'))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),

          formationsAsync.when(
            loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: ThixPolicy.domainLearning)))),
            error: (_, __) => const SliverToBoxAdapter(child: Center(child: Text('Erreur de chargement.'))),
            data: (paginated) {
              final formations = paginated.items;

              final recentFormations = formations.take(5).toList();
              final upcomingFormations = formations.skip(2).take(4).toList();
              final topFormations = [...formations]..sort((a, b) => b.rating.compareTo(a.rating));
              final trendingFormations = formations.reversed.take(5).toList();
              final languageFormations = formations.skip(1).take(4).toList();
              final shortPrograms = formations.skip(3).take(5).toList();

              return SliverList(
                delegate: SliverChildListDelegate([
                  if (user != null) Padding(padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16), child: _ContinueLearningCard(userId: user.id)),

                  const SizedBox(height: ThixPolicy.s20),

                  // ─── HERO COMPACT (carte produit, pas poster plein écran) ───
                  Padding(padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16), child: _HeroCarousel(recentFormations: recentFormations)),

                  const SizedBox(height: ThixPolicy.s24),

                  // ─── CATÉGORIES — désormais réellement réactives ───
                  _SectionHeader(title: 'Explorer par catégorie', onSeeAll: () => ref.read(_eduTabIndexProvider.notifier).state = 1),
                  const SizedBox(height: ThixPolicy.s12),
                  categoriesAsync.when(
                    data: (cats) => SizedBox(
                      height: 38,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                        scrollDirection: Axis.horizontal,
                        itemCount: cats.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s8),
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return EducationCategoryChip(
                              label: 'Tous',
                              isSelected: selectedCategory == null,
                              onTap: () {
                                ref.read(_selectedCategoryProvider.notifier).state = null;
                                ref.read(formationsProvider.notifier).filterByCategory(null);
                              },
                            );
                          }
                          final cat = cats[i - 1];
                          return EducationCategoryChip(
                            label: cat.name,
                            isSelected: selectedCategory == cat.id,
                            onTap: () {
                              ref.read(_selectedCategoryProvider.notifier).state = cat.id;
                              ref.read(formationsProvider.notifier).filterByCategory(cat.id);
                            },
                          );
                        },
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  const SizedBox(height: ThixPolicy.s24),

                  if (upcomingFormations.isNotEmpty) ...[
                    const _SectionHeader(title: 'À venir prochainement'),
                    const SizedBox(height: ThixPolicy.s12),
                    SizedBox(
                      height: 76,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                        scrollDirection: Axis.horizontal,
                        itemCount: upcomingFormations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s10),
                        itemBuilder: (_, i) {
                          final f = upcomingFormations[i];
                          return _CompactFormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}'));
                        },
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s24),
                  ],

                  if (topFormations.isNotEmpty) ...[
                    _SectionHeader(title: 'Top des formations', onSeeAll: () => ref.read(_eduTabIndexProvider.notifier).state = 1),
                    const SizedBox(height: ThixPolicy.s12),
                    SizedBox(
                      height: 250,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                        scrollDirection: Axis.horizontal,
                        itemCount: topFormations.length > 6 ? 6 : topFormations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
                        itemBuilder: (_, i) {
                          final f = topFormations[i];
                          return SizedBox(width: 190, child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}')));
                        },
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s24),
                  ],

                  if (trendingFormations.isNotEmpty) ...[
                    _SectionHeader(title: 'Tendances actuelles', onSeeAll: () => ref.read(_eduTabIndexProvider.notifier).state = 1),
                    const SizedBox(height: ThixPolicy.s12),
                    SizedBox(
                      height: 250,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                        scrollDirection: Axis.horizontal,
                        itemCount: trendingFormations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
                        itemBuilder: (_, i) {
                          final f = trendingFormations[i];
                          return SizedBox(width: 190, child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}')));
                        },
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s24),
                  ],

                  if (languageFormations.isNotEmpty) ...[
                    const _SectionHeader(title: 'Apprendre une langue'),
                    const SizedBox(height: ThixPolicy.s12),
                    SizedBox(
                      height: 76,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                        scrollDirection: Axis.horizontal,
                        itemCount: languageFormations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s10),
                        itemBuilder: (_, i) {
                          final f = languageFormations[i];
                          return _CompactFormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}'));
                        },
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s24),
                  ],

                  if (shortPrograms.isNotEmpty) ...[
                    _SectionHeader(title: 'Programmes courts', onSeeAll: () => ref.read(_eduTabIndexProvider.notifier).state = 1),
                    const SizedBox(height: ThixPolicy.s12),
                    SizedBox(
                      height: 250,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                        scrollDirection: Axis.horizontal,
                        itemCount: shortPrograms.length,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
                        itemBuilder: (_, i) {
                          final f = shortPrograms[i];
                          return SizedBox(width: 190, child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}')));
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 110),
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
// RACCOURCI RAPIDE (icône + libellé, fonctionnel)
// ============================================================================
class _QuickIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickIcon({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: ThixPolicy.tint, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: ThixPolicy.domainLearning, size: 20),
            ),
            const SizedBox(height: 5),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThixPolicy.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS DE L'ACCUEIL
// ============================================================================
class _CompactFormationCard extends StatelessWidget {
  final Formation formation;
  final VoidCallback onTap;

  const _CompactFormationCard({required this.formation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: ThixPolicy.shadowSoft(),
        ),
        child: Row(
          children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(color: ThixPolicy.tint, borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
              child: const Icon(Icons.school_rounded, color: ThixPolicy.domainLearning, size: 26),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(formation.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: ThixPolicy.textMain, height: 1.2)),
                  const SizedBox(height: 3),
                  Text(formation.instructorName ?? 'THIX Academy', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThixPolicy.textMain, letterSpacing: -0.3)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text('Tout voir', style: TextStyle(color: ThixPolicy.domainLearning, fontWeight: FontWeight.w700, fontSize: 12.5)),
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
        if (inProgress.isEmpty) return const SizedBox.shrink();

        final current = inProgress.first;
        final f = current.formation!;
        final pct = ((current.progress ?? 0) * 100).round();

        return GestureDetector(
          onTap: () => context.push('/education/formation/${f.id}'),
          child: Container(
            padding: const EdgeInsets.all(ThixPolicy.s16),
            decoration: BoxDecoration(
              color: ThixPolicy.inkDeep,
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              boxShadow: ThixPolicy.shadowCard(),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reprendre le cours', style: TextStyle(color: ThixPolicy.gold, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                      const SizedBox(height: 6),
                      Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold, height: 1.2)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: current.progress, minHeight: 5, backgroundColor: Colors.white.withOpacity(0.2), color: ThixPolicy.gold),
                            ),
                          ),
                          const SizedBox(width: ThixPolicy.s10),
                          Text('$pct%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ThixPolicy.s16),
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(color: ThixPolicy.gold, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: ThixPolicy.inkDeep, size: 24),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ─── HERO — Carte produit compacte (inspirée de la bannière Udemy) ───
/// Remplace l'ancien carrousel plein écran par une carte plus sobre et
/// professionnelle : dégradé de la couleur de la marque, texte concis, CTA.
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
          height: 168,
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
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [ThixPolicy.inkDeep, ThixPolicy.domainLearning],
                    ),
                    image: f.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(f.imageUrl!),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.42), BlendMode.darken),
                          )
                        : null,
                  ),
                  padding: const EdgeInsets.all(ThixPolicy.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: ThixPolicy.gold, borderRadius: BorderRadius.circular(6)),
                        child: const Text('NOUVEAU', style: TextStyle(color: ThixPolicy.inkDeep, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                      ),
                      const SizedBox(height: 12),
                      Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, height: 1.2, letterSpacing: -0.3)),
                      const SizedBox(height: 6),
                      Text(f.instructorName ?? 'THIX Academy', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: ThixPolicy.s10),
        if (widget.recentFormations.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.recentFormations.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 14 : 6, height: 6,
                decoration: BoxDecoration(color: _page == i ? ThixPolicy.domainLearning : ThixPolicy.border, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// ONGLET 2 : DÉCOUVRIR (avec filtre catégorie fonctionnel en haut)
// ============================================================================
class _ExplorePage extends ConsumerWidget {
  const _ExplorePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formationsAsync = ref.watch(formationsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(_selectedCategoryProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Découvrir', style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.4)),
        actions: [IconButton(icon: const Icon(Icons.search, color: ThixPolicy.textMain), onPressed: () => context.push('/education/search'))],
      ),
      body: Column(
        children: [
          // Filtre catégorie — fonctionnel, synchronisé avec l'accueil
          categoriesAsync.when(
            data: (cats) => Container(
              color: ThixPolicy.card,
              padding: const EdgeInsets.only(bottom: ThixPolicy.s12),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                  scrollDirection: Axis.horizontal,
                  itemCount: cats.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return EducationCategoryChip(
                        label: 'Tous',
                        isSelected: selectedCategory == null,
                        onTap: () {
                          ref.read(_selectedCategoryProvider.notifier).state = null;
                          ref.read(formationsProvider.notifier).filterByCategory(null);
                        },
                      );
                    }
                    final cat = cats[i - 1];
                    return EducationCategoryChip(
                      label: cat.name,
                      isSelected: selectedCategory == cat.id,
                      onTap: () {
                        ref.read(_selectedCategoryProvider.notifier).state = cat.id;
                        ref.read(formationsProvider.notifier).filterByCategory(cat.id);
                      },
                    );
                  },
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          Expanded(
            child: formationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.domainLearning)),
              error: (_, __) => const Center(child: Text('Erreur de chargement')),
              data: (paginated) {
                if (paginated.items.isEmpty) {
                  return const Center(
                    child: Text('Aucune formation dans cette catégorie', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s12, ThixPolicy.s16, 110),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: ThixPolicy.s12, mainAxisSpacing: ThixPolicy.s14),
                  itemCount: paginated.items.length,
                  itemBuilder: (_, i) {
                    final f = paginated.items[i];
                    return FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}'));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ONGLET 3 : BIBLIOTHÈQUE (ex "Mes cours" + collections personnelles)
// ============================================================================
class _LibraryPage extends ConsumerWidget {
  const _LibraryPage();

  Future<void> _openCreateCollectionDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nouvelle collection', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Ex : Mes favoris DevOps',
            filled: true, fillColor: ThixPolicy.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.domainLearning, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      ref.read(_customCollectionsProvider.notifier).add(name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider).value;
    if (userId == null) return const Center(child: Text('Non connecté'));

    final enrollAsync = ref.watch(myEnrollmentsProvider(userId));
    final collections = ref.watch(_customCollectionsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        title: const Text('Bibliothèque', style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.4)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, 110),
        children: [
          // ─── COLLECTIONS PERSONNALISÉES ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mes collections', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
              InkWell(
                onTap: () => _openCreateCollectionDialog(context, ref),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: ThixPolicy.tint, borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 15, color: ThixPolicy.domainLearning),
                      SizedBox(width: 3),
                      Text('Créer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ThixPolicy.domainLearning)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ThixPolicy.s12),
          if (collections.isEmpty)
            Container(
              padding: const EdgeInsets.all(ThixPolicy.s16),
              decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixPolicy.border)),
              child: const Text('Créez une collection pour organiser vos cours (ex: par métier, par objectif).',
                  style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500)),
            )
          else
            Wrap(
              spacing: ThixPolicy.s8,
              runSpacing: ThixPolicy.s8,
              children: collections.map((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: ThixPolicy.border)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder_rounded, size: 14, color: ThixPolicy.domainLearning),
                      const SizedBox(width: 6),
                      Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => ref.read(_customCollectionsProvider.notifier).remove(name),
                        child: const Icon(Icons.close_rounded, size: 14, color: ThixPolicy.textSecondary),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: ThixPolicy.s24),

          const Text('Mes cours en cours', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
          const SizedBox(height: ThixPolicy.s12),

          enrollAsync.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: ThixPolicy.domainLearning))),
            error: (_, __) => const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('Erreur')),
            data: (list) {
              if (list.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 56, color: ThixPolicy.borderStrong),
                      const SizedBox(height: ThixPolicy.s12),
                      const Text('Aucun cours en cours', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: ThixPolicy.s16),
                      ElevatedButton(
                        onPressed: () => ref.read(_eduTabIndexProvider.notifier).state = 1,
                        style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.domainLearning, foregroundColor: Colors.white),
                        child: const Text('Découvrir des cours'),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: list.map((e) {
                  final f = e.formation;
                  if (f == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: ThixPolicy.s12),
                    child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}'), progress: e.progress?.toDouble()),
                  );
                }).toList(),
              );
            },
          ),
        ],
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
        title: const Text('Mes certificats', style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.4)),
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
                  Icon(Icons.workspace_premium_rounded, size: 56, color: ThixPolicy.borderStrong),
                  const SizedBox(height: ThixPolicy.s12),
                  const Text('Vous n\'avez pas encore de certificats', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, 110),
            itemCount: certs.length,
            itemBuilder: (_, i) {
              final cert = certs[i];
              return Container(
                margin: const EdgeInsets.only(bottom: ThixPolicy.s12),
                padding: const EdgeInsets.all(ThixPolicy.s16),
                decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft()),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: const BoxDecoration(gradient: ThixPolicy.goldGradient, shape: BoxShape.circle),
                      child: const Icon(Icons.workspace_premium_rounded, color: ThixPolicy.inkDeep, size: 26),
                    ),
                    const SizedBox(width: ThixPolicy.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Certificat de réussite', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: ThixPolicy.textMain)),
                          const SizedBox(height: 3),
                          Text('Délivré le ${cert.issuedAt.day}/${cert.issuedAt.month}/${cert.issuedAt.year}', style: const TextStyle(fontSize: 11.5, color: ThixPolicy.textSecondary)),
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
// ONGLET 5 : PROFIL & PLUS
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
        title: const Text('Mon Compte', style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.4)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, 110),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(ThixPolicy.s16),
              decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rLg), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowCard()),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32, backgroundColor: ThixPolicy.tint,
                    backgroundImage: user?.userMetadata?['avatar_url'] != null ? NetworkImage(user!.userMetadata!['avatar_url']) : null,
                    child: user?.userMetadata?['avatar_url'] == null ? const Icon(Icons.person, size: 32, color: ThixPolicy.primaryDeep) : null,
                  ),
                  const SizedBox(width: ThixPolicy.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.userMetadata?['full_name'] ?? 'Apprenant THIX', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
                        const SizedBox(height: 3),
                        Text(user?.email ?? '', style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: ThixPolicy.s16),

            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/instructor/dashboard'),
                icon: const Icon(Icons.co_present_rounded, size: 20),
                label: const Text('Passer en mode Formateur', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.inkDeep, foregroundColor: ThixPolicy.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                ),
              ),
            ),

            const SizedBox(height: ThixPolicy.s24),

            Align(alignment: Alignment.centerLeft, child: Text('Outils & Ressources', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ThixPolicy.textSecondary.withOpacity(0.85)))),
            const SizedBox(height: ThixPolicy.s10),
            Container(
              decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border)),
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

            const SizedBox(height: ThixPolicy.s16),

            Container(
              decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border)),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: 2),
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 19),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: ThixPolicy.textMain)),
      trailing: const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textSecondary, size: 20),
    );
  }
}
