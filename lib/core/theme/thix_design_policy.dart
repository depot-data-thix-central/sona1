import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// THIX DESIGN POLICY
/// Source de vérité unique — même aspect Web + Mobile
/// Ne pas surcharger selon la plateforme.
/// ═══════════════════════════════════════════════════════════════
class ThixPolicy {
  ThixPolicy._();

  // ─────────────────────────────────────────────────────────────
  // COULEURS DE MARQUE
  // ─────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF2D6CDF);
  static const Color primaryDeep = Color(0xFF123B7A);
  static const Color inkDeep = Color(0xFF0A1F44);
  static const Color gold = Color(0xFFE3B23C);
  static const Color premiumAccent = Color(0xFFD4A017);

  // Surfaces
  static const Color surface = Color(0xFFF0F2F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color tint = Color(0xFFEEF3FF);

  // Texte
  static const Color textMain = Color(0xFF10192E);
  static const Color textSecondary = Color(0xFF7386A8);
  static const Color onBrand = Colors.white;

  // États
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Domaines (constellation / services)
  static const Color domainMedia = Color(0xFF7C3AED);
  static const Color domainMarket = Color(0xFFF97316);
  static const Color domainLearning = Color(0xFF2563EB);
  static const Color domainJobs = Color(0xFF16A34A);
  static const Color domainInfo = Color(0xFF0284C7);
  static const Color domainOpportunity = Color(0xFFF59E0B);
  static const Color domainEvents = Color(0xFFEF4444);
  static const Color domainNetwork = Color(0xFF4F46E5);
  static const Color domainHealth = Color(0xFFE11D48);
  static const Color domainMoney = Color(0xFF059669);
  static const Color domainGov = Color(0xFF334155);
  static const Color domainReservation = Color(0xFF0D9488);

  // ─────────────────────────────────────────────────────────────
  // ESPACEMENTS (grille 4 / 8)
  // ─────────────────────────────────────────────────────────────
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  // ─────────────────────────────────────────────────────────────
  // RAYONS
  // ─────────────────────────────────────────────────────────────
  static const double rSm = 12;
  static const double rMd = 16;
  static const double rLg = 20;
  static const double rXl = 24;
  static const double rFull = 999;

  // ─────────────────────────────────────────────────────────────
  // TYPO
  // ─────────────────────────────────────────────────────────────
  static const double titleLg = 18;
  static const double titleMd = 16;
  static const double body = 14;
  static const double caption = 12;
  static const double micro = 10;

  // ─────────────────────────────────────────────────────────────
  // CONSTELLATION — identique Web + Mobile (en dur)
  // ─────────────────────────────────────────────────────────────
  static const double constellationStageHeight = 360;
  static const double constellationMaxRadius = 148;
  static const double constellationInnerFactor = 0.70; // nœuds impairs
  static const double constellationHubRadius = 34;
  static const double constellationHubMenuRadius = 58;
  static const double constellationHubMenuNodeSize = 30;
  static const double constellationNodeSize = 52;
  static const double constellationNodeIconSize = 22;
  static const double constellationLabelSize = 10.5;
  static const double constellationNodeHalf = 35;
  static const double constellationOuterPadding = 34;

  // ─────────────────────────────────────────────────────────────
  // COMPOSANTS COMMUNS
  // ─────────────────────────────────────────────────────────────
  static const double minTapTarget = 44;
  static const double searchBarHeight = 48;
  static const double bottomNavHeight = 64;
  static const double appBarHeight = 72;

  // ─────────────────────────────────────────────────────────────
  // OMBRES
  // ─────────────────────────────────────────────────────────────
  static List<BoxShadow> shadowCard({double opacity = 0.08}) => [
        BoxShadow(
          color: inkDeep.withOpacity(opacity),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> shadowSoft({double opacity = 0.06}) => [
        BoxShadow(
          color: inkDeep.withOpacity(opacity),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> shadowNode({Color? color}) => [
        BoxShadow(
          color: (color ?? primary).withOpacity(0.18),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  // ─────────────────────────────────────────────────────────────
  // DÉGRADÉS
  // ─────────────────────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1F44), Color(0xFF2D6CDF)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE3B23C), Color(0xFFD4A017)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1F44), Color(0xFF1E3A8A), Color(0xFF2563EB)],
  );
}
