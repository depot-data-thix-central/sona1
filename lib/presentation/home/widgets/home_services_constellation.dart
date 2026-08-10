// lib/presentation/home/widgets/home_services_constellation.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class _ServiceItemData {
  final String key;
  final IconData icon;
  final String title;
  final int? badge;
  const _ServiceItemData({
    required this.key,
    required this.icon,
    required this.title,
    this.badge,
  });
}

class HomeServicesConstellation extends StatefulWidget {
  final SectionBadgeCounts counts;
  final void Function(String key) onServiceTap;
  final VoidCallback onHomeTap;
  final VoidCallback onMiniAppsTap;
  final VoidCallback onDocumentsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;

  const HomeServicesConstellation({
    super.key,
    required this.counts,
    required this.onServiceTap,
    required this.onHomeTap,
    required this.onMiniAppsTap,
    required this.onDocumentsTap,
    required this.onProfileTap,
    required this.onScanTap,
  });

  @override
  State<HomeServicesConstellation> createState() => _HomeServicesConstellationState();
}

class _HomeServicesConstellationState extends State<HomeServicesConstellation> {
  bool _expanded = false;

  /// Couleur unique appliquée à toutes les icônes de service — évite l'effet
  /// "arc-en-ciel" et donne un rendu mono-chrome propre façon capture de
  /// référence (icônes bleu marine, sans fond ni contour).
  static const Color _iconColor = ThixPolicy.primaryDeep;

  List<_ServiceItemData> _services(AppLocalizations l10n) {
    final c = widget.counts;
    return [
      // Logo TDIA repensé : lecture de contenu vidéo court format (inspiré du
      // contenu TikTok-style vu dans THIX MEDIA) plutôt qu'un simple bouton play.
      _ServiceItemData(key: 'thixMedia', icon: Icons.smart_display_rounded, title: 'TDIA', badge: c.media),
      _ServiceItemData(key: 'thixMarket', icon: Icons.storefront_rounded, title: l10n.t('serviceMarket'), badge: c.market),
      _ServiceItemData(key: 'formations', icon: Icons.school_rounded, title: l10n.t('serviceFormations'), badge: c.formations),
      _ServiceItemData(key: 'emplois', icon: Icons.work_rounded, title: l10n.t('serviceEmplois'), badge: c.jobs),
      _ServiceItemData(key: 'thixInfo', icon: Icons.newspaper_rounded, title: 'THIX MEDIA', badge: c.info),
      _ServiceItemData(key: 'opportunites', icon: Icons.lightbulb_rounded, title: l10n.t('serviceOpportunites'), badge: c.opportunities),
      _ServiceItemData(key: 'evenements', icon: Icons.event_rounded, title: l10n.t('serviceEvenements'), badge: c.events),
      // Renommé "Réseau Pro" → "THIX Pro"
      _ServiceItemData(key: 'reseauPro', icon: Icons.groups_rounded, title: 'THIX Pro', badge: c.network),
      _ServiceItemData(key: 'thixSante', icon: Icons.local_hospital_rounded, title: l10n.t('serviceSante'), badge: c.health),
      _ServiceItemData(key: 'thixMoney', icon: Icons.account_balance_wallet_rounded, title: l10n.t('serviceMoney'), badge: c.money),
      _ServiceItemData(key: 'monPays', icon: Icons.flag_rounded, title: l10n.t('serviceMonPays'), badge: c.monPays),
      _ServiceItemData(key: 'reservation', icon: Icons.confirmation_number_rounded, title: l10n.t('serviceReservation'), badge: c.reservation),
    ];
  }

  void _toggleExpanded() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final services = _services(l10n);

    // 2 lignes de 4 par défaut = 8 items visibles
    const visibleCount = 8;
    final showToggle = services.length > visibleCount;
    final displayed = _expanded ? services : services.take(visibleCount).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── TITRE DE SECTION ───
          Row(
            children: [
              const Icon(Icons.grid_view_rounded, size: 15, color: ThixPolicy.textSecondary),
              const SizedBox(width: 6),
              Text(
                l10n.t('servicesTitle'),
                style: const TextStyle(color: ThixPolicy.textMain, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2),
              ),
            ],
          ),
          const SizedBox(height: ThixPolicy.s12),

          // ─── GRILLE DE SERVICES — icônes épurées, monochromes, sans fond ───
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: ThixPolicy.s12,
              crossAxisSpacing: ThixPolicy.s4,
              childAspectRatio: 0.85,
            ),
            itemCount: displayed.length,
            itemBuilder: (_, i) => _ServiceGridItem(
              data: displayed[i],
              iconColor: _iconColor,
              onTap: () => widget.onServiceTap(displayed[i].key),
            ),
          ),

          if (showToggle) ...[
            const SizedBox(height: ThixPolicy.s8),
            Center(
              child: InkWell(
                onTap: _toggleExpanded,
                borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s12, vertical: ThixPolicy.s4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _expanded ? l10n.t('showLess') : l10n.t('showMore'),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ThixPolicy.primary),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: ThixPolicy.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE DE SERVICE — icône libre (pas de contour/fond), mono-couleur
// ═══════════════════════════════════════════════════════════════════════════
class _ServiceGridItem extends StatefulWidget {
  final _ServiceItemData data;
  final Color iconColor;
  final VoidCallback onTap;
  const _ServiceGridItem({required this.data, required this.iconColor, required this.onTap});

  @override
  State<_ServiceGridItem> createState() => _ServiceGridItemState();
}

class _ServiceGridItemState extends State<_ServiceGridItem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.90).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(d.icon, color: widget.iconColor, size: 30),
                if (d.badge != null && d.badge! > 0)
                  Positioned(
                    top: -4, right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: ThixPolicy.danger,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.4),
                      ),
                      child: Text(
                        '${d.badge}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              d.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textMain, height: 1.15),
            ),
          ],
        ),
      ),
    );
  }
}
