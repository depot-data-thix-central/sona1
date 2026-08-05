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

class _P {
  static const bg = Color(0xFFF8F9FE);
  static const surface = Colors.white;
  static const primary = Color(0xFFE93D6D);
  static const primaryDark = Color(0xFFD92C5C);
  static const primarySoft = Color(0xFFFFF0F3);
  static const ink = Color(0xFF1F2B5B);
  static const inkSoft = Color(0xFF6B7A99);
  static const border = Color(0xFFEFF1F6);
  static const blueLogo = Color(0xFF2B6BFF);
  static const shadow = [BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, 8))];
  static const shadowSoft = [BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4))];
}

@riverpod
Future<List<Map<String, dynamic>>> homePromoSlides(HomePromoSlidesRef ref) async {
  await Future.delayed(const Duration(milliseconds: 250));
  return [];
}

@riverpod
Future<List<Map<String, dynamic>>> homeCategories(HomeCategoriesRef ref) async {
  await Future.delayed(const Duration(milliseconds: 150));
  return [
    {'label': 'Salles', 'icon': Icons.apartment_rounded},
    {'label': 'Traiteurs', 'icon': Icons.room_service_rounded},
    {'label': 'M. de\ncérémonie', 'icon': Icons.mic_rounded},
    {'label': 'Décoration', 'icon': Icons.park_rounded},
    {'label': 'Photographes', 'icon': Icons.photo_camera_rounded},
    {'label': 'Vidéastes', 'icon': Icons.videocam_rounded},
    {'label': 'DJ', 'icon': Icons.music_note_rounded},
    {'label': 'Robes', 'icon': Icons.checkroom_rounded},
    {'label': 'Costumes', 'icon': Icons.checkroom_rounded},
    {'label': 'Plus', 'icon': Icons.apps_rounded},
  ];
}

@riverpod 
Future<Map<String, int>> homeStats(HomeStatsRef ref) async => {'a': 1};

