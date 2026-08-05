import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Imports relatifs exacts — inchangés (aucun impact DB/architecture)
import '../providers/education_provider.dart' hide certificatesProvider;
import '../providers/certificate_provider.dart';

import '../widgets/common/education_category_chip.dart';
import '../widgets/common/formation_card.dart';
import '../widgets/common/edu_image.dart';
import '../models/category.dart';
import '../models/formation.dart';
import '../models/certificate.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// DESIGN TOKENS — Charte THIX ID (palette resserrée, un seul point de vérité)
/// Objectif : cohérence visuelle premium + zéro dérive de couleurs "ad hoc".
/// ─────────────────────────────────────────────────────────────────────────
class _Edu {
  _Edu._();

  // Couleurs de marque
  static const Color inkDeep = Color(0xFF0A1F44); // navy deep
  static const Color ink = Color(0xFF123B7A); // navy
  static const Color brand = Color(0xFF2D6CDF); // primary blue
  static const Color brandLight = Color(0xFF5B9CFF); // dégradés uniquement
  static const Color gold = Color(0xFFE3B23C); // accent premium — usage rare et ciblé

  // Surfaces
  static const Color surface = Color(0xFFF7FAFF); // fond d'écran
  static const Color card = Color(0xFFFFFFFF); // cartes
  static const Color tint = Color(0xFFEFF5FF); // fond doux (bandeaux, chips actifs)
  static const Color divider = Color(0xFFE7EEFC);

  // Texte
  static const Color textPrimary = Color(0xFF10192E);
  static const Color textSecondary = Color(0xFF7386A8);
  static const Color onBrand = Colors.white;

  // États sémantiques (usage fonctionnel uniquement, jamais décoratif)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF97316);
  static const Color danger = Color(0xFFEF4444);

  // Dégradés réutilisables (un seul endroit à maintenir)
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [inkDeep, brand],
  );
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [inkDeep, ink, brand],
  );

  // Échelle d'espacement (8pt grid)
  static const double s4 = 4, s6 = 6, s8 = 8, s10 = 10, s12 = 12, s14 = 14;
  static const double s16 = 16, s18 = 18, s20 = 20, s22 = 22, s24 = 24;

  // Rayons
  static const double rSm = 12, rMd = 16, rLg = 20, rXl = 24, rXxl = 26;

  // Ombre premium unique (évite les BoxShadow dupliquées un peu partout)
  static List<BoxShadow> shadow({double opacity = 0.10, double blur = 20}) => [
        BoxShadow(color: inkDeep.withOpacity(opacity), blurRadius: blur, offset: const Offset(0, 8)),
      ];

  /// Cible tactile accessible minimale (44x44 — recommandation WCAG / iOS HIG)
  static const double minTapTarget = 44.0;
}

/// Index de l'onglet actif, partagé entre toutes les pages.
final _eduTabIndexProvider = StateProvider<int>((ref) => 0);

