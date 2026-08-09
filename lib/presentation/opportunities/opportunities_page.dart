// lib/presentation/opportunities/opportunities_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

import 'package:thix_id/models/opportunity_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/opportunity_service.dart';
import 'package:thix_id/services/external_link_service.dart';
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
    {'icon': Icons.apps_rounded, 'label': 'Toutes'},
    {'icon': Icons.school_rounded, 'label': 'Bourses'},
    {'icon': Icons.business_center_rounded, 'label': 'Emplois'},
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
    final user = ref.watch(authControllerProvider).value;
    // Remplace par la vraie logique de vérification de ton modèle User (ex: user?.role == 'admin')
    final bool isAdmin = user?.appMetadata?['role'] == 'admin' || user?.userMetadata?['is_admin'] == true;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      // 🌟 BOUTON ESPACE ADMIN (Visible uniquement par les administrateurs)
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.selectionClick();
                context.push('/opportunities/admin'); // Redirection vers ton espace admin
              },
              backgroundColor: ThixPolicy.inkDeep,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_business_rounded, size: 20),
              label: const Text('Espace Admin', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
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
                const SizedBox(height: ThixPolicy.s16),
                _buildSearchBar(),
                const SizedBox(height: ThixPolicy.s24),
                _buildCategorySection(),
                const SizedBox(height: ThixPolicy.s24),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: FutureBuilder<List<OpportunityItem>>(
              future: _opportunitiesFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 3)),
                  );
                }

                final list = snap.data ?? const <OpportunityItem>[];
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: ThixPolicy.textMuted.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          const Text('Aucune opportunité pour le moment.', style: TextStyle(color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                }

                final featured = list.take(5).toList(growable: false);
                final others = list.length > 5 ? list.skip(5).toList() : list;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader('À la une', null),
                    const SizedBox(height: ThixPolicy.s12),
                    FeaturedOpportunitiesCarousel(
                      opportunities: featured,
                      onOpen: (o) => context.push('/opportunities/${o.id}'),
                    ),
                    const SizedBox(height: ThixPolicy.s32),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                      child: _buildPremiumAlertBanner(),
                    ),
                    
                    const SizedBox(height: ThixPolicy.s32),
                    _buildSectionHeader('Toutes les opportunités', null),
                    const SizedBox(height: ThixPolicy.s12),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
                      child: Column(
                        children: others.map((o) => _OpportunityCard(
                          item: o,
                          onOpen: () => context.push('/opportunities/${o.id}'),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 100), // Espace pour le FAB Admin
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
      backgroundColor: ThixPolicy.card,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: ThixPolicy.inkDeep.withOpacity(0.1),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 20),
        onPressed: () => context.go(AppRoutes.home),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: ThixPolicy.tint, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.work_outline_rounded, color: ThixPolicy.primary, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('THIX Opportunités', style: TextStyle(color: ThixPolicy.textMain, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.3)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: const TextField(
          style: TextStyle(fontSize: 14, color: ThixPolicy.textMain),
          decoration: InputDecoration(
            hintText: 'Rechercher un emploi, une bourse...',
            hintStyle: TextStyle(fontSize: 13, color: ThixPolicy.textSecondary),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textSecondary),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s8),
            itemBuilder: (context, index) {
              final isSelected = _selectedCategoryIndex == index;
              final cat = _categories[index];
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategoryIndex = index);
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? ThixPolicy.inkDeep : ThixPolicy.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? ThixPolicy.inkDeep : ThixPolicy.border),
                    boxShadow: isSelected ? [BoxShadow(color: ThixPolicy.inkDeep.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))] : [],
                  ),
                  child: Row(
                    children: [
                      Icon(cat['icon'] as IconData, color: isSelected ? ThixPolicy.gold : ThixPolicy.textSecondary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        cat['label'] as String,
                        style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: isSelected ? Colors.white : ThixPolicy.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ThixPolicy.textMain, letterSpacing: -0.3)),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: const Text('Voir tout', style: TextStyle(fontSize: 13, color: ThixPolicy.primary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumAlertBanner() {
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s20),
      decoration: BoxDecoration(
        gradient: ThixPolicy.brandGradient,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        boxShadow: ThixPolicy.shadowCard(opacity: 0.15),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.notifications_active_rounded, color: ThixPolicy.gold, size: 24),
          ),
          const SizedBox(width: ThixPolicy.s16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alertes personnalisées', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Recevez les offres qui correspondent à votre profil.', style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.gold,
              foregroundColor: ThixPolicy.inkDeep,
              elevation: 0,
              minimumSize: const Size(80, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Activer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARTE OPPORTUNITÉ (Liste Classique)
// ============================================================
class _OpportunityCard extends StatelessWidget {
  final OpportunityItem item;
  final VoidCallback onOpen;
  const _OpportunityCard({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final img = item.imageAssetPath;
    return Container(
      margin: const EdgeInsets.only(bottom: ThixPolicy.s16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 140,
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
                        colors: [ThixPolicy.inkDeep.withOpacity(0.8), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: ThixPolicy.card.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                      child: Text(item.category.toUpperCase(), style: const TextStyle(fontSize: 10, color: ThixPolicy.primaryDeep, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: ThixPolicy.success, borderRadius: BorderRadius.circular(8)),
                      child: Text(item.rewardLabel, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(ThixPolicy.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontSize: 15, color: ThixPolicy.textMain, fontWeight: FontWeight.w900, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: ThixPolicy.s12),
                  Row(
                    children: [
                      const Icon(Icons.business_rounded, size: 16, color: ThixPolicy.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(item.organizer, style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 16, color: ThixPolicy.danger),
                      const SizedBox(width: 6),
                      Expanded(child: Text(item.deadlineLabel, style: const TextStyle(fontSize: 12, color: ThixPolicy.danger, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
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

// ============================================================
// CARROUSEL "À LA UNE"
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
    _controller = PageController(viewportFraction: 0.90);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.opportunities.isEmpty) return;
      final next = (_index + 1) % widget.opportunities.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
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
      height: 240,
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
                  padding: EdgeInsets.only(right: i == widget.opportunities.length - 1 ? 0 : 12, left: i == 0 ? 16 : 4),
                  child: _FeaturedOpportunityCard(opportunity: o, onTap: () => widget.onOpen(o)),
                );
              },
            ),
          ),
          const SizedBox(height: ThixPolicy.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.opportunities.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: active ? 20 : 6,
                decoration: BoxDecoration(color: active ? ThixPolicy.primary : ThixPolicy.borderStrong, borderRadius: BorderRadius.circular(10)),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FeaturedOpportunityCard extends StatelessWidget {
  final OpportunityItem opportunity;
  final VoidCallback onTap;
  const _FeaturedOpportunityCard({required this.opportunity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final img = opportunity.imageAssetPath;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          boxShadow: ThixPolicy.shadowCard(opacity: 0.1),
        ),
        clipBehavior: Clip.antiAlias,
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
                  colors: [ThixPolicy.inkDeep.withOpacity(0.9), Colors.transparent],
                  stops: const [0, 0.6],
                ),
              ),
            ),
            Positioned(
              top: 16, left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: ThixPolicy.gold, borderRadius: BorderRadius.circular(8)),
                child: const Text('À LA UNE', style: TextStyle(fontSize: 9, color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ),
            Positioned(
              left: 16, right: 16, bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: ThixPolicy.success.withOpacity(0.9), borderRadius: BorderRadius.circular(6)),
                    child: Text(opportunity.rewardLabel, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 10),
                  Text(opportunity.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w900, height: 1.2, letterSpacing: -0.3)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.business_center_rounded, size: 14, color: ThixPolicy.tint),
                      const SizedBox(width: 6),
                      Expanded(child: Text(opportunity.organizer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: ThixPolicy.tint, fontWeight: FontWeight.w600))),
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
