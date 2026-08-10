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
  final Color bgColor;
  final int? badge;
  const _ServiceItemData({
    required this.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.bgColor,
    this.badge,
  });
}

class _QuickHubItemData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickHubItemData({required this.icon, required this.label, required this.onTap});
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

  List<_ServiceItemData> _services(AppLocalizations l10n) {
    final c = widget.counts;
    return [
      _ServiceItemData(key: 'thixMedia', icon: Icons.play_circle_filled_rounded, title: 'TDIA', color: ThixPolicy.domainMedia, bgColor: ThixPolicy.domainMedia.withValues(alpha: 0.10), badge: c.media),
      _ServiceItemData(key: 'thixMarket', icon: Icons.storefront_rounded, title: l10n.t('serviceMarket'), color: ThixPolicy.domainMarket, bgColor: ThixPolicy.domainMarket.withValues(alpha: 0.10), badge: c.market),
      _ServiceItemData(key: 'formations', icon: Icons.school_rounded, title: l10n.t('serviceFormations'), color: ThixPolicy.domainLearning, bgColor: ThixPolicy.domainLearning.withValues(alpha: 0.10), badge: c.formations),
      _ServiceItemData(key: 'emplois', icon: Icons.work_rounded, title: l10n.t('serviceEmplois'), color: ThixPolicy.domainJobs, bgColor: ThixPolicy.domainJobs.withValues(alpha: 0.10), badge: c.jobs),
      _ServiceItemData(key: 'thixInfo', icon: Icons.newspaper_rounded, title: 'THIX MEDIA', color: ThixPolicy.domainInfo, bgColor: ThixPolicy.domainInfo.withValues(alpha: 0.10), badge: c.info),
      _ServiceItemData(key: 'opportunites', icon: Icons.lightbulb_rounded, title: l10n.t('serviceOpportunites'), color: ThixPolicy.domainOpportunity, bgColor: ThixPolicy.domainOpportunity.withValues(alpha: 0.10), badge: c.opportunities),
      _ServiceItemData(key: 'evenements', icon: Icons.event_rounded, title: l10n.t('serviceEvenements'), color: ThixPolicy.domainEvents, bgColor: ThixPolicy.domainEvents.withValues(alpha: 0.10), badge: c.events),
      _ServiceItemData(key: 'reseauPro', icon: Icons.groups_rounded, title: l10n.t('serviceReseauPro'), color: ThixPolicy.domainNetwork, bgColor: ThixPolicy.domainNetwork.withValues(alpha: 0.10), badge: c.network),
      _ServiceItemData(key: 'thixSante', icon: Icons.local_hospital_rounded, title: l10n.t('serviceSante'), color: ThixPolicy.domainHealth, bgColor: ThixPolicy.domainHealth.withValues(alpha: 0.10), badge: c.health),
      _ServiceItemData(key: 'thixMoney', icon: Icons.account_balance_wallet_rounded, title: l10n.t('serviceMoney'), color: ThixPolicy.domainMoney, bgColor: ThixPolicy.domainMoney.withValues(alpha: 0.10), badge: c.money),
      _ServiceItemData(key: 'monPays', icon: Icons.flag_rounded, title: l10n.t('serviceMonPays'), color: ThixPolicy.domainGov, bgColor: ThixPolicy.domainGov.withValues(alpha: 0.10), badge: c.monPays),
      _ServiceItemData(key: 'reservation', icon: Icons.confirmation_number_rounded, title: l10n.t('serviceReservation'), color: ThixPolicy.domainReservation, bgColor: ThixPolicy.domainReservation.withValues(alpha: 0.10), badge: c.reservation),
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

    final hubItems = <_QuickHubItemData>[
      _QuickHubItemData(icon: Icons.home_filled, label: l10n.t('hub_home'), onTap: widget.onHomeTap),
      _QuickHubItemData(icon: Icons.apps_rounded, label: l10n.t('hub_mini_apps'), onTap: widget.onMiniAppsTap),
      _QuickHubItemData(icon: Icons.folder_rounded, label: l10n.t('hub_documents'), onTap: widget.onDocumentsTap),
      _QuickHubItemData(icon: Icons.person_outline_rounded, label: l10n.t('hub_profile'), onTap: widget.onProfileTap),
      _QuickHubItemData(icon: Icons.qr_code_scanner_rounded, label: l10n.t('hub_scan_qr'), onTap: widget.onScanTap),
    ];

    // Nombre de services visibles avant "Voir plus" (2 lignes de 4 = 8)
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

          // ─── RACCOURCIS RAPIDES (remplace le hub radial) ───
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hubItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s12),
              itemBuilder: (_, i) {
                final item = hubItems[i];
                return _QuickHubButton(icon: item.icon, label: item.label, onTap: item.onTap);
              },
            ),
          ),

          const SizedBox(height: ThixPolicy.s20),

          // ─── GRILLE DE SERVICES ───
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: ThixPolicy.s16,
              crossAxisSpacing: ThixPolicy.s8,
              childAspectRatio: 0.78,
            ),
            itemCount: displayed.length,
            itemBuilder: (_, i) => _ServiceGridItem(
              data: displayed[i],
              onTap: () => widget.onServiceTap(displayed[i].key),
            ),
          ),

          if (showToggle) ...[
            const SizedBox(height: ThixPolicy.s12),
            Center(
              child: InkWell(
                onTap: _toggleExpanded,
                borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s8),
                  decoration: BoxDecoration(
                    color: ThixPolicy.tint,
                    borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                  ),
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
// BOUTON RACCOURCI RAPIDE (remplace les satellites du hub)
// ═══════════════════════════════════════════════════════════════════════════
class _QuickHubButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickHubButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: ThixPolicy.tint,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: ThixPolicy.border),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: ThixPolicy.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE DE SERVICE DANS LA GRILLE
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
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: d.bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Icon(d.icon, color: d.color, size: 24),
                ),
                if (d.badge != null && d.badge! > 0)
                  Positioned(
                    top: -4, right: -6,
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
