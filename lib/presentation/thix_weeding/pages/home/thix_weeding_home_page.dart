// lib/presentation/thix_weeding/pages/home/thix_weeding_home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/failure.dart';
import '../../data/repositories/wedding_repository_impl.dart';
import '../../domain/entities/wedding_entity.dart';

part 'thix_weeding_home_page.g.dart';

// ============================================================
// PALETTE — Charte THIX MARIAGE (Amour & Élégance / Lumineux)
// ============================================================
class _P {
  static const bg = Color(0xFFFFFBFC);
  static const surface = Colors.white;
  static const primary = Color(0xFFE31C4E);
  static const primarySoft = Color(0xFFFFE3EA);
  static const secondary = Color(0xFFFF7A9C);
  static const accent = Color(0xFFD4AF37);
  static const accentSoft = Color(0xFFFDF6E3);
  static const ink = Color(0xFF241521);
  static const inkSoft = Color(0xFF8A7580);
  static const border = Color(0xFFF3E1E6);
  static const gradPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE31C4E), Color(0xFFFF6B8B)],
  );
  static final shadow = [
    BoxShadow(color: const Color(0xFFE31C4E).withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8))
  ];
  static final shadowSoft = [
    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))
  ];
}

// ============================================================
// PROVIDERS
// ============================================================
@riverpod
Future<List<Map<String, dynamic>>> homePromoSlides(HomePromoSlidesRef ref) async {
  await Future.delayed(const Duration(milliseconds: 250));
  return [
    {'tag': 'PROMO FLASH', 'title': "Jusqu'à -40%", 'subtitle': 'Sur les salles de réception & traiteurs', 'detail': "Valable jusqu'au 30 Septembre 2026", 'cta': 'Profiter maintenant', 'imageUrl': 'https://picsum.photos/seed/wedding-venue/900/600'},
    {'tag': 'NOUVEAU', 'title': 'Créez votre site', 'subtitle': "De mariage en 5 minutes", 'detail': 'ID unique + invitations digitales', 'cta': 'Commencer', 'imageUrl': 'https://picsum.photos/seed/wedding-couple/900/600'},
    {'tag': 'PARTENAIRES', 'title': '+300 prestataires', 'subtitle': 'Vérifiés partout en RDC', 'detail': 'Avis authentiques & prix transparents', 'cta': 'Découvrir', 'imageUrl': 'https://picsum.photos/seed/wedding-deco/900/600'},
  ];
}

@riverpod
Future<List<Map<String, dynamic>>> homeCategories(HomeCategoriesRef ref) async {
  await Future.delayed(const Duration(milliseconds: 150));
  return [
    {'label': 'Salles', 'icon': Icons.villa_outlined},
    {'label': 'Traiteurs', 'icon': Icons.restaurant_outlined},
    {'label': 'M. de cérémonie', 'icon': Icons.mic_none_outlined},
    {'label': 'Décoration', 'icon': Icons.local_florist_outlined},
    {'label': 'Photographes', 'icon': Icons.camera_alt_outlined},
    {'label': 'Vidéastes', 'icon': Icons.videocam_outlined},
    {'label': 'DJ', 'icon': Icons.music_note_outlined},
    {'label': 'Robes', 'icon': Icons.checkroom_outlined},
    {'label': 'Costumes', 'icon': Icons.checkroom_outlined},
    {'label': 'Plus', 'icon': Icons.grid_view_rounded},
  ];
}

@riverpod
Future<Map<String, int>> homeStats(HomeStatsRef ref) async {
  await Future.delayed(const Duration(milliseconds: 200));
  return {'Prestataires': 312, 'Avis vérifiés': 1840, 'Offres actives': 26, 'Événements': 97};
}

