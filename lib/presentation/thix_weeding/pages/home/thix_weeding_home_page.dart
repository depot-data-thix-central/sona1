// lib/presentation/thix_weeding/pages/home/thix_weeding_home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/failure.dart';
import '../../data/repositories/wedding_repository_impl.dart';
import '../../domain/entities/wedding_entity.dart';

part 'thix_weeding_home_page.g.dart';

// ============================================================
// PALETTE — Charte THIX MARIAGE (Rouge Renforcé / Épuré)
// ============================================================
class _P {
  static const bg = Color(0xFFFFFBFC); // Blanc légèrement rosé, très lumineux
  static const surface = Colors.white;
  static const primary = Color(0xFFE31C3D); // Rouge passion renforcé
  static const primaryDark = Color(0xFFC4102E); // Rouge profond pour dégradé
  static const primarySoft = Color(0xFFFFE3E8); // Rose pâle très clair
  static const accent = Color(0xFFD4AF37); // Or premium / Champagne
  static const accentSoft = Color(0xFFFDF6E3);

  static const ink = Color(0xFF241521); // Texte principal, brun-noir chaleureux
  static const inkSoft = Color(0xFF8A7580); // Texte secondaire rosé-gris
  static const border = Color(0xFFF3E1E6); // Bordures très douces

  static const gradPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  // Ombre douce, lumineuse, "flottante"
  static final shadow = [
    BoxShadow(
      color: primary.withOpacity(0.07),
      blurRadius: 20,
      offset: const Offset(0, 8),
    )
  ];

  static final shadowSoft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 12,
      offset: const Offset(0, 4),
    )
  ];
}

// ============================================================
// PROVIDERS
// ============================================================
@riverpod
Future<List<Map<String, dynamic>>> homeCategories(HomeCategoriesRef ref) async {
  await Future.delayed(const Duration(milliseconds: 150));
  return [
    {'label': 'Salles', 'icon': Icons.location_city_rounded, 'bg': const Color(0xFFE0F2FE), 'color': const Color(0xFF2563EB)},
    {'label': 'Traiteurs', 'icon': Icons.restaurant_rounded, 'bg': const Color(0xFFFFE3E8), 'color': _P.primary},
    {'label': 'M. de cérémonie', 'icon': Icons.mic_rounded, 'bg': const Color(0xFFF3E8FF), 'color': const Color(0xFF7C3AED)},
    {'label': 'Décoration', 'icon': Icons.local_florist_rounded, 'bg': const Color(0xFFFEF3C7), 'color': const Color(0xFFD97706)},
    {'label': 'Photographes', 'icon': Icons.camera_alt_rounded, 'bg': const Color(0xFFDCFCE7), 'color': const Color(0xFF16A34A)},
    {'label': 'Vidéastes', 'icon': Icons.videocam_rounded, 'bg': const Color(0xFFDBEAFE), 'color': const Color(0xFF2563EB)},
    {'label': 'DJ', 'icon': Icons.music_note_rounded, 'bg': const Color(0xFFFFE3E8), 'color': _P.primary},
    {'label': 'Robes', 'icon': Icons.checkroom_rounded, 'bg': const Color(0xFFFCE7F3), 'color': const Color(0xFFDB2777)},
    {'label': 'Costumes', 'icon': Icons.style_rounded, 'bg': const Color(0xFFE0F2FE), 'color': const Color(0xFF2563EB)},
    {'label': 'Plus', 'icon': Icons.grid_view_rounded, 'bg': const Color(0xFFF3E8FF), 'color': const Color(0xFF7C3AED)},
  ];
}

@riverpod
Future<List<Map<String, dynamic>>> homeOffers(HomeOffersRef ref) async {
  await Future.delayed(const Duration(milliseconds: 250));
  return [
    {
      'title': 'Salles de fête',
      'subtitle': 'Réservez votre salle idéale',
      'discount': '-30%',
      'icon': Icons.location_city_rounded,
      'color': _P.primary,
    },
    {
      'title': 'Traiteurs',
      'subtitle': 'Menus spéciaux mariage',
      'discount': '-20%',
      'icon': Icons.restaurant_rounded,
      'color': const Color(0xFF2563EB),
    },
    {
      'title': 'Photographe offert',
      'subtitle': 'Pour toute réservation package complet',
      'discount': 'OFFERT',
      'icon': Icons.camera_alt_rounded,
      'color': _P.ink,
    },
    {
      'title': 'Décoration',
      'subtitle': 'Ambiances inoubliables',
      'discount': '-15%',
      'icon': Icons.local_florist_rounded,
      'color': _P.accent,
    },
  ];
}

