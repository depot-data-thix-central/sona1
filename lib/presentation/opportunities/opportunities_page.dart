// lib/presentation/opportunities/opportunities_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'package:thix_id/models/opportunity_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/opportunity_service.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';

// ============================================================
// PAGE PRINCIPALE : LISTE DES OPPORTUNITÉS
// ============================================================
class OpportunitiesPage extends ConsumerStatefulWidget {
  const OpportunitiesPage({super.key});

  @override
  ConsumerState<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends ConsumerState<OpportunitiesPage> {
  final OpportunityService _service = OpportunityService();
  late Future<List<OpportunityItem>> _opportunitiesFuture;
  int _selectedCategoryIndex = 0;

  final List<Map<String, dynamic>> _categories = [
    {'icon': Icons.grid_view_rounded, 'label': 'Toutes'},
    {'icon': Icons.school_rounded, 'label': 'Bourses'},
    {'icon': Icons.work_rounded, 'label': 'Emplois'},
    {'icon': Icons.monetization_on_rounded, 'label': 'Subventions'},
    {'icon': Icons.emoji_events_rounded, 'label': 'Concours'},
  ];

  @override
  void initState() {
    super.initState();
    _opportunitiesFuture = _service.listOpportunities();
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 VÉRIFICATION DU RÔLE ADMIN
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final bool isAdmin = supabaseUser?.appMetadata?['role'] == 'admin' || supabaseUser?.userMetadata?['is_admin'] == true;

    return Scaffold(
      backgroundColor: ThixPolicy.surface, 
      
      // 🌟 BOUTON ESPACE ADMIN (Premium Style)
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.selectionClick();
                context.push('/opportunities/admin'); 
              },
              backgroundColor: ThixPolicy.inkDeep,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.admin_panel_settings_rounded, size: 20),
              label: const Text('Espace Admin', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
            )
          : null,
          
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context),
          
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: ThixPolicy.s8),
                _buildPremiumSearchBar(),
                const SizedBox(height: ThixPolicy.s24),
                _buildPremiumCategoryChips(),
                const SizedBox(height: ThixPolicy.s32),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: FutureBuilder<List<OpportunityItem>>(
              future: _opportunitiesFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator(color: ThixPolicy.primaryDeep, strokeWidth: 3)),
                  );
                }

                final list = snap.data ?? const <OpportunityItem>[];
                if (list.isEmpty) {
                  return _buildEmptyState();
                }

                final featured = list.take(5).toList(growable: false);
                final others = list.length > 5 ? list.skip(5).toList() : list;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader('À LA UNE', 'Sélection premium'),
                    const SizedBox(height: ThixPolicy.s16),
                    FeaturedOpportunitiesCarousel(
                      opportunities: featured,
                      onOpen: (o) => context.push('/opportunities/${o.id}'),
                    ),
                    
                    const SizedBox(height: ThixPolicy.s40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                      child: _buildEnterpriseAlertBanner(),
                    ),
                    
                    const SizedBox(height: ThixPolicy.s40),
                    _buildSectionHeader('TOUTES LES OPPORTUNITÉS', 'Explorez les offres récentes'),
                    const SizedBox(height: ThixPolicy.s16),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                      child: Column(
                        children: others.map((o) => _OpportunityEnterpriseCard(
                          item: o,
                          onOpen: () => context.push('/opportunities/${o.id}'),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 120), // Padding extra pour le FAB
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMPOSANTS UI ENTREPRISE
  // ============================================================
  
  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: ThixPolicy.surface,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: ThixPolicy.inkDeep.withOpacity(0.05),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.inkDeep, size: 20),
        onPressed: () => context.go(AppRoutes.home),
      ),
      title: const Text('THIX Opportunités', style: TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_rounded, color: ThixPolicy.inkDeep),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildPremiumSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          border: Border.all(color: ThixPolicy.borderStrong.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const TextField(
          style: TextStyle(fontSize: 14, color: ThixPolicy.textMain, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Rechercher un emploi, une bourse, un mot-clé...',
            hintStyle: TextStyle(fontSize: 13, color: ThixPolicy.textMuted, fontWeight: FontWeight.w400),
            prefixIcon: Icon(Icons.search_rounded, size: 22, color: ThixPolicy.primaryDeep),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          final cat = _categories[index];
          return InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedCategoryIndex = index);
            },
            borderRadius: BorderRadius.circular(ThixPolicy.rFull),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? ThixPolicy.inkDeep : Colors.transparent,
                borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                border: Border.all(color: isSelected ? ThixPolicy.inkDeep : ThixPolicy.borderStrong),
              ),
              child: Row(
                children: [
                  Icon(cat['icon'] as IconData, color: isSelected ? ThixPolicy.gold : ThixPolicy.textSecondary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    cat['label'] as String,
                    style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isSelected ? Colors.white : ThixPolicy.textSecondary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: ThixPolicy.primaryDeep, letterSpacing: 1.2)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ThixPolicy.inkDeep, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildEnterpriseAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s24),
      decoration: BoxDecoration(
        color: ThixPolicy.inkDeep,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        boxShadow: [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ThixPolicy.gold.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.notifications_active_rounded, color: ThixPolicy.gold, size: 28),
          ),
          const SizedBox(width: ThixPolicy.s20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Veille Stratégique', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                SizedBox(height: 4),
                Text('Recevez les offres exclusives directement sur votre profil THIX.', style: TextStyle(color: ThixPolicy.textDisabled, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.gold,
              foregroundColor: ThixPolicy.inkDeep,
              elevation: 0,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Activer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: ThixPolicy.tint, shape: BoxShape.circle),
              child: const Icon(Icons.business_center_outlined, size: 48, color: ThixPolicy.primaryDeep),
            ),
            const SizedBox(height: ThixPolicy.s20),
            const Text('Aucune opportunité', style: TextStyle(color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Revenez plus tard pour de nouvelles offres.', style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CARTE OPPORTUNITÉ (Style Premium B2B)
// ============================================================
class _OpportunityEnterpriseCard extends StatelessWidget {
  final OpportunityItem item;
  final VoidCallback onOpen;
  
  const _OpportunityEnterpriseCard({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final img = item.imageAssetPath;
    
    return Container(
      margin: const EdgeInsets.only(bottom: ThixPolicy.s20),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rXl),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 120, // Plus compact pour une lecture liste rapide
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (img != null)
                    (img.startsWith('http') ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover) : Image.asset(img, fit: BoxFit.cover))
                  else
                    Container(color: ThixPolicy.surfaceStrong),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [ThixPolicy.inkDeep.withOpacity(0.6), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16, left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(4)),
                      child: Text(item.category.toUpperCase(), style: const TextStyle(fontSize: 10, color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(ThixPolicy.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontSize: 16, color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900, height: 1.3, letterSpacing: -0.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: ThixPolicy.s16),
                  
                  // Meta Data Row
                  Row(
                    children: [
                      _buildMetaData(Icons.domain_rounded, item.organizer, ThixPolicy.textSecondary),
                      const SizedBox(width: ThixPolicy.s16),
                      _buildMetaData(Icons.location_on_rounded, item.location, ThixPolicy.textSecondary),
                    ],
                  ),
                  const SizedBox(height: ThixPolicy.s16),
                  const Divider(height: 1, color: ThixPolicy.border),
                  const SizedBox(height: ThixPolicy.s16),
                  
                  // Action & Reward Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Récompense / Avantage', style: TextStyle(fontSize: 10, color: ThixPolicy.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            const SizedBox(height: 2),
                            Text(item.rewardLabel, style: const TextStyle(fontSize: 13, color: ThixPolicy.success, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: ThixPolicy.tint, borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_filled_rounded, size: 14, color: ThixPolicy.primaryDeep),
                            const SizedBox(width: 6),
                            Text(item.deadlineLabel, style: const TextStyle(fontSize: 11, color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaData(IconData icon, String text, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

// ============================================================
// CARROUSEL "À LA UNE" (Éditorial Premium)
// ============================================================
class FeaturedOpportunitiesCarousel extends StatefulWidget {
  final List<OpportunityItem> opportunities;
  final ValueChanged<OpportunityItem> onOpen;

  const FeaturedOpportunitiesCarousel({super.key, required this.opportunities, required this.onOpen});

  @override
  State<FeaturedOpportunitiesCarousel> createState() => _FeaturedOpportunitiesCarouselState();
}

class _FeaturedOpportunitiesCarouselState extends State<FeaturedOpportunitiesCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.92);
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || widget.opportunities.isEmpty) return;
      final next = (_index + 1) % widget.opportunities.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 800), curve: Curves.fastOutSlowIn);
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
    if (widget.opportunities.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 320, // Plus grand pour donner un vrai aspect "Magazine/Éditorial"
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.opportunities.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final o = widget.opportunities[i];
                return Padding(
                  padding: EdgeInsets.only(right: i == widget.opportunities.length - 1 ? 0 : 16, left: i == 0 ? 20 : 0),
                  child: _FeaturedPremiumCard(opportunity: o, onTap: () => widget.onOpen(o)),
                );
              },
            ),
          ),
          const SizedBox(height: ThixPolicy.s20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.opportunities.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 4,
                width: active ? 24 : 8,
                decoration: BoxDecoration(color: active ? ThixPolicy.inkDeep : ThixPolicy.borderStrong, borderRadius: BorderRadius.circular(4)),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FeaturedPremiumCard extends StatelessWidget {
  final OpportunityItem opportunity;
  final VoidCallback onTap;
  
  const _FeaturedPremiumCard({required this.opportunity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final img = opportunity.imageAssetPath;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ThixPolicy.rXl),
          boxShadow: [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 12))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (img != null)
              (img.startsWith('http') ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover) : Image.asset(img, fit: BoxFit.cover))
            else
              Container(color: ThixPolicy.primaryDeep),
            
            // Dégradé luxueux
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [ThixPolicy.inkDeep.withOpacity(0.95), ThixPolicy.inkDeep.withOpacity(0.2), Colors.transparent],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
            
            // Badge Supérieur
            Positioned(
              top: 20, left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: ThixPolicy.gold, borderRadius: BorderRadius.circular(6)),
                child: const Text('ÉDITION SPÉCIALE', style: TextStyle(fontSize: 10, color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
              ),
            ),
            
            // Contenu Inférieur
            Positioned(
              left: 20, right: 20, bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white.withOpacity(0.3))),
                        child: Text(opportunity.category.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(opportunity.deadlineLabel, style: const TextStyle(fontSize: 11, color: ThixPolicy.gold, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(opportunity.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w900, height: 1.2, letterSpacing: -0.5)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.corporate_fare_rounded, size: 16, color: ThixPolicy.surface),
                      const SizedBox(width: 6),
                      Expanded(child: Text(opportunity.organizer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: ThixPolicy.surface, fontWeight: FontWeight.w600))),
                    ],
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