@riverpod
Future<List<Map<String, dynamic>>> homeOffers(HomeOffersRef ref) async {
  await Future.delayed(const Duration(milliseconds: 250));
  return [
    {'title': 'Salles de fête', 'subtitle': 'Réservez votre salle idéale', 'discount': '-30%', 'icon': Icons.villa_outlined, 'color': _P.primary},
    {'title': 'Traiteurs', 'subtitle': 'Menus spéciaux mariage', 'discount': '-20%', 'icon': Icons.restaurant_outlined, 'color': _P.secondary},
    {'title': 'Photographe offert', 'subtitle': 'Pour toute réservation package complet', 'discount': 'OFFERT', 'icon': Icons.camera_alt_outlined, 'color': _P.ink},
    {'title': 'Décoration', 'subtitle': 'Ambiances inoubliables', 'discount': '-15%', 'icon': Icons.local_florist_outlined, 'color': _P.accent},
  ];
}

@riverpod
Future<List<Map<String, dynamic>>> homeProviders(HomeProvidersRef ref) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return [
    {'name': 'Palais des Congrès', 'category': 'Salle de fête', 'zone': 'Douala', 'rating': 4.8, 'reviews': 128, 'price': 'À partir de 600.000 FC', 'icon': Icons.villa_outlined},
    {'name': "Saveurs d'Afrique", 'category': 'Traiteur', 'zone': 'Douala', 'rating': 4.9, 'reviews': 96, 'price': 'À partir de 450.000 FC', 'icon': Icons.restaurant_outlined},
    {'name': 'Lens Prod', 'category': 'Photographe', 'zone': 'Douala', 'rating': 4.9, 'reviews': 215, 'price': 'À partir de 300.000 FC', 'icon': Icons.camera_alt_outlined},
    {'name': 'Dream Décor', 'category': 'Décoration', 'zone': 'Douala', 'rating': 4.7, 'reviews': 78, 'price': 'À partir de 250.000 FC', 'icon': Icons.local_florist_outlined},
  ];
}

@riverpod
Future<List<Map<String, dynamic>>> homeAnnouncements(HomeAnnouncementsRef ref) async {
  await Future.delayed(const Duration(milliseconds: 200));
  return [
    {'tag': 'À VENDRE', 'title': 'Robe de mariée T38', 'subtitle': '450.000 FC', 'icon': Icons.checkroom_outlined},
    {'tag': 'À LOUER', 'title': 'Salle 200 places', 'subtitle': '800.000 FC / jour', 'icon': Icons.villa_outlined},
    {'tag': 'SERVICE', 'title': 'Coiffure & maquillage', 'subtitle': "Dès 30.000 FC", 'icon': Icons.face_retouching_natural_outlined},
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
  final PageController _promoController = PageController();
  int _promoIndex = 0;
  Timer? _promoTimer;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController();
    _focusNode = FocusNode();
    _promoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_promoController.hasClients) return;
      final next = (_promoIndex + 1) % 3;
      _promoController.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.fastOutSlowIn);
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    _focusNode.dispose();
    _promoController.dispose();
    _promoTimer?.cancel();
    super.dispose();
  }

  Future<void> _onStaffAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connectez-vous pour accéder à l\'espace staff')));
      context.push('/thix-weeding/auth/login');
      return;
    }
    try {
      final repo = ref.read(weddingRepositoryProvider);
      final weddings = await repo.getWeddingsByOwnerId(user.id);
      if (!mounted) return;
      if (weddings.isEmpty) {
        context.push('/thix-weeding/create');
      } else if (weddings.length == 1) {
        context.push('/thix-weeding/staff/${weddings.first.id}');
      } else {
        context.push('/thix-weeding/staff/my-weddings');
      }
    } catch (_) {
      if (!mounted) return;
      context.push('/thix-weeding/staff/my-weddings');
    }
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

  void _onScanQr() {
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
          SliverToBoxAdapter(
            child: _HeroSearchSection(
              controller: _idController,
              focusNode: _focusNode,
              isLoading: _isSearching,
              onSearch: _onSearch,
              onScanQr: _onScanQr,
              onStaffTap: _onStaffAccess,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
          SliverToBoxAdapter(
            child: catsAsync.when(
              data: (cats) => _CategoryGrid(categories: cats, onTap: _onTapGeneric),
              loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: _P.primary))),
              error: (_, __) => const SizedBox(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _SectionHeader(title: 'Offres du moment'))),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: offersAsync.when(
              data: (offers) => _OffersRow(offers: offers, onTap: _onTapGeneric),
              loading: () => const SizedBox(height: 170, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary))),
              error: (e, _) => SizedBox(height: 60, child: Center(child: Text('Erreur: $e'))),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 36)),
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _SectionHeader(title: "Prestataires d'Excellence"))),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: providersAsync.when(
              data: (providers) => _ProvidersGrid(providers: providers, onTap: _onTapGeneric),
              loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary))),
              error: (_, __) => const SizedBox(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 36)),
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _SectionHeader(title: 'Dernières Annonces'))),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: announcementsAsync.when(
              data: (ann) => _AnnouncementsList(items: ann, onTap: _onTapGeneric),
              loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary))),
              error: (_, __) => const SizedBox(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _TrustRow())),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}