@riverpod
Future<List<Map<String, dynamic>>> homeProviders(HomeProvidersRef ref) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return [
    {
      'name': 'Palais des Congrès',
      'category': 'Salle de fête',
      'zone': 'Douala',
      'rating': 4.8,
      'reviews': 128,
      'price': 'À partir de 600.000 FC',
      'icon': Icons.location_city_rounded,
    },
    {
      'name': "Saveurs d'Afrique",
      'category': 'Traiteur',
      'zone': 'Douala',
      'rating': 4.9,
      'reviews': 96,
      'price': 'À partir de 450.000 FC',
      'icon': Icons.restaurant_rounded,
    },
    {
      'name': 'Lens Prod',
      'category': 'Photographe',
      'zone': 'Douala',
      'rating': 4.9,
      'reviews': 215,
      'price': 'À partir de 300.000 FC',
      'icon': Icons.camera_alt_rounded,
    },
    {
      'name': 'Dream Décor',
      'category': 'Décoration',
      'zone': 'Douala',
      'rating': 4.7,
      'reviews': 78,
      'price': 'À partir de 250.000 FC',
      'icon': Icons.local_florist_rounded,
    },
  ];
}

@riverpod
Future<List<Map<String, dynamic>>> homeAnnouncements(HomeAnnouncementsRef ref) async {
  await Future.delayed(const Duration(milliseconds: 200));
  return [
    {'tag': 'À VENDRE', 'title': 'Robe de mariée T38', 'subtitle': '450.000 FC', 'icon': Icons.checkroom_rounded},
    {'tag': 'À LOUER', 'title': 'Salle 200 places', 'subtitle': '800.000 FC / jour', 'icon': Icons.location_city_rounded},
    {'tag': 'SERVICE', 'title': 'Coiffure & maquillage', 'subtitle': "Dès 30.000 FC", 'icon': Icons.face_retouching_natural_rounded},
  ];
}

// ============================================================
// PAGE PRINCIPALE
// ============================================================
class ThixWeedingHomePage extends ConsumerStatefulWidget {
  const ThixWeedingHomePage({super.key});

  @override
  ConsumerState<ThixWeedingHomePage> createState() => _ThixWeedingHomePageState();
}

class _ThixWeedingHomePageState extends ConsumerState<ThixWeedingHomePage> {
  late final TextEditingController _idController;
  late final FocusNode _focusNode;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _idController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    if (_isSearching) return;

    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();