/// Nombre de notifications non lues — branché sur Supabase.
/// ⚠️ Requête strictement identique à l'originale : aucun changement de schéma.
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
      // Accessibilité : le lecteur d'écran annonce le rôle du panneau
      useRootNavigator: true,
      builder: (_) => Semantics(
        label: 'Menu supplémentaire',
        container: true,
        child: Container(
          decoration: const BoxDecoration(
            color: _Edu.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(_Edu.rXl)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: _Edu.divider, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 18),
              _MenuTile(icon: Icons.card_giftcard_rounded, label: 'Cours gratuits', color: _Edu.success, onTap: () { Navigator.pop(context); context.push('/education/free-courses'); }),
              _MenuTile(icon: Icons.videocam_rounded, label: 'Webinaires', color: _Edu.brand, onTap: () { Navigator.pop(context); context.push('/education/webinars'); }),
              _MenuTile(icon: Icons.groups_rounded, label: 'Mentorat', color: _Edu.warning, onTap: () { Navigator.pop(context); context.push('/education/mentorat'); }),
              _MenuTile(icon: Icons.event_rounded, label: 'Événements', color: _Edu.ink, onTap: () { Navigator.pop(context); context.push('/education/events'); }),
              _MenuTile(icon: Icons.support_agent_rounded, label: 'Aide & support', color: _Edu.textSecondary, onTap: () { Navigator.pop(context); context.push('/education/help'); }),
            ],
          ),
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
      backgroundColor: _Edu.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(76),
        child: Container(
          color: _Edu.card,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Ouvrir le menu',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(_Edu.rSm),
                      onTap: () => _openMoreMenu(context),
                      child: Container(
                        width: _Edu.minTapTarget,
                        height: _Edu.minTapTarget,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _Edu.tint, borderRadius: BorderRadius.circular(_Edu.rSm)),
                        child: const Icon(Icons.menu_rounded, color: _Edu.ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(gradient: _Edu.brandGradient, borderRadius: BorderRadius.all(Radius.circular(11))),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RichText(
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(children: [
                            const TextSpan(text: 'THIX ', style: TextStyle(color: _Edu.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                            TextSpan(
                              text: selectedIndex == 0 ? 'FORMATION' : _titles[selectedIndex].toUpperCase(),
                              style: const TextStyle(color: _Edu.brand, fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ]),
                        ),
                        if (selectedIndex == 0)
                          const Text(
                            "Apprenez aujourd'hui, réussissez demain.",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _Edu.textSecondary, fontSize: 11.5),
                          ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Rechercher une formation',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(21),
                      onTap: () => context.push('/education/search'),
                      child: const SizedBox(
                        width: _Edu.minTapTarget,
                        height: _Edu.minTapTarget,
                        child: Icon(Icons.search_rounded, color: _Edu.ink, size: 22),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: unreadAsync.maybeWhen(
                      data: (c) => c > 0 ? 'Notifications, $c non lues' : 'Notifications',
                      orElse: () => 'Notifications',
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(21),
                      onTap: () => context.push('/notifications'),
                      child: SizedBox(
                        width: _Edu.minTapTarget,
                        height: _Edu.minTapTarget,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_none_rounded, color: _Edu.ink, size: 23),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: unreadAsync.maybeWhen(
                                data: (count) => count > 0
                                    ? Container(
                                        padding: const EdgeInsets.all(3),
                                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                        decoration: const BoxDecoration(color: _Edu.danger, shape: BoxShape.circle),
                                        child: Text(
                                          count > 9 ? '9+' : '$count',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                                orElse: () => const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Mon profil',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => ref.read(_eduTabIndexProvider.notifier).state = 5,
                      child: CircleAvatar(
                        radius: _Edu.minTapTarget / 2,
                        backgroundColor: _Edu.tint,
                        backgroundImage: (user?.userMetadata?['avatar_url'] != null)
                            ? NetworkImage(user!.userMetadata!['avatar_url'])
                            : null,
                        child: (user?.userMetadata?['avatar_url'] == null)
                            ? const Icon(Icons.person_rounded, color: _Edu.ink, size: 18)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // IndexedStack conserve l'état de chaque onglet (perf : pas de rebuild inutile)
      body: IndexedStack(index: selectedIndex, children: _pages),
      bottomNavigationBar: _BottomNav(selectedIndex: selectedIndex),
    );
  }
}

/// Barre de navigation extraite en widget dédié → se reconstruit seule
/// (le body ne se re-render pas quand seul l'onglet change de style visuel).
class _BottomNav extends ConsumerWidget {
  final int selectedIndex;
  const _BottomNav({required this.selectedIndex});

  static const _titles = EducationHome._titles;
  static const _navIcons = EducationHome._navIcons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        decoration: BoxDecoration(color: _Edu.card, borderRadius: BorderRadius.circular(_Edu.rXxl), boxShadow: _Edu.shadow()),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_titles.length, (i) {
                final isCenter = i == 2; // "Apprendre" mis en avant
                final isSelected = selectedIndex == i;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: _titles[i],
                  child: isCenter
                      ? InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () => ref.read(_eduTabIndexProvider.notifier).state = i,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: _Edu.brandGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: _Edu.brand.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
                                ),
                                child: Icon(_navIcons[i], color: Colors.white, size: 24),
                              ),
                              const SizedBox(height: 3),
                              Text(_titles[i], style: const TextStyle(fontSize: 9, color: _Edu.brand, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        )
                      : InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => ref.read(_eduTabIndexProvider.notifier).state = i,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: isSelected ? _Edu.tint : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(_navIcons[i], color: isSelected ? _Edu.brand : _Edu.textSecondary, size: 20),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _titles[i],
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isSelected ? _Edu.brand : _Edu.textSecondary,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                );
              }),
            ),
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
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _Edu.textPrimary)),
            ],
          ),
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
  bool get wantKeepAlive => true; // évite de recharger la page à chaque changement d'onglet

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
      loading: () => const Center(child: CircularProgressIndicator(color: _Edu.brand)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Une erreur est survenue. Réessayez plus tard.', textAlign: TextAlign.center, style: const TextStyle(color: _Edu.textSecondary)),
        ),
      ),
      data: (paginated) {
        final formations = paginated.items;
        final recommended = [...formations]..sort((a, b) => b.rating.compareTo(a.rating));

        return RefreshIndicator(
          color: _Edu.brand,
          onRefresh: () async {
            ref.invalidate(formationsProvider);
            ref.invalidate(categoriesProvider);
            if (userId != null) ref.invalidate(myEnrollmentsProvider(userId));
          },
          child: CustomScrollView(
            controller: _scrollController,
            // cacheExtent modéré : fluidité sur bas de gamme sans exploser la mémoire
            cacheExtent: 800,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 0), child: RepaintBoundary(child: _HeroCarousel())),
                    const SizedBox(height: 18),
                    const _QuickActionsRow(),
                    const SizedBox(height: 22),
                    _SectionHeader(
                      title: 'Catégories populaires',
                      onSeeAll: () => ref.read(_eduTabIndexProvider.notifier).state = 2,
                    ),
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
                                  key: ValueKey('cat-${cat.id}'),
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
                    const SizedBox(height: 24),
                    if (recommended.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'Formations recommandées',
                        onSeeAll: () => ref.read(_eduTabIndexProvider.notifier).state = 2,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 236,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: recommended.length > 8 ? 8 : recommended.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (c, i) {
                            final f = recommended[i];
                            return RepaintBoundary(
                              key: ValueKey('rec-${f.id}'),
                              child: SizedBox(
                                width: 152,
                                child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}')),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        button: true,
                        label: 'Voir mes certificats',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(_Edu.rXl),
                          onTap: () => ref.read(_eduTabIndexProvider.notifier).state = 3,
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(color: _Edu.tint, borderRadius: BorderRadius.circular(_Edu.rXl)),
                            child: Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(color: _Edu.card, borderRadius: BorderRadius.circular(16)),
                                  child: const Icon(Icons.workspace_premium_rounded, color: _Edu.brand, size: 28),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Obtenez des certificats reconnus', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: _Edu.textPrimary)),
                                      SizedBox(height: 3),
                                      Text('Valorisez vos compétences et démarquez-vous.', style: TextStyle(fontSize: 12, color: _Edu.textSecondary)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: _Edu.brand),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (userId != null)
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _ProgressRow(userId: userId)),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SectionHeader(title: 'Toutes les formations'),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              // Grille en Sliver natif : évite le shrinkWrap coûteux d'un GridView imbriqué
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (c, i) {
                      if (i >= formations.length) {
                        return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                      }
                      final f = formations[i];
                      return RepaintBoundary(
                        key: ValueKey('all-${f.id}'),
                        child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}')),
                      );
                    },
                    childCount: formations.length + (paginated.hasMore ? 2 : 0),
                  ),
                ),
              ),
              if (paginated.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }
}

