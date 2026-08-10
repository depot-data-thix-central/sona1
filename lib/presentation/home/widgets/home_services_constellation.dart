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
  final Color color;
  final int? badge;
  const _ServiceItemData({
    required this.key,
    required this.icon,
    required this.title,
    required this.color,
    this.badge,
  });
}

class HomeServicesConstellation extends StatelessWidget {
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

  List<_ServiceItemData> _services(AppLocalizations l10n) {
    final c = counts;
    return [
      // Logo TDIA repensé : lecture de contenu vidéo court format.
      _ServiceItemData(key: 'thixMedia', icon: Icons.smart_display_rounded, title: 'TDIA', color: ThixPolicy.domainMedia, badge: c.media),
      _ServiceItemData(key: 'thixMarket', icon: Icons.storefront_rounded, title: l10n.t('serviceMarket'), color: ThixPolicy.domainMarket, badge: c.market),
      _ServiceItemData(key: 'formations', icon: Icons.school_rounded, title: l10n.t('serviceFormations'), color: ThixPolicy.domainLearning, badge: c.formations),
      _ServiceItemData(key: 'emplois', icon: Icons.work_rounded, title: l10n.t('serviceEmplois'), color: ThixPolicy.domainJobs, badge: c.jobs),
      _ServiceItemData(key: 'thixInfo', icon: Icons.newspaper_rounded, title: 'THIX MEDIA', color: ThixPolicy.domainInfo, badge: c.info),
      _ServiceItemData(key: 'opportunites', icon: Icons.lightbulb_rounded, title: l10n.t('serviceOpportunites'), color: ThixPolicy.domainOpportunity, badge: c.opportunities),
      _ServiceItemData(key: 'evenements', icon: Icons.event_rounded, title: l10n.t('serviceEvenements'), color: ThixPolicy.domainEvents, badge: c.events),
      // Renommé "Réseau Pro" → "THIX Pro"
      _ServiceItemData(key: 'reseauPro', icon: Icons.groups_rounded, title: 'THIX Pro', color: ThixPolicy.domainNetwork, badge: c.network),
      _ServiceItemData(key: 'thixSante', icon: Icons.local_hospital_rounded, title: l10n.t('serviceSante'), color: ThixPolicy.domainHealth, badge: c.health),
      _ServiceItemData(key: 'thixMoney', icon: Icons.account_balance_wallet_rounded, title: l10n.t('serviceMoney'), color: ThixPolicy.domainMoney, badge: c.money),
      _ServiceItemData(key: 'monPays', icon: Icons.flag_rounded, title: l10n.t('serviceMonPays'), color: ThixPolicy.domainGov, badge: c.monPays),
      _ServiceItemData(key: 'reservation', icon: Icons.confirmation_number_rounded, title: l10n.t('serviceReservation'), color: ThixPolicy.domainReservation, badge: c.reservation),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final services = _services(l10n);

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

          // ─── GRILLE DE SERVICES — toutes visibles, icônes libres, couleurs par domaine ───
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
            itemCount: services.length,
            itemBuilder: (_, i) => _ServiceGridItem(
              data: services[i],
              onTap: () => onServiceTap(services[i].key),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE DE SERVICE — icône libre (pas de contour/fond), couleur par domaine
// ═══════════════════════════════════════════════════════════════════════════
class _ServiceGridItem extends StatefulWidget {
  final _ServiceItemData data;
  final VoidCallback onTap;
  const _ServiceGridItem({required this.data, required this.onTap});

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
                Icon(d.icon, color: d.color, size: 30),
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
