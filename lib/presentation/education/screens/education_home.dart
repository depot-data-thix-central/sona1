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
// CONSTANTES COULEURS "ENTREPRISE ÉDUCATION" (Compléments à ThixPolicy)
// ============================================================================
const Color _eduNavyBlue = Color(0xFF0F172A); // Ardoise foncée / Navy profond
const Color _eduAccentBlue = Color(0xFF0284C7); // Bleu institutionnel dynamique
const Color _eduShelfWood = Color(0xFFD4A373); // Couleur bois inspirée de 1000104931.jpg
const Color _eduShelfShadow = Color(0xFFB5835A);

// ============================================================================
// PROVIDERS
// ============================================================================
final _eduTabIndexProvider = StateProvider<int>((ref) => 0);

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
    (Icons.local_library_rounded, 'Bibliothèque'),
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
          height: 64,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                  color: _eduNavyBlue.withOpacity(0.08), 
                  blurRadius: 24, 
                  offset: const Offset(0, 8)),
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
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.$1,
                        color: isSelected ? _eduAccentBlue : ThixPolicy.textSecondary,
                        size: isSelected ? 24 : 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? _eduAccentBlue : ThixPolicy.textSecondary,
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
      color: _eduAccentBlue,
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
          // ─── HEADER ENTREPRISE ───
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
                          radius: 22,
                          backgroundColor: _eduNavyBlue.withOpacity(0.05),
                          backgroundImage: user?.userMetadata?['avatar_url'] != null ? NetworkImage(user!.userMetadata!['avatar_url']) : null,
                          child: user?.userMetadata?['avatar_url'] == null ? const Icon(Icons.person, color: _eduNavyBlue, size: 22) : null,
                        ),
                        const SizedBox(width: ThixPolicy.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bonjour, ${user?.userMetadata?['full_name']?.split(' ')[0] ?? 'Apprenant'}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _eduNavyBlue)),
                              const Text('Prêt à développer vos compétences ?', style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500)),
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
                                child: const Icon(Icons.notifications_none_rounded, color: _eduNavyBlue, size: 20),
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
                  const SizedBox(height: ThixPolicy.s16),
                  
                  // ─── BARRE DE RECHERCHE ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                    child: GestureDetector(
                      onTap: () => context.push('/education/search'),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                        decoration: BoxDecoration(
                          color: ThixPolicy.surface, 
                          borderRadius: BorderRadius.circular(ThixPolicy.inputRadius), 
                          border: Border.all(color: ThixPolicy.border)
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: ThixPolicy.textSecondary, size: 22),
                            const SizedBox(width: ThixPolicy.s10),
                            const Expanded(
                              child: Text('Rechercher un programme, une certification...', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ThixPolicy.s16),
                  
                  // ─── RACCOURCIS RAPIDES ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                    child: Row(
                      children: [
                        Expanded(child: _QuickIcon(icon: Icons.grid_view_rounded, label: 'Parcourir', onTap: () => ref.read(_eduTabIndexProvider.notifier).state = 1)),
                        Expanded(child: _QuickIcon(icon: Icons.local_library_rounded, label: 'Bibliothèque', onTap: () => ref.read(_eduTabIndexProvider.notifier).state = 2)),
                        Expanded(child: _QuickIcon(icon: Icons.workspace_premium_rounded, label: 'Certificats', onTap: () => ref.read(_eduTabIndexProvider.notifier).state = 3)),
                        Expanded(child: _QuickIcon(icon: Icons.co_present_rounded, label: 'Formateur', onTap: () => context.push('/instructor/dashboard'))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s20)),

          formationsAsync.when(
            loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _eduAccentBlue)))),
            error: (_, __) => const SliverToBoxAdapter(child: Center(child: Text('Erreur de chargement.'))),
            data: (paginated) {
              final formations = paginated.items;
              final recentFormations = formations.take(5).toList();
              final topFormations = [...formations]..sort((a, b) => b.rating.compareTo(a.rating));

              return SliverList(
                delegate: SliverChildListDelegate([
                  if (user != null) Padding(padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16), child: _ContinueLearningCard(userId: user.id)),
                  const SizedBox(height: ThixPolicy.s20),

                  // ─── HERO AUTO-SCROLLING ───
                  Padding(padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16), child: _HeroCarousel(recentFormations: recentFormations)),
                  const SizedBox(height: ThixPolicy.s24),

                  // ─── CATÉGORIES ───
                  _SectionHeader(title: 'Programmes d\'Expertise', onSeeAll: () => ref.read(_eduTabIndexProvider.notifier).state = 1),
                  const SizedBox(height: ThixPolicy.s12),
                  categoriesAsync.when(
                    data: (cats) => SizedBox(
                      height: 40,
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

                  if (topFormations.isNotEmpty) ...[
                    _SectionHeader(title: 'Top des formations', onSeeAll: () => ref.read(_eduTabIndexProvider.notifier).state = 1),
                    const SizedBox(height: ThixPolicy.s12),
                    SizedBox(
                      height: 260,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                        scrollDirection: Axis.horizontal,
                        itemCount: topFormations.length > 6 ? 6 : topFormations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
                        itemBuilder: (_, i) {
                          final f = topFormations[i];
                          return SizedBox(width: 200, child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}')));
                        },
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s24),
                  ],

                  const SizedBox(height: 120),
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
// RACCOURCI RAPIDE 
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
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: _eduAccentBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: _eduAccentBlue, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _eduNavyBlue)),
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
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _eduNavyBlue, letterSpacing: -0.3)),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text('Voir le catalogue', style: TextStyle(color: _eduAccentBlue, fontWeight: FontWeight.w700, fontSize: 13)),
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
              gradient: const LinearGradient(colors: [_eduNavyBlue, Color(0xFF1E293B)]),
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
              boxShadow: [BoxShadow(color: _eduNavyBlue.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('REPRENDRE L\'APPRENTISSAGE', style: TextStyle(color: ThixPolicy.gold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.3)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(value: current.progress, minHeight: 6, backgroundColor: Colors.white.withOpacity(0.15), color: ThixPolicy.gold),
                            ),
                          ),
                          const SizedBox(width: ThixPolicy.s12),
                          Text('$pct%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ThixPolicy.s16),
                Container(
                  width: 48, height: 48,
                  decoration: const BoxDecoration(color: ThixPolicy.gold, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: _eduNavyBlue, size: 28),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ─── HERO CAROUSEL AVEC AUTO-SCROLLING ───
class _HeroCarousel extends StatefulWidget {
  final List<Formation> recentFormations;
  const _HeroCarousel({required this.recentFormations});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final PageController _controller = PageController();
  int _page = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.recentFormations.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
        if (_page < widget.recentFormations.length - 1) {
          _page++;
        } else {
          _page = 0;
        }
        if (_controller.hasClients) {
          _controller.animateToPage(
            _page,
            duration: const Duration(milliseconds: 600),
            curve: Curves.fastOutSlowIn,
          );
        }
      });
    }
  }

  @override
  void dispose() {
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
          height: 180,
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
                      begin: Alignment.topLeft, 
                      end: Alignment.bottomRight,
                      colors: [_eduNavyBlue, _eduAccentBlue],
                    ),
                    image: f.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(f.imageUrl!),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
                          )
                        : null,
                    boxShadow: [BoxShadow(color: _eduNavyBlue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  padding: const EdgeInsets.all(ThixPolicy.s24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white30)),
                        child: const Text('NOUVEAU PROGRAMME', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                      ),
                      const SizedBox(height: 12),
                      Text(f.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.2, letterSpacing: -0.5)),
                      const SizedBox(height: 8),
                      Text(f.instructorName ?? 'THIX Academy', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
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
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 18 : 8, height: 8,
                decoration: BoxDecoration(
                  color: _page == i ? _eduAccentBlue : ThixPolicy.border, 
                  borderRadius: BorderRadius.circular(4)
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// ONGLET 2 : DÉCOUVRIR
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
        title: const Text('Catalogue', style: TextStyle(color: _eduNavyBlue, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
        actions: [IconButton(icon: const Icon(Icons.search, color: _eduNavyBlue), onPressed: () => context.push('/education/search'))],
      ),
      body: Column(
        children: [
          categoriesAsync.when(
            data: (cats) => Container(
              color: ThixPolicy.card,
              padding: const EdgeInsets.only(bottom: ThixPolicy.s16),
              child: SizedBox(
                height: 40,
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
              loading: () => const Center(child: CircularProgressIndicator(color: _eduAccentBlue)),
              error: (_, __) => const Center(child: Text('Erreur de chargement')),
              data: (paginated) {
                if (paginated.items.isEmpty) {
                  return const Center(
                    child: Text('Aucune formation dans cette catégorie', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, 120),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.68, crossAxisSpacing: ThixPolicy.s16, mainAxisSpacing: ThixPolicy.s16),
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
// ONGLET 3 : VÉRITABLE BIBLIOTHÈQUE (Typage fort avec Book)
// ============================================================================
class _LibraryPage extends ConsumerWidget {
  const _LibraryPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider).value;
    if (userId == null) return const Center(child: Text('Non connecté'));

    // Ton provider qui retourne un Future<List<Book>>
    final booksAsync = ref.watch(myBooksProvider(userId)); 

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6), // Fond texturé derrière l'étagère
      appBar: AppBar(
        backgroundColor: _eduNavyBlue,
        elevation: 0,
        title: const Text('Ma Bibliothèque', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _eduAccentBlue)),
        error: (err, stack) => Center(child: Text('Erreur de chargement des livres: $err')),
        data: (List<Book> books) {
          
          if (books.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_rounded, size: 64, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: ThixPolicy.s16),
                  const Text('Vos étagères sont vides.', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: ThixPolicy.s8),
                  const Text('Aucun livre n\'est actuellement chargé.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: ThixPolicy.s24),
                  ElevatedButton(
                    onPressed: () => ref.read(_eduTabIndexProvider.notifier).state = 1,
                    style: ElevatedButton.styleFrom(backgroundColor: _eduAccentBlue, foregroundColor: Colors.white),
                    child: const Text('Explorer les livres'),
                  ),
                ],
              ),
            );
          }

          // Séparer les livres par groupe de 3 pour remplir les "étagères"
          List<List<Book>> shelves = [];
          for (var i = 0; i < books.length; i += 3) {
            shelves.add(books.sublist(i, i + 3 > books.length ? books.length : i + 3));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 120, top: 24),
            itemCount: shelves.length,
            itemBuilder: (context, index) {
              return _LibraryShelf(booksOnShelf: shelves[index]);
            },
          );
        },
      ),
    );
  }
}

class _LibraryShelf extends StatelessWidget {
  final List<Book> booksOnShelf; 
  const _LibraryShelf({required this.booksOnShelf});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (index) {
              if (index < booksOnShelf.length) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _BookSpineCard(book: booksOnShelf[index]),
                  ),
                );
              } else {
                return const Expanded(child: SizedBox.shrink());
              }
            }),
          ),
          // La base en bois de l'étagère
          Container(
            height: 18,
            decoration: BoxDecoration(
              color: _eduShelfWood,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(color: _eduShelfShadow.withOpacity(0.8), offset: const Offset(0, 4), blurRadius: 4),
              ],
              border: const Border(
                bottom: BorderSide(color: Color(0xFF8A5A35), width: 4), 
                top: BorderSide(color: Color(0xFFF3D2B3), width: 1), 
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _BookSpineCard extends StatelessWidget {
  final Book book; 
  const _BookSpineCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/education/book/${book.id}'),
      child: Container(
        height: 170, 
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(-4, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Couverture du livre utilisant imageUrl du modèle
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                child: book.imageUrl != null && book.imageUrl!.isNotEmpty
                    ? Image.network(book.imageUrl!, fit: BoxFit.cover)
                    : Container(
                        color: _eduNavyBlue, 
                        child: const Center(child: Icon(Icons.auto_stories, color: Colors.white, size: 36))
                      ),
              ),
            ),
            // 2. Bas du livre / Dos de couverture avec Titre et Auteur
            Expanded(
              flex: 4, // Légèrement agrandi pour accommoder l'auteur
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(left: BorderSide(color: Colors.black12, width: 3)), 
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2), blurRadius: 2)
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title, 
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis, 
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: _eduNavyBlue, height: 1.1)
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.author, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis, 
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 9, color: Colors.grey)
                    ),
                    const Spacer(),
                    // Barre stylisée optionnelle
                    LinearProgressIndicator(
                      value: 0.0, // À relier à un système de progression plus tard si besoin
                      minHeight: 3, 
                      backgroundColor: Colors.grey[200], 
                      color: _eduAccentBlue
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _LibraryShelf extends StatelessWidget {
  final List<Formation> booksOnShelf;
  const _LibraryShelf({required this.booksOnShelf});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Les "Livres/Cours" posés sur l'étagère
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: booksOnShelf.map((formation) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _BookSpineCard(formation: formation),
                ),
              );
            }).toList(),
          ),
          // La base en bois de l'étagère (référence visuelle à 1000104931.jpg)
          Container(
            height: 18,
            decoration: BoxDecoration(
              color: _eduShelfWood,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(color: _eduShelfShadow.withOpacity(0.8), offset: const Offset(0, 4), blurRadius: 4),
              ],
              border: const Border(
                bottom: BorderSide(color: Color(0xFF8A5A35), width: 4),
                top: BorderSide(color: Color(0xFFF3D2B3), width: 1),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BookSpineCard extends StatelessWidget {
  final Formation formation;
  const _BookSpineCard({required this.formation});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/education/formation/${formation.id}'),
      child: Container(
        height: 190, // Fixer la hauteur pour donner l'aspect d'un livre
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(-4, 0)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Couverture du livre
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                child: formation.imageUrl != null
                    ? Image.network(formation.imageUrl!, fit: BoxFit.cover)
                    : Container(color: _eduNavyBlue, child: const Icon(Icons.school, color: Colors.white, size: 40)),
              ),
            ),
            // Dos / Titre du livre
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.black12, width: 4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formation.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: _eduNavyBlue, height: 1.2)),
                    const Spacer(),
                    LinearProgressIndicator(value: 0.4, minHeight: 4, backgroundColor: Colors.grey[200], color: _eduAccentBlue),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        title: const Text('Certifications', style: TextStyle(color: _eduNavyBlue, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
      ),
      body: certsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _eduAccentBlue)),
        error: (_, __) => const Center(child: Text('Erreur')),
        data: (certs) {
          if (certs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium_rounded, size: 64, color: ThixPolicy.borderStrong),
                  const SizedBox(height: ThixPolicy.s16),
                  const Text('Aucune certification obtenue', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
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
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg), 
                  border: Border.all(color: const Color(0xFFE2E8F0)), 
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(gradient: ThixPolicy.goldGradient, borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.workspace_premium_rounded, color: ThixPolicy.inkDeep, size: 30),
                    ),
                    const SizedBox(width: ThixPolicy.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Certificat d\'Expertise', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _eduNavyBlue)),
                          const SizedBox(height: 4),
                          Text('Délivré le ${cert.issuedAt.day}/${cert.issuedAt.month}/${cert.issuedAt.year}', style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: _eduAccentBlue, size: 28), 
                      onPressed: () => context.push('/education/certificate/${cert.id}', extra: cert)
                    ),
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
// ONGLET 5 : PROFIL
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
        title: const Text('Compte Professionnel', style: TextStyle(color: _eduNavyBlue, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(ThixPolicy.s16, ThixPolicy.s16, ThixPolicy.s16, 120),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(ThixPolicy.s20),
              decoration: BoxDecoration(
                color: _eduNavyBlue, 
                borderRadius: BorderRadius.circular(ThixPolicy.rLg), 
                boxShadow: [BoxShadow(color: _eduNavyBlue.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))]
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36, backgroundColor: Colors.white24,
                    backgroundImage: user?.userMetadata?['avatar_url'] != null ? NetworkImage(user!.userMetadata!['avatar_url']) : null,
                    child: user?.userMetadata?['avatar_url'] == null ? const Icon(Icons.person, size: 36, color: Colors.white) : null,
                  ),
                  const SizedBox(width: ThixPolicy.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.userMetadata?['full_name'] ?? 'Apprenant', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(user?.email ?? '', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: ThixPolicy.s24),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/instructor/dashboard'),
                icon: const Icon(Icons.business_center_rounded, size: 22),
                label: const Text('Espace Formateur', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _eduAccentBlue, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: ThixPolicy.s32),

            Align(alignment: Alignment.centerLeft, child: Text('Outils Institutionnels', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _eduNavyBlue.withOpacity(0.7)))),
            const SizedBox(height: ThixPolicy.s12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                children: [
                  _ProfileMenuTile(icon: Icons.auto_stories_rounded, label: 'Ressources ouvertes', color: Colors.green[600]!, onTap: () => context.push('/education/free-courses')),
                  const Divider(height: 1, color: Color(0xFFE2E8F0), indent: 64),
                  _ProfileMenuTile(icon: Icons.ondemand_video_rounded, label: 'Masterclasses', color: Colors.purple[600]!, onTap: () => context.push('/education/webinars')),
                  const Divider(height: 1, color: Color(0xFFE2E8F0), indent: 64),
                  _ProfileMenuTile(icon: Icons.handshake_rounded, label: 'Réseau & Mentorat', color: Colors.orange[600]!, onTap: () => context.push('/education/mentorat')),
                  const Divider(height: 1, color: Color(0xFFE2E8F0), indent: 64),
                  _ProfileMenuTile(icon: Icons.event_available_rounded, label: 'Agenda des événements', color: _eduAccentBlue, onTap: () => context.push('/education/events')),
                ],
              ),
            ),

            const SizedBox(height: ThixPolicy.s24),

            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: _ProfileMenuTile(icon: Icons.help_center_rounded, label: 'Support Technique', color: Colors.grey[700]!, onTap: () => context.push('/education/help')),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20, vertical: 6),
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _eduNavyBlue)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 24),
    );
  }
}