/// En-tête de section réutilisé (évite la duplication Row/Text/InkWell).
class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: _Edu.textPrimary)),
          if (onSeeAll != null)
            Semantics(
              button: true,
              label: 'Voir tout : $title',
              child: InkWell(
                onTap: onSeeAll,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Text('Voir tout', style: TextStyle(color: _Edu.brand, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Carousel éditorial du hero (contenu statique, aucune donnée métier).
class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel();
  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  static const _slides = [
    {'title': 'Développez vos compétences,\nchangez votre avenir.', 'subtitle': 'Des milliers de cours et certificats pour booster votre carrière.', 'icon': Icons.trending_up_rounded},
    {'title': 'Apprenez à votre rythme,\noù que vous soyez.', 'subtitle': 'Cours accessibles 24h/24 depuis votre téléphone.', 'icon': Icons.phone_iphone_rounded},
    {'title': 'Des formateurs experts\nde chez vous.', 'subtitle': 'Des professionnels congolais partagent leur savoir-faire.', 'icon': Icons.groups_rounded},
    {'title': 'Décrochez un certificat\nreconnu.', 'subtitle': 'Valorisez votre profil auprès des recruteurs.', 'icon': Icons.workspace_premium_rounded},
    {'title': "Rejoignez une communauté\nd'apprenants.", 'subtitle': 'Échangez, progressez et réussissez ensemble.', 'icon': Icons.diversity_3_rounded},
    {'title': 'Commencez gratuitement\ndès aujourd\'hui.', 'subtitle': 'Découvrez nos cours gratuits sans engagement.', 'icon': Icons.card_giftcard_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      _page = (_page + 1) % _slides.length;
      _controller.animateToPage(_page, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = ProviderScope.containerOf(context, listen: false).read(_eduTabIndexProvider.notifier);
    return Column(
      children: [
        SizedBox(
          height: 158,
          child: PageView.builder(
            controller: _controller,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (c, i) {
              final s = _slides[i];
              return Semantics(
                button: true,
                label: '${s['title']}. ${s['subtitle']}',
                child: GestureDetector(
                  onTap: () => tabIndex.state = 2,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: const BoxDecoration(gradient: _Edu.heroGradient, borderRadius: BorderRadius.all(Radius.circular(24))),
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: _Edu.gold, borderRadius: BorderRadius.circular(12)),
                                child: const Text('À LA UNE', style: TextStyle(color: _Edu.inkDeep, fontSize: 10.5, fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(height: 10),
                              Text(s['title'] as String, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.2)),
                              const SizedBox(height: 6),
                              Text(s['subtitle'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(18)),
                          child: Icon(s['icon'] as IconData, color: _Edu.gold, size: 30),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _slides.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _page == i ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(color: _page == i ? _Edu.brand : _Edu.divider, borderRadius: BorderRadius.circular(3)),
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
    final items = <({IconData icon, String label, VoidCallback onTap})>[
      (icon: Icons.grid_view_rounded, label: 'Toutes les\nformations', onTap: () => notifier.state = 2),
      (icon: Icons.workspace_premium_rounded, label: 'Certifications', onTap: () => notifier.state = 3),
      (icon: Icons.local_fire_department_rounded, label: 'Populaires', onTap: () => notifier.state = 2),
      (icon: Icons.menu_book_rounded, label: 'Mes cours', onTap: () => notifier.state = 1),
      (icon: Icons.history_rounded, label: 'Reprendre', onTap: () => notifier.state = 1),
    ];
    return SizedBox(
      height: 78,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (c, i) {
          final item = items[i];
          return Semantics(
            button: true,
            label: item.label.replaceAll('\n', ' '),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: item.onTap,
              child: Container(
                width: 74,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(color: _Edu.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _Edu.divider)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: _Edu.brand, size: 22),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _Edu.textPrimary, height: 1.1),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "Continuez votre apprentissage" + "Objectif du mois" — données 100% réelles
/// via myEnrollmentsProvider (aucune valeur fictive, requête inchangée).
class _ProgressRow extends ConsumerWidget {
  final String userId;
  const _ProgressRow({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollAsync = ref.watch(myEnrollmentsProvider(userId));
    return enrollAsync.when(
      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final inProgress = list.where((e) => e.formation != null && (e.progress ?? 0) > 0 && (e.progress ?? 0) < 1).toList();
        final current = inProgress.isNotEmpty ? inProgress.first : null;
        final completedCount = list.where((e) => (e.progress ?? 0) >= 1).length;
        const goal = 5; // objectif fixe — à remplacer par une valeur Supabase si stockée un jour

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: current == null
                  ? const _EmptyProgressCard()
                  : Semantics(
                      button: true,
                      label: 'Continuer ${current.formation!.title}, ${((current.progress ?? 0) * 100).round()} pour cent terminé',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push('/education/formation/${current.formation!.id}'),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: _Edu.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _Edu.divider)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Continuez votre apprentissage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Edu.textSecondary)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  EduImage(url: current.formation!.imageUrl, width: 44, height: 44, radius: BorderRadius.circular(12)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      current.formation!.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _Edu.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(value: current.progress, minHeight: 6, backgroundColor: _Edu.divider, color: _Edu.success),
                              ),
                              const SizedBox(height: 6),
                              Text('${((current.progress ?? 0) * 100).round()}% terminé', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _Edu.success)),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                label: 'Objectif : terminer $goal formations, $completedCount sur $goal',
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _Edu.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _Edu.divider)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Objectif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Edu.textSecondary)),
                      const SizedBox(height: 8),
                      const Text('Terminez $goal formations\npour un badge.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Edu.textPrimary, height: 1.3)),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: (completedCount / goal).clamp(0.0, 1.0), minHeight: 6, backgroundColor: _Edu.divider, color: _Edu.brand),
                      ),
                      const SizedBox(height: 6),
                      Text('$completedCount / $goal formations', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _Edu.brand)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyProgressCard extends StatelessWidget {
  const _EmptyProgressCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _Edu.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _Edu.divider)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Continuez votre apprentissage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Edu.textSecondary)),
          SizedBox(height: 10),
          Text('Aucune formation en cours', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _Edu.textPrimary)),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Une erreur est survenue.')),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(color: _Edu.tint, shape: BoxShape.circle),
                  child: Icon(Icons.book_rounded, size: 36, color: _Edu.ink.withOpacity(0.5)),
                ),
                const SizedBox(height: 16),
                const Text('Aucune formation en cours', style: TextStyle(fontWeight: FontWeight.w800, color: _Edu.textPrimary)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          cacheExtent: 800,
          itemCount: list.length,
          itemBuilder: (c, i) {
            final enrollment = list[i];
            final formation = enrollment.formation;
            if (formation == null) return const SizedBox.shrink();
            return Padding(
              key: ValueKey('enroll-${formation.id}'),
              padding: const EdgeInsets.only(bottom: 12),
              child: RepaintBoundary(
                child: FormationCard(
                  formation: formation,
                  onTap: () => context.push('/education/formation/${formation.id}'),
                  progress: enrollment.progress?.toDouble(),
                ),
              ),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Une erreur est survenue.')),
      data: (paginated) => ListView.builder(
        padding: const EdgeInsets.all(16),
        cacheExtent: 800,
        itemCount: paginated.items.length,
        itemBuilder: (c, i) {
          final f = paginated.items[i];
          return Padding(
            key: ValueKey('list-${f.id}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: RepaintBoundary(child: FormationCard(formation: f, onTap: () => context.push('/education/formation/${f.id}'))),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Une erreur est survenue.')),
      data: (certs) {
        if (certs.isEmpty) return const Center(child: Text('Aucun certificat', style: TextStyle(color: _Edu.textSecondary)));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          cacheExtent: 800,
          itemCount: certs.length,
          itemBuilder: (c, i) {
            final cert = certs[i];
            return Container(
              key: ValueKey('cert-${cert.id}'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _Edu.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _Edu.divider)),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(gradient: _Edu.brandGradient, borderRadius: BorderRadius.all(Radius.circular(14))),
                    child: const Icon(Icons.verified_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text('Délivré le ${cert.issuedAt.day}/${cert.issuedAt.month}/${cert.issuedAt.year}', style: const TextStyle(color: _Edu.textPrimary, fontWeight: FontWeight.w600))),
                  Semantics(
                    button: true,
                    label: 'Voir le certificat',
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => context.push('/education/certificate/${cert.id}', extra: cert),
                    ),
                  ),
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
  Widget build(BuildContext context) => const Center(
        child: Text('Bibliothèque — Bientôt disponible', style: TextStyle(color: _Edu.textSecondary, fontWeight: FontWeight.w600)),
      );
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
              width: 100,
              height: 100,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: _Edu.brandGradient),
              child: const Icon(Icons.person_rounded, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(user?.email ?? 'Utilisateur', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _Edu.textPrimary)),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: _Edu.minTapTarget + 4,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/instructor/dashboard'),
                icon: const Icon(Icons.school_rounded),
                label: const Text('Passer en mode formateur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Edu.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