// ============================================================
// HERO SECTION — AVEC BOUTON STAFF
// ============================================================
class _HeroSearchSection extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSearch;
  final VoidCallback onScanQr;
  final VoidCallback onStaffTap;

  const _HeroSearchSection({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSearch,
    required this.onScanQr,
    required this.onStaffTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        color: _P.primarySoft,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Opacity(
                  opacity: 0.9,
                  child: Image.network('https://picsum.photos/seed/wedding-hero/500/650', width: 190, height: 260, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 190, height: 260, color: _P.border)),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(text: const TextSpan(style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1.2), children: [TextSpan(text: 'THIX ', style: TextStyle(color: _P.ink)), TextSpan(text: 'MARIAGE', style: TextStyle(color: _P.primary))])),
                    InkWell(
                      onTap: onStaffTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(12), boxShadow: _P.shadowSoft, border: Border.all(color: _P.border)),
                        child: const Row(children: [Icon(Icons.dashboard_customize_rounded, size: 16, color: _P.primary), SizedBox(width: 6), Text('Espace Staff', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _P.ink))]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const SizedBox(width: 230, child: Text('Vous avez un\nID de mariage?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _P.ink, height: 1.15))),
                const SizedBox(height: 8),
                const SizedBox(width: 210, child: Text('Accédez à tous les détails de votre événement', style: TextStyle(fontSize: 13, color: _P.inkSoft, fontWeight: FontWeight.w400, height: 1.3))),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(18), boxShadow: _P.shadow),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(Icons.search_rounded, size: 20, color: _P.inkSoft),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: controller, focusNode: focusNode, textCapitalization: TextCapitalization.characters, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _P.ink), decoration: const InputDecoration(isDense: true, hintText: 'Entrez votre ID de mariage', hintStyle: TextStyle(fontSize: 13, color: _P.inkSoft, fontWeight: FontWeight.w400), border: InputBorder.none), onSubmitted: (_) => onSearch())),
                      InkWell(
                        onTap: isLoading? null : onSearch,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), decoration: BoxDecoration(gradient: _P.gradPrimary, borderRadius: BorderRadius.circular(14)), child: isLoading? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white))) : const Text('Rechercher', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [const Expanded(child: Divider(color: _P.border, thickness: 1)), Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('OU', style: TextStyle(fontSize: 11, color: _P.inkSoft, fontWeight: FontWeight.w600))), const Expanded(child: Divider(color: _P.border, thickness: 1))]),
                const SizedBox(height: 14),
                InkWell(onTap: onScanQr, borderRadius: BorderRadius.circular(16), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _P.border)), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.qr_code_scanner_rounded, size: 18, color: _P.primary), SizedBox(width: 10), Text('Scanner un QR Code', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _P.ink))]))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _P.ink, letterSpacing: -0.3)), InkWell(onTap: () {}, child: const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Row(children: [Text('Voir tout', style: TextStyle(fontSize: 12, color: _P.primary, fontWeight: FontWeight.w700)), Icon(Icons.chevron_right_rounded, size: 16, color: _P.primary)])))]);
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final void Function(String) onTap;
  const _CategoryGrid({required this.categories, required this.onTap});
  static const _bubbleColors = [Color(0xFFDCEAFB), Color(0xFFFFE1E7), Color(0xFFEBE1FB), Color(0xFFFFEDD9), Color(0xFFDDF5E6), Color(0xFFDDF3FB), Color(0xFFFFF3D6), Color(0xFFFFDCE8), Color(0xFFDCE6FF), Color(0xFFEDE9FB)];
  static const _iconColors = [Color(0xFF2D6CDF), Color(0xFFE31C4E), Color(0xFF8B5CF6), Color(0xFFE38B1C), Color(0xFF1CA050), Color(0xFF1CA6C7), Color(0xFFC79A1C), Color(0xFFE31C7A), Color(0xFF3352D9), Color(0xFF6B4CD9)];
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(24), boxShadow: _P.shadowSoft),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 16, crossAxisSpacing: 4, childAspectRatio: 0.72),
        itemBuilder: (context, i) {
          final c = categories[i];
          final bubble = _bubbleColors[i % _bubbleColors.length];
          final iconColor = _iconColors[i % _iconColors.length];
          return InkWell(
            onTap: () => onTap(c['label'] as String),
            borderRadius: BorderRadius.circular(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 52, height: 52, decoration: BoxDecoration(color: bubble, shape: BoxShape.circle), child: Icon(c['icon'] as IconData, size: 22, color: iconColor)), const SizedBox(height: 8), Text(c['label'] as String, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _P.ink, height: 1.15))]),
          );
        },
      ),
    );
  }
}

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
            child: Container(width: 140, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.09), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.18))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)), child: Text(o['discount'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))), const Spacer(), Icon(o['icon'] as IconData, size: 20, color: color), const SizedBox(height: 8), Text(o['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink)), const SizedBox(height: 2), Text(o['subtitle'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _P.inkSoft, fontWeight: FontWeight.w500))])),
          );
        },
      ),
    );
  }
}

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
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.72),
        itemBuilder: (context, i) {
          final p = providers[i];
          return InkWell(
            onTap: () => onTap(p['name'] as String),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(20), boxShadow: _P.shadowSoft),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Stack(fit: StackFit.expand, children: [ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), child: Image.network('https://picsum.photos/seed/${p['name']}/300/300', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _P.primarySoft, child: Icon(p['icon'] as IconData, size: 32, color: _P.primary)))), Positioned(top: 10, right: 10, child: Container(width: 30, height: 30, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.favorite_border_rounded, size: 15, color: _P.primary)))])),
                Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _P.ink)), const SizedBox(height: 2), Text('${p['category']} · ${p['zone']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: _P.inkSoft, fontWeight: FontWeight.w500)), const SizedBox(height: 6), Row(children: [const Icon(Icons.star_rounded, size: 14, color: _P.accent), const SizedBox(width: 3), Text('${p['rating']} (${p['reviews']})', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _P.ink))]), const SizedBox(height: 4), Text(p['price'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _P.primary))])),
              ]),
            ),
          );
        },
      ),
    );
  }
}

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
            child: Container(width: 148, decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(18), boxShadow: _P.shadowSoft), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(height: 78, child: Stack(children: [Container(width: double.infinity, decoration: const BoxDecoration(color: _P.primarySoft, borderRadius: BorderRadius.vertical(top: Radius.circular(18))), child: Center(child: Icon(a['icon'] as IconData, size: 26, color: _P.primary))), Positioned(top: 10, left: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: _P.ink, borderRadius: BorderRadius.circular(6)), child: Text(a['tag'] as String, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4))))])), Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a['title'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _P.ink, height: 1.2)), const Spacer(), Text(a['subtitle'] as String, style: const TextStyle(fontSize: 11, color: _P.primary, fontWeight: FontWeight.w800))]))])),
          );
        },
      ),
    );
  }
}

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
      decoration: BoxDecoration(gradient: _P.gradPrimary, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: _items.map((e) => Column(mainAxisSize: MainAxisSize.min, children: [Icon(e['icon'] as IconData, size: 22, color: Colors.white), const SizedBox(height: 8), Text(e['label'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600))])).toList()),
    );
  }
}
