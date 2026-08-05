// lib/presentation/opportunities/opportunities_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/models/opportunity_item.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/services/opportunity_service.dart';
import 'package:thix_id/theme.dart';

// ============================================================
// CHARTE GRAPHIQUE UNIFIÉE — Style "Mon Pays" / Événement
// ============================================================
class _OppColors {
  static const Color primaryBlue = Color(0xFF0B3D91);
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color lightBg = Color(0xFFF6F8FB);
  static const Color gold = Color(0xFFF7C948);
  static const Color rdcRed = Color(0xFFCE1126); // <-- LA COULEUR MANQUANTE EST ICI
  static const Color mutedText = Color(0xFF6B7690);
  static const Color cardBorder = Color(0xFFEEF1F7);
  static const Color darkText = Color(0xFF10182B);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color softBlue = Color(0xFFEEF1F7);
}


class OpportunitiesPage extends StatefulWidget {
  const OpportunitiesPage({super.key});

  @override
  State<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<OpportunitiesPage> {
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
    return Scaffold(
      backgroundColor: _OppColors.lightBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                _buildSearchBar(),
                const SizedBox(height: 20),
                _buildCategorySection(),
                const SizedBox(height: 20),
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
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_OppColors.primaryBlue),
                      ),
                    ),
                  );
                }

                final list = snap.data ?? const <OpportunityItem>[];
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: _OppColors.mutedText.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'Aucune opportunité pour le moment.',
                            style: TextStyle(color: _OppColors.mutedText, fontWeight: FontWeight.w600),
                          ),
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
                    const SizedBox(height: 12),
                    FeaturedOpportunitiesCarousel(
                      opportunities: featured,
                      onOpen: (o) => context.push('/opportunities/${o.id}'),
                    ),
                    const SizedBox(height: 24),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildNotificationBanner(),
                    ),
                    
                    const SizedBox(height: 24),
                    _buildSectionHeader('Toutes les opportunités', null),
                    const SizedBox(height: 12),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: others.map((o) => _OpportunityCard(
                          item: o,
                          onOpen: () => context.push('/opportunities/${o.id}'),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 80),
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
  // HEADER
  // ============================================================
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_OppColors.navyDeep, _OppColors.primaryBlue],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x332D6CDF), blurRadius: 22, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go(AppRoutes.home),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THIX OPPORTUNITÉS',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                ),
                SizedBox(height: 2),
                Text(
                  'Bourses, subventions, concours',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECHERCHE
  // ============================================================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _OppColors.pureWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _OppColors.cardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: _OppColors.mutedText),
            SizedBox(width: 9),
            Text('Rechercher une opportunité...', style: TextStyle(fontSize: 12.5, color: _OppColors.mutedText)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CATÉGORIES (Quick Access)
  // ============================================================
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Catégories',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _OppColors.primaryBlue),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 85,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final isSelected = _selectedCategoryIndex == index;
              final cat = _categories[index];
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategoryIndex = index);
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 75,
                  decoration: BoxDecoration(
                    color: isSelected ? _OppColors.primaryBlue : _OppColors.pureWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? Colors.transparent : _OppColors.cardBorder),
                    boxShadow: isSelected 
                      ? [BoxShadow(color: _OppColors.primaryBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] 
                      : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cat['icon'] as IconData, color: isSelected ? _OppColors.gold : _OppColors.primaryBlue, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        cat['label'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : _OppColors.darkText,
                        ),
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

  // ============================================================
  // EN-TÊTE DE SECTION
  // ============================================================
  Widget _buildSectionHeader(String title, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _OppColors.primaryBlue)),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: const Row(
                children: [
                  Text('Voir tout', style: TextStyle(fontSize: 12, color: Color(0xFF5B8DEF), fontWeight: FontWeight.w700)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF5B8DEF)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // BANNIÈRE
  // ============================================================
  Widget _buildNotificationBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _OppColors.primaryBlue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _OppColors.primaryBlue.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: _OppColors.gold, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alerte Opportunités', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Soyez le premier à postuler.', style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: _OppColors.gold,
              foregroundColor: _OppColors.primaryBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Activer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARTE OPPORTUNITÉ (Liste)
// ============================================================
class _OpportunityCard extends StatelessWidget {
  final OpportunityItem item;
  final VoidCallback onOpen;
  const _OpportunityCard({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final img = item.imageAssetPath;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _OppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _OppColors.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
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
                    (img.startsWith('http') ? Image.network(img, fit: BoxFit.cover) : Image.asset(img, fit: BoxFit.cover))
                  else
                    Container(color: _OppColors.softBlue),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(item.category, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _OppColors.gold, borderRadius: BorderRadius.circular(8)),
                      child: Text(item.rewardLabel, style: const TextStyle(fontSize: 10, color: _OppColors.navyDeep, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontSize: 15, color: _OppColors.darkText, fontWeight: FontWeight.w900, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.apartment_rounded, size: 16, color: _OppColors.primaryBlue),
                      const SizedBox(width: 6),
                      Expanded(child: Text(item.organizer, style: const TextStyle(fontSize: 12, color: _OppColors.mutedText, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 16, color: _OppColors.rdcRed),
                      const SizedBox(width: 6),
                      Expanded(child: Text(item.deadlineLabel, style: const TextStyle(fontSize: 12, color: _OppColors.mutedText), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: onOpen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _OppColors.softBlue,
                        foregroundColor: _OppColors.primaryBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Voir les détails', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
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
    _controller = PageController(viewportFraction: 0.88);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
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
      height: 220,
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.opportunities.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: active ? 18 : 6,
                decoration: BoxDecoration(
                  color: active ? _OppColors.primaryBlue : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARTE "À LA UNE"
// ============================================================
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
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: _OppColors.navyDeep.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (img != null)
              (img.startsWith('http') ? Image.network(img, fit: BoxFit.cover) : Image.asset(img, fit: BoxFit.cover))
            else
              Container(color: _OppColors.softBlue),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [_OppColors.primaryBlue.withOpacity(0.95), Colors.transparent],
                  stops: const [0, 0.7],
                ),
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _OppColors.gold, borderRadius: BorderRadius.circular(8)),
                child: const Text('À LA UNE', style: TextStyle(fontSize: 9, color: _OppColors.navyDeep, fontWeight: FontWeight.w900)),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(opportunity.rewardLabel, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opportunity.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w900, height: 1.15),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.apartment_rounded, size: 16, color: _OppColors.gold),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          opportunity.organizer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _OppColors.gold, fontWeight: FontWeight.w800),
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
}
