// lib/presentation/home/widgets/home_services_constellation.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/notification_counters_service.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class _ServiceNodeData {
  final String key;
  final IconData icon;
  final String title;
  final Color color;
  final int? badge;
  const _ServiceNodeData({required this.key, required this.icon, required this.title, required this.color, this.badge});
}

class _QuadrantBlock {
  final String label;
  final Color color;
  final List<_ServiceNodeData> items;
  const _QuadrantBlock({required this.label, required this.color, required this.items});
}

class _HubMenuItemData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HubMenuItemData({required this.icon, required this.label, required this.onTap});
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

class _HomeServicesConstellationState extends State<HomeServicesConstellation> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _menuExpanded = false;

  static const double _stageHeight = ThixPolicy.constellationStageHeight;
  static const double _hubRadius = ThixPolicy.constellationHubRadius;
  static const double _hubMenuRadius = ThixPolicy.constellationHubMenuRadius;
  static const double _hubMenuNodeSize = ThixPolicy.constellationHubMenuNodeSize;

  /// Gap angulaire (en degrés) entre deux blocs — crée l'effet "segments
  /// séparés" du donut, comme sur la maquette de référence.
  static const double _gapDeg = 7;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleHubMenu() {
    HapticFeedback.mediumImpact();
    setState(() => _menuExpanded = !_menuExpanded);
  }

  void _runHubItem(VoidCallback action) {
    setState(() => _menuExpanded = false);
    action();
  }

  List<_QuadrantBlock> _blocks(AppLocalizations l10n) {
    final c = widget.counts;
    return [
      _QuadrantBlock(
        label: l10n.t('blockMedia'),
        color: ThixPolicy.domainMedia,
        items: [
          _ServiceNodeData(key: 'thixMedia', icon: Icons.smart_display_rounded, title: 'TDIA', color: ThixPolicy.domainMedia, badge: c.media),
          _ServiceNodeData(key: 'thixInfo', icon: Icons.newspaper_rounded, title: 'THIX MEDIA', color: ThixPolicy.domainMedia, badge: c.info),
          _ServiceNodeData(key: 'evenements', icon: Icons.event_rounded, title: l10n.t('serviceEvenements'), color: ThixPolicy.domainMedia, badge: c.events),
        ],
      ),
      _QuadrantBlock(
        label: l10n.t('blockCareer'),
        color: ThixPolicy.domainLearning,
        items: [
          _ServiceNodeData(key: 'formations', icon: Icons.school_rounded, title: l10n.t('serviceFormations'), color: ThixPolicy.domainLearning, badge: c.formations),
          _ServiceNodeData(key: 'emplois', icon: Icons.work_rounded, title: l10n.t('serviceEmplois'), color: ThixPolicy.domainLearning, badge: c.jobs),
          _ServiceNodeData(key: 'opportunites', icon: Icons.lightbulb_rounded, title: l10n.t('serviceOpportunites'), color: ThixPolicy.domainLearning, badge: c.opportunities),
        ],
      ),
      _QuadrantBlock(
        label: l10n.t('blockBusiness'),
        color: ThixPolicy.domainMarket,
        items: [
          _ServiceNodeData(key: 'thixMarket', icon: Icons.storefront_rounded, title: l10n.t('serviceMarket'), color: ThixPolicy.domainMarket, badge: c.market),
          _ServiceNodeData(key: 'thixMoney', icon: Icons.account_balance_wallet_rounded, title: l10n.t('serviceMoney'), color: ThixPolicy.domainMarket, badge: c.money),
          _ServiceNodeData(key: 'reservation', icon: Icons.confirmation_number_rounded, title: l10n.t('serviceReservation'), color: ThixPolicy.domainMarket, badge: c.reservation),
        ],
      ),
      _QuadrantBlock(
        label: l10n.t('blockCommunity'),
        color: ThixPolicy.domainNetwork,
        items: [
          _ServiceNodeData(key: 'reseauPro', icon: Icons.groups_rounded, title: 'THIX Pro', color: ThixPolicy.domainNetwork, badge: c.network),
          _ServiceNodeData(key: 'thixSante', icon: Icons.local_hospital_rounded, title: l10n.t('serviceSante'), color: ThixPolicy.domainNetwork, badge: c.health),
          _ServiceNodeData(key: 'monPays', icon: Icons.flag_rounded, title: l10n.t('serviceMonPays'), color: ThixPolicy.domainNetwork, badge: c.monPays),
        ],
      ),
    ];
  }

  Offset _polar(Offset center, double angleDeg, double radius) {
    final rad = angleDeg * math.pi / 180;
    return center + Offset(radius * math.cos(rad), radius * math.sin(rad));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final blocks = _blocks(l10n);

    final hubItems = <_HubMenuItemData>[
      _HubMenuItemData(icon: Icons.home_filled, label: l10n.t('hub_home'), onTap: () => _runHubItem(widget.onHomeTap)),
      _HubMenuItemData(icon: Icons.apps_rounded, label: l10n.t('hub_mini_apps'), onTap: () => _runHubItem(widget.onMiniAppsTap)),
      _HubMenuItemData(icon: Icons.folder_rounded, label: l10n.t('hub_documents'), onTap: () => _runHubItem(widget.onDocumentsTap)),
      _HubMenuItemData(icon: Icons.person_outline_rounded, label: l10n.t('hub_profile'), onTap: () => _runHubItem(widget.onProfileTap)),
      _HubMenuItemData(icon: Icons.qr_code_scanner_rounded, label: l10n.t('hub_scan_qr'), onTap: () => _runHubItem(widget.onScanTap)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, size: 15, color: ThixPolicy.textSecondary),
              const SizedBox(width: 6),
              Text(
                l10n.t('servicesTitle'),
                style: const TextStyle(color: ThixPolicy.textMain, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: -0.2),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: _stageHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final center = Offset(w / 2, _stageHeight / 2 - 6);
                final outerR = math.min(
                  w / 2 - ThixPolicy.constellationOuterPadding,
                  ThixPolicy.constellationMaxRadius,
                );
                final innerR = math.max(_hubMenuRadius + 22, outerR * 0.52);
                final nodeRingR = (innerR + outerR) / 2;

                // Positions des satellites du hub (menu Home/MiniApps/...)
                final hubPositions = <Offset>[];
                for (var i = 0; i < hubItems.length; i++) {
                  final angle = -90.0 + (i * (360.0 / hubItems.length));
                  hubPositions.add(_polar(center, angle, _hubMenuRadius));
                }

                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // ─── 4 SEGMENTS DE FOND (donut par catégorie) ───
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _QuadrantDonutPainter(
                              center: center,
                              innerRadius: innerR,
                              outerRadius: outerR,
                              blockCount: blocks.length,
                              blockColors: blocks.map((b) => b.color).toList(),
                              gapDeg: _gapDeg,
                            ),
                          ),
                        ),

                        // ─── LABELS DE CATÉGORIE (bord extérieur de chaque segment) ───
                        for (var qi = 0; qi < blocks.length; qi++)
                          Builder(builder: (context) {
                            final startAngle = -90.0 + qi * (360.0 / blocks.length);
                            final midAngle = startAngle + (360.0 / blocks.length) / 2;
                            final labelPos = _polar(center, midAngle, outerR + 14);
                            return Positioned(
                              left: labelPos.dx - 44,
                              top: labelPos.dy - 8,
                              child: SizedBox(
                                width: 88,
                                child: Text(
                                  blocks[qi].label,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                    color: blocks[qi].color,
                                  ),
                                ),
                              ),
                            );
                          }),

                        // ─── NŒUDS DE SERVICE (3 par bloc, posés sur l'anneau) ───
                        for (var qi = 0; qi < blocks.length; qi++)
                          for (var ni = 0; ni < blocks[qi].items.length; ni++)
                            Builder(builder: (context) {
                              final span = (360.0 / blocks.length) - (2 * _gapDeg);
                              final startAngle = -90.0 + qi * (360.0 / blocks.length) + _gapDeg;
                              final t = (ni + 1) / (blocks[qi].items.length + 1);
                              final angle = startAngle + span * t;
                              final pos = _polar(center, angle, nodeRingR);
                              final node = blocks[qi].items[ni];
                              return Positioned(
                                left: pos.dx - 35,
                                top: pos.dy - ThixPolicy.constellationNodeHalf,
                                child: _ConstellationNode(
                                  data: node,
                                  onTap: () => widget.onServiceTap(node.key),
                                ),
                              );
                            }),

                        // ─── SATELLITES DU HUB (menu Home/MiniApps/Documents/Profil/Scan) ───
                        for (var i = 0; i < hubItems.length; i++)
                          Positioned(
                            left: hubPositions[i].dx - (_hubMenuNodeSize / 2),
                            top: hubPositions[i].dy - (_hubMenuNodeSize / 2),
                            child: _HubSatelliteButton(
                              visible: _menuExpanded,
                              order: i,
                              size: _hubMenuNodeSize,
                              icon: hubItems[i].icon,
                              label: hubItems[i].label,
                              onTap: hubItems[i].onTap,
                            ),
                          ),

                        // ─── HUB CENTRAL ───
                        Positioned(
                          left: center.dx - _hubRadius,
                          top: center.dy - _hubRadius,
                          child: GestureDetector(
                            onTap: _toggleHubMenu,
                            child: Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.04),
                              child: AnimatedRotation(
                                turns: _menuExpanded ? 0.125 : 0,
                                duration: const Duration(milliseconds: 220),
                                child: Container(
                                  width: _hubRadius * 2, height: _hubRadius * 2,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [ThixPolicy.gold, ThixPolicy.premiumAccent],
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: ThixPolicy.gold.withValues(alpha: 0.40), blurRadius: 18, spreadRadius: 1),
                                      BoxShadow(color: ThixPolicy.premiumAccent.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 6)),
                                    ],
                                    border: Border.all(color: Colors.white, width: 2.4),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(_menuExpanded ? Icons.close_rounded : Icons.grid_view_rounded, color: Colors.white, size: 26),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PEINTRE DES 4 SEGMENTS DE DONUT (un par bloc/catégorie)