    try {
      final repo = ref.read(weddingRepositoryProvider);
      final WeddingEntity wedding = await repo.getWeddingById(id);
      if (!mounted) return;
      context.push('/thix-weeding/guest/${wedding.id}');
    } on Failure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade600));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID introuvable, vérifiez et réessayez')));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _onScanQr() async {
    FocusScope.of(context).unfocus();
    // TODO: brancher le scanner QR réel (ex: mobile_scanner) puis appeler
    // le même flux que _onSearch() avec l'ID décodé.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanner QR bientôt disponible')));
  }

  void _onTapGeneric(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label bientôt disponible')));
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(homeCategoriesProvider);
    final offersAsync = ref.watch(homeOffersProvider);
    final providersAsync = ref.watch(homeProvidersProvider);
    final announcementsAsync = ref.watch(homeAnnouncementsProvider);

    return Scaffold(
      backgroundColor: _P.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // HERO — Recherche ID + visuel romantique
          SliverToBoxAdapter(
            child: _HeroSearchSection(
              controller: _idController,
              focusNode: _focusNode,
              isLoading: _isSearching,
              onSearch: _onSearch,
              onScanQr: _onScanQr,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // RACCOURCIS CATEGORIES — Icônes épurées, carrés arrondis
          SliverToBoxAdapter(
            child: catsAsync.when(
              data: (cats) => _CategoryGrid(categories: cats, onTap: _onTapGeneric),
              loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: _P.primary))),
              error: (_, __) => const SizedBox(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // OFFRES DU MOMENT
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _SectionHeader(title: 'Offres du moment'),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: offersAsync.when(
              data: (offers) => _OffersRow(offers: offers, onTap: _onTapGeneric),
              loading: () => const SizedBox(height: 170, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary))),
              error: (e, _) => SizedBox(height: 60, child: Center(child: Text('Erreur: $e'))),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 36)),

          // PRESTATAIRES A LA UNE
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _SectionHeader(title: "Prestataires d'Excellence"),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: providersAsync.when(
              data: (providers) => _ProvidersGrid(providers: providers, onTap: _onTapGeneric),
              loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary))),
              error: (_, __) => const SizedBox(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 36)),

          // DERNIÈRES ANNONCES
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _SectionHeader(title: 'Dernières Annonces'),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: announcementsAsync.when(
              data: (ann) => _AnnouncementsList(items: ann, onTap: _onTapGeneric),
              loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary))),
              error: (_, __) => const SizedBox(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // BANDEAU DE CONFIANCE
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _TrustRow(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}

// ============================================================
// HERO SECTION — Visuel romantique + barre ID pleine largeur + QR
// ============================================================
class _HeroSearchSection extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSearch;
  final VoidCallback onScanQr;

  const _HeroSearchSection({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSearch,
    required this.onScanQr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        color: _P.primarySoft,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Visuel romantique en fond, cadré à droite
            Positioned(
              right: -20,
              top: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.network(
                  'https://picsum.photos/seed/wedding-hero/500/650',
                  width: 190,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 190, height: 250, color: _P.border),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                    children: [
                      TextSpan(text: 'THIX ', style: TextStyle(color: _P.ink)),
                      TextSpan(text: 'MARIAGE', style: TextStyle(color: _P.primary)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const SizedBox(
                  width: 220,
                  child: Text(
                    'Vous avez un\nID de mariage ?',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _P.ink, height: 1.15),
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(
                  width: 200,
                  child: Text(
                    'Accédez à tous les détails de votre événement',
                    style: TextStyle(fontSize: 13, color: _P.inkSoft, fontWeight: FontWeight.w400, height: 1.3),
                  ),
                ),
                const SizedBox(height: 22),
                // Barre de recherche pleine largeur + icône QR juste à côté
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: _P.surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _P.shadow,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, size: 22, color: _P.inkSoft),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                textCapitalization: TextCapitalization.characters,
                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _P.ink),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'Entrez votre ID de mariage',
                                  hintStyle: TextStyle(fontSize: 13.5, color: _P.inkSoft, fontWeight: FontWeight.w400),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) => onSearch(),
                              ),
                            ),
                            if (isLoading)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary),
                              )
                            else
                              InkWell(
                                onTap: onSearch,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(gradient: _P.gradPrimary, shape: BoxShape.circle),
                                  child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: onScanQr,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 56,
                        decoration: BoxDecoration(
                          color: _P.surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _P.shadow,
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded, size: 24, color: _P.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SECTION HEADER
// ============================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _P.ink, letterSpacing: -0.3)),
        InkWell(
          onTap: () {},
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text('Voir tout', style: TextStyle(fontSize: 12, color: _P.primary, fontWeight: FontWeight.w700)),
                Icon(Icons.chevron_right_rounded, size: 16, color: _P.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// CATEGORY GRID — Carrés arrondis épurés (pas de "stickers")
// ============================================================
class _CategoryGrid extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final void Function(String) onTap;
  const _CategoryGrid({required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _P.shadowSoft,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 18,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
        ),
        itemBuilder: (context, i) {
          final c = categories[i];
          return InkWell(
            onTap: () => onTap(c['label'] as String),
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: c['bg'] as Color,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(c['icon'] as IconData, size: 26, color: c['color'] as Color),
                ),
                const SizedBox(height: 8),
                Text(
                  c['label'] as String,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _P.ink, height: 1.15),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// OFFRES DU MOMENT
// ============================================================
class _OffersRow extends StatelessWidget {
  final List<Map<String, dynamic>> offers;
  final void Function(String) onTap;
  const _OffersRow({required this.offers, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: offers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final o = offers[i];
          final color = o['color'] as Color;
          return InkWell(
            onTap: () => onTap(o['title'] as String),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                    child: Text(o['discount'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const Spacer(),
                  Icon(o['icon'] as IconData, size: 20, color: color),
                  const SizedBox(height: 8),
                  Text(o['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink)),
                  const SizedBox(height: 2),
                  Text(o['subtitle'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _P.inkSoft, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// PRESTATAIRES D'EXCELLENCE
// ============================================================
class _ProvidersGrid extends StatelessWidget {
  final List<Map<String, dynamic>> providers;
  final void Function(String) onTap;
  const _ProvidersGrid({required this.providers, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: providers.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (context, i) {
          final p = providers[i];
          return InkWell(
            onTap: () => onTap(p['name'] as String),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: _P.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _P.shadowSoft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          child: Image.network(
                            'https://picsum.photos/seed/${p['name']}/300/300',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: _P.primarySoft,
                              child: Icon(p['icon'] as IconData, size: 32, color: _P.primary),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.favorite_border_rounded, size: 15, color: _P.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _P.ink)),
                        const SizedBox(height: 2),
                        Text('${p['category']} · ${p['zone']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: _P.inkSoft, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: _P.accent),
                            const SizedBox(width: 3),
                            Text('${p['rating']} (${p['reviews']})', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _P.ink)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(p['price'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _P.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// DERNIÈRES ANNONCES
// ============================================================
class _AnnouncementsList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(String) onTap;
  const _AnnouncementsList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final a = items[i];
          return InkWell(
            onTap: () => onTap(a['title'] as String),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 148,
              decoration: BoxDecoration(
                color: _P.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: _P.shadowSoft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 78,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(color: _P.primarySoft, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
                          child: Center(child: Icon(a['icon'] as IconData, size: 26, color: _P.primary)),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: _P.ink, borderRadius: BorderRadius.circular(6)),
                            child: Text(a['tag'] as String, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a['title'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _P.ink, height: 1.2)),
                        const Spacer(),
                        Text(a['subtitle'] as String, style: const TextStyle(fontSize: 11, color: _P.primary, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// BANDEAU DE CONFIANCE
// ============================================================
class _TrustRow extends StatelessWidget {
  const _TrustRow();

  static const _items = [
    {'icon': Icons.shield_outlined, 'label': 'Sécurisé'},
    {'icon': Icons.headset_mic_outlined, 'label': 'Support 24/7'},
    {'icon': Icons.verified_outlined, 'label': 'Vérifié'},
    {'icon': Icons.favorite_border_rounded, 'label': 'Fait avec Amour'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: _P.gradPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _items.map((e) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(e['icon'] as IconData, size: 22, color: Colors.white),
              const SizedBox(height: 8),
              Text(e['label'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