@riverpod
Future<List<Map<String, dynamic>>> homeOffers(HomeOffersRef ref) async {
  return [
    {'discount': '-30%', 'title': 'Salles de fête', 'subtitle': 'Réservez votre salle\nidéale', 'image': 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=400', 'bg': const Color(0xFFEBF0FF), 'color': const Color(0xFF2B6BFF)},
    {'discount': '-20%', 'title': 'Traiteurs', 'subtitle': 'Menus spéciaux\nmariage', 'image': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400', 'bg': const Color(0xFFFFE6EB), 'color': const Color(0xFFE93D6D)},
    {'discount': 'Photographe\noffert', 'title': '', 'subtitle': 'Pour toute réservation\nde package complet', 'image': 'https://images.unsplash.com/photo-1452780212940-6f5c0d14d848?w=400', 'bg': const Color(0xFFEBF0FF), 'color': _P.ink},
    {'discount': '-15%', 'title': 'Décoration', 'subtitle': 'Ambiances\ninoubliables', 'image': 'https://images.unsplash.com/photo-1518895949257-7621c3c786d7?w=400', 'bg': const Color(0xFFFFF3E0), 'color': const Color(0xFFFF8C00)},
  ];
}

@riverpod
Future<List<Map<String, dynamic>>> homeProviders(HomeProvidersRef ref) async {
  return [
    {'name': 'Palais des Congrès', 'category': 'Salle de fête', 'zone': 'Douala', 'rating': 4.8, 'reviews': 128, 'price': 'À partir de 600.000 FC', 'image': 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=600'},
    {'name': "Saveurs d'Afrique", 'category': 'Traiteur', 'zone': 'Douala', 'rating': 4.9, 'reviews': 96, 'price': 'À partir de 450.000 FC', 'image': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600'},
    {'name': 'Lens Prod', 'category': 'Photographe', 'zone': 'Douala', 'rating': 4.9, 'reviews': 215, 'price': 'À partir de 300.000 FC', 'image': 'https://images.unsplash.com/photo-1542038784456-1ea8e935640e?w=600'},
    {'name': 'Dream Décor', 'category': 'Décoration', 'zone': 'Douala', 'rating': 4.7, 'reviews': 78, 'price': 'À partir de 250.000 FC', 'image': 'https://images.unsplash.com/photo-1520854221256-17451ccdf07b?w=600'},
  ];
}

@riverpod 
Future<List<Map<String, dynamic>>> homeAnnouncements(HomeAnnouncementsRef ref) async => [];

class ThixWeedingHomePage extends ConsumerStatefulWidget {
  const ThixWeedingHomePage({super.key});
  @override 
  ConsumerState<ThixWeedingHomePage> createState() => _ThixWeedingHomePageState();
}

class _ThixWeedingHomePageState extends ConsumerState<ThixWeedingHomePage> {
  late final TextEditingController _idController;
  late final FocusNode _focusNode;
  bool _isSearching = false;
  final _notificationCount = 3;

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

  Future<void> _onStaffAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) { 
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

  void _onScanQr() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanner QR bientôt disponible')));
  void _onNotifications() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifications bientôt disponibles')));
  void _onTapGeneric(String label) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label bientôt disponible')));

  @override 
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(homeCategoriesProvider);
    final offersAsync = ref.watch(homeOffersProvider);
    final providersAsync = ref.watch(homeProvidersProvider);

    return Scaffold(
      backgroundColor: _P.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: SafeArea(bottom: false, child: _TopHeader(notificationCount: _notificationCount, onNotificationsTap: _onNotifications, onProfileTap: _onStaffAccess))),
          SliverToBoxAdapter(child: _HeroSearchSection(controller: _idController, focusNode: _focusNode, isLoading: _isSearching, onSearch: _onSearch, onScanQr: _onScanQr)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: catsAsync.when(data: (cats) => _CategoryGrid(categories: cats, onTap: _onTapGeneric), loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: _P.primary))), error: (_, __) => const SizedBox())),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _SectionHeader(title: 'Offres du moment'))),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(child: offersAsync.when(data: (offers) => _OffersRow(offers: offers, onTap: _onTapGeneric), loading: () => const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())), error: (_, __) => const SizedBox())),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _SectionHeader(title: 'Prestataires recommandés'))),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(child: providersAsync.when(data: (providers) => _ProvidersGrid(providers: providers, onTap: _onTapGeneric), loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())), error: (_, __) => const SizedBox())),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: _TrustRow())),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  final int notificationCount; 
  final VoidCallback onNotificationsTap; 
  final VoidCallback onProfileTap;
  
  const _TopHeader({
    required this.notificationCount, 
    required this.onNotificationsTap, 
    required this.onProfileTap,
  });
  
  @override 
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: _P.shadowSoft), child: Center(child: Text('R', style: TextStyle(color: _P.blueLogo, fontSize: 26, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [RichText(text: TextSpan(style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800), children: [const TextSpan(text: 'THIX ', style: TextStyle(color: _P.ink)), TextSpan(text: 'MARIAGE', style: TextStyle(color: _P.blueLogo))])), const SizedBox(height: 2), const Row(children: [Text('Tout pour un mariage parfait ', style: TextStyle(fontSize: 12, color: _P.inkSoft)), Text('💗', style: TextStyle(fontSize: 11))])])),
        InkWell(onTap: onNotificationsTap, borderRadius: BorderRadius.circular(24), child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: _P.shadowSoft), child: Stack(children: [const Center(child: Icon(Icons.notifications_none_rounded, size: 22, color: _P.ink)), if (notificationCount > 0) Positioned(top: 2, right: 2, child: Container(width: 18, height: 18, decoration: BoxDecoration(color: _P.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)), child: Center(child: Text('$notificationCount', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)))))]))),
        const SizedBox(width: 8),
        InkWell(onTap: onProfileTap, borderRadius: BorderRadius.circular(24), child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: _P.shadowSoft), child: const Icon(Icons.person_outline_rounded, size: 22, color: _P.ink))),
      ]),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFFFF6F7), borderRadius: BorderRadius.circular(24), boxShadow: _P.shadowSoft),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(children: [
            Positioned.fill(child: Row(children: [const Expanded(flex: 55, child: SizedBox()), Expanded(flex: 45, child: Image.network('https://images.unsplash.com/photo-1519741497674-611481863552?w=600', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFFFFE6EB))))])),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Row(children: [
                Expanded(
                  flex: 60,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Vous avez un', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _P.ink, height: 1.1)),
                    const SizedBox(height: 2),
                    const Text('ID de mariage?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _P.primary, height: 1.1)),
                    const SizedBox(height: 10),
                    const Text('Accédez à tous les détails\nde votre événement', style: TextStyle(fontSize: 12, color: _P.inkSoft, height: 1.3)),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: _P.shadowSoft),
                      child: Row(children: [
                        const SizedBox(width: 8),
                        const Icon(Icons.search, size: 18, color: Color(0xFFB0B8CC)),
                        const SizedBox(width: 6),
                        Expanded(child: TextField(controller: controller, focusNode: focusNode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), decoration: const InputDecoration(isDense: true, hintText: 'Entrez votre ID de mariage', hintStyle: TextStyle(fontSize: 11, color: Color(0xFF9AA5BF)), border: InputBorder.none), onSubmitted: (_) => onSearch())),
                        InkWell(onTap: isLoading ? null : onSearch, borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: _P.primary, borderRadius: BorderRadius.circular(10)), child: isLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Rechercher', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)))),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [const Expanded(child: Divider(color: _P.border)), Container(margin: const EdgeInsets.symmetric(horizontal: 12), padding: const EdgeInsets.symmetric(horizontal: 8), child: const Text('OU', style: TextStyle(fontSize: 11, color: _P.inkSoft, fontWeight: FontWeight.w600))), const Expanded(child: Divider(color: _P.border))]),
                    const SizedBox(height: 12),
                    InkWell(onTap: onScanQr, borderRadius: BorderRadius.circular(14), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: _P.shadowSoft), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.qr_code_scanner_rounded, size: 18, color: _P.ink), SizedBox(width: 8), Text('Scanner un QR Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _P.ink))]))),
                  ]),
                ),
                const Expanded(flex: 40, child: SizedBox()),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget { 
  final String title; 
  const _SectionHeader({required this.title}); 
  @override 
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _P.ink)), InkWell(onTap: () {}, child: const Row(children: [Text('Voir tout', style: TextStyle(fontSize: 12, color: Color(0xFF2B6BFF), fontWeight: FontWeight.w600)), Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF2B6BFF))]))]); 
}