// ═══════════════════════════════════════════════════════════════════════════
class _QuadrantDonutPainter extends CustomPainter {
  final Offset center;
  final double innerRadius;
  final double outerRadius;
  final int blockCount;
  final List<Color> blockColors;
  final double gapDeg;

  _QuadrantDonutPainter({
    required this.center,
    required this.innerRadius,
    required this.outerRadius,
    required this.blockCount,
    required this.blockColors,
    required this.gapDeg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sweepPerBlock = 360.0 / blockCount;

    for (var i = 0; i < blockCount; i++) {
      final startDeg = -90.0 + i * sweepPerBlock + gapDeg;
      final endDeg = -90.0 + (i + 1) * sweepPerBlock - gapDeg;
      final startRad = startDeg * math.pi / 180;
      final sweepRad = (endDeg - startDeg) * math.pi / 180;

      final path = Path();
      final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
      final innerRect = Rect.fromCircle(center: center, radius: innerRadius);

      path.addArc(outerRect, startRad, sweepRad);
      final endRad = startRad + sweepRad;
      final innerEnd = center + Offset(innerRadius * math.cos(endRad), innerRadius * math.sin(endRad));
      path.lineTo(innerEnd.dx, innerEnd.dy);
      path.arcTo(innerRect, endRad, -sweepRad, false);
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..color = blockColors[i].withValues(alpha: 0.10)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = blockColors[i].withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _QuadrantDonutPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// SATELLITE DU HUB (menu Home/MiniApps/Documents/Profil/Scan) — inchangé
// ═══════════════════════════════════════════════════════════════════════════
class _HubSatelliteButton extends StatelessWidget {
  final bool visible;
  final int order;
  final double size;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HubSatelliteButton({required this.visible, required this.order, required this.size, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1.0 : 0.4,
      duration: Duration(milliseconds: 180 + order * 30),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Duration(milliseconds: 150 + order * 30),
        child: IgnorePointer(
          ignoring: !visible,
          child: Tooltip(
            message: label,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.premiumAccent.withValues(alpha: 0.35), width: 1.2),
                  boxShadow: ThixPolicy.shadowSoft(),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 15, color: ThixPolicy.premiumAccent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NŒUD DE SERVICE — inchangé
// ═══════════════════════════════════════════════════════════════════════════
class _ConstellationNode extends StatefulWidget {
  final _ServiceNodeData data;
  final VoidCallback onTap;
  const _ConstellationNode({required this.data, required this.onTap});
  @override State<_ConstellationNode> createState() => _ConstellationNodeState();
}

class _ConstellationNodeState extends State<_ConstellationNode> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 140));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final size = ThixPolicy.constellationNodeSize;
    final iconSize = ThixPolicy.constellationNodeIconSize;
    final fontSize = ThixPolicy.constellationLabelSize;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: size, height: size,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: d.color.withValues(alpha: 0.35), width: 1.2),
                      boxShadow: [BoxShadow(color: d.color.withValues(alpha: 0.22), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    alignment: Alignment.center,
                    child: Icon(d.icon, color: d.color, size: iconSize),
                  ),
                  if (d.badge != null && d.badge! > 0)
                    Positioned(
                      top: -4, right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: ThixPolicy.danger,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.2),
                        ),
                        child: Text('${d.badge}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                d.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: ThixPolicy.textMain, height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