class _CategoryGrid extends StatelessWidget {
  final List<Map<String, dynamic>> categories; 
  final void Function(String) onTap;
  const _CategoryGrid({required this.categories, required this.onTap});
  static const bubbles = [Color(0xFFE6EFFF), Color(0xFFFFE1E7), Color(0xFFF0E6FF), Color(0xFFFFE8CC), Color(0xFFE0FFF0), Color(0xFFE0F3FF), Color(0xFFFFF3D0), Color(0xFFFFE0E9), Color(0xFFE0E7FF), Color(0xFFF3E8FF)];
  static const colors = [Color(0xFF3A7DFF), Color(0xFFE93D6D), Color(0xFF8B5CF6), Color(0xFFFF8C1A), Color(0xFF00C48C), Color(0xFF00A8E8), Color(0xFFFFB400), Color(0xFFFF4D7A), Color(0xFF3A5DFF), Color(0xFF9B5CFF)];
  
  @override 
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), 
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: _P.shadowSoft), 
      child: GridView.builder(
        shrinkWrap: true, 
        physics: const NeverScrollableScrollPhysics(), 
        itemCount: categories.length, 
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 14, crossAxisSpacing: 4, childAspectRatio: 0.78), 
        itemBuilder: (context, i) { 
          final c = categories[i]; 
          return InkWell(
            onTap: () => onTap(c['label']), 
            borderRadius: BorderRadius.circular(12), 
            child: Column(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: bubbles[i % bubbles.length], borderRadius: BorderRadius.circular(16)), child: Icon(c['icon'] as IconData, size: 24, color: colors[i % colors.length])), 
              const SizedBox(height: 6), 
              Text(c['label'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _P.ink, height: 1.15))
            ]),
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
      height: 148, 
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16), 
        scrollDirection: Axis.horizontal, 
        itemCount: offers.length, 
        separatorBuilder: (_, __) => const SizedBox(width: 10), 
        itemBuilder: (context, i) { 
          final o = offers[i]; 
          final isBigDiscount = (o['discount'] as String).contains('%'); 
          return InkWell(
            onTap: () => onTap(o['title'] ?? o['discount']), 
            borderRadius: BorderRadius.circular(16), 
            child: Container(
              width: 148, 
              decoration: BoxDecoration(color: o['bg'] as Color, borderRadius: BorderRadius.circular(16)), 
              child: Stack(children: [
                Padding(
                  padding: const EdgeInsets.all(12), 
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o['discount'] as String, style: TextStyle(fontSize: isBigDiscount ? 22 : 14, fontWeight: FontWeight.w900, color: o['color'] as Color, height: 1.1)), 
                    const SizedBox(height: 4), 
                    if ((o['title'] as String).isNotEmpty) 
                      Text(o['title'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _P.ink)), 
                    const SizedBox(height: 4), 
                    Text(o['subtitle'] as String, style: const TextStyle(fontSize: 9.5, color: _P.inkSoft, height: 1.2))
                  ]),
                ), 
                Positioned(
                  bottom: 0, 
                  left: 0, 
                  right: 0, 
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)), 
                    child: Image.network(o['image'] as String, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 64)),
                  ),
                ),
              ]),
            ),
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
    return SizedBox(
      height: 220, 
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16), 
        scrollDirection: Axis.horizontal, 
        itemCount: providers.length, 
        separatorBuilder: (_, __) => const SizedBox(width: 12), 
        itemBuilder: (context, i) { 
          final p = providers[i]; 
          return InkWell(
            onTap: () => onTap(p['name']), 
            borderRadius: BorderRadius.circular(16), 
            child: Container(
              width: 160, 
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: _P.shadowSoft), 
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Stack(children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), 
                    child: Image.network(p['image'] as String, height: 110, width: 160, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 110, color: _P.border)),
                  ), 
                  Positioned(
                    top: 8, 
                    right: 8, 
                    child: Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: _P.shadowSoft), child: const Icon(Icons.favorite_border_rounded, size: 16, color: _P.ink)),
                  ),
                ]), 
                Padding(
                  padding: const EdgeInsets.all(10), 
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _P.ink)), 
                    const SizedBox(height: 2), 
                    Text('${p['category']} • ${p['zone']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _P.inkSoft)), 
                    const SizedBox(height: 4), 
                    Row(children: [const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFB400)), const SizedBox(width: 2), Text('${p['rating']} (${p['reviews']})', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _P.ink))]), 
                    const SizedBox(height: 4), 
                    Text(p['price'] as String, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2B6BFF)))
                  ]),
                ),
              ]),
            ),
          ); 
        },
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();
  @override 
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.verified_user_outlined, 'title': 'Prestataires\nvérifiés', 'sub': 'Qualité garantie', 'bg': const Color(0xFFE6EFFF), 'color': const Color(0xFF2B6BFF)},
      {'icon': Icons.lock_outline_rounded, 'title': 'Paiement\nsécurisé', 'sub': 'Transactions sûres', 'bg': const Color(0xFFE0FFF0), 'color': const Color(0xFF00C48C)},
      {'icon': Icons.support_agent_rounded, 'title': 'Support 24/7', 'sub': 'Nous sommes là\npour vous', 'bg': const Color(0xFFF0E6FF), 'color': const Color(0xFF8B5CF6)},
      {'icon': Icons.star_border_rounded, 'title': 'Avis\ncertifiés', 'sub': 'Basés sur de\nvrais avis', 'bg': const Color(0xFFFFF3D0), 'color': const Color(0xFFFFB400)},
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: _P.shadowSoft),
      child: Row(children: items.map((e) => Expanded(child: Column(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: e['bg'] as Color, borderRadius: BorderRadius.circular(10)), child: Icon(e['icon'] as IconData, size: 18, color: e['color'] as Color)), const SizedBox(height: 6), Text(e['title'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _P.ink, height: 1.2)), const SizedBox(height: 2), Text(e['sub'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8.5, color: _P.inkSoft, height: 1.2))]))).toList()),
    );
  }
}
